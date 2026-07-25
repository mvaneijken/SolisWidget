#!/bin/bash
# Run the Connect IQ "Run No Evil" unit tests headlessly.
#
# Designed to run inside the ghcr.io/matco/connectiq-tester container, which
# bundles the Connect IQ SDK, device files and the simulator:
#
#   docker run --rm -v "$PWD":/work -w /work --entrypoint bash \
#     ghcr.io/matco/connectiq-tester:latest .github/scripts/run-tests.sh fenix7
#
# The container's own entrypoint compiles with strict type checking (-l 3),
# which this codebase does not use — this script mirrors it with type
# checking disabled (-l 0) instead.
#
# Usage: run-tests.sh [device_id]
set -u

DEVICE_ID=${1:-fenix7}
APP_DIR="SolisWidget"

# Kill the simulator and Xvfb when the script exits
trap 'kill $(jobs -p) 2>/dev/null' EXIT

echo "Generating temporary signing key (test build only)..."
openssl genrsa -out /tmp/key.pem 4096 2>/dev/null
openssl pkcs8 -topk8 -inform PEM -outform DER -in /tmp/key.pem -out /tmp/key.der -nocrypt

cd "$APP_DIR"

echo "Compiling unit-test build for $DEVICE_ID..."
monkeyc -f monkey.jungle -d "$DEVICE_ID" -o bin/app-test.prg -y /tmp/key.der -t -w -l 0
if [[ ! -f bin/app-test.prg ]]; then
    echo "Compilation failed!"
    exit 1
fi

echo "Starting headless simulator..."
export DISPLAY=:1
Xvfb "$DISPLAY" -screen 0 1280x1024x24 &
simulator > /dev/null 2>&1 &
sleep 5

echo "Running tests..."
result_file=/tmp/result.txt
# monkeydo always exits with code 1, even when all tests pass,
# so success is determined by parsing its output instead
timeout 300 monkeydo bin/app-test.prg "$DEVICE_ID" -t > "$result_file"
cat "$result_file"

result=$(tail -1 "$result_file")
if [[ $result == PASSED* ]]; then
    echo "Tests passed."
    exit 0
else
    echo "Tests failed!"
    exit 1
fi
