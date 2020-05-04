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
CACHEDIR="${HOME}/.cache/buildbot/mythtv/${BRANCH}"

CACHEJSON="${CACHEDIR}/compile_commands.json"
LOCALJSON="compile_commands.json"

#
# Save compdb if newer
#
if [[ -e "${LOCALJSON}" ]] ; then
    if [[ "${LOCALJSON}" -nt "${CACHEJSON}" ]]; then
        echo "Copying ${LOCALJSON} to cache."
        cp -f "${LOCALJSON}" "${CACHEJSON}"
    else
        echo "Not copying ${LOCALJSON} to cache."
    fi
else
    echo "No ${LOCALJSON} file."
fi

