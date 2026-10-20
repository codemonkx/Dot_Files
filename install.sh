#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  Catppuccin Sapphire Hyprland + Quickshell Dotfiles Installer
#  Repository: https://github.com/codemonkx/Dot_Files
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colors
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_BLUE="\033[38;2;137;180;250m"      # #89B4FA (Sapphire Accent)
C_CYAN="\033[38;2;137;220;235m"      # #89DCEB
C_GREEN="\033[38;2;166;227;161m"     # #A6E3A1
C_YELLOW="\033[38;2;249;226;175m"    # #F9E2AF
C_RED="\033[38;2;243;139;168m"       # #F38BA8
C_MUTED="\033[38;2;108;112;134m"

log()   { echo -e "${C_BLUE}::${C_RESET} ${C_BOLD}$*${C_RESET}"; }
info()  { echo -e "  ${C_CYAN}➜${C_RESET} $*"; }
ok()    { echo -e "  ${C_GREEN}✔${C_RESET} $*"; }
warn()  { echo -e "  ${C_YELLOW}▲${C_RESET} $*"; }
err()   { echo -e "  ${C_RED}✖${C_RESET} $*" >&2; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
MODE="symlink" # default: symlink (use --copy for hard copy)

# Parse flags
for arg in "$@"; do
    case "$arg" in
        --copy|-c) MODE="copy" ;;
        --help|-h)
            echo "Usage: ./install.sh [OPTIONS]"
            echo "Options:"
            echo "  --symlink, -s    Symlink configs from repository to ~/.config (default)"
            echo "  --copy, -c       Copy configs directly to ~/.config"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
    esac
done

echo -e "\n${C_BLUE}${C_BOLD}"
cat << 'EOF'
  ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
  ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
  ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
  ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
  ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝
EOF
echo -e "${C_RESET}"
echo -e "  ${C_CYAN}Catppuccin Sapphire Hyprland + Quickshell Rice Installer${C_RESET}\n"

# ─── 1. Package Dependencies ──────────────────────────────────────────────────
log "Checking system dependencies..."

DEPENDENCIES=(
    hyprland
    hypridle
    hyprlock
    quickshell
    swaybg
    pipewire
    wireplumber
    playerctl
    brightnessctl
    power-profiles-daemon
    upower
    networkmanager
    bluez
    bluez-utils
    wl-clipboard
    grim
    slurp
    jq
    python
    zenity
    ghostty
    fish
    fastfetch
    cava
    btop
    ttf-font-awesome
    ttf-inter
    ttf-jetbrains-mono-nerd
    # ── Essential Everyday Apps ──
    nautilus
    micro
    steam
    loupe
    file-roller
    pavucontrol
    hyprpolkitagent
    xdg-desktop-portal-hyprland
)

MISSING_PKGS=()
for pkg in "${DEPENDENCIES[@]}"; do
    if ! pacman -Q "$pkg" &>/dev/null; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    warn "The following packages are missing: ${MISSING_PKGS[*]}"
    
    AUR_HELPER=""
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    fi

    if [ -n "$AUR_HELPER" ]; then
        read -rp "  Install missing packages with $AUR_HELPER? [Y/n] " install_choice
        if [[ ! "$install_choice" =~ ^[Nn]$ ]]; then
            $AUR_HELPER -S --needed "${MISSING_PKGS[@]}" || warn "Some packages failed to install. Continuing..."
        fi
    elif command -v pacman &>/dev/null; then
        read -rp "  Install official packages with pacman? [Y/n] " install_choice
        if [[ ! "$install_choice" =~ ^[Nn]$ ]]; then
            sudo pacman -S --needed "${MISSING_PKGS[@]}" || warn "Some packages failed to install. Continuing..."
        fi
    else
        warn "Package manager not recognized. Please install these manually: ${MISSING_PKGS[*]}"
    fi
else
    ok "All core package dependencies are satisfied!"
fi

# Optional recommended AUR apps (Vesktop, Brave)
EXTRA_AUR=()
if ! command -v vesktop &>/dev/null && ! (command -v flatpak &>/dev/null && flatpak info dev.vencord.Vesktop &>/dev/null 2>&1); then
    EXTRA_AUR+=(vesktop-bin)
fi
if ! command -v brave &>/dev/null && ! command -v brave-browser &>/dev/null; then
    EXTRA_AUR+=(brave-bin)
fi

AUR_HELPER=""
if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
fi

