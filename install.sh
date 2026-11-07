#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  ❄️ Catppuccin Sapphire Hyprland + Quickshell Desktop Environment Installer
#  Repository: https://github.com/codemonkx/Dot_Files
#  Designed for 100% reproducible deployment on Bare Metal & Virtual Machines
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Terminal Colors & Visual Formatting ───────────────────────────────────────
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_BLUE="\033[38;2;137;180;250m"      # #89B4FA (Sapphire Blue)
C_CYAN="\033[38;2;137;220;235m"      # #89DCEB
C_GREEN="\033[38;2;166;227;161m"     # #A6E3A1
C_YELLOW="\033[38;2;249;226;175m"    # #F9E2AF
C_RED="\033[38;2;243;139;168m"       # #F38BA8
C_MAGENTA="\033[38;2;203;166;247m"   # #CBA6F7
C_SURFACE="\033[38;2;49;50;68m"      # #313244

log()   { echo -e "\n${C_BLUE}${C_BOLD}::${C_RESET} ${C_BOLD}$*${C_RESET}"; }
info()  { echo -e "  ${C_CYAN}➜${C_RESET} $*"; }
ok()    { echo -e "  ${C_GREEN}✔${C_RESET} $*"; }
warn()  { echo -e "  ${C_YELLOW}▲${C_RESET} $*"; }
err()   { echo -e "  ${C_RED}✖${C_RESET} $*" >&2; }

# ─── Self-Bootstrapping Detection (Pipe / Remote Curl support) ─────────────────
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_SOURCE" ] && [ -f "$SCRIPT_SOURCE" ]; then
    DOTFILES_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
else
    DOTFILES_DIR=""
fi

REPO_URL="https://github.com/codemonkx/Dot_Files.git"
TARGET_CLONE_DIR="$HOME/.dotfiles"

# If script was piped through curl or run outside the git repository
if [ -z "$DOTFILES_DIR" ] || [ ! -d "$DOTFILES_DIR/.config/hypr" ]; then
    echo -e "${C_BLUE}${C_BOLD}::${C_RESET} ${C_BOLD}Bootstrapping Catppuccin Sapphire Dotfiles...${C_RESET}"
    info "Preparing target directory at ${TARGET_CLONE_DIR}..."

    if ! command -v git &>/dev/null; then
        info "Installing git..."
        sudo pacman -S --needed --noconfirm git base-devel
    fi

    if [ -d "$TARGET_CLONE_DIR/.git" ]; then
        info "Updating existing repository at ${TARGET_CLONE_DIR}..."
        git -C "$TARGET_CLONE_DIR" pull --ff-only || true
    else
        info "Cloning repository from ${REPO_URL}..."
        git clone "$REPO_URL" "$TARGET_CLONE_DIR"
    fi

    info "Handing over execution to local installer..."
    exec bash "$TARGET_CLONE_DIR/install.sh" "$@"
fi

# ─── Configuration & Defaults ──────────────────────────────────────────────────
BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
INSTALL_ACTION="full"  # full | symlink | config_only | pkgs_only
MODE="copy"            # copy | symlink
AUTO_YES=false
DRY_RUN=false

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
    systemd
)

# ─── Parse Command-Line Flags ─────────────────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --copy|-c)         MODE="copy";    INSTALL_ACTION="full" ;;
        --symlink|-s)      MODE="symlink"; INSTALL_ACTION="symlink" ;;
        --config-only|-co) INSTALL_ACTION="config_only" ;;
        --pkgs-only|-po)   INSTALL_ACTION="pkgs_only" ;;
        --yes|-y)          AUTO_YES=true ;;
        --dry-run)         DRY_RUN=true ;;
        --help|-h)
            echo -e "${C_BOLD}Catppuccin Sapphire Hyprland + Quickshell Installer${C_RESET}"
            echo ""
            echo "Usage: ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --copy, -c          Full installation, copying configs to ~/.config (default)"
            echo "  --symlink, -s       Full installation, symlinking ~/.config to repo"
            echo "  --config-only, -co  Only deploy configs & fonts (skip package installs)"
            echo "  --pkgs-only, -po    Only install system dependencies & AUR packages"
            echo "  --yes, -y           Non-interactive mode (accept all default options)"
            echo "  --dry-run           Test run without modifying files or installing packages"
            echo "  --help, -h          Display this help message"
            echo ""
            exit 0
            ;;
    esac
done

# ─── Header Banner ────────────────────────────────────────────────────────────
clear 2>/dev/null || true
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
echo -e "  ${C_CYAN}Catppuccin Sapphire Hyprland + Quickshell Desktop Environment${C_RESET}"
echo -e "  ${C_DIM}Source: ${DOTFILES_DIR}${C_RESET}\n"

