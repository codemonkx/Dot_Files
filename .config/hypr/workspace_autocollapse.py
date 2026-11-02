#!/usr/bin/env python3
"""
Workspace Auto-Collapse Daemon for Hyprland
Automatically shifts workspace numbers down to eliminate gaps when all apps on
an intermediate workspace are closed or moved.
Example: If Workspace 3 becomes empty while 4 and 5 have open apps,
         Workspace 4 becomes 3, and Workspace 5 becomes 4.
"""

import os
import sys
import json
import socket
import time
import subprocess
import threading

DEBOUNCE_DELAY = 0.15  # seconds
_timer = None
_lock = threading.Lock()

def get_hyprland_socket_path():
    xrd = os.environ.get("XDG_RUNTIME_DIR", "")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not xrd or not sig:
        uid = os.getuid()
        xrd = f"/run/user/{uid}"
        hypr_dir = os.path.join(xrd, "hypr")
        if os.path.isdir(hypr_dir):
            entries = [e for e in os.listdir(hypr_dir) if not e.startswith(".") and "_" in e]
            if entries:
                sig = entries[0]
    return os.path.join(xrd, "hypr", sig, ".socket2.sock")

def consolidate_workspaces():
    try:
        clients_output = subprocess.check_output(["hyprctl", "clients", "-j"], stderr=subprocess.DEVNULL)
        clients = json.loads(clients_output)
    except Exception:
        return

    ws_windows = {}
    for c in clients:
        if c.get("mapped") is False:
            continue
        ws_id = c.get("workspace", {}).get("id", -1)
        if ws_id > 0:  # Ignore special workspaces (id < 0)
            ws_windows.setdefault(ws_id, []).append(c["address"])

    if not ws_windows:
        return

    occupied = sorted(ws_windows.keys())
    # Gaps exist if occupied is not exactly [1, 2, ..., len(occupied)]
    expected = list(range(1, len(occupied) + 1))
    if occupied == expected:
        return  # Already perfectly packed

    # Map old workspace IDs to sequential IDs starting at 1
    target_mapping = {}
    for idx, old_id in enumerate(occupied, start=1):
        target_mapping[old_id] = idx

    shifts = {old: new for old, new in target_mapping.items() if old != new}
    if not shifts:
        return

    try:
        active_ws_info = json.loads(subprocess.check_output(["hyprctl", "activeworkspace", "-j"], stderr=subprocess.DEVNULL))
        active_ws = active_ws_info.get("id", 1)
    except Exception:
        active_ws = 1

    new_active_ws = target_mapping.get(active_ws, active_ws)

    # Shift windows in ascending order of target_ws
    for old_id in sorted(shifts.keys()):
        target_ws = shifts[old_id]
        for addr in ws_windows[old_id]:
            subprocess.run(
                ["hyprctl", "dispatch", "movetoworkspacesilent", f"{target_ws},address:{addr}"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

    # Follow active workspace if it moved
    if active_ws in shifts and active_ws != new_active_ws:
        subprocess.run(
            ["hyprctl", "dispatch", "workspace", str(new_active_ws)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

def trigger_debounce():
    global _timer
    with _lock:
        if _timer is not None:
            _timer.cancel()
        _timer = threading.Timer(DEBOUNCE_DELAY, consolidate_workspaces)
        _timer.daemon = True
        _timer.start()

def main():
    # Run once on startup to clean up any pre-existing gaps
    consolidate_workspaces()

    while True:
        sock_path = get_hyprland_socket_path()
        if not os.path.exists(sock_path):
            time.sleep(1)
            continue

        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.connect(sock_path)
                buffer = ""
                while True:
                    data = sock.recv(4096)
                    if not data:
                        break
                    buffer += data.decode("utf-8", errors="replace")
                    lines = buffer.split("\n")
                    buffer = lines.pop()

                    for line in lines:
                        line = line.strip()
                        if not line:
                            continue
                        if (line.startswith("closewindow>>") or
                            line.startswith("movewindow>>") or
                            line.startswith("destroyworkspace>>")):
                            trigger_debounce()
        except Exception:
            time.sleep(1)

if __name__ == "__main__":
    main()
