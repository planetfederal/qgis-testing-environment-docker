#!/bin/bash
# Accepts:
# $1 branch
# $2 legacy ("true"|"false")

set -e

mkdir /build/release
cd /build/release

CMAKE_EXTRA_ARGS=""

# 2.18, we want the OAuth2 plugin
if [[ "$1" == *"2_18"* ]]; then
    pushd .
    wget -O oauth_plugin.zip https://github.com/boundlessgeo/qgis-oauth-cxxplugin/archive/master.zip
    unzip oauth_plugin.zip
    mv qgis-oauth-cxxplugin-master/oauth2  /build/QGIS/src/auth/
    rm oauth_plugin.zip
    echo "ADD_SUBDIRECTORY(oauth2)" >> /build/QGIS/src/auth/CMakeLists.txt
    CMAKE_EXTRA_ARGS="-DWITH_INTERNAL_O2=OFF -DO2_LIBRARY_STATIC=/usr/local/lib/libo2.so -DO2_INCLUDE_DIR=/usr/local/include/o2"
    popd
fi



if [ "$2"  = "true" ]; then
    # Build for < master (Py2/Qt4)
    cmake /build/QGIS \
        -DQWT_INCLUDE_DIR=/usr/include/qwt-qt4 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DPYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython2.7.so \
        -DQSCINTILLA_INCLUDE_DIR=/usr/include/qt4 \
        -DWITH_QWTPOLAR=OFF \
        -DWITH_SERVER=ON \
        -DBUILD_TESTING=OFF \
        -DENABLE_TESTS=OFF \
        -DWITH_INTERNAL_QWTPOLAR=ON $CMAKE_EXTRA_ARGS
else
    # Build for master (Py3/Qt5)
    cmake /build/QGIS \
        -DPYTHON_VER=3 \
        -DWITH_GRASS=ON \
        -DWITH_GRASS7=ON \
        -DQWT_INCLUDE_DIR=/usr/include/qwt \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DPYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.5m.so \
        -DQSCINTILLA_INCLUDE_DIR=/usr/include/x86_64-linux-gnu/qt5/ \
        -DQSCINTILLA_LIBRARY=/usr/lib/libqt5scintilla2.so \
        -DWITH_QWTPOLAR=OFF \
        -DWITH_SERVER=ON \
        -DBUILD_TESTING=OFF \
        -DENABLE_TESTS=OFF \
        -DWITH_INTERNAL_QWTPOLAR=ON
fi

make install -j4
ldconfig

strip `find /usr/lib/ -name "libqgis*" -type f`
strip `find  /usr/share/qgis/ -name "*.so" -type f`