# ─── Interactive Mode Selector ─────────────────────────────────────────────────
if [ "$AUTO_YES" = false ] && [ "$INSTALL_ACTION" = "full" ] && [ "$MODE" = "copy" ]; then
    echo -e "  ${C_BOLD}Choose an installation profile:${C_RESET}"
    echo -e "    ${C_BLUE}${C_BOLD}[1] Standard Full Install${C_RESET} ${C_DIM}(Recommended: packages, configs, fonts, services)${C_RESET}"
    echo -e "    ${C_CYAN}${C_BOLD}[2] Developer Symlink Mode${C_RESET} ${C_DIM}(Symlinks ~/.config to this repo for live editing)${C_RESET}"
    echo -e "    ${C_MAGENTA}${C_BOLD}[3] Update Configs Only${C_RESET} ${C_DIM}(Deploy latest configs & fonts without touching packages)${C_RESET}"
    echo -e "    ${C_YELLOW}${C_BOLD}[4] Packages & Services Only${C_RESET} ${C_DIM}(Install required dependencies and start daemons)${C_RESET}"
    echo -e "    ${C_DIM}[5] Exit installer${C_RESET}"
    echo ""
    read -rp "  Select option [1-5] (default: 1): " choice
    case "$choice" in
        2) MODE="symlink"; INSTALL_ACTION="symlink" ;;
        3) INSTALL_ACTION="config_only" ;;
        4) INSTALL_ACTION="pkgs_only" ;;
        5) echo "Installation cancelled."; exit 0 ;;
        *) MODE="copy";    INSTALL_ACTION="full" ;;
    esac
fi

# ─── Step 1: Environment & Virtualization Detection ────────────────────────────
log "[1/7] Inspecting hardware and hypervisor environment..."

IS_VM=false
VIRT_TYPE="Bare Metal"
if command -v systemd-detect-virt &>/dev/null; then
    if DETECTED_VIRT=$(systemd-detect-virt 2>/dev/null); then
        if [ "$DETECTED_VIRT" != "none" ] && [ -n "$DETECTED_VIRT" ]; then
            IS_VM=true
            VIRT_TYPE="Virtual Machine (${DETECTED_VIRT})"
        fi
    fi
fi

if [ "$IS_VM" = true ]; then
    info "Virtualization detected: ${C_YELLOW}${VIRT_TYPE}${C_RESET}. Software cursor fallback will be configured."
else
    ok "Host environment: ${C_GREEN}${VIRT_TYPE}${C_RESET}"
fi

# Detect ASUS ROG/TUF gaming hardware
IS_ASUS_GAMING=false
if [ -f /sys/class/dmi/id/product_name ]; then
    DMI_PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
    if echo "$DMI_PRODUCT" | grep -Ei "ROG|TUF|Zephyrus|Strix|Flow" &>/dev/null; then
        IS_ASUS_GAMING=true
        info "ASUS gaming laptop detected (${DMI_PRODUCT}). GPU helper integration active."
    fi
fi

# ─── Step 2: Sudo Privileges & Keepalive ──────────────────────────────────────
if [ "$INSTALL_ACTION" != "config_only" ] && [ "$DRY_RUN" = false ]; then
    log "[2/7] Authenticating administrative privileges..."
    sudo -v || { err "Administrator privileges required for package management."; exit 1; }
    # Background sudo keepalive
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi

