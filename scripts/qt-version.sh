#!/bin/sh

# Use gcc to get target string
GCC=$(which gcc 2> /dev/null)
EXISTS_GSS=$?
TARGET=""
if [ $EXISTS_GSS -eq 0 ] ; then
    TARGET=$(gcc -v 2>&1 | grep -e ^Target | cut -f 2 -d ' ')
fi

# List of possible qmake locations
QLOC=""
if [ -n $TARGET ] ; then
    # raspbian, debian (stretch and earlier), Ubuntu
    QLOC=/usr/lib/${TARGET}/qt5/bin/qmake
fi
# /usr/local/bin/qmake          <= FreeBSD
# /usr/lib/qt5/bin/qmake        <= Debian Buster
# /usr/bin/qmake-qt5            <= Fedora, Centos
# /usr/bin/qmake                <= Archlinux

QLOC="$QLOC \
    /usr/local/bin/qmake \
    /usr/lib/qt5/bin/qmake \
    /usr/bin/qmake-qt5 \
    /usr/bin/qmake \
"

for q in $QLOC ; do
    if [ -x $q ] ; then
        exec $q -v
    fi
done
echo "Can't find Qt5"
