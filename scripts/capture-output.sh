#!/bin/bash

if [[ $# -lt 2 ]] ; then
    echo "Usage: $0 <output-file> <command> [<arg1> ...]"
fi

OUTPUT=$1
shift
echo "Running: $* |& tee $OUTPUT"
$* |& tee $OUTPUT
