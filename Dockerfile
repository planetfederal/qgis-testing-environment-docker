FROM ubuntu:16.04
MAINTAINER Alessandro Pasotti <apasotti@boundlessgeo.com>

################################################################################
# build arguments: branch and repository
# WARNING: if branch == "master" Py3 and Qt5 build will be activated

ARG QGIS_BRANCH=master
# Note: do not use git but https here!
ARG QGIS_REPOSITORY=https://github.com/qgis/QGIS.git


################################################################################
# apt-catcher-ng caching:

# Use local cached debs from host to save your bandwidth and speed thing up.
# APT_CATCHER_IP can be changed passing an argument to the build script:
# --build-arg APT_CATCHER_IP=xxx.xxx.xxx.xxx,
# set the IP to that of your apt-cacher-ng host or comment the following 2 lines
# out if you do not want to use caching
ARG APT_CATCHER_IP
RUN  if [ "${APT_CATCHER_IP}" != "" ]; then \
        echo 'Acquire::http { Proxy "http://'${APT_CATCHER_IP}':3142"; };' >> /etc/apt/apt.conf.d/01proxy; \
     fi


################################################################################
# QGIS build

# Add install script for testing environment python packages
# This is not directly related to QGIS build but the installation
# will be handled by getDeps script
ADD requirements.txt /usr/local/requirements.txt

COPY scripts /build/scripts

# Install dependencies and git clone the repo and Make it
RUN /build/scripts/getDeps.sh ${QGIS_BRANCH}
RUN cd /build && /build/scripts/getCode.sh ${QGIS_REPOSITORY} ${QGIS_BRANCH}
RUN cd /build && /build/scripts/make.sh ${QGIS_BRANCH}


################################################################################
# Testing environment setup

# Add QGIS test runner
ADD qgis_*.* /usr/bin/

RUN chmod +x /usr/bin/qgis_*

# Add service configuration script
ADD supervisord.conf /etc/supervisor/
ADD supervisor.xvfb.conf /etc/supervisor/supervisor.d/

# This paths are for
# - kartoza images (compiled)
# - deb installed
# - built from git
# needed to find PyQt wrapper provided by QGIS
ENV PYTHONPATH=/usr/share/qgis/python/:/usr/lib/python2.7/dist-packages/qgis:/usr/lib/python3/dist-packages/qgis:/usr/share/qgis/python/qgis

# Remove some unnecessary files
RUN /build/scripts/clean.sh ${QGIS_BRANCH}

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
