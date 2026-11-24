#!/bin/bash

PREV_VOL_INFO=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
PREV_VOL=$(echo "$PREV_VOL_INFO" | awk '{printf "%.0f", $2 * 100}')

case "$1" in
up)
  if [ "$PREV_VOL" -ge 100 ]; then
    exit 0
  fi
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0
  ;;
down)
  if [ "$PREV_VOL" -le 0 ]; then
    exit 0
  fi
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
  ;;
mute)
  wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
  ;;
mic-mute)
  wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
  ;;
esac

if [ "$1" = "mic-mute" ]; then
  MIC_INFO=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
  MIC_VOL=$(echo "$MIC_INFO" | awk '{printf "%.0f", $2 * 100}')
  MIC_MUTED=$(echo "$MIC_INFO" | grep -q "MUTED" && echo "true" || echo "false")
  qs ipc call osd showMic "$MIC_VOL" "$MIC_MUTED" 2>/dev/null || true
  exit 0
fi

VOLUME_INFO=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
VOLUME=$(echo "$VOLUME_INFO" | awk '{printf "%.0f", $2 * 100}')
MUTED=$(echo "$VOLUME_INFO" | grep -q "MUTED" && echo "true" || echo "false")

qs ipc call osd showVolume "$VOLUME" "$MUTED" 2>/dev/null || true
