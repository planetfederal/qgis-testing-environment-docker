FROM kartoza/qgis-base:v2
MAINTAINER Alessandro Pasotti <apasotti@boundlessgeo.com>

ARG QGIS_BRANCH=master
# Note: do not use git but https here!
ARG QGIS_REPOSITORY=https://github.com/qgis/QGIS.git

# Clone the specified branch from the specified repo:
RUN git clone --depth 1 -b ${QGIS_BRANCH} ${QGIS_REPOSITORY}; \
    mkdir /build; \
    cd /build; \
        cmake /QGIS \
        -DQWT_INCLUDE_DIR=/usr/include/qwt \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DPYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython2.7.so \
        -DQSCINTILLA_INCLUDE_DIR=/usr/include/qt4 \
        -DWITH_QWTPOLAR=OFF \
        -DWITH_SERVER=OFF \
        -DBUILD_TESTING=OFF \
        -DENABLE_TESTS=OFF \
        -DWITH_INTERNAL_QWTPOLAR=ON; \
    make install -j4; \
    cd /; \
    rm -rf /QGIS; \
    rm -rf /build; \
    ldconfig


# Use apt-catcher-ng caching
# Use local cached debs from host to save your bandwidth and speed thing up.
# APT_CATCHER_IP can be changed passing an argument to the build script:
# --build-arg APT_CATCHER_IP=xxx.xxx.xxx.xxx,
# set the IP to that of your apt-cacher-ng host or comment the following 2 lines
# out if you do not want to use caching
# ARG APT_CATCHER_IP=localhost
# RUN  echo 'Acquire::http { Proxy "http://'${APT_CATCHER_IP}':3142"; };' >> /etc/apt/apt.conf.d/01proxy

# Install required dependencies
RUN apt-get -y update
RUN apt-get install -y \
    vim \
    xvfb \
    python-pip \
    python-dev \
    supervisor \
    expect-dev

# Add install script
ADD requirements.txt /usr/local/requirements.txt
ADD install.sh /usr/local/bin/install.sh
RUN chmod +x /usr/local/bin/install.sh
RUN /usr/local/bin/install.sh

# Add QGIS test runner
ADD qgis_testrunner.py /usr/bin/qgis_testrunner.py
RUN chmod +x /usr/bin/qgis_testrunner.py
ADD qgis_testrunner.sh /usr/bin/qgis_testrunner.sh
RUN chmod +x /usr/bin/qgis_testrunner.sh
ADD qgis_setup.sh /usr/bin/qgis_setup.sh
RUN chmod +x /usr/bin/qgis_setup.sh

# Monkey patch to prevent modal stacktrace on python errors
ADD startup.py /root/.qgis2/python/startup.py

# Add start script
ADD supervisord.conf /etc/supervisor/
ADD supervisor.xvfb.conf /etc/supervisor/supervisor.d/

# This paths are for
# - kartoza images (compiled)
# - deb installed
# - built from git
# needed to find PyQt wrapper provided by QGIS
ENV PYTHONPATH=/usr/share/qgis/python/:/usr/lib/python2.7/dist-packages/qgis:/usr/share/qgis/python/qgis

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
