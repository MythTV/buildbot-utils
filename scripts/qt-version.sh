#!/bin/sh

if [ "$#" -gt 1 ]; then
  echo "Usage: $0 [qt6]" >&2
  exit 1
elif [ "$#" -eq 1 ]; then
    case "$1" in
        qt*)
            qtver="$(echo $1 | tr -d -c '0123456789')"
            ;;
        *)
            echo "Usage: $0 qt<num>" >&2
            exit 1
            ;;
    esac
else
    qtver="5"
fi

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
    QLOC=/usr/lib/${TARGET}/qt${qtver}/bin/qmake
fi
# /usr/local/lib/qt5/bin/qmake  <= FreeBSD
# /usr/lib/qt5/bin/qmake        <= Debian Buster
# /usr/bin/qmake-qt5            <= Fedora, Centos
# /usr/bin/qmake                <= Archlinux

QLOC="$QLOC \
    /usr/local/lib/qt${qtver}/bin/qmake \
    /usr/lib/qt${qtver}/bin/qmake \
    /usr/bin/qmake-qt${qtver} \
    /usr/bin/qmake${qtver} \
    /usr/bin/qmake \
"

for q in $QLOC ; do
    if [ -x $q ] ; then
        exec $q -v
    fi
done
echo "Can't find Qt${qtver}"
