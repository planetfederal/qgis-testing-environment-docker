#!/bin/bash
# Accepts:
# $1 branch
# $2 legacy ("true"|"false")

set -e

apt-get remove -y --purge qt4-qmake cmake-data qt4-linguist-tools libqt4-dev-bin

# Keep python dev and other libs we need to build psutils for reporting plugin
dpkg --purge `dpkg -l "*-dev" | egrep -v 'libexpat|python' | sed -ne 's/ii  \(.*-dev\(:amd64\)\?\) .*/\1/p'` || true

if [ "$2"  != "true" ]; then
    # Clean for master (Py3/Qt5)
    apt-get remove -y libqt4* libgtk* libsane gfortran-5 *gnome* libsane *pango* \
                   glib* *gphoto*
fi

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
rm -rf /build
