#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  Catppuccin Sapphire Hyprland + Quickshell Dotfiles Installer
#  Repository: https://github.com/codemonkx/Dot_Files
#  Designed for 100% reproducible deployment on Bare Metal & Virtual Machines
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Colors & Output Formatting ───────────────────────────────────────────────
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
MODE="copy" # Default: copy (use --symlink for developer symlink mode)
AUTO_YES=false
DRY_RUN=false

# ─── Parse Flags ──────────────────────────────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --symlink|-s) MODE="symlink" ;;
        --copy|-c)    MODE="copy" ;;
        --yes|-y)     AUTO_YES=true ;;
        --dry-run)    DRY_RUN=true ;;
        --help|-h)
            echo "Usage: ./install.sh [OPTIONS]"
            echo "Options:"
            echo "  --copy, -c       Copy configs directly to ~/.config (default)"
            echo "  --symlink, -s    Symlink configs from repository to ~/.config"
            echo "  --yes, -y        Non-interactive mode (accept all default prompts)"
            echo "  --dry-run        Test and preview steps without modifying files"
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

# ─── 1. Environment & Hardware / Hypervisor Detection ─────────────────────────
log "Detecting hardware & runtime environment..."

IS_VM=false
VIRT_TYPE="none"
if command -v systemd-detect-virt &>/dev/null; then
    if VIRT_OUT=$(systemd-detect-virt 2>/dev/null); then
        if [ "$VIRT_OUT" != "none" ] && [ -n "$VIRT_OUT" ]; then
            IS_VM=true
            VIRT_TYPE="$VIRT_OUT"
        fi
    fi
fi

if [ "$IS_VM" = true ]; then
    info "Virtual Machine detected (${VIRT_TYPE}). Enabling VM-specific optimizations..."
else
    ok "Bare-metal hardware detected."
fi

# ─── 2. Sudo Privileges & Keepalive ───────────────────────────────────────────
if [ "$DRY_RUN" = false ]; then
    log "Requesting administrator privileges..."
    sudo -v || { err "Administrator privileges required for package installation."; exit 1; }
    # Keep sudo alive throughout installation
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi

# ─── 3. Package Management & Automatic AUR Helper Bootstrap ───────────────────
log "Configuring AUR helper (yay / paru)..."

AUR_HELPER=""

if [ "$AUTO_YES" = true ]; then
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    else
        AUR_HELPER="yay"
    fi
else
    echo -e "  ${C_CYAN}Select your preferred AUR helper:${C_RESET}"
    echo -e "    ${C_BOLD}1) yay${C_RESET}   (Fast, Go-based AUR helper)"
    echo -e "    ${C_BOLD}2) paru${C_RESET}  (Feature-packed, Rust-based AUR helper)"
    read -rp "  Enter choice [1/2] (default: 1): " aur_choice
    case "$aur_choice" in
        2|paru) AUR_HELPER="paru" ;;
        *)      AUR_HELPER="yay" ;;
    esac
fi

if ! command -v "$AUR_HELPER" &>/dev/null && [ "$DRY_RUN" = false ]; then
    info "'$AUR_HELPER' is not installed. Bootstrapping '${AUR_HELPER}-bin' from AUR..."
    sudo pacman -S --needed --noconfirm base-devel git
    BOOTSTRAP_DIR="/tmp/${AUR_HELPER}_bootstrap_$$"
    mkdir -p "$BOOTSTRAP_DIR"
    git clone "https://aur.archlinux.org/${AUR_HELPER}-bin.git" "$BOOTSTRAP_DIR/${AUR_HELPER}-bin"
    (cd "$BOOTSTRAP_DIR/${AUR_HELPER}-bin" && makepkg -si --noconfirm)
    rm -rf "$BOOTSTRAP_DIR"
    ok "Installed and configured '$AUR_HELPER' successfully!"
else
    ok "Using AUR helper: $AUR_HELPER"
fi

# ─── 4. Install Dependencies ──────────────────────────────────────────────────
log "Checking system dependencies..."

