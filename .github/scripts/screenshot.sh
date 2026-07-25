#!/bin/bash
# Capture Connect IQ store screenshots for one device, using the demo build
# (monkey-demo.jungle) which shows realistic values without network access.
# One screenshot is saved per widget page (6 pages).
#
# The simulator segfaults roughly 20-30 seconds after startup under Xvfb,
# and also crashes on synthetic key/mouse input. So: no input events are
# used at all, and the simulator is restarted for every page. The demo
# build advances to the next page on each app launch (a counter in app
# storage, which persists on disk across simulator restarts).
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
SIM_WIN=""

start_sim_and_app() {
    simulator > /tmp/simulator.log 2>&1 &
    SIM_PID=$!
    sleep 6
    if ! kill -0 "$SIM_PID" 2>/dev/null; then
        echo "Simulator died during startup:"
        tail -5 /tmp/simulator.log || true
        return 1
    fi

    monkeydo bin/demo.prg "$DEVICE_ID" > /tmp/monkeydo.log 2>&1 &
    sleep 8

    if ! kill -0 "$SIM_PID" 2>/dev/null; then
        echo "Simulator died while launching the app:"
        tail -5 /tmp/simulator.log || true
        tail -5 /tmp/monkeydo.log || true
        return 1
    fi
    return 0
}

# Several simulator windows share the same class; the largest one holds
# the device rendering
find_main_window() {
    local best_area=0 id area
    SIM_WIN=""
    for id in $(xdotool search --class "simulator" 2>/dev/null); do
        eval "$(xdotool getwindowgeometry --shell "$id" 2>/dev/null)" || continue
        area=$((WIDTH * HEIGHT))
        if (( area > best_area )); then
            best_area=$area
            SIM_WIN=$id
        fi
    done
    [[ -n $SIM_WIN ]]
}

capture() {
    import -display "$DISPLAY" -window "$SIM_WIN" png:- \
        | convert - -trim +repage "$ROOT/$OUT_DIR/${DEVICE_ID}-page$1.png"
    echo "Captured page $1: $(identify -format '%wx%h' "$ROOT/$OUT_DIR/${DEVICE_ID}-page$1.png" 2>/dev/null || echo missing)"
}

stop_sim() {
    kill "$SIM_PID" 2>/dev/null
    wait "$SIM_PID" 2>/dev/null
    pkill -f monkeydo 2>/dev/null
    sleep 1
}

page_cycle() {
    local page=$1
    start_sim_and_app || { stop_sim; return 1; }
    find_main_window || { echo "No simulator window found"; stop_sim; return 1; }
    capture "$page" || { stop_sim; return 1; }
    stop_sim
    return 0
}

echo "Capturing all pages (fresh simulator per page)..."
for page in 1 2 3 4 5 6; do
    if ! page_cycle "$page"; then
        echo "Retrying page $page..."
        page_cycle "$page" || { echo "Page $page failed twice, giving up."; exit 1; }
    fi
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
