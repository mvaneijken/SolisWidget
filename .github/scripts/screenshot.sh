#!/bin/bash
# Capture Connect IQ store screenshots for one device, using the demo build
# (monkey-demo.jungle) which shows realistic values without network access.
# One screenshot is saved per widget page (6 pages).
#
# The simulator is fragile under Xvfb: it can crash on synthetic input and
# sometimes shortly after device load. So: no input events at all, plain
# Xvfb, a fresh simulator per page, and the demo build advances to the next
# page on each app launch (a counter in app storage, persisted on disk).
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
apt-get install -y -qq --no-install-recommends \
    imagemagick xdotool x11-utils unzip curl ca-certificates >/dev/null

# Optionally replace the image's SDK (set SDK_VERSION); by default the
# image's own SDK and device files are used.
if [[ -n ${SDK_VERSION:-} ]]; then
    curl -fsS "https://developer.garmin.com/downloads/connect-iq/sdks/sdks.json" -o /tmp/sdks.json
    SDK_FILE=$(grep -o "connectiq-sdk-lin-${SDK_VERSION}[^\"]*" /tmp/sdks.json | head -1)
    if [[ -n $SDK_FILE ]]; then
        echo "Downloading $SDK_FILE..."
        curl -fsS "https://developer.garmin.com/downloads/connect-iq/sdks/$SDK_FILE" -o /tmp/sdk.zip \
            && mkdir -p /opt/sdk-alt \
            && unzip -qo /tmp/sdk.zip -d /opt/sdk-alt \
            && chmod +x /opt/sdk-alt/bin/* 2>/dev/null \
            && export PATH="/opt/sdk-alt/bin:$PATH"
    else
        echo "SDK $SDK_VERSION not offered — continuing with the image's SDK"
    fi
fi
echo "Using monkeyc: $(command -v monkeyc) — simulator: $(command -v simulator)"

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

# Several simulator windows share the same class; the largest one is the
# device rendering (only present once the device has loaded)
find_main_window() {
    local best_area=0 id area
    SIM_WIN=""
    for id in $(xdotool search --class "simulator" 2>/dev/null); do
        eval "$(xdotool getwindowgeometry --shell "$id" 2>/dev/null)" || continue
        area=$((WIDTH * HEIGHT))
        if (( area > best_area && area > 400000 )); then
            best_area=$area
            SIM_WIN=$id
        fi
    done
    [[ -n $SIM_WIN ]]
}

# Capture the device window; only accept a frame whose screen centre is
# dark (the widget draws white-on-black — a blank device screen is white).
# import can hang on a dead window, so the pipeline is bounded.
capture() {
    local page=$1 ok=1 i w dark
    local img="$ROOT/$OUT_DIR/${DEVICE_ID}-page$page.png"
    for i in $(seq 1 8); do
        if ! kill -0 "$SIM_PID" 2>/dev/null; then
            echo "Simulator no longer running (attempt $i)"
            break
        fi
        if ! find_main_window; then
            sleep 2
            continue
        fi
        if timeout 15 bash -c "import -display '$DISPLAY' -window '$SIM_WIN' png:- | convert - -trim +repage '$img.tmp'" 2>/dev/null; then
            w=$(identify -format '%w' "$img.tmp" 2>/dev/null || echo 0)
            dark=$(convert "$img.tmp" -gravity center -crop 30%x30%+0+0 +repage -colorspace Gray -format '%[fx:mean<0.6?1:0]' info: 2>/dev/null || echo 0)
            if (( w > 500 )) && [[ $dark == "1" ]]; then
                mv "$img.tmp" "$img"
                ok=0
                break
            fi
        fi
        sleep 2
    done
    rm -f "$img.tmp"
    if (( ok == 0 )); then
        echo "Captured page $page: $(identify -format '%wx%h' "$img" 2>/dev/null)"
    else
        echo "No valid capture for page $page"
    fi
    return $ok
}

stop_sim() {
    kill -9 "$SIM_PID" 2>/dev/null
    wait "$SIM_PID" 2>/dev/null || true
    pkill -9 -x simulator 2>/dev/null || true
    pkill -9 -f monkeybrains 2>/dev/null || true
    sleep 1
}

page_cycle() {
    local page=$1
    simulator > /tmp/simulator.log 2>&1 &
    SIM_PID=$!
    sleep 5
    monkeydo bin/demo.prg "$DEVICE_ID" > /tmp/monkeydo.log 2>&1 &
    sleep 15
    capture "$page"
    local rc=$?
    echo "--- monkeydo.log (page $page) ---"
    cat /tmp/monkeydo.log 2>/dev/null || true
    echo "--- simulator.log tail (page $page) ---"
    tail -5 /tmp/simulator.log 2>/dev/null || true
    echo "--- end logs ---"
    stop_sim
    return $rc
}

echo "Capturing all pages (fresh simulator per page)..."
for page in 1 2 3 4 5 6; do
    if ! page_cycle "$page"; then
        echo "Retrying page $page..."
        page_cycle "$page" || { echo "Page $page failed twice, giving up."; exit 1; }
    fi
done

# Final validation: every page must be a real device-sized image
for page in 1 2 3 4 5 6; do
    img="$ROOT/$OUT_DIR/${DEVICE_ID}-page$page.png"
    width=$(identify -format '%w' "$img" 2>/dev/null || echo 0)
    if [[ ${width} -lt 500 ]]; then
        echo "Screenshot for page $page is invalid (width ${width}px)!"
        exit 1
    fi
done
echo "All page screenshots captured successfully."
