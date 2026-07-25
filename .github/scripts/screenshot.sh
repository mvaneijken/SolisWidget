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

echo "Installing capture tools and software OpenGL..."
apt-get update -qq >/dev/null
apt-get install -y -qq --no-install-recommends \
    imagemagick xdotool x11-utils \
    libgl1 libglx-mesa0 libgl1-mesa-dri libegl1 mesa-utils >/dev/null

# The simulator segfaults shortly after loading the device skin when no
# usable OpenGL is present — force Mesa software rendering
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe

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
Xvfb "$DISPLAY" -screen 0 1600x1200x24 +extension GLX +render -noreset &
sleep 2
glxinfo -B 2>/dev/null | head -6 || echo "glxinfo unavailable"

SIM_PID=0
SIM_WIN=""

start_sim_and_app() {
    simulator > /tmp/simulator.log 2>&1 &
    SIM_PID=$!
    sleep 4
    if ! kill -0 "$SIM_PID" 2>/dev/null; then
        echo "Simulator died during startup:"
        tail -5 /tmp/simulator.log || true
        return 1
    fi

    monkeydo bin/demo.prg "$DEVICE_ID" > /tmp/monkeydo.log 2>&1 &
    return 0
}

# Several simulator windows share the same class; the plain main window
# (with menu bar) is ~450x670, while the device rendering opens as a
# separate larger window once monkeydo has loaded the device
find_main_window() {
    local best_area=0 id area
    SIM_WIN=""
    SIM_AREA=0
    for id in $(xdotool search --class "simulator" 2>/dev/null); do
        eval "$(xdotool getwindowgeometry --shell "$id" 2>/dev/null)" || continue
        area=$((WIDTH * HEIGHT))
        if (( area > best_area )); then
            best_area=$area
            SIM_WIN=$id
            SIM_AREA=$area
        fi
    done
    [[ -n $SIM_WIN ]]
}

# Wait until the device window exists (bigger than the ~300k px main
# window), checking that the simulator stays alive meanwhile
wait_for_device_window() {
    local i
    for i in $(seq 1 25); do
        if ! kill -0 "$SIM_PID" 2>/dev/null; then
            echo "Simulator died while waiting for the device window:"
            tail -5 /tmp/simulator.log || true
            tail -5 /tmp/monkeydo.log || true
            return 1
        fi
        if find_main_window && (( SIM_AREA > 400000 )); then
            return 0
        fi
        sleep 1
    done
    echo "Device window never appeared."
    return 1
}

# Capture the device window repeatedly (the widget needs a moment to
# draw after the window appears, and the simulator can crash at any
# time) — keep the newest successful image. import can hang on a dead
# window, so the pipeline is bounded with timeout.
capture() {
    local page=$1 ok=1 i w dark
    local img="$ROOT/$OUT_DIR/${DEVICE_ID}-page$page.png"
    for i in $(seq 1 12); do
        if ! kill -0 "$SIM_PID" 2>/dev/null; then break; fi
        find_main_window || break
        if timeout 15 bash -c "import -display '$DISPLAY' -window '$SIM_WIN' png:- | convert - -trim +repage '$img.tmp'" 2>/dev/null; then
            w=$(identify -format '%w' "$img.tmp" 2>/dev/null || echo 0)
            # The widget draws white text on a black screen; before the app
            # has launched the device screen is blank white — only accept a
            # frame whose screen centre is dark
            dark=$(convert "$img.tmp" -gravity center -crop 30%x30%+0+0 +repage -colorspace Gray -format '%[fx:mean<0.6?1:0]' info: 2>/dev/null || echo 0)
            if (( w > 500 )) && [[ $dark == "1" ]]; then
                mv "$img.tmp" "$img"
                ok=0
                # One more loop iteration replaces this frame with a newer
                # one if the app redraws; two good frames are plenty
                if (( i > 1 )); then break; fi
            fi
        fi
        sleep 2
    done
    rm -f "$img.tmp"
    if (( ok == 0 )); then
        echo "Captured page $page: $(identify -format '%wx%h' "$img" 2>/dev/null)"
    else
        echo "No valid capture for page $page"
        tail -3 /tmp/simulator.log || true
        tail -5 /tmp/monkeydo.log || true
    fi
    return $ok
}

stop_sim() {
    # SIGKILL: the simulator can ignore SIGTERM, which would hang wait
    kill -9 "$SIM_PID" 2>/dev/null
    wait "$SIM_PID" 2>/dev/null || true
    pkill -9 -x simulator 2>/dev/null || true
    pkill -9 -f monkeybrains 2>/dev/null || true
    sleep 1
}

page_cycle() {
    local page=$1
    start_sim_and_app || { stop_sim; return 1; }
    wait_for_device_window || { stop_sim; return 1; }
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
    if [[ ${width} -lt 500 ]]; then
        echo "Screenshot for page $page is blank (width ${width}px) — capture failed!"
        exit 1
    fi
done
echo "All page screenshots captured successfully."
