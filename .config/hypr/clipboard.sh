#!/usr/bin/env bash
# ~/.config/hypr/clipboard.sh
# Cliphist & Wayland clipboard helper for Windows-style Quickshell Clipboard Manager

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:$PATH"
CLIPHIST="$(which cliphist 2>/dev/null || echo "$HOME/.local/bin/cliphist")"
PIN_FILE="$HOME/.config/hypr/pinned_clips.json"

ACTION="${1:-list}"
ARG2="${2:-}"
ARG3="${3:-}"

THUMB_DIR="/tmp/cliphist_thumbs"
mkdir -p "$THUMB_DIR"

case "$ACTION" in
    daemon)
        # Kill existing watches to prevent duplicate entries
        pkill -f "wl-paste --type text --watch" 2>/dev/null || true
        pkill -f "wl-paste --type image --watch" 2>/dev/null || true
        sleep 0.2
        nohup wl-paste --type text --watch "$CLIPHIST" store >/dev/null 2>&1 &
        nohup wl-paste --type image --watch "$CLIPHIST" store >/dev/null 2>&1 &
        ;;

    list)
        QUERY="${ARG2:-}"
        LIMIT="${ARG3:-80}"
        python3 -c "
import subprocess, os, re, json, sys

query = '''${QUERY}'''.strip().lower()
limit = int('''${LIMIT}''' or '80')
thumb_dir = '${THUMB_DIR}'
cliphist_bin = '${CLIPHIST}'
pin_file = '${PIN_FILE}'

pinned_ids = set()
if os.path.exists(pin_file):
    try:
        with open(pin_file, 'r') as f:
            pinned_ids = set(json.load(f))
    except Exception:
        pass

try:
    raw_list = subprocess.check_output([cliphist_bin, 'list'], stderr=subprocess.DEVNULL, text=True)
except Exception:
    raw_list = ''

items = []
lines = raw_list.strip().split('\n')
for line in lines:
    if not line.strip():
        continue
    parts = line.split('\t', 1)
    if len(parts) < 2:
        continue
    cid, content = parts[0].strip(), parts[1].strip()
    is_pinned = cid in pinned_ids

    # Check if binary image data
    img_match = re.match(r'\[\[ binary data ([\d\.]+ \w+) (\w+) (\d+x\d+) \]\]', content)
    if img_match:
        size_str, fmt, dims = img_match.groups()
        if query and query not in 'image' and query not in fmt.lower() and query not in dims:
            continue
        thumb_path = os.path.join(thumb_dir, f'{cid}.{fmt}')
        if not os.path.exists(thumb_path):
            try:
                raw_bytes = subprocess.check_output([cliphist_bin, 'decode', cid], stderr=subprocess.DEVNULL)
                with open(thumb_path, 'wb') as f:
                    f.write(raw_bytes)
            except Exception:
                thumb_path = ''
        items.append({
            'id': cid,
            'type': 'image',
            'format': fmt.upper(),
            'size': size_str,
            'dims': dims,
            'preview': f'Image ({dims}, {size_str})',
            'pinned': is_pinned,
            'thumb': thumb_path
        })
    else:
        # Text entry
        if query and query not in content.lower():
            continue
        
        # Classify text type (url, code, text)
        is_url = content.startswith('http://') or content.startswith('https://') or content.startswith('www.')
        is_code = ('{' in content and '}' in content) or ('function' in content) or ('import ' in content) or ('def ' in content)
        
        entry_type = 'url' if is_url else ('code' if is_code else 'text')

        # Clean preview text
        clean_preview = ' '.join(content.split())
        if len(clean_preview) > 220:
            clean_preview = clean_preview[:220] + '...'

        items.append({
            'id': cid,
            'type': entry_type,
            'format': 'TEXT',
            'size': f'{len(content)} chars',
            'dims': '',
            'preview': clean_preview,
            'full_text': content[:1500],
            'pinned': is_pinned,
            'thumb': ''
        })

    if len(items) >= limit * 2:
        break

# Sort pinned items first, maintaining chronological order
items.sort(key=lambda x: 0 if x.get('pinned') else 1)
print(json.dumps(items[:limit]))
"
        ;;

    toggle-pin)
        ID="$ARG2"
        if [ -n "$ID" ]; then
            python3 -c "
import json, os
pin_file = '${PIN_FILE}'
pinned = []
if os.path.exists(pin_file):
    try:
        with open(pin_file, 'r') as f:
            pinned = json.load(f)
    except Exception:
        pass

