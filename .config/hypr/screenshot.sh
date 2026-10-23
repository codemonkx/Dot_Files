#!/usr/bin/env bash
# ~/.config/hypr/screenshot.sh
# Interactive & CLI screenshot engine for Hyprland + Quickshell
# Supports Selection, Screen, and Window modes with persistent clipboard copy, audio feedback, and notification preview.

export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export LANG="${LANG:-en_US.UTF-8}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"

MODE="${1:-selection}"
INCLUDE_CURSOR="${2:-0}"
DELAY="${3:-0}"

# If a delay was requested, sleep first
if [ "$DELAY" -gt 0 ] 2>/dev/null; then
    sleep "$DELAY"
fi

TARGET_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$TARGET_DIR"

TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
FILENAME="Screenshot_${TIMESTAMP}.png"
FILEPATH="${TARGET_DIR}/${FILENAME}"

GRIM_ARGS=()
if [ "$INCLUDE_CURSOR" = "1" ] || [ "$INCLUDE_CURSOR" = "true" ]; then
    GRIM_ARGS+=("-c")
fi

case "$MODE" in
    selection|region)
        # Interactive crop selection with slurp
        GEOM=$(slurp -d -b "#1e1e2ecc" -c "#89b4faff" -s "#89b4fa33" -w 2 2>/dev/null || true)
        if [ -z "$GEOM" ]; then
            # User aborted selection with Escape or right click
            exit 0
        fi
        GRIM_ARGS+=("-g" "$GEOM")
        ;;

    window)
        # Snap slurp to windows on active workspace
        ACTIVE_WS=$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.id' 2>/dev/null || echo "1")
        WINS=$(hyprctl -j clients 2>/dev/null | jq -r --argjson ws "$ACTIVE_WS" '.[] | select(.workspace.id == $ws and .mapped == true and .hidden == false) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1]) \(.title)"' 2>/dev/null || true)

        if [ -n "$WINS" ]; then
            GEOM=$(echo "$WINS" | slurp -r -b "#1e1e2ecc" -c "#89b4faff" -s "#89b4fa33" -B "#89b4fa22" -w 2 2>/dev/null || true)
        else
            # Fallback if no window detected on current workspace
            GEOM=$(slurp -d -b "#1e1e2ecc" -c "#89b4faff" -s "#89b4fa33" -w 2 2>/dev/null || true)
        fi

        if [ -z "$GEOM" ]; then
            exit 0
        fi
        GRIM_ARGS+=("-g" "$GEOM")
        ;;

    screen|full)
        # Capture focused monitor or entire desktop
        FOCUSED_MON=$(hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null || true)
        if [ -n "$FOCUSED_MON" ] && [ "$FOCUSED_MON" != "null" ]; then
            GRIM_ARGS+=("-o" "$FOCUSED_MON")
        fi
        ;;

    *)
        # Default fallback
        GEOM=$(slurp -d -b "#1e1e2ecc" -c "#89b4faff" -s "#89b4fa33" -w 2 2>/dev/null || true)
        if [ -z "$GEOM" ]; then
            exit 0
        fi
        GRIM_ARGS+=("-g" "$GEOM")
        ;;
esac

# Capture screenshot with grim
grim "${GRIM_ARGS[@]}" "$FILEPATH"

if [ ! -f "$FILEPATH" ] || [ ! -s "$FILEPATH" ]; then
    exit 1
fi

# Copy image to Wayland clipboard in background using nohup so wl-copy stays alive indefinitely
nohup wl-copy --type image/png < "$FILEPATH" >/dev/null 2>&1 &

# Play shutter audio feedback in background
SHUTTER_SOUND="/usr/share/sounds/freedesktop/stereo/screen-capture.oga"
[ ! -f "$SHUTTER_SOUND" ] && SHUTTER_SOUND="/usr/share/sounds/freedesktop/stereo/camera-shutter.oga"

if [ -f "$SHUTTER_SOUND" ]; then
    if command -v paplay >/dev/null 2>&1; then
        paplay "$SHUTTER_SOUND" >/dev/null 2>&1 &
    elif command -v pw-play >/dev/null 2>&1; then
        pw-play "$SHUTTER_SOUND" >/dev/null 2>&1 &
    fi
fi

# Trigger Quickshell camera flash animation via IPC
quickshell ipc --any-display call screenshot flash >/dev/null 2>&1 || true

# Send notification toast with thumbnail preview
notify-send -a "Screenshot" \
            -i "$FILEPATH" \
            "Screenshot Saved" \
            "Copied to clipboard and saved to ~/Pictures/Screenshots/${FILENAME}" \
            >/dev/null 2>&1 || true

echo "$FILEPATH"
exit 0
