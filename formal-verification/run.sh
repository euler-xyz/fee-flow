#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Running make record"

source "$SCRIPT_DIR"/make-patch.sh

# get any params passed to this script
# e.g. ./run.sh --no-compile
# and pass them to the node command
node "$SCRIPT_DIR"/runCertora.js "$@"
