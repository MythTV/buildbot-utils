#!/bin/sh

GCC=`which gcc 2> /dev/null`
EXISTS_GSS=$?
if [ $EXISTS_GSS -eq 0 ] ; then
    gcc --version
fi

CLANG=`which clang 2> /dev/null`
EXISTS_CLANG=$?
if [ $EXISTS_CLANG -eq 0 ] ; then
    clang --version
fi
