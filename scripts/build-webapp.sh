#!/bin/bash

NPM=`which npm 2> /dev/null`
if [ $? -ne 0 ]; then
    echo "npm not installed, skipping webapp build"
    exit 0
fi

echo "npm is installed, running webapp build"

pushd html/backend > /dev/null
npm install
npm run build

popd > /dev/null
