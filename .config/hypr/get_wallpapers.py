#!/usr/bin/env python3
import os
import json

SOURCES_FILE = os.path.expanduser("~/.config/hypr/wallpaper_sources.json")
cur_file = os.path.expanduser("~/.config/hypr/current_wallpaper")
valid_exts = ('.jpg', '.jpeg', '.png', '.webp')

current_wall = ""
if os.path.exists(cur_file):
    try:
        with open(cur_file, 'r') as f:
            current_wall = f.read().strip()
    except Exception:
        pass

if not current_wall or not os.path.exists(current_wall):
    current_wall = os.path.expanduser('~/Pictures/wall.jpg')

# Load only user configured sources (no hardcoded defaults)
sources = []
if os.path.exists(SOURCES_FILE):
    try:
        with open(SOURCES_FILE, 'r') as f:
            loaded = json.load(f)
            if isinstance(loaded, list):
                sources = loaded
    except Exception:
        pass

wallpapers = []
categories_set = set()
seen_paths = set()
folders_info = []

for src in sources:
    expanded_src = os.path.normpath(os.path.expanduser(src.strip()))
    if not os.path.isdir(expanded_src):
        continue

    folder_wall_count = 0
    src_folder_name = os.path.basename(expanded_src) or expanded_src

    for root, dirs, files in os.walk(expanded_src):
        if '.git' in root:
            continue
        rel = os.path.relpath(root, expanded_src)
        
        if rel == '.':
            # Direct files inside the source folder
            cat = src_folder_name.replace('_', ' ').replace('-', ' ').title()
        else:
            # Inside a subfolder
            parts = rel.split(os.sep)
            cat = parts[0].replace('_', ' ').replace('-', ' ').title()

        for f in sorted(files):
            if f.lower().endswith(valid_exts):
                p = os.path.join(root, f)
                if p in seen_paths:
                    continue
                seen_paths.add(p)
                folder_wall_count += 1
                categories_set.add(cat)
                
                clean_name = os.path.splitext(f)[0].replace('-', ' ').replace('_', ' ').title()
                if len(clean_name) > 28:
                    clean_name = clean_name[:25] + "..."
                wallpapers.append({
                    "path": p,
                    "name": clean_name,
                    "category": cat,
                    "folder": expanded_src
                })

    folders_info.append({
        "path": expanded_src,
        "name": src_folder_name.replace('_', ' ').replace('-', ' ').title(),
        "count": folder_wall_count
    })

sorted_cats = ["All"] + sorted(list(categories_set))

print(json.dumps({
    "current": current_wall,
    "categories": sorted_cats,
    "folders": folders_info,
    "wallpapers": wallpapers
}))
