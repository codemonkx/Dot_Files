<div align="center">

# ❄️ Catppuccin Sapphire Hyprland + Quickshell

A modern, fluid, and cohesive Linux desktop environment powered by **Hyprland** and **Quickshell** in the **Catppuccin Sapphire** colorway.

[![Hyprland](https://img.shields.io/badge/Hyprland-0.56+-00ADEF?style=for-the-badge&logo=archlinux&logoColor=white)](https://hyprland.org)
[![Quickshell](https://img.shields.io/badge/Quickshell-0.3.2+-89B4FA?style=for-the-badge&logo=qt&logoColor=white)](https://quickshell.outfoxxed.me)
[![Catppuccin](https://img.shields.io/badge/Palette-Catppuccin%20Mocha%20Sapphire-89B4FA?style=for-the-badge)](https://github.com/catppuccin/catppuccin)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

<br/>

<img src="assets/desktop_showcase.png" alt="Desktop Showcase" width="100%"/>

</div>

<br/>

---

## ✨ Interface Showcase

<table>
  <tr>
    <td width="50%" align="center">
      <b>🎛️ Main Control Panel</b><br/>
      <i>GNOME-style Quick Toggles & Trio of Pill Sliders</i><br/><br/>
      <img src="assets/control_panel_card.png" width="350" />
    </td>
    <td width="50%" align="center">
      <b>⚙️ System Settings Panel</b><br/>
      <i>Unified 2×3 Grid & Sliding Power Profile</i><br/><br/>
      <img src="assets/settings_panel_card.png" width="350" />
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <b>🚀 Application Launcher</b><br/>
      <i>Centered search & categorized quick launch</i><br/><br/>
      <img src="assets/app_launcher_view.png" width="480" />
    </td>
    <td width="50%" align="center">
      <b>🖼️ Animated Wallpaper Selector</b><br/>
      <i>Grid explorer, folder picker & cross-fade engine</i><br/><br/>
      <img src="assets/wallpaper_selector_view.png" width="480" />
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <b>🎵 Full Media Player</b><br/>
      <i>Interactive playback, waveform visualizer & album art glow</i><br/><br/>
      <img src="assets/media_player_view.png" width="480" />
    </td>
    <td width="50%" align="center">
      <b>📺 Native Screen Share Picker</b><br/>
      <i>Catppuccin Sapphire picker for Vesktop, Discord & OBS</i><br/><br/>
      <img src="assets/screenshare_picker_card.png" width="480" />
    </td>
  </tr>
</table>

---

## 🌟 Desktop Shell & UI Features

- **Top Bar (`Bar.qml`):** Floating curved capsule with active workspaces, live clock & calendar, dynamic music ticker, and interactive system status pill.
- **Control Panel (`ControlPanel.qml`):**
  - Instantaneous 144Hz C++ PipeWire volume slider with audio sink switcher.
  - Dedicated microphone volume & mute slider with real-time feedback.
  - Screen brightness slider with hardware backlight integration.
  - Wi-Fi, Bluetooth, Do Not Disturb, and Notification toggles.
- **System Settings Panel:**
  - **Night Light:** GPU fragment shader (`night-light.frag`) warm temperature filter.
  - **Caffeine Mode:** Prevents screen dimming and lock idle timers.
  - **Refresh Rate:** 144Hz Smooth vs 60Hz Battery Saver instant toggle.
  - **Window Blur:** Dynamic Hyprland blur toggle.
  - **Touchpad:** macOS Natural Scrolling & Tap to Click controls.
  - **Power Profiles:** 3-Way sliding pill for Performance, Balanced, and Power Saver.
  - **Quick Shortcuts:** Instant terminal shortcuts to `hyprland.conf` and `quickshell`.
- **Screen Share Picker (`ScreenSharePicker.qml` & `share_picker.sh`):**
  - Replaces default Qt `hyprland-share-picker` with a native Catppuccin Sapphire Quickshell modal.
  - Direct integration with `xdg-desktop-portal-hyprland` via `~/.config/hypr/xdph.conf`.
  - 3-Way sliding pill for **Displays**, **Application Windows**, and **Region Selection** (`slurp`).
  - Automatic app icon mapping, workspace indicators, and token remember support.
- **Wallpapers (`WallpaperSelector.qml` & `WallpaperBackground.qml`):** Smooth cross-fade animation engine, category explorer, folder manager, and automatic synchronization with [`Wallpapers`](https://github.com/codemonkx/Wallpapers).
- **Notifications (`NotificationPanel.qml` & `NotificationToasts.qml`):** Floating toast banners and collapsible history center.
- **Lock Screen (`hyprlock.conf`):** Catppuccin Sapphire authentication card with blurred wallpaper backdrop.

---

## 🚀 One-Line Installation

Clone the repository and run the automated installer:

```bash
git clone https://github.com/codemonkx/Dot_Files.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

### What the installer does:
1. Verifies and installs all required dependencies (`hyprland`, `quickshell`, `pipewire`, `wireplumber`, `brightnessctl`, `fonts`, etc.).
2. Creates a timestamped backup of your existing configs in `~/.config_backup_<timestamp>/`.
3. Symlinks all configuration directories (`hypr`, `quickshell`, `ghostty`, `cava`, `fastfetch`, `btop`, `fish`) into `~/.config/`.
4. Clones the official [`Wallpapers`](https://github.com/codemonkx/Wallpapers) repository into `~/Pictures/Wallpapers`.
5. Enables background system services (`power-profiles-daemon`, `bluetooth`).

---

## ⌨️ Keybindings Reference

| Shortcut | Description |
| :--- | :--- |
| <kbd>SUPER</kbd> + <kbd>SPACE</kbd> | Open App Launcher |
| <kbd>SUPER</kbd> + <kbd>A</kbd> | Toggle Main Control Panel |
| <kbd>SUPER</kbd> + <kbd>I</kbd> | Toggle System Settings Panel |
| <kbd>SUPER</kbd> + <kbd>W</kbd> | Open Wallpaper Selector |
| <kbd>SUPER</kbd> + <kbd>N</kbd> | Toggle Notification Center |
| <kbd>SUPER</kbd> + <kbd>M</kbd> | Toggle Full Media Player |
| <kbd>SUPER</kbd> + <kbd>Return</kbd> | Launch Ghostty Terminal |
| <kbd>SUPER</kbd> + <kbd>Q</kbd> | Close Active Window |
| <kbd>SUPER</kbd> + <kbd>L</kbd> | Lock Screen (`hyprlock`) |
| <kbd>SUPER</kbd> + <kbd>Esc</kbd> | Open Power Menu |
| <kbd>XF86AudioMute</kbd> | Toggle Speaker Mute (with OSD) |
| <kbd>XF86AudioMicMute</kbd> | Toggle Microphone Mute (with OSD) |
| <kbd>XF86AudioRaiseVolume</kbd> | Volume Up (with OSD) |
| <kbd>XF86AudioLowerVolume</kbd> | Volume Down (with OSD) |
| <kbd>XF86MonBrightnessUp</kbd> | Brightness Up (with OSD) |
| <kbd>XF86MonBrightnessDown</kbd> | Brightness Down (with OSD) |

---

## 📦 Required Dependencies & Essential Applications

If you prefer to install software manually or verify your environment:

### 1. Essential Desktop & Everyday Apps
| Application | Category | Package | Description |
| :--- | :--- | :--- | :--- |
| **Nautilus** | File Manager | `nautilus` | Sleek GTK4 file manager with dark theme support |
| **Micro** | Terminal Editor | `micro` | Modern terminal text editor with mouse support & standard shortcuts |
| **Vesktop** | Discord Client | `vesktop-bin` | Wayland-optimized Discord client with screen audio sharing |
| **Steam** | Gaming Platform | `steam` | Valve gaming client with Proton/Wine compatibility |
| **Brave** | Web Browser | `brave-bin` | Fast, privacy-oriented web browser |
| **Loupe** | Image Viewer | `loupe` | Fast image viewer for GNOME/Wayland |
| **File Roller** | Archive Manager | `file-roller` | Archive manager for `.zip`, `.tar.gz`, `.7z`, and `.rar` |
| **Pavucontrol** | Audio Device Manager | `pavucontrol` | Detailed PipeWire/PulseAudio input/output switcher |
| **Hyprpolkitagent** | Auth Agent | `hyprpolkitagent` | Polkit authentication agent for privilege escalation |

```bash
# Official repository apps
sudo pacman -S nautilus micro steam loupe file-roller pavucontrol hyprpolkitagent vlc

# AUR apps (Vesktop & Brave)
yay -S vesktop-bin brave-bin
# (Or via Flatpak: flatpak install flathub dev.vencord.Vesktop com.brave.Browser)
```

---

### 2. Core Compositor & Environment
```bash
sudo pacman -S hyprland hypridle hyprlock swaybg pipewire wireplumber playerctl brightnessctl power-profiles-daemon upower networkmanager bluez bluez-utils wl-clipboard grim slurp jq python zenity ghostty fish fastfetch cava btop
```

### 3. AUR Desktop Shell
```bash
yay -S quickshell-git
```

### 4. Required Fonts
```bash
sudo pacman -S ttf-font-awesome ttf-inter ttf-jetbrains-mono-nerd
```

---

## 📂 Repository Layout

```
.
├── .config/
│   ├── hypr/               # Hyprland, hyprlock, hypridle, shaders & scripts
│   ├── quickshell/         # Complete QML desktop shell components
│   ├── ghostty/            # Terminal theme and typography
│   ├── fastfetch/          # Custom fastfetch ASCII art & spec sheet
│   ├── cava/               # Audio visualizer config & shaders
│   ├── btop/               # System monitor theme
│   └── fish/               # Fish shell configuration
├── assets/                 # High-resolution screenshots and showcase media
├── install.sh              # Automated interactive installer
├── uninstall.sh            # Backup restorer & uninstaller
├── .gitignore              # Clean ignore rules
└── README.md               # Documentation & keybinding guide
```

---

## 👤 Author

- **GitHub:** [@codemonkx](https://github.com/codemonkx)
- **Email:** [nithinx002@gmail.com](mailto:nithinx002@gmail.com)
