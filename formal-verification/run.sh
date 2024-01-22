#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Running make record"

"$SCRIPT_DIR"/make-patch.sh

certoraRun  "$SCRIPT_DIR"/certora/conf/default.conf
