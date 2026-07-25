#!/bin/bash
# Capture Connect IQ store screenshots for one device, using the demo build
# (monkey-demo.jungle) which shows realistic values without network access.
# One screenshot is saved per widget page (6 pages).
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

echo "Installing capture tools..."
apt-get update -qq >/dev/null
apt-get install -y -qq --no-install-recommends imagemagick xdotool x11-utils >/dev/null

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

export DISPLAY=:1
Xvfb "$DISPLAY" -screen 0 1600x1200x24 &
sleep 2

SIM_PID=0

start_sim_and_app() {
    echo "Starting headless simulator..."
    simulator > /tmp/simulator.log 2>&1 &
    SIM_PID=$!
    sleep 8
    if ! kill -0 "$SIM_PID" 2>/dev/null; then
        echo "Simulator died during startup:"
        tail -5 /tmp/simulator.log || true
        return 1
    fi

    echo "Launching widget in the simulator..."
    monkeydo bin/demo.prg "$DEVICE_ID" > /tmp/monkeydo.log 2>&1 &
    sleep 12

    if ! kill -0 "$SIM_PID" 2>/dev/null; then
        echo "Simulator died while running the app:"
        tail -5 /tmp/simulator.log || true
        tail -5 /tmp/monkeydo.log || true
        return 1
    fi
    return 0
}

# The simulator occasionally crashes under Xvfb — retry once
if ! start_sim_and_app; then
    echo "Retrying simulator start..."
    kill $(jobs -p) 2>/dev/null
    sleep 2
    Xvfb "$DISPLAY" -screen 0 1600x1200x24 2>/dev/null &
    sleep 2
    start_sim_and_app || { echo "Simulator failed twice, giving up."; exit 1; }
fi

echo "Windows on the display:"
xwininfo -root -tree -display "$DISPLAY" | grep -E '^\s+0x' || true

# Find the main simulator window: several windows share the "simulator"
# class, so pick the largest one (the device rendering)
BEST_AREA=0
SIM_WIN=""
WX=0; WY=0; WW=0; WH=0
for id in $(xdotool search --class "simulator" 2>/dev/null); do
    eval "$(xdotool getwindowgeometry --shell "$id" 2>/dev/null)" || continue
    area=$((WIDTH * HEIGHT))
    if (( area > BEST_AREA )); then
        BEST_AREA=$area
        SIM_WIN=$id
        WX=$X; WY=$Y; WW=$WIDTH; WH=$HEIGHT
    fi
done
if [[ -z $SIM_WIN ]]; then
    echo "Could not find the simulator window!"
    exit 1
fi
echo "Main simulator window: $SIM_WIN (${WW}x${WH}+${WX}+${WY})"

capture() {
    if ! kill -0 "$SIM_PID" 2>/dev/null; then
        echo "Simulator is no longer running at page $1!"
        tail -5 /tmp/simulator.log || true
        return 1
    fi
    import -display "$DISPLAY" -window "$SIM_WIN" png:- \
        | convert - -trim +repage "$ROOT/$OUT_DIR/${DEVICE_ID}-page$1.png"
    echo "Captured page $1: $(identify -format '%wx%h' "$ROOT/$OUT_DIR/${DEVICE_ID}-page$1.png" 2>/dev/null || echo missing)"
}

# Capture all six pages. The simulator crashes on synthetic key/mouse
# input under Xvfb, so no input is sent at all: the demo build cycles to
# the next page on every app launch (a counter in app storage), and the
# app is simply relaunched with monkeydo between captures.
echo "Capturing all pages..."
capture 1 || exit 1
for page in 2 3 4 5 6; do
    monkeydo bin/demo.prg "$DEVICE_ID" > /tmp/monkeydo.log 2>&1 &
    sleep 10
    capture "$page" || exit 1
done

# Validate: a blank display trims down to a tiny image
for page in 1 2 3 4 5 6; do
    img="$ROOT/$OUT_DIR/${DEVICE_ID}-page$page.png"
    width=$(identify -format '%w' "$img" 2>/dev/null || echo 0)
    if [[ ${width} -lt 100 ]]; then
        echo "Screenshot for page $page is blank (width ${width}px) — capture failed!"
        exit 1
    fi
done
echo "All page screenshots captured successfully."
