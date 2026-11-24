#!/usr/bin/env bash
# Launch Ghostty as a floating, centered 1000x600 window.
# Ghostty has no per-window --class option (unlike kitty), so detect the newly
# created window by address and apply the float/size/center only to that one.
# This Hyprland build replaces `hyprctl dispatch <name>` with Lua dispatchers,
# so the actions below use hl.dsp.* syntax.

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:$PATH"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

before="$(hyprctl clients -j 2>/dev/null | jq -r '.[].address' | sort)"

ghostty --gtk-single-instance=false >/dev/null 2>&1 &

address=""
for _ in $(seq 1 40); do
	sleep 0.1
	now="$(hyprctl clients -j 2>/dev/null | jq -r '.[].address' | sort)"
	address="$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$now") | head -n1)"
	[ -n "$address" ] && break
done

if [ -n "$address" ]; then
	hyprctl dispatch "hl.dsp.window.float({ action = 'set', window = 'address:$address' })"
	hyprctl dispatch "hl.dsp.window.resize({ x = 1000, y = 600, relative = false, window = 'address:$address' })"
	hyprctl dispatch "hl.dsp.window.center({ window = 'address:$address' })"
fi
