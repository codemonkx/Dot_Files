#!/bin/bash
NEW_WALL="$1"
if [ ! -f "$NEW_WALL" ]; then
    echo "File not found: $NEW_WALL" >&2
    exit 1
fi

echo "$NEW_WALL" > "$HOME/.config/hypr/current_wallpaper"

if [ "$NEW_WALL" != "$HOME/Pictures/wall.jpg" ]; then
    mkdir -p "$HOME/Pictures"
    cp -f "$NEW_WALL" "$HOME/Pictures/wall.jpg"
fi

# Kill swaybg if running so Quickshell's animated background has sole control
pkill -x swaybg 2>/dev/null || true

# Trigger smooth animated cross-fade transition in Quickshell
qs ipc call wallpaperbg set "$NEW_WALL"
