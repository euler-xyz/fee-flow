#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

FORMAL_VERIFICATION_DIR="$SCRIPT_DIR"

echo "Deleting old patched directory"
rm -rf "$FORMAL_VERIFICATION_DIR"/patched
echo "-------------------------------------"

echo

echo "Recreating patches..."
make -C "$FORMAL_VERIFICATION_DIR" apply