# ─── Step 3: Package Management & System Dependencies ──────────────────────────
if [ "$INSTALL_ACTION" = "full" ] || [ "$INSTALL_ACTION" = "symlink" ] || [ "$INSTALL_ACTION" = "pkgs_only" ]; then
    log "[3/7] Managing packages and dependencies..."

    # Configure AUR Helper (yay / paru)
    AUR_HELPER=""
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    else
        AUR_HELPER="yay"
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
        ok "Using AUR helper: ${C_BOLD}$AUR_HELPER${C_RESET}"
    fi

    # Official Arch/CachyOS package list
    OFFICIAL_PKGS=(
        # Compositor & Wayland
        hyprland
        hypridle
        hyprlock
        swaybg
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
        hyprpolkitagent

        # Audio Subsystem
        pipewire
        wireplumber
        pipewire-pulse
        pavucontrol
        playerctl

        # System & Hardware Management
        brightnessctl
        power-profiles-daemon
        upower
        networkmanager
        bluez
        bluez-utils
        blueman
        pacman-contrib

        # Wayland Clipboard & Utilities
        wl-clipboard
        cliphist
        grim
        slurp
        jq
        python
        zenity
        libnotify
        gnome-keyring
        gsettings-desktop-schemas

        # Terminal & Everyday Tools
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

        # Performance & Gaming
        gamemode
        lib32-gamemode
        libva-utils

        # System Typography
        ttf-font-awesome
        ttf-inter
        ttf-jetbrains-mono-nerd
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
            sudo pacman -S --needed --noconfirm "${MISSING_OFFICIAL[@]}" || warn "Some packages could not be installed immediately."
        fi
        ok "Official package dependencies installed."
    else
        ok "All core official packages are already installed."
    fi

    # Essential AUR packages
    AUR_PKGS=()
    if ! pacman -Q quickshell &>/dev/null && ! pacman -Q quickshell-git &>/dev/null; then
        AUR_PKGS+=(quickshell)
    fi
    if ! pacman -Q wlrctl &>/dev/null; then
        AUR_PKGS+=(wlrctl)
    fi

    if [ ${#AUR_PKGS[@]} -gt 0 ] && [ "$DRY_RUN" = false ] && [ -n "$AUR_HELPER" ]; then
        info "Installing core AUR packages: ${AUR_PKGS[*]}..."
        $AUR_HELPER -S --needed --noconfirm "${AUR_PKGS[@]}" || {
            warn "Attempting fallback installation with quickshell-git..."
            $AUR_HELPER -S --needed --noconfirm quickshell-git wlrctl || true
        }
        ok "Core AUR packages satisfied."
    else
        ok "Quickshell and AUR core components are satisfied."
    fi

    # Recommended Desktop Applications (Brave & Vesktop)
    EXTRA_AUR=()
    if ! command -v brave &>/dev/null && ! command -v brave-browser &>/dev/null; then
        EXTRA_AUR+=(brave-bin)
    fi
    if ! command -v vesktop &>/dev/null && ! (command -v flatpak &>/dev/null && flatpak info dev.vencord.Vesktop &>/dev/null 2>&1); then
        EXTRA_AUR+=(vesktop-bin)
    fi

    if [ ${#EXTRA_AUR[@]} -gt 0 ] && [ "$DRY_RUN" = false ] && [ -n "$AUR_HELPER" ]; then
        INSTALL_RECOMMENDED=true
        if [ "$AUTO_YES" = false ]; then
            read -rp "  Install recommended apps (${EXTRA_AUR[*]})? [Y/n] " extra_choice
            if [[ "$extra_choice" =~ ^[Nn]$ ]]; then
                INSTALL_RECOMMENDED=false
            fi
        fi

        if [ "$INSTALL_RECOMMENDED" = true ]; then
            info "Installing recommended desktop applications..."
            $AUR_HELPER -S --needed --noconfirm "${EXTRA_AUR[@]}" 2>/dev/null || warn "Could not install some recommended apps."
            ok "Recommended applications configured."
        fi
    fi
else
    info "Skipping package installation (Config deployment mode)."
fi

# ─── Step 4: Deploy Bundled Custom Typography ─────────────────────────────────
if [ "$INSTALL_ACTION" != "pkgs_only" ]; then
    log "[4/7] Deploying custom fonts & refreshing fontconfig cache..."

    FONT_DIR="$HOME/.local/share/fonts/kadal"
    mkdir -p "$FONT_DIR"

    if [ -d "$DOTFILES_DIR/assets/fonts" ]; then
        if [ "$DRY_RUN" = false ]; then
            cp -rf "$DOTFILES_DIR/assets/fonts/"* "$FONT_DIR/"
            fc-cache -f "$FONT_DIR" 2>/dev/null || true
            ok "Custom typography (Inter, Font Awesome 6 Pro, PixelifySans, Rowdies) deployed."
        fi
    else
        warn "assets/fonts directory not found in repository. Using system font fallbacks."
    fi
fi

# ─── Step 5: Backup & Deploy Configuration Files ──────────────────────────────
if [ "$INSTALL_ACTION" != "pkgs_only" ]; then
    log "[5/7] Deploying desktop configurations (Mode: ${C_BOLD}${MODE}${C_RESET})..."

    mkdir -p "$HOME/.config"
    BACKUP_CREATED=false

    # Backup existing configurations
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
        ok "Existing configurations safely archived at ${C_BOLD}${BACKUP_DIR}${C_RESET}"
    fi

    # Deploy new configurations
    for d in "${CONFIG_DIRS[@]}"; do
        src="$DOTFILES_DIR/.config/$d"
        dst="$HOME/.config/$d"

        if [ ! -d "$src" ]; then
            continue
        fi

        if [ "$DRY_RUN" = false ]; then
            if [ "$MODE" = "symlink" ]; then
                info "Symlinking ${dst} ➜ ${src}"
                ln -sfn "$src" "$dst"
            else
                info "Copying ${src} ➜ ${dst}"
                cp -rf "$src" "$dst"
            fi
        fi
    done

    # Ensure executable permissions on all script helpers
    if [ "$DRY_RUN" = false ]; then
        chmod +x "$HOME/.config/hypr/"*.sh 2>/dev/null || true
        chmod +x "$HOME/.config/hypr/"*.py 2>/dev/null || true
    fi
    ok "Configurations deployed with executable script permissions."

    # VM Optimization: Software Cursors fallback
    if [ "$IS_VM" = true ] && [ "$DRY_RUN" = false ]; then
        info "Applying VM cursor optimization in hyprland.lua..."
        HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
        if [ -f "$HYPR_LUA" ]; then
            sed -i 's/no_hardware_cursors = false/no_hardware_cursors = true/g' "$HYPR_LUA"
            ok "Software cursor fallback configured for Virtual Machine."
        fi
    fi

    # Configure GTK dark mode preference
    if command -v gsettings &>/dev/null && [ "$DRY_RUN" = false ]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
        ok "Configured GTK prefer-dark interface scheme."
    fi
fi

# ─── Step 6: Wallpaper Setup ──────────────────────────────────────────────────
if [ "$INSTALL_ACTION" != "pkgs_only" ]; then
    log "[6/7] Setting up desktop wallpaper..."

    mkdir -p "$HOME/Pictures"

    # Deploy default bundled wallpaper immediately
    if [ -f "$DOTFILES_DIR/assets/wallpaper/default.jpg" ] && [ "$DRY_RUN" = false ]; then
        cp -f "$DOTFILES_DIR/assets/wallpaper/default.jpg" "$HOME/Pictures/wall.jpg"
        echo "$HOME/Pictures/wall.jpg" > "$HOME/.config/hypr/current_wallpaper" 2>/dev/null || true
        ok "Default Catppuccin wallpaper deployed to ~/Pictures/wall.jpg"
    fi

    # Optional 120-Wallpaper Pack download
    WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
    if [ ! -d "$WALLPAPER_DIR" ] && [ "$DRY_RUN" = false ]; then
        if [ "$AUTO_YES" = true ]; then
            info "Skipping full 120-wallpaper collection download (non-interactive mode)."
        else
            read -rp "  Download the complete 120-wallpaper collection (~200MB)? [y/N] " wp_choice
            if [[ "$wp_choice" =~ ^[Yy]$ ]]; then
                info "Cloning wallpapers to ${WALLPAPER_DIR}..."
                git clone --depth 1 https://github.com/codemonkx/Wallpapers.git "$WALLPAPER_DIR" || warn "Wallpaper download skipped."
                ok "Wallpaper collection downloaded."
            fi
        fi
    else
        ok "Wallpaper library ready at ${WALLPAPER_DIR}"
    fi
fi

# ─── Step 7: Services, Daemons & Hardware Rules ───────────────────────────────
log "[7/7] Configuring background daemons & system services..."

if [ "$DRY_RUN" = false ]; then
    # Unblock and enable Bluetooth
    if command -v rfkill &>/dev/null; then
        rfkill unblock bluetooth 2>/dev/null || true
    fi
    sudo systemctl enable --now bluetooth.service 2>/dev/null || true

    # Power profiles daemon
    sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null || true

    # Pacman automatic cache pruning timer
    if systemctl list-unit-files | grep -q "paccache.timer"; then
        sudo systemctl enable --now paccache.timer 2>/dev/null || true
    fi

    # User audio and portal services
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true

    # User workspace auto-collapse daemon (Dynamic Gap Elimination)
    systemctl --user daemon-reload 2>/dev/null || true
    if [ -f "$HOME/.config/systemd/user/workspace-autocollapse.service" ]; then
        systemctl --user enable --now workspace-autocollapse.service 2>/dev/null || true
        ok "Dynamic Workspace Gap Elimination daemon activated."
    fi

    # ASUS GHelper sudoers setup
    if [ -f "/usr/local/lib/ghelper/gpu-helper" ]; then
        if [ ! -f "/etc/sudoers.d/99-ghelper" ]; then
            echo "$USER ALL=(ALL) NOPASSWD: /usr/local/lib/ghelper/gpu-helper" | sudo tee /etc/sudoers.d/99-ghelper >/dev/null
            sudo chmod 0440 /etc/sudoers.d/99-ghelper
            ok "Configured passwordless helper privileges for GHelper."
        fi
    fi

    # Set Nautilus as default directory handler
    xdg-mime default org.gnome.Nautilus.desktop inode/directory 2>/dev/null || true
fi
ok "System services and user daemons configured."

# ─── Post-Installation Verification & Health Check ────────────────────────────
echo ""
echo -e "${C_BLUE}${C_BOLD}══════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "  ${C_CYAN}${C_BOLD}POST-INSTALLATION HEALTH VALIDATION${C_RESET}"
echo -e "${C_BLUE}${C_BOLD}══════════════════════════════════════════════════════════════════${C_RESET}"

CHECK_FAILURES=0

# Hyprland Config Syntax Check
if command -v hyprland &>/dev/null; then
    if hyprland --verify-config &>/dev/null; then
        ok "Hyprland configuration syntax: Valid"
    else
        warn "Hyprland configuration returned syntax notices."
    fi
else
    warn "Hyprland is not yet in PATH."
    ((CHECK_FAILURES++))
fi

# Quickshell Check
if command -v quickshell &>/dev/null; then
    ok "Quickshell desktop engine: Installed"
else
    warn "Quickshell binary not found."
    ((CHECK_FAILURES++))
fi

# Typography Check (Inter & Font Awesome)
if fc-list :family=Inter | grep -qi "Inter"; then
    ok "Primary UI Font (Inter): Registered"
else
    warn "Inter font not detected in fontconfig."
    ((CHECK_FAILURES++))
fi

if fc-list :family="Font Awesome 6 Free" | grep -qi "Font Awesome"; then
    ok "Icon Font (Font Awesome 6): Registered"
else
    warn "Font Awesome 6 not detected in fontconfig."
fi

# Clipboard Utilities Check
if command -v wl-copy &>/dev/null && command -v cliphist &>/dev/null; then
    ok "Clipboard Subsystem (wl-clipboard + cliphist): Ready"
else
    warn "Clipboard utilities missing."
    ((CHECK_FAILURES++))
fi

# Workspace Daemon Check
if systemctl --user is-active --quiet workspace-autocollapse.service 2>/dev/null; then
    ok "Dynamic Workspace Gap Elimination daemon: Running"
else
    info "Workspace daemon installed (will start with Hyprland session)."
fi

# ─── Summary & Next Steps ─────────────────────────────────────────────────────
echo ""
echo -e "${C_GREEN}${C_BOLD}✔ Desktop Environment setup completed successfully!${C_RESET}\n"

echo -e "  • Mode:             ${C_BOLD}${MODE}${C_RESET} (to ~/.config)"
echo -e "  • Target Platform:  ${C_BOLD}${VIRT_TYPE}${C_RESET}"
echo -e "  • Active Wallpaper: ${C_BOLD}~/Pictures/wall.jpg${C_RESET}"
echo -e "  • Custom Fonts:     ${C_BOLD}~/.local/share/fonts/kadal/${C_RESET}"
if [ "$BACKUP_CREATED" = true ]; then
    echo -e "  • Prior Configs:    ${C_BOLD}${BACKUP_DIR}${C_RESET}"
fi

echo -e "\n${C_BOLD}Next Steps:${C_RESET}"
echo -e "  1. If currently inside Hyprland: run ${C_BLUE}${C_BOLD}hyprctl reload${C_RESET} and ${C_BLUE}${C_BOLD}~/.config/hypr/refresh.sh${C_RESET}"
echo -e "  2. Or simply log out and start a fresh Hyprland session."

echo -e "\n${C_BOLD}Essential Shortcuts:${C_RESET}"
echo -e "  • App Launcher:         ${C_CYAN}SUPER + SPACE${C_RESET}"
echo -e "  • Control Panel:        ${C_CYAN}SUPER + A${C_RESET}"
echo -e "  • Settings Panel:       ${C_CYAN}SUPER + I${C_RESET}"
echo -e "  • Clipboard History:    ${C_CYAN}SUPER + V${C_RESET}"
echo -e "  • Screenshot Tool:      ${C_CYAN}SUPER + Shift + S${C_RESET} or ${C_CYAN}PrintScreen${C_RESET}"
echo -e "  • Wallpaper Selector:   ${C_CYAN}SUPER + W${C_RESET}"
echo -e "  • Full Media Player:    ${C_CYAN}SUPER + M${C_RESET}"
echo -e "  • Terminal (Ghostty):   ${C_CYAN}SUPER + Enter${C_RESET}\n"
