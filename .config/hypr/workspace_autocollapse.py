#!/usr/bin/env python3
"""
Hyprland Dynamic Workspace Gap Elimination Daemon
Automatically shifts workspaces down to eliminate gaps when windows are closed or moved.

Example: If Workspaces 1, 2, 4, 5 are occupied (Workspace 3 is empty):
  - Workspace 4 shifts to Workspace 3
  - Workspace 5 shifts to Workspace 4
Workspaces are always contiguous (1, 2, 3, 4...) with zero holes.
"""

import os
import sys
import fcntl
import socket
import time
import subprocess
import threading

DEBOUNCE_DELAY = 0.15  # seconds
_timer = None
_lock = threading.Lock()
_is_consolidating = False

# Ensure single instance
_lock_file = None
def acquire_single_instance_lock():
    global _lock_file
    lock_path = "/tmp/hypr_workspace_autocollapse.lock"
    try:
        _lock_file = open(lock_path, "w")
        fcntl.flock(_lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except (IOError, BlockingIOError):
        # Daemon already running
        sys.exit(0)

LUA_CONSOLIDATE_SCRIPT = """
local windows = hl.get_windows()
local ws_map = {}
for _, w in ipairs(windows) do
    if w.mapped and not w.pinned then
        local ws = w.workspace
        if ws and ws.id > 0 then
            ws_map[ws.id] = ws_map[ws.id] or {}
            table.insert(ws_map[ws.id], w)
        end
    end
end

local occupied = {}
for id, _ in pairs(ws_map) do
    table.insert(occupied, id)
end
table.sort(occupied)

if #occupied == 0 then
    return "empty"
end

local has_gap = false
for i, id in ipairs(occupied) do
    if id ~= i then
        has_gap = true
        break
    end
end

if not has_gap then
    return "contiguous"
end

local target_map = {}
for i, id in ipairs(occupied) do
    target_map[id] = i
end

local active_ws = hl.get_active_workspace()
local active_id = active_ws and active_ws.id or 1
local new_active_id = target_map[active_id]
if not new_active_id then
    if active_id > #occupied then
        new_active_id = #occupied
    else
        new_active_id = active_id
    end
end

for _, old_id in ipairs(occupied) do
    local target_id = target_map[old_id]
    if target_id and target_id ~= old_id then
        for _, w in ipairs(ws_map[old_id]) do
            hl.dispatch(hl.dsp.window.move({ window = w, workspace = target_id, silent = true }))
        end
    end
end

if active_id ~= new_active_id then
    hl.dispatch(hl.dsp.focus({ workspace = new_active_id }))
end
return "consolidated"
"""

def consolidate_workspaces():
    global _is_consolidating
    with _lock:
        _is_consolidating = True

    try:
        # Fast Lua consolidation
        res = subprocess.run(
            ["hyprctl", "eval", LUA_CONSOLIDATE_SCRIPT],
            capture_output=True,
            text=True,
            timeout=2
        )
        if res.returncode != 0:
            # Fallback for standard .conf mode if eval fails
            fallback_consolidate()
    except Exception:
        pass
    finally:
        # Allow socket events triggered by window movement to settle
        time.sleep(0.08)
        with _lock:
            _is_consolidating = False

def fallback_consolidate():
    """Fallback consolidation using legacy JSON hyprctl if Lua eval is unavailable"""
    import json
    try:
        clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], stderr=subprocess.DEVNULL))
    except Exception:
        return

    ws_windows = {}
    for c in clients:
        if c.get("mapped") is False or c.get("pinned") is True:
            continue
        ws_id = c.get("workspace", {}).get("id", -1)
        if ws_id > 0:
            ws_windows.setdefault(ws_id, []).append(c["address"])

    if not ws_windows:
        return

    occupied = sorted(ws_windows.keys())
    if occupied == list(range(1, len(occupied) + 1)):
        return

    target_map = {old: idx for idx, old in enumerate(occupied, start=1)}
    shifts = {old: new for old, new in target_map.items() if old != new}
    if not shifts:
        return

    try:
        active_ws_info = json.loads(subprocess.check_output(["hyprctl", "activeworkspace", "-j"], stderr=subprocess.DEVNULL))
        active_ws = active_ws_info.get("id", 1)
    except Exception:
        active_ws = 1

    new_active_ws = target_map.get(active_ws, active_ws)

    for old_id in sorted(shifts.keys()):
        target_ws = shifts[old_id]
        for addr in ws_windows[old_id]:
            subprocess.run(
                ["hyprctl", "dispatch", "movetoworkspacesilent", f"{target_ws},address:{addr}"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

    if active_ws != new_active_ws:
        subprocess.run(
            ["hyprctl", "dispatch", "workspace", str(new_active_ws)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

def trigger_debounce():
    global _timer
    with _lock:
        if _is_consolidating:
            return
        if _timer is not None:
            _timer.cancel()
        _timer = threading.Timer(DEBOUNCE_DELAY, consolidate_workspaces)
        _timer.daemon = True
        _timer.start()

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

def main():
    acquire_single_instance_lock()

    # Initial consolidation check on launch
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
                        # React to window close, window move, or workspace destruction
                        if (line.startswith("closewindow") or
                            line.startswith("movewindow") or
                            line.startswith("destroyworkspace")):
                            trigger_debounce()
        except Exception:
            time.sleep(1)

if __name__ == "__main__":
    main()
