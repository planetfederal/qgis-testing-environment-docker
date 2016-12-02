#!/bin/bash
# $1 = ${QGIS_REPOSITORY}
# $2 = ${QGIS_BRANCH}
set -e


cd /build
git clone --depth 1 -b $2 $1
cd QGIS

if [ "$2"  != "master" ]; then
    cd src/plugins
    git clone  --depth 1 https://github.com/boundlessgeo/qgis-master-pass-cxxplugin.git
    mv qgis-master-pass-cxxplugin keychain_bridge
    echo 'ADD_SUBDIRECTORY(keychain_bridge)' >> CMakeLists.txt
fi
