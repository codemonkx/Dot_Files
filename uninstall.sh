#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  ❄️ Catppuccin Sapphire Dotfiles Uninstaller & Backup Restorer
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

C_RESET="\033[0m"
C_BOLD="\033[1m"
C_BLUE="\033[38;2;137;180;250m"
C_GREEN="\033[38;2;166;227;161m"
C_YELLOW="\033[38;2;249;226;175m"
C_RED="\033[38;2;243;139;168m"

echo -e "\n${C_BLUE}${C_BOLD}:: Catppuccin Sapphire Dotfiles Uninstall & Restore Utility${C_RESET}\n"

CONFIG_DIRS=(
    hypr
    quickshell
    ghostty
    fastfetch
    cava
    btop
    fish
    pipewire
    gtk-3.0
    gtk-4.0
)

# 1. Check for existing backups
LATEST_BACKUP=$(ls -td "$HOME"/.config_backup_* 2>/dev/null | head -n 1 || true)

if [ -n "$LATEST_BACKUP" ] && [ -d "$LATEST_BACKUP" ]; then
    echo -e "Found previous configuration backup at ${C_BOLD}${LATEST_BACKUP}${C_RESET}."
    read -rp "Do you want to restore this backup now? [y/N]: " restore_choice
    if [[ "$restore_choice" =~ ^[Yy]$ ]]; then
        # Stop user services first
        systemctl --user stop workspace-autocollapse.service 2>/dev/null || true
        systemctl --user disable workspace-autocollapse.service 2>/dev/null || true
        rm -f "$HOME/.config/systemd/user/workspace-autocollapse.service" 2>/dev/null || true

        for d in "${CONFIG_DIRS[@]}"; do
            rm -rf "$HOME/.config/$d"
            if [ -d "$LATEST_BACKUP/$d" ]; then
                echo "Restoring ~/.config/$d..."
                cp -rf "$LATEST_BACKUP/$d" "$HOME/.config/$d"
            fi
        done
        echo -e "\n${C_GREEN}✔ Configurations restored successfully from backup!${C_RESET}"
        exit 0
    fi
fi

# 2. Complete removal prompt
read -rp "Remove dotfiles configurations from ~/.config? [y/N]: " remove_choice
if [[ "$remove_choice" =~ ^[Yy]$ ]]; then
    # Stop user services
    systemctl --user stop workspace-autocollapse.service 2>/dev/null || true
    systemctl --user disable workspace-autocollapse.service 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/workspace-autocollapse.service" 2>/dev/null || true

    for d in "${CONFIG_DIRS[@]}"; do
        if [ -e "$HOME/.config/$d" ] || [ -L "$HOME/.config/$d" ]; then
            echo "Removing ~/.config/$d..."
            rm -rf "$HOME/.config/$d"
        fi
    done
    echo -e "\n${C_GREEN}✔ Dotfiles configurations removed.${C_RESET}"
fi
