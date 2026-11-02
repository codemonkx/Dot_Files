-- Hyprland Lua Configuration
-- Migrated from hyprland.conf for Hyprland 0.56+ / 0.57+
-- Refer to https://wiki.hypr.land/Configuring/Start/

---@module 'hl'

------------------
---- MONITORS ----
------------------

-- Primary Laptop Display (144Hz)
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@144",
    position = "0x0",
    scale    = 1,
})

-- Universal Monitor Fallback (Works automatically for VMs, Virtual-1, and external displays)
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "ghostty"
local fileManager = "nautilus"
local menu        = "qs ipc call launcher toggle"
local mainMod     = "SUPER"

-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
    hl.exec_cmd("hypridle")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("~/.config/hypr/swaybg.sh")
    hl.exec_cmd("~/.config/hypr/quickshell.sh")
    hl.exec_cmd("~/.config/hypr/clipboard.sh daemon")
    hl.exec_cmd("python3 ~/.config/hypr/workspace_autocollapse.py")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XCURSOR_THEME", "phinger-cursors-light")
hl.env("HYPRCURSOR_THEME", "phinger-cursors-light")

-- GPU selection lives in ~/.config/environment.d/gpu.conf (env= here is too late).
-- NOTE: use only plain /dev/dri/cardN paths there. Do NOT use
-- /dev/dri/by-path/* — aquamarine splits AQ_DRM_DEVICES on ':' and those
-- names contain colons, which makes it fail with "Found no gpus to use".

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    general = {
        gaps_in  = 1,
        gaps_out = 3,
        border_size = 3,
        layout = "dwindle",
        allow_tearing = false,
        col = {
            active_border   = "rgba(121212ee)",
            inactive_border = "rgba(1E1E1Eaa)",
        },
    },

    decoration = {
        rounding = 8,
        blur = {
            enabled = true,
            size    = 3,
            passes  = 1,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = 0,
        focus_on_activate = true,
        initial_workspace_tracking = 1,
    },

    input = {
        kb_layout = "us",
        numlock_by_default = true,
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
        },
        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.
    },
})

-- Animation curves
hl.curve("myBezier", {
    type = "bezier",
    points = { { 0.05, 0.9 }, { 0.1, 1.05 } },
})

hl.animation({ leaf = "windows",     enabled = true, speed = 4, bezier = "default", style = "popin 10%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",      enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade",        enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 4, bezier = "default" })

-----------------
---- DEVICES ----
-----------------

hl.device({
    name = "epic-mouse-v1",
})

----------------------
---- WINDOW RULES ----
----------------------

-- Picture-in-Picture
hl.window_rule({
    name = "pip",
    match = { title = "(?i).*(picture-in-picture|picture in picture).*" },
    float = true,
    pin = true,
    size = "640 360",
    move = "100%-660 100%-380",
})

-- File Choosers & Modals
hl.window_rule({
    name = "file-dialogs",
    match = { title = "^(Open File|Save File|Open Folder|Choose Files|Save As|Select a File|Confirm to replace files)$" },
    float = true,
    center = true,
    size = "900 600",
})

-- System Utilities
hl.window_rule({
    name = "pavucontrol",
    match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol)$" },
    float = true,
    center = true,
    size = "720 540",
})

hl.window_rule({
    name = "nm-connection-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
    center = true,
    size = "680 500",
})

hl.window_rule({
    name = "blueman-manager",
    match = { class = "^(blueman-manager)$" },
    float = true,
    center = true,
    size = "680 500",
})

hl.window_rule({
    name = "file-roller",
    match = { class = "^(org.gnome.FileRoller)$" },
    float = true,
    center = true,
    size = "750 500",
})

hl.window_rule({
    name = "xdg-desktop-portal-gtk",
    match = { class = "^(xdg-desktop-portal-gtk)$" },
    float = true,
    center = true,
})

---------------------
---- KEYBINDINGS ----
---------------------

-- Applications & Windows
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("hyprctl dispatch exit"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/refresh.sh"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 0"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 1"))
hl.bind(mainMod .. " + SHIFT + SPACE", hl.dsp.window.float())
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("brave"))

-- Focus movement
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Switch workspaces with Numpad keys (NumLock On & Off)
local numpad_map = {
    { on = "KP_1", off = "KP_End",    ws = 1 },
    { on = "KP_2", off = "KP_Down",   ws = 2 },
    { on = "KP_3", off = "KP_Next",   ws = 3 },
    { on = "KP_4", off = "KP_Left",   ws = 4 },
    { on = "KP_5", off = "KP_Begin",  ws = 5 },
    { on = "KP_6", off = "KP_Right",  ws = 6 },
    { on = "KP_7", off = "KP_Home",   ws = 7 },
    { on = "KP_8", off = "KP_Up",     ws = 8 },
    { on = "KP_9", off = "KP_Prior",  ws = 9 },
    { on = "KP_0", off = "KP_Insert", ws = 10 },
}

for _, np in ipairs(numpad_map) do
    hl.bind(mainMod .. " + " .. np.on,  hl.dsp.focus({ workspace = np.ws }))
    hl.bind(mainMod .. " + " .. np.off, hl.dsp.focus({ workspace = np.ws }))
    hl.bind(mainMod .. " + SHIFT + " .. np.on,  hl.dsp.window.move({ workspace = np.ws }))
    hl.bind(mainMod .. " + SHIFT + " .. np.off, hl.dsp.window.move({ workspace = np.ws }))
end

-- Workspaces mouse scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move & resize windows with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Hardware Multimedia keys (Volume, Brightness, Mute)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl s 5%+ && qs ipc call osd brightness"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%- && qs ipc call osd brightness"), { repeating = true, locked = true })
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),         { repeating = true, locked = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true })

-- Quickshell Integration
hl.bind(mainMod .. " + D", hl.dsp.global("quickshell:launcher"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("qs ipc call control toggle"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("qs ipc call control openSettings"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
-- Laptop lid close & open triggers
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl dispatch dpms on"), { locked = true })
hl.bind(mainMod .. " + escape", hl.dsp.exec_cmd("qs ipc call power toggle"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs ipc call wallpaper toggle"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("~/.config/hypr/clipboard.sh toggle"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("~/.config/hypr/clipboard.sh open-emoji"))

-- GNOME-style interactive screenshot overlay
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("qs ipc call screenshot toggle"))
hl.bind("Print",                   hl.dsp.exec_cmd("qs ipc call screenshot toggle"))
hl.bind(mainMod .. " + Print",     hl.dsp.exec_cmd("qs ipc call screenshot toggle"))

------------------------
---- CURSOR SUBMAP -----
------------------------

hl.define_submap("cursor", function()
    -- Jump cursor to a position
    hl.bind("a", hl.dsp.exec_cmd("hyprctl dispatch submap reset && wl-kbptr && hyprctl dispatch submap cursor"))

    -- Cursor movement
    hl.bind("j", hl.dsp.exec_cmd("wlrctl pointer move 0 10"),  { repeating = true })
    hl.bind("k", hl.dsp.exec_cmd("wlrctl pointer move 0 -10"), { repeating = true })
    hl.bind("l", hl.dsp.exec_cmd("wlrctl pointer move 10 0"),  { repeating = true })
    hl.bind("h", hl.dsp.exec_cmd("wlrctl pointer move -10 0"), { repeating = true })

    -- Buttons
    hl.bind("q", hl.dsp.exec_cmd("wlrctl pointer click left"))
    hl.bind("w", hl.dsp.exec_cmd("wlrctl pointer click middle"))
    hl.bind("e", hl.dsp.exec_cmd("wlrctl pointer click right"))

    -- Scrolling
    hl.bind("f", hl.dsp.exec_cmd("wlrctl pointer scroll 10 0"),  { repeating = true })
    hl.bind("r", hl.dsp.exec_cmd("wlrctl pointer scroll -10 0"), { repeating = true })
    hl.bind("t", hl.dsp.exec_cmd("wlrctl pointer scroll 0 -10"), { repeating = true })
    hl.bind("g", hl.dsp.exec_cmd("wlrctl pointer scroll 0 10"),  { repeating = true })

    -- Exit cursor submap
    hl.bind("escape", hl.dsp.exec_cmd("hyprctl keyword cursor:inactive_timeout 3; hyprctl keyword cursor:hide_on_key_press true; hyprctl dispatch submap reset"))
end)

-- Entrypoint for Cursor Mode (SUPER + C)
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("hyprctl keyword cursor:inactive_timeout 0; hyprctl keyword cursor:hide_on_key_press false; hyprctl dispatch submap cursor"))