if '$ID' in pinned:
    pinned.remove('$ID')
else:
    pinned.append('$ID')

with open(pin_file, 'w') as f:
    json.dump(pinned, f)
"
        fi
        ;;

    paste-text)
        TEXT="$ARG2"
        if [ -n "$TEXT" ]; then
            echo -n "$TEXT" | wl-copy
            quickshell ipc --any-display call clipboard close >/dev/null 2>&1 || true
            sleep 0.08
            hyprctl dispatch sendshortcut "CTRL,V,activewindow" >/dev/null 2>&1 || true
        fi
        ;;

    copy)
        ID="$ARG2"
        if [ -z "$ID" ]; then exit 1; fi
        
        LINE=$("$CLIPHIST" list | grep -E "^${ID}[[:space:]]" | head -n 1 || true)
        if echo "$LINE" | grep -q "\[\[ binary data"; then
            # Binary image copy
            TMP_FILE="/tmp/clip_copy_${ID}.png"
            "$CLIPHIST" decode "$ID" > "$TMP_FILE"
            nohup wl-copy --type image/png < "$TMP_FILE" >/dev/null 2>&1 &
        else
            "$CLIPHIST" decode "$ID" | wl-copy
        fi
        ;;

    paste)
        ID="$ARG2"
        if [ -z "$ID" ]; then exit 1; fi
        
        # Copy to clipboard
        LINE=$("$CLIPHIST" list | grep -E "^${ID}[[:space:]]" | head -n 1 || true)
        if echo "$LINE" | grep -q "\[\[ binary data"; then
            TMP_FILE="/tmp/clip_copy_${ID}.png"
            "$CLIPHIST" decode "$ID" > "$TMP_FILE"
            nohup wl-copy --type image/png < "$TMP_FILE" >/dev/null 2>&1 &
        else
            "$CLIPHIST" decode "$ID" | wl-copy
        fi

        # Close clipboard window via IPC
        quickshell ipc --any-display call clipboard close >/dev/null 2>&1 || true

        # Give focus back to target window and send CTRL+V
        sleep 0.08
        hyprctl dispatch sendshortcut "CTRL,V,activewindow" >/dev/null 2>&1 || true
        ;;

    delete)
        ID="$ARG2"
        if [ -z "$ID" ]; then exit 1; fi
        # Find exact entry and delete
        LINE=$("$CLIPHIST" list | grep -E "^${ID}[[:space:]]" | head -n 1 || true)
        if [ -n "$LINE" ]; then
            echo "$LINE" | "$CLIPHIST" delete
        fi
        # Remove from pinned file if present
        python3 -c "
import json, os
pin_file = '${PIN_FILE}'
if os.path.exists(pin_file):
    try:
        with open(pin_file, 'r') as f: pinned = json.load(f)
        if '$ID' in pinned:
            pinned.remove('$ID')
            with open(pin_file, 'w') as f: json.dump(pinned, f)
    except: pass
" 2>/dev/null || true
        rm -f "${THUMB_DIR}/${ID}".* 2>/dev/null || true
        ;;

    wipe)
        # Windows-style Clear All: Deletes unpinned items, keeps pinned items safe!
        python3 -c "
import subprocess, json, os

pin_file = '${PIN_FILE}'
cliphist_bin = '${CLIPHIST}'
pinned_ids = set()

if os.path.exists(pin_file):
    try:
        with open(pin_file, 'r') as f:
            pinned_ids = set(json.load(f))
    except Exception:
        pass

try:
    raw_list = subprocess.check_output([cliphist_bin, 'list'], stderr=subprocess.DEVNULL, text=True)
except Exception:
    raw_list = ''

for line in raw_list.strip().split('\n'):
    if not line.strip(): continue
    parts = line.split('\t', 1)
    if not parts: continue
    cid = parts[0].strip()
    if cid not in pinned_ids:
        p = subprocess.Popen([cliphist_bin, 'delete'], stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
        p.communicate(input=line.encode())
"
        ;;

    wipe-all)
        "$CLIPHIST" wipe
        rm -f "$PIN_FILE" 2>/dev/null || true
        rm -rf "${THUMB_DIR:?}"/* 2>/dev/null || true
        ;;

    *)
        echo "Usage: $0 {daemon|list [query] [limit]|toggle-pin <id>|paste-text <text>|copy <id>|paste <id>|delete <id>|wipe|wipe-all}"
        exit 1
        ;;
esac
