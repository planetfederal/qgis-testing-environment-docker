qgis-testing-environment
================================

This is a simple container for testing QGIS Desktop and for
executing unit tests inside a real QGIS instance.

# Features

The docker file builds QGIS from a specified git repo and branch and
sets up a testing environment and to run tests inside QGIS.

You can use this docker to test QGIS or to run unit tests inside QGIS,
xvfb is available and running as a service inside the container to allow
for fully automated headless testing in Travis CI jobs.

# Building

You can build the image with:

```
$ docker build -t qgis-testing-environment \
    --build-arg QGIS_REPOSITORY='https://github.com/qgis/QGIS.git' \
    --build-arg QGIS_BRANCH='master' .
```

Optional APT CATCHER support can be activated by uncommenting a few lines in the
docker file (see the comments in `Dockerfile`).

# Building with Vagrant

A `Vagrantfile` is available for *AWS* and *VirtualBox* providers.

A set of environment variables can be used to configure the build:

- **SHELL_ARGS** the parameters passed to the build script in this order:
    - *REPO* defaults to `https://github.com/qgis/QGIS.git`
    - *BRANCH* defaults to `master`
    - *TAG* defaults to `master` (this is the Docker image tag and not the git tag)
    - *DOCKER_HUB_USERNAME* no default
    - *DOCKER_HUB_PASSWORD* no default


 for the *AWS* provider:

- **AWS_KEY**
- **AWS_SECRET**
- **AWS_KEYNAME**
- **AWS_KEYPATH**
- **AWS_REGION**
- **AWS_AMI** : this might depend on the region, the tests were performed on
  "ami-87564feb", that is a standard Ubuntu 14.04 available in region eu-central-1
- **AWS_INST_TYPE** : instance type to launch, e.g. "m3.large"


Example run script for the *AWS* provider (`AWS_*` env vars are not shown):

    #!/bin/bash
    # Pass arguments to vagrant to configure the build
    #
    # None of the arguments is mandatory,
    # 1: REPO default: https://github.com/qgis/QGIS.git
    # 2: BRANCH default: master
    # 3: TAG (for the generated Docker image): default: master
    # 4: DOCKER_HUB_USERNAME: no default
    # 5: DOCKER_HUB_PASSWORD: no default

    REPO="https://github.com/qgis/QGIS.git"
    BRANCH="master"
    TAG="master"
    DOCKER_HUB_USERNAME="mydockerusername"
    DOCKER_HUB_PASSWORD="mydockerpassword"

    ARGS="$REPO $BRANCH $TAG $DOCKER_HUB_USERNAME \
         $DOCKER_HUB_PASSWORD"
    SHELL_ARGS="${ARGS}" vagrant up --provider=aws
    vagrant -f destroy

# Configuring a Jenkins job to do automatic builds

Jenkins needs Vagrant and Git plugins.
Vagrant needs the AWS plugin installed and available for the `jenkins` user:

    $ sudo -iu jenkins vagrant plugin install vagrant-aws

# Running QGIS

To run a container, assuming that you want to use your current display to use
QGIS and the image is named `qgis-testing-environment`:

```
# Allow connections from any host
$ xhost +
$ docker run --rm  -it --name qgis-testing-environment -v /tmp/.X11-unix:/tmp/.X11-unix  \
    -e DISPLAY=unix$DISPLAY qgis-testing-environment qgis
```

# Running unit tests inside QGIS

Suppose that you have local directory containing the tests to execute into
QGIS:

```
/my_tests/travis_tests/
├── faketest.py
├── __init__.py
├── tclass.py
└── test_TravisTest.py
```

To run the tests inside the container, you have to mount the directory that
contains the tests (e.g. your local directory `/my_tests`) into a volume
that is accessible by the container.


```
$ docker run -d --name qgis-testing-environment -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v /my_tests/:/tests_directory -e DISPLAY=:99 qgis-testing-environment

```

When done, you can invoke the test runnner (output follows, the failure is
expected):

