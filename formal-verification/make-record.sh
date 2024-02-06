#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

FORMAL_VERIFICATION_DIR="$SCRIPT_DIR"

# This one is used if you want to do some changes to the files in the patched directory
# and then rcord the changes in the diff folder as .patch files 
make -C "$FORMAL_VERIFICATION_DIR" record 
