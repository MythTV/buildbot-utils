#!/bin/sh

VERFILE=$1

echo "MythTV Version"
echo "---------------------------------------------------------------------"
cat $VERFILE
echo ""
echo ""

GCC=`which gcc`
EXISTS_GSS=$?
if [ $EXISTS_GSS -eq 0 ] ; then
    echo "GCC Version"
    echo "---------------------------------------------------------------------"
    gcc --version
    echo ""
    echo ""
fi

CLANG=`which clang`
EXISTS_CLANG=$?
if [ $EXISTS_CLANG -eq 0 ] ; then
    echo "Clang Version"
    echo "---------------------------------------------------------------------"
    clang --version
    echo ""
    echo ""
fi

if [ "x${MSYSTEM}x" = "xMINGW32x" ] ; then
    QMAKE=`cd $PWD/../../../../common/mythbuild/qt-everywhere-opensource-src-4.7.0/qmake ; pwd`/qmake
else
    QMAKE=`grep ^QMAKE= config.mak | cut -d= -f 2`
fi
echo "Qt Version"
echo "---------------------------------------------------------------------"
${QMAKE} --version
echo ""
echo ""

ICC=`which icc`
EXISTS_ICC=$?
if [ $EXISTS_ICC -eq 0 ] ; then
    echo "ICC Version (may not be relevant)"
    echo "---------------------------------------------------------------------"
    icc --version 2> /dev/null || echo "ICC is not available"
    icpc --version 2> /dev/null || echo "ICPC is not available"
    echo ""
    echo ""
fi

echo "System Memory"
echo "---------------------------------------------------------------------"
# Linux
OS=`uname -s`
if [ $OS = 'Linux' -a -x /usr/bin/free ] ; then
    /usr/bin/free -h
fi
# FreeBSD
if [ $OS = 'FreeBSD' -a -x /usr/bin/vmstat ] ; then
    /usr/bin/vmstat -h
fi
echo ""
echo ""
