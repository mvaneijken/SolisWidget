#!/bin/bash
# Build the store-uploadable .iq package, compiling the app for every device
# listed in the manifest (this is the main "is it publishable" check).
#
# Designed to run inside the ghcr.io/matco/connectiq-tester container:
#
#   docker run --rm -v "$PWD":/work -w /work --entrypoint bash \
#     ghcr.io/matco/connectiq-tester:latest \
#     .github/scripts/build-iq.sh developer_key.der bin/SolisWidget.iq
#
# Usage: build-iq.sh <signing-key-path> [output-path]
# Both paths are relative to the repository root.
set -eu

KEY_PATH=${1:?signing key path required}
OUTPUT=${2:-bin/SolisWidget.iq}

ROOT=$(pwd)
mkdir -p "$(dirname "$ROOT/$OUTPUT")"

cd SolisWidget
echo "Building release export package..."
monkeyc -e -f monkey.jungle -o "$ROOT/$OUTPUT" -y "$ROOT/$KEY_PATH" -r -w -l 0

if [[ ! -f "$ROOT/$OUTPUT" ]]; then
    echo "Export build failed!"
    exit 1
fi
echo "Built $OUTPUT"