```
$ docker exec -it qgis-testing-environment sh -c "qgis_testrunner.sh travis_tests.test_TravisTest.run_fail"
QGIS Test Runner - Trying to import travis_tests.test_TravisTest
QGIS Test Runner - launching QGIS as qgis --nologo --noversioncheck --code /usr/bin/qgis_testrunner.py travis_tests.test_TravisTest ...
QGIS Test Runner - QGIS exited with returncode: 143
Warning: QCss::Parser - Failed to load file  "/style.qss"
QInotifyFileSystemWatcherEngine::addPaths: inotify_add_watch failed: No such file or directory
Warning: QFileSystemWatcher: failed to add paths: /root/.qgis2//project_templates
QGIS Test Runner Inside - starting the tests ...
QGIS Test Runner - Trying to import travis_tests.test_TravisTest
test_QGIS_is_available (travis_tests.test_TravisTest.TravisTestsTests)
Test QGIS bindings can be imported ... ok
test_funca (travis_tests.test_TravisTest.TravisTestsTests)
Test funcA function ... ok
test_funcb (travis_tests.test_TravisTest.TravisTestsTests)
Test funcB function ... ok
test_funcb_fails (travis_tests.test_TravisTest.TravisTestsTests)
Test funcB function fails ... FAIL

======================================================================
FAIL: test_funcb_fails (travis_tests.test_TravisTest.TravisTestsTests)
Test funcB function fails
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/tests_directory/travis_tests/test_TravisTest.py", line 33, in test_funcb_fails
    self.assertEqual(c.funcB(), '')
AssertionError: 'B' != ''

----------------------------------------------------------------------
Ran 4 tests in 0.001s

FAILED (failures=1)
```

## Options for the test runner

The env var `QGIS_EXTRA_OPTIONS` defaults to an empty string and can
contains extra parameters that are passed to QGIS by the test runner.


# Implementation notes

The main goal of this image was to execute unit tests inside a real instance
of QGIS (not a mocked one).

The QGIS tests should be runnable from a Travis CI job.

The implementation is:

- run the docker, mounting as volumes the unit tests folder in `/tests_directory`
    (or the QGIS plugin   folder if the unit tests belong to a plugin and the
    plugin is needed to run the tests)
- execute `qgis_setup.sh MyPluginName` script in docker that sets up QGIS to
  avoid blocking modal dialogs  and installs the plugin into QGIS if needed
    - create config and python plugin folders for QGIS
    - disable tooltips in the `QGIS2.conf` file
    - enable the plugin  in the `QGIS2.conf` file
    - install the `startup.py` script to disable python exception modal dialogs
- execute the tests by running `qgis_testrunner.sh MyPluginName.tests.tests_MyTestModule.run_my_tests_function`
- the output of the tests is captured by the `test_runner.sh` script and
  searched for `FAILED` (that is in the standard unit tests output), if
  that string is present in the output, the script exists with `1` else
  it exits with `0`.

`qgis_testrunner.sh` accepts a dotted notation path to the test module that
can end with the function that has to be called inside the module to run the
tests. The last part (`.run_my_tests_function`) can be omitted and defaults to
`run_all`.


# Running in Travis

This is a simple use case for running unit tests of a small QGIS plugin:

```
services:
    - docker
before_install:
    # Build this docker:
    # - cd qgis-testing-environment && docker build -t qgis-testing-environment .
    # or just pull it:
    - docker pull elpaso/qgis-testing-environment:latest
install:
    - docker run -d --name qgis-testing-environment -v ${TRAVIS_BUILD_DIR}:/tests_directory -e DISPLAY=:99 elpaso/qgis-testing-environment
    - sleep 10
    # Setup qgis and enable the plugin
    - docker exec -it qgis-testing-environment sh -c "qgis_setup.sh QuickWKT"
    # If needd additional steps (for example make or paver setup, place it here)
    # Link the plugin to the tests_directory
    - docker exec -it qgis-testing-environment sh -c "ln -s /tests_directory /root/.qgis2/python/plugins/QuickWKT"

script:
    - docker exec -it qgis-testing-environment sh -c "qgis_testrunner.sh QuickWKT.tests.test_Plugin"
```
