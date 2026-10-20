#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  Dotfiles Uninstaller & Backup Restorer
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

CONFIG_DIRS=(hypr quickshell ghostty fastfetch cava btop fish)

echo ":: Dotfiles Uninstall / Restore Utility"

# Find latest backup
LATEST_BACKUP=$(ls -td "$HOME"/.config_backup_* 2>/dev/null | head -n 1 || true)

if [ -n "$LATEST_BACKUP" ] && [ -d "$LATEST_BACKUP" ]; then
    read -rp "Found backup at $LATEST_BACKUP. Restore it now? [y/N] " restore_choice
    if [[ "$restore_choice" =~ ^[Yy]$ ]]; then
        for d in "${CONFIG_DIRS[@]}"; do
            rm -rf "$HOME/.config/$d"
            if [ -d "$LATEST_BACKUP/$d" ]; then
                echo "Restoring $d..."
                mv "$LATEST_BACKUP/$d" "$HOME/.config/$d"
            fi
        done
        echo "✔ Backup restored successfully!"
        exit 0
    fi
fi

read -rp "Remove dotfiles symlinks from ~/.config? [y/N] " remove_choice
if [[ "$remove_choice" =~ ^[Yy]$ ]]; then
    for d in "${CONFIG_DIRS[@]}"; do
        if [ -L "$HOME/.config/$d" ]; then
            echo "Removing symlink ~/.config/$d"
            rm -f "$HOME/.config/$d"
        fi
    done
    echo "✔ Dotfiles symlinks removed."
fi
