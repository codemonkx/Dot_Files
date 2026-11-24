#!/bin/sh
# Minflair — Open (or focus) a widget/application window.
#
# Idempotent: if the window is already open it stays open. Opening an app from
# the launcher must not toggle it closed. For keybinds use the widget IPC:
#   qs ipc call widgets toggle <widget_id>
WIDGET_ID="${1:-}"

if [ -z "$WIDGET_ID" ]; then
  echo "Usage: $(basename "$0") <widget_id>" >&2
  exit 1
fi

exec qs ipc call widgets open "$WIDGET_ID"
