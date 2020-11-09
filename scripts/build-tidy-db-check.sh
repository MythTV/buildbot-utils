#!/bin/bash

function parse_git_branch() {
    git branch --contains 2>/dev/null  \
        | sed -e '/^[^*]/d'            \
              -e 's/\* //'             \
              -e 's/(\(.*\))/\1/'      \
              -e 's/.*\///'            \
              -e 's/\(.*\)/\1/'
}

#
# Find the top of the MythTV source
#
while [[ ! -e ".git" ]] ; do
    cd ..
    if [[ `pwd` == "/" ]] ; then
        echo "fail"
        exit
    fi
done

#
# Need storage outside the tree
#
BRANCH=$( parse_git_branch )
CACHEDIR="${HOME}/.cache/buildbot/mythtv${1}/${BRANCH}"
mkdir -p "${CACHEDIR}"
if [[ ! -e "${CACHEDIR}" ]] ; then
   echo "cachefail"
   exit
fi
CACHECSUM="${CACHEDIR}/source-checksum"
CACHEJSON="${CACHEDIR}/compile_commands.json"
LOCALJSON="compile_commands.json"

#
# Current checksum of source file names
#
CHECKSUM=$( find . -name \*.cpp -o -name \*.c -o -name \*.h | md5sum | cut -b -32 )

#
# Compare to previous checksum and report
#
if [[ ! -e "${CACHEJSON}" ]] ; then
    echo ${CHECKSUM} > "${CACHECSUM}"
    echo "new"
    exit
fi

if [[ ! -e "${CACHECSUM}" ]] ; then
    echo ${CHECKSUM} > "${CACHECSUM}"
    echo "new2"
    exit
fi

line=$( head -n 1 "${CACHECSUM}" )
if [[ $line != ${CHECKSUM} ]]; then
    echo ${CHECKSUM} > "${CACHECSUM}"
    echo "changed"
else
    cp -a "${CACHEJSON}" "${LOCALJSON}"
    echo "ok"
fi
