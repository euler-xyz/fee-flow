#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Running make record"

"$SCRIPT_DIR"/make-patch.sh

# get any args passed to this script
args=("$@")

# check if the arg is only one
if [ $# -eq 1 ]; then
  # if the arg is only one, then it is the file name
  FILE_NAME=$1
  certoraRun  "$SCRIPT_DIR"/certora/conf/"$FILE_NAME".conf
else 
  # if we have more than one arg, then we have an invalid number of args
  # error "Invalid number of arguments"
  if [ $# -gt 1 ]; then
	echo "Invalid number of arguments"
	exit 1
  else
    # if we have no args, then we run the default conf file
	certoraRun  "$SCRIPT_DIR"/certora/conf/default.conf
  fi	
fi
