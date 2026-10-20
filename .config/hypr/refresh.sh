#!/usr/bin/env bash
killall quickshell swaybg 2>/dev/null
sleep 0.5
nohup ~/.config/hypr/swaybg.sh >/dev/null 2>&1 &
nohup ~/.config/hypr/quickshell.sh >/dev/null 2>&1 &