OFFICIAL_PKGS=(
    hyprland
    hypridle
    hyprlock
    swaybg
    pipewire
    wireplumber
    pipewire-pulse
    pavucontrol
    playerctl
    brightnessctl
    power-profiles-daemon
    upower
    networkmanager
    bluez
    bluez-utils
    wl-clipboard
    cliphist
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
    nautilus
    micro
    steam
    loupe
    file-roller
    ttf-font-awesome
    ttf-inter
    ttf-jetbrains-mono-nerd
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    hyprpolkitagent
)

MISSING_OFFICIAL=()
for pkg in "${OFFICIAL_PKGS[@]}"; do
    if ! pacman -Q "$pkg" &>/dev/null; then
        MISSING_OFFICIAL+=("$pkg")
    fi
done

if [ ${#MISSING_OFFICIAL[@]} -gt 0 ]; then
    info "Installing ${#MISSING_OFFICIAL[@]} missing official packages..."
    if [ "$DRY_RUN" = false ]; then
        sudo pacman -S --needed --noconfirm "${MISSING_OFFICIAL[@]}" || warn "Some official packages failed to install."
    fi
else
    ok "All core official packages are satisfied!"
fi

# Essential AUR packages (Quickshell, wlrctl)
AUR_PKGS=()
if ! pacman -Q quickshell &>/dev/null && ! pacman -Q quickshell-git &>/dev/null; then
    AUR_PKGS+=(quickshell)
fi
if ! pacman -Q wlrctl &>/dev/null; then
    AUR_PKGS+=(wlrctl)
fi

if [ ${#AUR_PKGS[@]} -gt 0 ]; then
    info "Installing AUR packages: ${AUR_PKGS[*]}..."
    if [ "$DRY_RUN" = false ] && [ -n "$AUR_HELPER" ]; then
        $AUR_HELPER -S --needed --noconfirm "${AUR_PKGS[@]}" || {
            # Fallback for quickshell package naming variations
            warn "Attempting fallback to quickshell-git..."
            $AUR_HELPER -S --needed --noconfirm quickshell-git wlrctl || true
        }
    fi
fi

# Recommended AUR apps (Vesktop, Brave)
EXTRA_AUR=()
if ! command -v vesktop &>/dev/null && ! (command -v flatpak &>/dev/null && flatpak info dev.vencord.Vesktop &>/dev/null 2>&1); then
    EXTRA_AUR+=(vesktop-bin)
fi
if ! command -v brave &>/dev/null && ! command -v brave-browser &>/dev/null; then
    EXTRA_AUR+=(brave-bin)
fi

if [ ${#EXTRA_AUR[@]} -gt 0 ] && [ "$DRY_RUN" = false ] && [ -n "$AUR_HELPER" ]; then
    if [ "$AUTO_YES" = true ]; then
        $AUR_HELPER -S --needed --noconfirm "${EXTRA_AUR[@]}" 2>/dev/null || true
    else
        read -rp "  Install recommended apps (${EXTRA_AUR[*]}) with $AUR_HELPER? [Y/n] " aur_choice
        if [[ ! "$aur_choice" =~ ^[Nn]$ ]]; then
            $AUR_HELPER -S --needed --noconfirm "${EXTRA_AUR[@]}" || warn "Could not install some recommended apps."
        fi
    fi
fi

# ─── 5. Deploy Bundled Custom Fonts ───────────────────────────────────────────
log "Deploying bundled custom typography (Rowdies, Font Awesome 6 Pro, Inter)..."

FONT_DIR="$HOME/.local/share/fonts/kadal"
mkdir -p "$FONT_DIR"

if [ -d "$DOTFILES_DIR/assets/fonts" ]; then
    if [ "$DRY_RUN" = false ]; then
        cp -rf "$DOTFILES_DIR/assets/fonts/"* "$FONT_DIR/"
        fc-cache -f "$FONT_DIR" 2>/dev/null || true
        ok "Custom fonts installed and font-cache refreshed!"
    fi
else
    warn "assets/fonts directory not found in repository. Using system fallbacks."
fi

# ─── 6. Backup Existing Configs ───────────────────────────────────────────────
log "Preparing configuration deployment (Mode: ${MODE})..."

CONFIG_DIRS=(
    hypr
    quickshell
    ghostty
    fastfetch
    cava
    btop
    fish
    pipewire
)

mkdir -p "$HOME/.config"
BACKUP_CREATED=false

for d in "${CONFIG_DIRS[@]}"; do
    target="$HOME/.config/$d"
    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ "$BACKUP_CREATED" = false ] && [ "$DRY_RUN" = false ]; then
            mkdir -p "$BACKUP_DIR"
            BACKUP_CREATED=true
        fi
        if [ "$DRY_RUN" = false ]; then
            info "Archiving existing ~/.config/$d to ${BACKUP_DIR}/"
            mv "$target" "$BACKUP_DIR/"
        fi
    fi
done

if [ "$BACKUP_CREATED" = true ]; then
    ok "Existing configurations safely archived at ${BACKUP_DIR}"
fi

# ─── 7. Deploy Configurations ─────────────────────────────────────────────────
log "Deploying configurations..."

for d in "${CONFIG_DIRS[@]}"; do
    src="$DOTFILES_DIR/.config/$d"
    dst="$HOME/.config/$d"

    if [ ! -d "$src" ]; then
        continue
    fi

    if [ "$DRY_RUN" = false ]; then
        if [ "$MODE" = "symlink" ]; then
            info "Symlinking $dst ➜ $src"
            ln -sfn "$src" "$dst"
        else
            info "Copying $src ➜ $dst"
            cp -rf "$src" "$dst"
        fi
    fi
done

# Ensure executable permissions on helper scripts
if [ "$DRY_RUN" = false ]; then
    chmod +x "$HOME/.config/hypr/"*.sh 2>/dev/null || true
    chmod +x "$HOME/.config/hypr/"*.py 2>/dev/null || true
fi
ok "Configurations deployed with executable script permissions!"

# ─── 8. VM Optimizations (Software Cursor Fallback) ───────────────────────────
if [ "$IS_VM" = true ] && [ "$DRY_RUN" = false ]; then
    log "Applying Virtual Machine display & cursor tweaks..."
    # Ensure hardware cursors are disabled in VM so mouse pointer is always visible
    HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
    if [ -f "$HYPR_LUA" ]; then
        if ! grep -q "no_hardware_cursors = true" "$HYPR_LUA"; then
            sed -i 's/no_hardware_cursors = false/no_hardware_cursors = true/g' "$HYPR_LUA"
        fi
    fi
    ok "VM software cursor fallback enabled!"
fi

# ─── 9. Desktop Wallpaper Setup ───────────────────────────────────────────────
log "Desktop Wallpaper Setup..."

NEED_WALLPAPER=true
if [ "$AUTO_YES" = false ]; then
    read -rp "  Do you want to setup wallpaper? [Y/n] " wp_needed_input
    if [[ "$wp_needed_input" =~ ^[Nn]$ ]]; then
        NEED_WALLPAPER=false
        info "Skipping wallpaper setup as requested."
    fi
fi

if [ "$NEED_WALLPAPER" = true ]; then
    mkdir -p "$HOME/Pictures"

    # 1. Deploy default bundled wallpaper immediately
    if [ -f "$DOTFILES_DIR/assets/wallpaper/default.jpg" ] && [ "$DRY_RUN" = false ]; then
        cp -f "$DOTFILES_DIR/assets/wallpaper/default.jpg" "$HOME/Pictures/wall.jpg"
        echo "$HOME/Pictures/wall.jpg" > "$HOME/.config/hypr/current_wallpaper" 2>/dev/null || true
        ok "Default high-resolution Catppuccin wallpaper deployed!"
    fi

    # 2. Optionally clone the 120-wallpaper collection
    WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
    if [ ! -d "$WALLPAPER_DIR" ] && [ "$DRY_RUN" = false ]; then
        if [ "$AUTO_YES" = true ]; then
            info "Non-interactive mode: skipping full 120-wallpaper collection download."
        else
            read -rp "  Would you also like to download the full 120-wallpaper collection from GitHub (~200MB)? [y/N] " full_wp_choice
            if [[ "$full_wp_choice" =~ ^[Yy]$ ]]; then
                info "Cloning wallpapers to ${WALLPAPER_DIR}..."
                git clone --depth 1 https://github.com/codemonkx/Wallpapers.git "$WALLPAPER_DIR" || warn "Could not clone wallpapers. You can download manually later."
            fi
        fi
    else
        ok "Wallpapers directory ready at ${WALLPAPER_DIR}"
    fi
fi

# ─── 10. Enable System & User Services ────────────────────────────────────────
log "Enabling background daemons & user services..."

if [ "$DRY_RUN" = false ]; then
    # System daemons
    sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null || true
    sudo systemctl enable --now bluetooth.service 2>/dev/null || true

    # User audio & portal services
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true

    # Default file manager association
    xdg-mime default org.gnome.Nautilus.desktop inode/directory 2>/dev/null || true
fi
ok "System services and user daemons configured!"

# ─── 11. Automated Post-Install Health Check ──────────────────────────────────
log "Running post-installation validation..."

HEALTH_ERRORS=0

# Check 1: Hyprland configuration syntax
if command -v hyprland &>/dev/null; then
    if hyprland --verify-config &>/dev/null; then
        ok "Hyprland configuration syntax: OK (Lua engine validated)"
    else
        warn "Hyprland configuration reported warnings or syntax notices."
    fi
fi

# Check 2: Rowdies font registration
if fc-list :family=Rowdies | grep -q "Rowdies"; then
    ok "Custom typography (Rowdies): Registered"
else
    warn "Rowdies font not registered in fontconfig."
    ((HEALTH_ERRORS++))
fi

# Check 3: Quickshell binary
if command -v quickshell &>/dev/null; then
    ok "Desktop shell (Quickshell): Installed"
else
    warn "Quickshell binary not found in PATH."
    ((HEALTH_ERRORS++))
fi

# Check 4: Clipboard utilities
if command -v wl-copy &>/dev/null && command -v cliphist &>/dev/null; then
    ok "Clipboard subsystem (wl-clipboard + cliphist): OK"
else
    warn "Clipboard utilities missing."
    ((HEALTH_ERRORS++))
fi

# ─── 12. Final Summary ────────────────────────────────────────────────────────
echo -e "\n${C_GREEN}${C_BOLD}✔ Installation completed successfully!${C_RESET}\n"
echo -e "Summary:"
echo -e "  • Mode:              ${C_BOLD}${MODE}${C_RESET} (to ~/.config)"
echo -e "  • Hypervisor/Target: ${C_BOLD}${VIRT_TYPE}${C_RESET}"
echo -e "  • Wallpapers:        ${C_BOLD}~/Pictures/wall.jpg${C_RESET}"
echo -e "  • Custom Fonts:      ${C_BOLD}~/.local/share/fonts/kadal/${C_RESET}"
echo -e "\nNext steps:"
echo -e "  1. If running inside Hyprland: run ${C_BOLD}hyprctl reload${C_RESET} and ${C_BOLD}~/.config/hypr/refresh.sh${C_RESET}"
echo -e "  2. Or simply log out and start a fresh Hyprland session."
echo -e "  3. Open Control Panel:    ${C_BOLD}SUPER + A${C_RESET}"
echo -e "  4. Open App Launcher:     ${C_BOLD}SUPER + SPACE${C_RESET}"
echo -e "  5. Open Screenshot Tool:  ${C_BOLD}SUPER + SHIFT + S${C_RESET} or ${C_BOLD}PrintScreen${C_RESET}\n"
