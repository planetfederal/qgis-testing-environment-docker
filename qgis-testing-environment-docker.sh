#!/bin/bash
# Launch Vagrant to build a QGIS Docker image on an AWS instance
#
#
# The following variables must be set in the env
# and are passed to Vagrant
#
# REPO default: https://github.com/qgis/QGIS.git
# BRANCH default: master
# TAG (for the generated Docker image): default: master
# LEGACY Py2/Qt4 build: default: false
# DOCKER_HUB_USERNAME: no default
# DOCKER_HUB_PASSWORD: no default
# DOCKER_HUB_ACCOUNT: default to DOCKER_HUB_USERNAME
# VAGRANT_LOG: no default, set to "debug" for verbose output
#
# AWS_KEY: no default
# AWS_SECRET: no default
# AWS_KEYNAME: no default
# AWS_KEYPATH: no default (jenkins user must own this file and chmod 0600)
# AWS_REGION: no default


cd "${WORKSPACE}"

ARGS="$REPO $BRANCH $TAG $LEGACY $DOCKER_HUB_USERNAME $DOCKER_HUB_PASSWORD $DOCKER_HUB_ACCOUNT"
SHELL_ARGS="${ARGS}" vagrant up --provider=aws
vagrant destroy -f
