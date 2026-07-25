#!/bin/bash
# Capture a Connect IQ store screenshot for one device, using the demo build
# (monkey-demo.jungle) which shows realistic values without network access.
#
# Designed to run inside the ghcr.io/matco/connectiq-tester container:
#
#   docker run --rm -v "$PWD":/work -w /work --entrypoint bash \
#     ghcr.io/matco/connectiq-tester:latest .github/scripts/screenshot.sh fr965
#
# Usage: screenshot.sh <device_id> [output-dir]
set -u

DEVICE_ID=${1:?device id required}
OUT_DIR=${2:-screenshots}

# Kill the simulator and Xvfb when the script exits
trap 'kill $(jobs -p) 2>/dev/null' EXIT

echo "Installing ImageMagick and xdotool for the capture..."
apt-get update -qq >/dev/null
apt-get install -y -qq --no-install-recommends imagemagick xdotool >/dev/null

echo "Generating temporary signing key (demo build only)..."
openssl genrsa -out /tmp/key.pem 4096 2>/dev/null
openssl pkcs8 -topk8 -inform PEM -outform DER -in /tmp/key.pem -out /tmp/key.der -nocrypt

ROOT=$(pwd)
mkdir -p "$ROOT/$OUT_DIR"

cd SolisWidget

echo "Building demo build for $DEVICE_ID..."
monkeyc -f monkey-demo.jungle -d "$DEVICE_ID" -o bin/demo.prg -y /tmp/key.der -w -l 0
if [[ ! -f bin/demo.prg ]]; then
    echo "Demo build failed!"
    exit 1
fi

echo "Starting headless simulator..."
export DISPLAY=:1
Xvfb "$DISPLAY" -screen 0 1600x1200x24 &
simulator > /dev/null 2>&1 &
sleep 5

echo "Launching widget in the simulator..."
monkeydo bin/demo.prg "$DEVICE_ID" &
# Give the app time to start and render the demo data
sleep 20

# No window manager runs in Xvfb, so grab the root display and trim the
# black background down to the simulator window
capture() {
    import -display "$DISPLAY" -window root png:- \
        | convert - -trim +repage "$ROOT/$OUT_DIR/${DEVICE_ID}-page$1.png"
    echo "Captured page $1"
}

# Focus the simulator window so key presses reach it
SIM_WIN=$(xdotool search --name "imulator" | head -1 || true)
if [[ -z ${SIM_WIN} ]]; then
    SIM_WIN=$(xdotool search --name ".*" | tail -1 || true)
fi
echo "Simulator window: ${SIM_WIN:-not found}"
if [[ -n ${SIM_WIN} ]]; then
    xdotool windowfocus --sync "$SIM_WIN" || true
fi

# Capture all six pages: Enter maps to the START/select button in the
# simulator, and onSelect advances the widget to the next page
echo "Capturing all pages..."
capture 1
for page in 2 3 4 5 6; do
    xdotool key --clearmodifiers Return
    sleep 3
    capture "$page"
done

if [[ ! -s "$ROOT/$OUT_DIR/${DEVICE_ID}-page1.png" ]]; then
    echo "Screenshot capture failed!"
    exit 1
fi
identify "$ROOT/$OUT_DIR/${DEVICE_ID}"-page*.png
echo "Saved page screenshots to $OUT_DIR/"
