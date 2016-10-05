#!/bin/bash
set -e

mkdir /build/release
cd /build/release


if [ "$1"  != "master" ]; then
    # Build for < master (Py2/Qt4)
    cmake /build/QGIS \
        -DQWT_INCLUDE_DIR=/usr/include/qwt-qt4 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DPYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython2.7.so \
        -DQSCINTILLA_INCLUDE_DIR=/usr/include/qt4 \
        -DWITH_QWTPOLAR=OFF \
        -DWITH_SERVER=OFF \
        -DBUILD_TESTING=OFF \
        -DENABLE_TESTS=OFF \
        -DWITH_INTERNAL_QWTPOLAR=ON
else
    # Build for master (Py3/Qt5)
    cmake /build/QGIS \
        -DQWT_INCLUDE_DIR=/usr/include/qwt \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DPYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.5m.so \
        -DQSCINTILLA_INCLUDE_DIR=/usr/include/x86_64-linux-gnu/qt5/ \
        -DQSCINTILLA_LIBRARY=/usr/lib/libqt5scintilla2.so \
        -DWITH_QWTPOLAR=OFF \
        -DWITH_SERVER=OFF \
        -DBUILD_TESTING=OFF \
        -DENABLE_TESTS=OFF \
        -DWITH_INTERNAL_QWTPOLAR=ON
fi

make install -j4
ldconfig

strip `find /usr/lib/ -name "libqgis*" -type f`
strip `find  /usr/share/qgis/ -name "*.so" -type f`
