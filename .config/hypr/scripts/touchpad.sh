#!/bin/bash

# Log invocation for troubleshooting
echo "$(date '+%Y-%m-%d %H:%M:%S') - touchpad.sh called with arg: '$1'" >>/tmp/touchpad.log

ACTION="${1:-toggle}"

# Find touchpad name from Hyprland
TOUCHPAD=$(hyprctl devices -j 2>/dev/null | jq -r '(.mice[] | select(.name | test("touchpad"; "i")) | .name) // empty' | head -n 1)

if [ -z "$TOUCHPAD" ]; then
  TOUCHPAD="elan0521:01-04f3:31b1-touchpad"
fi

STATE_FILE="/tmp/hypr_touchpad_disabled"

case "$ACTION" in
on)
  rm -f "$STATE_FILE"
  hyprctl eval "hl.config({ device = { { name = '$TOUCHPAD', enabled = true } } })" >/dev/null 2>&1 || true
  qs ipc call osd showMessage "Touchpad" "Enabled" "touchpad" 2>/dev/null || true
  ;;
off)
  touch "$STATE_FILE"
  hyprctl eval "hl.config({ device = { { name = '$TOUCHPAD', enabled = false } } })" >/dev/null 2>&1 || true
  qs ipc call osd showMessage "Touchpad" "Disabled" "touchpad" 2>/dev/null || true
  ;;
toggle | *)
  if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
    hyprctl eval "hl.config({ device = { { name = '$TOUCHPAD', enabled = true } } })" >/dev/null 2>&1 || true
    qs ipc call osd showMessage "Touchpad" "Enabled" "touchpad" 2>/dev/null || true
  else
    touch "$STATE_FILE"
    hyprctl eval "hl.config({ device = { { name = '$TOUCHPAD', enabled = false } } })" >/dev/null 2>&1 || true
    qs ipc call osd showMessage "Touchpad" "Disabled" "touchpad" 2>/dev/null || true
  fi
  ;;
esac
