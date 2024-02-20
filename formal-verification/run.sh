#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Running make record"

"$SCRIPT_DIR"/make-patch.sh

# get any args passed to this script
args=("$@")

# if the arg is only one, then it is the file name
FILE_NAME=$1
# append all the rest of args 
REST_OF_ARGS=${args[@]:1}
certoraRun  "$SCRIPT_DIR"/certora/conf/"$FILE_NAME".conf $REST_OF_ARGS
