#!/usr/bin/env python3
import os
import sys
import json
import subprocess

SOURCES_FILE = os.path.expanduser("~/.config/hypr/wallpaper_sources.json")
VALID_EXTS = ('.jpg', '.jpeg', '.png', '.webp')

def load_sources():
    if not os.path.exists(SOURCES_FILE):
        return []
    try:
        with open(SOURCES_FILE, 'r') as f:
            sources = json.load(f)
            if not isinstance(sources, list):
                return []
            return sources
    except Exception:
        return []

def save_sources(sources):
    clean = []
    seen = set()
    for s in sources:
        norm = os.path.normpath(os.path.expanduser(s.strip()))
        if norm and norm not in seen:
            seen.add(norm)
            clean.append(norm)
    os.makedirs(os.path.dirname(SOURCES_FILE), exist_ok=True)
    with open(SOURCES_FILE, 'w') as f:
        json.dump(clean, f, indent=2)
    return clean

def count_wallpapers(folder):
    if not os.path.isdir(folder):
        return 0
    count = 0
    for root, dirs, files in os.walk(folder):
        if '.git' in root:
            continue
        for f in files:
            if f.lower().endswith(VALID_EXTS):
                count += 1
    return count

def add_folder(path):
    if not path:
        return {"success": False, "error": "Path cannot be empty"}
    expanded = os.path.normpath(os.path.expanduser(path.strip()))
    if not os.path.exists(expanded):
        return {"success": False, "error": f"Folder does not exist: {path}"}
    if not os.path.isdir(expanded):
        return {"success": False, "error": f"Path is not a directory: {path}"}

    count = count_wallpapers(expanded)
    sources = load_sources()
    if expanded in sources:
        return {"success": True, "message": f"Folder already added ({count} wallpapers found)", "path": expanded, "count": count}

    sources.append(expanded)
    save_sources(sources)
    return {
        "success": True,
        "message": f"Added '{os.path.basename(expanded)}' ({count} wallpapers)",
        "path": expanded,
        "count": count
    }

def remove_folder(path):
    if not path:
        return {"success": False, "error": "Path cannot be empty"}
    expanded = os.path.normpath(os.path.expanduser(path.strip()))
    sources = load_sources()
    if expanded in sources:
        sources.remove(expanded)
        save_sources(sources)
        return {"success": True, "message": f"Removed '{os.path.basename(expanded)}'"}
    return {"success": False, "error": "Folder not found in configured list"}

def browse_folder():
    """Launch zenity to pick a folder."""
    try:
        cmd = [
            "zenity", "--file-selection", "--directory",
            "--title=Select Wallpaper Folder",
            f"--filename={os.path.expanduser('~/Pictures/')}"
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            selected = res.stdout.strip()
            if selected:
                return {"success": True, "path": selected}
        return {"success": False, "error": "Selection canceled"}
    except Exception as e:
        return {"success": False, "error": str(e)}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"sources": load_sources()}))
        sys.exit(0)

    action = sys.argv[1]
    if action == "list":
        sources = load_sources()
        detailed = []
        for s in sources:
            detailed.append({
                "path": s,
                "name": os.path.basename(s) or s,
                "count": count_wallpapers(s)
            })
        print(json.dumps({"success": True, "sources": detailed}))
    elif action == "add" and len(sys.argv) >= 3:
        target = sys.argv[2]
        res = add_folder(target)
        print(json.dumps(res))
    elif action == "remove" and len(sys.argv) >= 3:
        target = sys.argv[2]
        res = remove_folder(target)
        print(json.dumps(res))
    elif action == "browse":
        res = browse_folder()
        print(json.dumps(res))
    else:
        print(json.dumps({"success": False, "error": f"Unknown action {action}"}))
