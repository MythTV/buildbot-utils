#!/bin/bash
if [ -n "$EXTRAPATH" ] ; then
	export PATH=$PATH:$EXTRAPATH
fi

# Strip out excessive stupid ""
ARGS=`echo $*`
$ARGS
