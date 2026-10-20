#!/usr/bin/env bash
# ~/.config/hypr/share_picker.sh
# Custom screen share picker bridge between xdg-desktop-portal-hyprland and Quickshell

export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export LANG="${LANG:-en_US.UTF-8}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"

FIFO="/run/user/$UID/xdph_picker_fifo_$$"
mkfifo "$FIFO"
trap 'rm -f "$FIFO"' EXIT

# Send request to Quickshell ScreenSharePicker (silence quickshell logs from portal stdout)
if ! quickshell ipc --any-display call screenshare open "$FIFO" "$XDPH_WINDOW_SHARING_LIST" >/dev/null 2>&1; then
    # Fallback to default picker if Quickshell is not running
    exec /usr/bin/hyprland-share-picker "$@"
fi

# Block waiting for user response from FIFO
read -r SELECTION < "$FIFO"

if [[ "$SELECTION" =~ ^\[SELECTION\] ]]; then
    echo "$SELECTION"
    exit 0
fi

exit 1
