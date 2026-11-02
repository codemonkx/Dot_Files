#!/usr/bin/env bash
# ~/.config/hypr/clipboard.sh
# Cliphist & Wayland clipboard helper for Quickshell Clipboard Manager

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:$PATH"
CLIPHIST="$(which cliphist 2>/dev/null || echo "$HOME/.local/bin/cliphist")"

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
        LIMIT="${ARG3:-75}"
        python3 -c "
import subprocess, os, re, json, sys

query = '''${QUERY}'''.strip().lower()
limit = int('''${LIMIT}''' or '75')
thumb_dir = '${THUMB_DIR}'
cliphist_bin = '${CLIPHIST}'

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

    # Check if binary image data
    img_match = re.match(r'\[\[ binary data ([\d\.]+ \w+) (\w+) (\d+x\d+) \]\]', content)
    if img_match:
        size_str, fmt, dims = img_match.groups()
        if query and query not in 'image' and query not in fmt and query not in dims:
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
        if len(clean_preview) > 180:
            clean_preview = clean_preview[:180] + '...'

        items.append({
            'id': cid,
            'type': entry_type,
            'format': 'TEXT',
            'size': f'{len(content)} chars',
            'dims': '',
            'preview': clean_preview,
            'full_text': content[:1000],
            'thumb': ''
        })

    if len(items) >= limit:
        break

print(json.dumps(items))
"
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
        rm -f "${THUMB_DIR}/${ID}".* 2>/dev/null || true
        ;;

    wipe)
        "$CLIPHIST" wipe
        rm -rf "${THUMB_DIR:?}"/* 2>/dev/null || true
        ;;

    *)
        echo "Usage: $0 {daemon|list [query] [limit]|copy <id>|paste <id>|delete <id>|wipe}"
        exit 1
        ;;
esac