if [ ${#EXTRA_AUR[@]} -gt 0 ] && [ -n "$AUR_HELPER" ]; then
    read -rp "  Install recommended apps (${EXTRA_AUR[*]}) with $AUR_HELPER? [Y/n] " aur_extra_choice
    if [[ ! "$aur_extra_choice" =~ ^[Nn]$ ]]; then
        $AUR_HELPER -S --needed "${EXTRA_AUR[@]}" || warn "Could not install some AUR packages."
    fi
fi

# ─── 2. Backup Existing Configs ───────────────────────────────────────────────
log "Preparing ~/.config backup directory: ${BACKUP_DIR}"

CONFIG_DIRS=(
    hypr
    quickshell
    ghostty
    fastfetch
    cava
    btop
    fish
)

mkdir -p "$HOME/.config"
BACKUP_CREATED=false

for d in "${CONFIG_DIRS[@]}"; do
    target="$HOME/.config/$d"
    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ "$BACKUP_CREATED" = false ]; then
            mkdir -p "$BACKUP_DIR"
            BACKUP_CREATED=true
        fi
        info "Backing up existing ~/.config/$d to ${BACKUP_DIR}/"
        mv "$target" "$BACKUP_DIR/"
    fi
done

if [ "$BACKUP_CREATED" = true ]; then
    ok "Existing configurations safely archived at ${BACKUP_DIR}"
fi

# ─── 3. Deploy Configurations ─────────────────────────────────────────────────
log "Deploying configurations (Mode: ${MODE})..."

for d in "${CONFIG_DIRS[@]}"; do
    src="$DOTFILES_DIR/.config/$d"
    dst="$HOME/.config/$d"

    if [ ! -d "$src" ]; then
        continue
    fi

    if [ "$MODE" = "symlink" ]; then
        info "Symlinking $dst ➜ $src"
        ln -sfn "$src" "$dst"
    else
        info "Copying $src ➜ $dst"
        cp -rf "$src" "$dst"
    fi
done

# Ensure executable permissions on helper scripts
chmod +x "$HOME/.config/hypr/"*.sh 2>/dev/null || true
chmod +x "$HOME/.config/hypr/"*.py 2>/dev/null || true
ok "Configurations deployed and script permissions granted!"

# ─── 4. Wallpapers Repository ─────────────────────────────────────────────────
log "Checking Wallpapers..."

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
if [ ! -d "$WALLPAPER_DIR" ]; then
    info "Wallpapers folder not found at ${WALLPAPER_DIR}."
    read -rp "  Clone official Wallpapers repository from GitHub? [Y/n] " wp_choice
    if [[ ! "$wp_choice" =~ ^[Nn]$ ]]; then
        mkdir -p "$HOME/Pictures"
        git clone https://github.com/codemonkx/Wallpapers.git "$WALLPAPER_DIR" || warn "Could not clone wallpapers. You can clone manually later."
    fi
else
    ok "Wallpapers repository found at ${WALLPAPER_DIR}"
fi

# Set default wallpaper fallback if not present
mkdir -p "$HOME/Pictures"
if [ ! -f "$HOME/Pictures/wall.jpg" ]; then
    FIRST_WALL=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | head -n 1 || true)
    if [ -n "$FIRST_WALL" ]; then
        cp -f "$FIRST_WALL" "$HOME/Pictures/wall.jpg"
        echo "$FIRST_WALL" > "$HOME/.config/hypr/current_wallpaper" 2>/dev/null || true
        ok "Initialized default wallpaper: $(basename "$FIRST_WALL")"
    fi
fi

# ─── 5. Enable System Services ────────────────────────────────────────────────
log "Checking essential background services..."

if systemctl is-enabled power-profiles-daemon.service &>/dev/null; then
    ok "power-profiles-daemon is active"
else
    info "Enabling power-profiles-daemon.service..."
    sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null || warn "Could not enable power-profiles-daemon.service automatically"
fi

if systemctl is-enabled bluetooth.service &>/dev/null; then
    ok "bluetooth service is active"
else
    info "Enabling bluetooth.service..."
    sudo systemctl enable --now bluetooth.service 2>/dev/null || warn "Could not enable bluetooth.service automatically"
fi

# ─── 6. Final Summary ─────────────────────────────────────────────────────────
echo -e "\n${C_GREEN}${C_BOLD}✔ Setup successfully installed!${C_RESET}\n"
echo -e "Next steps:"
echo -e "  1. If you are already inside Hyprland: run ${C_BOLD}hyprctl reload${C_RESET} and ${C_BOLD}quickshell &${C_RESET}"
echo -e "  2. Or simply log out and start a fresh Hyprland session."
echo -e "  3. Open Control Panel: ${C_BOLD}SUPER + A${C_RESET} (or click top-right status pill)"
echo -e "  4. Open Settings: ${C_BOLD}SUPER + I${C_RESET} (or right-click status pill)"
echo -e "  5. Open App Launcher: ${C_BOLD}SUPER + SPACE${C_RESET}\n"
EOF
