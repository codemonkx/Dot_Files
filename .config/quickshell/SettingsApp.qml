import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower

PanelWindow {
    id: settingsWindow

    property bool isOpen: false
    signal closeRequested()
    signal openRequested()

    onOpenRequested: {
        isOpen = true
        refreshSettings()
    }
    onCloseRequested: {
        isOpen = false
    }

    function toggle() {
        if (isOpen) close()
        else open()
    }

    function open() {
        isOpen = true
        refreshSettings()
    }

    function close() {
        isOpen = false
    }

    // ─── Theme Colors & Fonts (Pure Black OLED Edition) ───────
    property color winBg: "#000000"
    property color sidebarBg: "#000000"
    property color cardBg: "#000000"
    property color cardBorder: "#222230"
    property color dividerColor: "#13131A"
    property color fgColor: "#CDD6F4"
    property color fgMuted: "#A6ADC8"
    property color fgSubtle: "#6C7086"
    property color accentColor: "#89B4FA" // Catppuccin Sapphire
    property color accentBg: "#0F1828"
    property color dangerColor: "#F38BA8"
    property color successColor: "#A6E3A1"

    property string mainFont: "Inter"
    property string iconFont: "Font Awesome 6 Free"
    property string monoFont: "JetBrainsMono NF"

    // ─── Navigation State ─────────────────────────────────────
    property string activeTab: "overview" // "overview", "power", "display", "input", "appearance", "system", "shortcuts", "about"

    // ─── System & Hardware States ─────────────────────────────
    property string currentPowerProfile: "performance"
    property int currentRefreshRate: 144
    property bool nightLightActive: false
    property bool blurEnabled: true
    property bool animationsEnabled: true
    property bool naturalScrollEnabled: true
    property bool tapToClickEnabled: true
    property bool caffeineActive: false
    property bool settingsLoading: false

    property string cpuModel: "11th Gen Intel(R) Core(TM) i5-11400H @ 2.70GHz"
    property string gpuModel: "NVIDIA GeForce RTX 3050 Laptop GPU"
    property string kernelVersion: "7.3.1-cachyos"
    property string uptimeStr: "up 15 hours"
    property string memUsage: "5.1Gi / 15Gi"

    // ─── Query Process ────────────────────────────────────────
    Process {
        id: settingsQueryProc
        command: [
            "sh", "-c",
            "echo '===POWER==='; powerprofilesctl get 2>/dev/null || echo 'performance'; " +
            "echo '===REFRESH==='; hyprctl monitors -j 2>/dev/null | grep -o '\"refreshRate\": [0-9.]*' | head -1 | cut -d: -f2 | cut -d. -f1 | tr -d ' ' || echo '144'; " +
            "echo '===CAFFEINE==='; ps -C hypridle -o state= 2>/dev/null | grep -q 'T' && echo '1' || echo '0'; " +
            "echo '===NIGHTLIGHT==='; hyprctl getoption decoration:screen_shader 2>/dev/null | grep -q 'str: .\\+' && echo '1' || echo '0'; " +
            "echo '===BLUR==='; hyprctl getoption decoration:blur:enabled 2>/dev/null | grep -E -q 'bool: true|int: 1' && echo '1' || echo '0'; " +
            "echo '===ANIM==='; hyprctl getoption animations:enabled 2>/dev/null | grep -E -q 'bool: true|int: 1' && echo '1' || echo '0'; " +
            "echo '===NATURAL==='; hyprctl getoption input:touchpad:natural_scroll 2>/dev/null | grep -E -q 'bool: true|int: 1' && echo '1' || echo '0'; " +
            "echo '===TAP==='; hyprctl getoption input:touchpad:tap-to-click 2>/dev/null | grep -E -q 'bool: true|int: 1' && echo '1' || echo '0'; " +
            "echo '===CPU==='; lscpu 2>/dev/null | grep 'Model name' | head -1 | cut -d: -f2 | xargs || echo '11th Gen Intel i5-11400H'; " +
            "echo '===GPU==='; nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo 'NVIDIA GeForce RTX 3050'; " +
            "echo '===KERNEL==='; uname -r; " +
            "echo '===UPTIME==='; uptime -p | sed 's/up //'; " +
            "echo '===MEM==='; free -h | awk '/^Mem:/ {print $3 \" / \" $2}'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                settingsWindow.settingsLoading = false
                let pMatch = text.match(/===POWER===\s*([^\n\r]+)/)
                if (pMatch) settingsWindow.currentPowerProfile = pMatch[1].trim()

                let rMatch = text.match(/===REFRESH===\s*([^\n\r]+)/)
                if (rMatch) settingsWindow.currentRefreshRate = parseInt(rMatch[1].trim()) || 144

                let cMatch = text.match(/===CAFFEINE===\s*([^\n\r]+)/)
                if (cMatch) settingsWindow.caffeineActive = (cMatch[1].trim() === "1")

                let nlMatch = text.match(/===NIGHTLIGHT===\s*([^\n\r]+)/)
                if (nlMatch) settingsWindow.nightLightActive = (nlMatch[1].trim() === "1")

                let bMatch = text.match(/===BLUR===\s*([^\n\r]+)/)
                if (bMatch) settingsWindow.blurEnabled = (bMatch[1].trim() === "1")

                let aMatch = text.match(/===ANIM===\s*([^\n\r]+)/)
                if (aMatch) settingsWindow.animationsEnabled = (aMatch[1].trim() === "1")

                let nMatch = text.match(/===NATURAL===\s*([^\n\r]+)/)
                if (nMatch) settingsWindow.naturalScrollEnabled = (nMatch[1].trim() === "1")

                let tMatch = text.match(/===TAP===\s*([^\n\r]+)/)
                if (tMatch) settingsWindow.tapToClickEnabled = (tMatch[1].trim() === "1")

                let cpuMatch = text.match(/===CPU===\s*([^\n\r]+)/)
                if (cpuMatch) settingsWindow.cpuModel = cpuMatch[1].trim()

                let gpuMatch = text.match(/===GPU===\s*([^\n\r]+)/)
                if (gpuMatch) settingsWindow.gpuModel = gpuMatch[1].trim()

                let kMatch = text.match(/===KERNEL===\s*([^\n\r]+)/)
                if (kMatch) settingsWindow.kernelVersion = kMatch[1].trim()

                let uMatch = text.match(/===UPTIME===\s*([^\n\r]+)/)
                if (uMatch) settingsWindow.uptimeStr = uMatch[1].trim()

                let mMatch = text.match(/===MEM===\s*([^\n\r]+)/)
                if (mMatch) settingsWindow.memUsage = mMatch[1].trim()
            }
        }
    }

    function refreshSettings() {
        settingsLoading = true
        settingsQueryProc.running = false
        settingsQueryProc.running = true
    }

    // ─── Setting Action Handlers ──────────────────────────────
    function setPowerProfile(mode) {
        settingsWindow.currentPowerProfile = mode
        Quickshell.execDetached(["powerprofilesctl", "set", mode])
    }

    function setRefreshRate(hz) {
        settingsWindow.currentRefreshRate = hz
        Quickshell.execDetached(["hyprctl", "repl", `hl.monitor({ output = 'eDP-1', mode = '1920x1080@${hz}', position = '0x0', scale = 1 })`])
    }

    function toggleNightLight() {
        settingsWindow.nightLightActive = !settingsWindow.nightLightActive
        let shader = settingsWindow.nightLightActive ? (Quickshell.env("HOME") + "/.config/hypr/shaders/night-light.frag") : ""
        Quickshell.execDetached(["hyprctl", "repl", `hl.config({ decoration = { screen_shader = '${shader}' } })`])
    }

    function toggleBlur() {
        settingsWindow.blurEnabled = !settingsWindow.blurEnabled
        Quickshell.execDetached(["hyprctl", "repl", `hl.config({ decoration = { blur = { enabled = ${settingsWindow.blurEnabled ? "true" : "false"} } } })`])
    }

    function toggleAnimations() {
        settingsWindow.animationsEnabled = !settingsWindow.animationsEnabled
        Quickshell.execDetached(["hyprctl", "repl", `hl.config({ animations = { enabled = ${settingsWindow.animationsEnabled ? "true" : "false"} } })`])
    }

    function toggleNaturalScroll() {
        settingsWindow.naturalScrollEnabled = !settingsWindow.naturalScrollEnabled
        Quickshell.execDetached(["hyprctl", "repl", `hl.config({ input = { touchpad = { natural_scroll = ${settingsWindow.naturalScrollEnabled ? "true" : "false"} } } })`])
    }

    function toggleTapToClick() {
        settingsWindow.tapToClickEnabled = !settingsWindow.tapToClickEnabled
        Quickshell.execDetached(["hyprctl", "repl", `hl.config({ input = { touchpad = { tap_to_click = ${settingsWindow.tapToClickEnabled ? "true" : "false"} } } })`])
    }

    function toggleCaffeine() {
        settingsWindow.caffeineActive = !settingsWindow.caffeineActive
        if (settingsWindow.caffeineActive) {
            Quickshell.execDetached(["killall", "-STOP", "hypridle"])
        } else {
            Quickshell.execDetached(["killall", "-CONT", "hypridle"])
        }
    }

    // ─── Global Shortcut & IPC Handler ────────────────────────
    GlobalShortcut {
        name: "settings"
        description: "Toggle Hyprland Desktop Settings"
        onPressed: settingsWindow.toggle()
    }

    IpcHandler {
        target: "settings"
        function toggle() { settingsWindow.toggle() }
        function open() { settingsWindow.open() }
        function close() { settingsWindow.close() }
        function openTab(tab: string) {
            settingsWindow.activeTab = tab
            settingsWindow.open()
        }
    }

    // ─── Window Configuration ─────────────────────────────────
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: isOpen || openAnim.running || closeAnim.running

    // Dismiss on Escape
    Item {
        focus: settingsWindow.isOpen
        Keys.onEscapePressed: settingsWindow.closeRequested()
    }

    // ─── Dimmed Backdrop ──────────────────────────────────────
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#000000"
        opacity: settingsWindow.isOpen ? 0.52 : 0.0
        visible: opacity > 0.001

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: settingsWindow.closeRequested()
        }
    }

    // ─── Central Desktop Settings Application Window ──────────
    Rectangle {
        id: appWindowCard
        width: Math.min(740, Math.round(parent.width * 0.85))
        height: Math.min(640, Math.round(parent.height * 0.85))
        anchors.centerIn: parent
        radius: 16
        color: settingsWindow.winBg
        border.color: settingsWindow.cardBorder
        border.width: 1
        clip: true

        scale: settingsWindow.isOpen ? 1.0 : 0.96
        opacity: settingsWindow.isOpen ? 1.0 : 0.0

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: appWindowCard; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: appWindowCard; property: "opacity"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            id: closeAnim
            NumberAnimation { target: appWindowCard; property: "scale"; to: 0.96; duration: 180; easing.type: Easing.InQuad }
            NumberAnimation { target: appWindowCard; property: "opacity"; to: 0.0; duration: 160; easing.type: Easing.InQuad }
        }

        onScaleChanged: {
            if (!settingsWindow.isOpen && scale <= 0.965) {
                // finished closing
            }
        }

        // Absorbs clicks inside card
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: (mouse) => { mouse.accepted = true }
        }

        // ─── TWO-COLUMN DESKTOP LAYOUT ─────────────────────────
        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ══════════════════════════════════════════════════
            // LEFT COLUMN: NAVIGATION SIDEBAR (210px)
            // ══════════════════════════════════════════════════
            Rectangle {
                Layout.preferredWidth: 210
                Layout.fillHeight: true
                color: settingsWindow.sidebarBg
                border.width: 0

                // Hairline divider on right edge
                Rectangle {
                    anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                    width: 1
                    color: settingsWindow.dividerColor
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    // App Header Branding
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Layout.bottomMargin: 10
                        Layout.leftMargin: 6
                        spacing: 10

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: settingsWindow.accentBg
                            border.width: 1
                            border.color: settingsWindow.accentColor

                            Text {
                                anchors.centerIn: parent
                                text: "\uf013" // gear
                                font { family: settingsWindow.iconFont; weight: Font.Bold; pixelSize: 15 }
                                color: settingsWindow.accentColor
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: "Settings"
                                font { family: settingsWindow.mainFont; pixelSize: 15; weight: Font.Bold }
                                color: "#FFFFFF"
                            }
                            Text {
                                text: "Hyprland Desktop"
                                font { family: settingsWindow.mainFont; pixelSize: 10 }
                                color: settingsWindow.fgSubtle
                            }
                        }
                    }

                    // Navigation Items List
                    Repeater {
                        model: [
                            { id: "overview", label: "Overview", icon: "\uf009" },
                            { id: "power", label: "Power & Battery", icon: "\uf0e7" },
                            { id: "display", label: "Display", icon: "\uf26c" },
                            { id: "input", label: "Input & Touchpad", icon: "\uf245" },
                            { id: "appearance", label: "Appearance", icon: "\uf53f" },
                            { id: "system", label: "System Status", icon: "\uf085" },
                            { id: "shortcuts", label: "Shortcuts & Config", icon: "\uf121" },
                            { id: "about", label: "About", icon: "\uf05a" }
                        ]

                        delegate: Rectangle {
                            id: navItem
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 8
                            readonly property bool isSelected: settingsWindow.activeTab === modelData.id
                            color: isSelected ? settingsWindow.accentBg : (navMouse.containsMouse ? "#0D0D14" : "transparent")
                            border.width: 1
                            border.color: isSelected ? settingsWindow.accentColor : "transparent"

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                spacing: 10

                                Text {
                                    text: modelData.icon
                                    font { family: settingsWindow.iconFont; weight: Font.Bold; pixelSize: 12 }
                                    color: navItem.isSelected ? settingsWindow.accentColor : (navMouse.containsMouse ? "#FFFFFF" : settingsWindow.fgSubtle)
                                    Layout.preferredWidth: 16
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    text: modelData.label
                                    font { family: settingsWindow.mainFont; pixelSize: 12; weight: navItem.isSelected ? Font.Bold : Font.Medium }
                                    color: navItem.isSelected ? "#FFFFFF" : (navMouse.containsMouse ? "#FFFFFF" : settingsWindow.fgMuted)
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: navMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsWindow.activeTab = modelData.id
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Sidebar Footer: Quick Battery & Machine Status
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 8
                        color: "#08080C"
                        border.width: 1
                        border.color: "#161620"

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 8

                            Text {
                                text: {
                                    let pct = Math.round(UPower.displayDevice.percentage * 100)
                                    if (UPower.onBattery) {
                                        if (pct <= 20) return "\uf244"
                                        if (pct <= 50) return "\uf243"
                                        if (pct <= 75) return "\uf242"
                                        return "\uf240"
                                    }
                                    return "\uf0e7"
                                }
                                font { family: settingsWindow.iconFont; weight: Font.Bold; pixelSize: 11 }
                                color: UPower.onBattery ? settingsWindow.fgColor : settingsWindow.successColor
                            }

                            Text {
                                text: `${Math.round(UPower.displayDevice.percentage * 100)}% • ${settingsWindow.currentPowerProfile}`
                                font { family: settingsWindow.mainFont; pixelSize: 10; weight: Font.Medium }
                                color: settingsWindow.fgMuted
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════
            // RIGHT COLUMN: SETTINGS CONTENT AREA (Remaining width)
            // ══════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // ── Top Header Row ────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: "transparent"

                        // Bottom border
                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 1
                            color: settingsWindow.dividerColor
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 24; rightMargin: 20 }
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: {
                                        switch(settingsWindow.activeTab) {
                                            case "overview": return "Overview";
                                            case "power": return "Power & Performance";
                                            case "display": return "Display & Graphics";
                                            case "input": return "Input & Gestures";
                                            case "appearance": return "Appearance & Effects";
                                            case "system": return "System Status";
                                            case "shortcuts": return "Shortcuts & Dotfiles";
                                            case "about": return "About System";
                                            default: return "Settings";
                                        }
                                    }
                                    font { family: settingsWindow.mainFont; pixelSize: 17; weight: Font.Bold }
                                    color: "#FFFFFF"
                                }
                                Text {
                                    text: {
                                        switch(settingsWindow.activeTab) {
                                            case "overview": return "Hardware summary and frequently used desktop controls";
                                            case "power": return "CPU scaling governor, GPU status, and battery health";
                                            case "display": return "Monitor refresh rate, night light shader, and resolution";
                                            case "input": return "Touchpad behavior, natural scrolling, and tap gestures";
                                            case "appearance": return "Compositor dual-cavity blur, animations, and decorations";
                                            case "system": return "Caffeine keep-awake policy, OS, and memory metrics";
                                            case "shortcuts": return "Quick configuration launchers opened in Ghostty terminal";
                                            case "about": return "System specifications, desktop software versions, and keybinds";
                                            default: return "";
                                        }
                                    }
                                    font { family: settingsWindow.mainFont; pixelSize: 11 }
                                    color: settingsWindow.fgSubtle
                                }
                            }

                            // Refresh button
                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: refArea.containsMouse ? "#141420" : "#0A0A10"
                                border.width: 1
                                border.color: refArea.containsMouse ? settingsWindow.accentColor : "#1B1B26"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf021" // sync
                                    font { family: settingsWindow.iconFont; weight: Font.Bold; pixelSize: 11 }
                                    color: settingsWindow.settingsLoading ? settingsWindow.accentColor : settingsWindow.fgMuted
                                    rotation: settingsWindow.settingsLoading ? 180 : 0
                                    Behavior on rotation { NumberAnimation { duration: 300 } }
                                }

                                MouseArea {
                                    id: refArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsWindow.refreshSettings()
                                }
                            }

                            // Close button
                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: clsArea.containsMouse ? "#261018" : "#0A0A10"
                                border.width: 1
                                border.color: clsArea.containsMouse ? settingsWindow.dangerColor : "#1B1B26"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf00d" // times
                                    font { family: settingsWindow.iconFont; weight: Font.Bold; pixelSize: 11 }
                                    color: clsArea.containsMouse ? settingsWindow.dangerColor : settingsWindow.fgMuted
                                }

                                MouseArea {
                                    id: clsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsWindow.closeRequested()
                                }
                            }
                        }
                    }

                    // ── Scrollable Page Viewport ──────────────
                    Flickable {
                        id: contentFlickable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: width
                        contentHeight: activePageLoader.implicitHeight + 36
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Item {
                            id: activePageLoader
                            width: parent.width - 48
                            x: 24
                            y: 16
                            implicitHeight: currentContentItem.implicitHeight

                            // Dynamic Page Switcher
                            ColumnLayout {
                                id: currentContentItem
                                width: parent.width
                                spacing: 14

                                // ══════════════════════════════
                                // PAGE 1: OVERVIEW
                                // ══════════════════════════════
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 14
                                    visible: settingsWindow.activeTab === "overview"

                                    // Hardware Snapshot Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 116
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder

                                        GridLayout {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            columns: 2
                                            rowSpacing: 10
                                            columnSpacing: 16

                                            // Metric 1: Power Profile
                                            RowLayout {
                                                spacing: 10
                                                Rectangle {
                                                    width: 32
                                                    height: 32
                                                    radius: 8
                                                    color: "#0E0E14"
                                                    Text { anchors.centerIn: parent
                                                    text: "\uf0e7"
                                                    font { family: settingsWindow.iconFont
                                                    weight: Font.Bold
                                                    pixelSize: 13 }
                                                    color: settingsWindow.accentColor }
                                                }
                                                ColumnLayout {
                                                    spacing: 1
                                                    Text { text: "Power Profile"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 10 }
                                                    color: settingsWindow.fgSubtle }
                                                    Text { text: settingsWindow.currentPowerProfile.toUpperCase()
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 12
                                                    weight: Font.Bold }
                                                    color: "#FFFFFF" }
                                                }
                                            }

                                            // Metric 2: Monitor Rate
                                            RowLayout {
                                                spacing: 10
                                                Rectangle {
                                                    width: 32
                                                    height: 32
                                                    radius: 8
                                                    color: "#0E0E14"
                                                    Text { anchors.centerIn: parent
                                                    text: "\uf26c"
                                                    font { family: settingsWindow.iconFont
                                                    weight: Font.Bold
                                                    pixelSize: 13 }
                                                    color: settingsWindow.accentColor }
                                                }
                                                ColumnLayout {
                                                    spacing: 1
                                                    Text { text: "Display Rate"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 10 }
                                                    color: settingsWindow.fgSubtle }
                                                    Text { text: `${settingsWindow.currentRefreshRate}Hz • 1080p`
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 12
                                                    weight: Font.Bold }
                                                    color: "#FFFFFF" }
                                                }
                                            }

                                            // Metric 3: Battery
                                            RowLayout {
                                                spacing: 10
                                                Rectangle {
                                                    width: 32
                                                    height: 32
                                                    radius: 8
                                                    color: "#0E0E14"
                                                    Text { anchors.centerIn: parent
                                                    text: "\uf240"
                                                    font { family: settingsWindow.iconFont
                                                    weight: Font.Bold
                                                    pixelSize: 13 }
                                                    color: settingsWindow.successColor }
                                                }
                                                ColumnLayout {
                                                    spacing: 1
                                                    Text { text: "Battery Status"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 10 }
                                                    color: settingsWindow.fgSubtle }
                                                    Text { text: `${Math.round(UPower.displayDevice.percentage * 100)}% (${UPower.onBattery ? "On Battery" : "Charging"})`
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 12
                                                    weight: Font.Bold }
                                                    color: "#FFFFFF" }
                                                }
                                            }

                                            // Metric 4: Compositor
                                            RowLayout {
                                                spacing: 10
                                                Rectangle {
                                                    width: 32
                                                    height: 32
                                                    radius: 8
                                                    color: "#0E0E14"
                                                    Text { anchors.centerIn: parent
                                                    text: "\uf108"
                                                    font { family: settingsWindow.iconFont
                                                    weight: Font.Bold
                                                    pixelSize: 13 }
                                                    color: settingsWindow.accentColor }
                                                }
                                                ColumnLayout {
                                                    spacing: 1
                                                    Text { text: "Window Manager"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 10 }
                                                    color: settingsWindow.fgSubtle }
                                                    Text { text: "Hyprland 0.57.1"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 12
                                                    weight: Font.Bold }
                                                    color: "#FFFFFF" }
                                                }
                                            }
                                        }
                                    }

                                    // Quick Toggles Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: ovRowsCol.implicitHeight + 20
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder

                                        ColumnLayout {
                                            id: ovRowsCol
                                            anchors { top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 12 }
                                            spacing: 6

                                            Text {
                                                text: "QUICK CONTROLS"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 10
                                                weight: Font.Bold }
                                                color: settingsWindow.fgSubtle
                                                Layout.bottomMargin: 4
                                            }

                                            // Row 1: Night Light
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 38
                                                spacing: 10
                                                Rectangle { width: 28
                                                height: 28
                                                radius: 7
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf186"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 11 }
                                                color: settingsWindow.nightLightActive ? settingsWindow.accentColor : settingsWindow.fgSubtle } }
                                                ColumnLayout { Layout.fillWidth: true
                                                spacing: 1
                                                Text { text: "Night Light"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 12
                                                weight: Font.DemiBold }
                                                color: "#FFFFFF" }
                                                Text { text: "Warm eye-care GPU screen filter"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 10 }
                                                color: settingsWindow.fgSubtle } }
                                                Rectangle {
                                                    width: 38
                                                    height: 22
                                                    radius: 11
                                                    color: settingsWindow.nightLightActive ? settingsWindow.accentColor : "#1A1A26"
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                    Rectangle { width: 16
                                                    height: 16
                                                    radius: 8
                                                    y: 3
                                                    x: settingsWindow.nightLightActive ? 19 : 3
                                                    color: settingsWindow.nightLightActive ? "#11111B" : "#BAC2DE"
                                                    Behavior on x { NumberAnimation { duration: 140
                                                    easing.type: Easing.OutCubic } } }
                                                    MouseArea { anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsWindow.toggleNightLight() }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }

                                            // Row 2: Caffeine
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 38
                                                spacing: 10
                                                Rectangle { width: 28
                                                height: 28
                                                radius: 7
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf0f4"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 11 }
                                                color: settingsWindow.caffeineActive ? settingsWindow.accentColor : settingsWindow.fgSubtle } }
                                                ColumnLayout { Layout.fillWidth: true
                                                spacing: 1
                                                Text { text: "Caffeine Mode"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 12
                                                weight: Font.DemiBold }
                                                color: "#FFFFFF" }
                                                Text { text: "Inhibit display sleep & idle daemon"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 10 }
                                                color: settingsWindow.fgSubtle } }
                                                Rectangle {
                                                    width: 38
                                                    height: 22
                                                    radius: 11
                                                    color: settingsWindow.caffeineActive ? settingsWindow.accentColor : "#1A1A26"
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                    Rectangle { width: 16
                                                    height: 16
                                                    radius: 8
                                                    y: 3
                                                    x: settingsWindow.caffeineActive ? 19 : 3
                                                    color: settingsWindow.caffeineActive ? "#11111B" : "#BAC2DE"
                                                    Behavior on x { NumberAnimation { duration: 140
                                                    easing.type: Easing.OutCubic } } }
                                                    MouseArea { anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsWindow.toggleCaffeine() }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }

                                            // Row 3: Window Blur
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 38
                                                spacing: 10
                                                Rectangle { width: 28
                                                height: 28
                                                radius: 7
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf043"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 11 }
                                                color: settingsWindow.blurEnabled ? settingsWindow.accentColor : settingsWindow.fgSubtle } }
                                                ColumnLayout { Layout.fillWidth: true
                                                spacing: 1
                                                Text { text: "Window Blur"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 12
                                                weight: Font.DemiBold }
                                                color: "#FFFFFF" }
                                                Text { text: "Compositor dual-cavity background blur"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 10 }
                                                color: settingsWindow.fgSubtle } }
                                                Rectangle {
                                                    width: 38
                                                    height: 22
                                                    radius: 11
                                                    color: settingsWindow.blurEnabled ? settingsWindow.accentColor : "#1A1A26"
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                    Rectangle { width: 16
                                                    height: 16
                                                    radius: 8
                                                    y: 3
                                                    x: settingsWindow.blurEnabled ? 19 : 3
                                                    color: settingsWindow.blurEnabled ? "#11111B" : "#BAC2DE"
                                                    Behavior on x { NumberAnimation { duration: 140
                                                    easing.type: Easing.OutCubic } } }
                                                    MouseArea { anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsWindow.toggleBlur() }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }

                                            // Row 4: Desktop Animations
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 38
                                                spacing: 10
                                                Rectangle { width: 28
                                                height: 28
                                                radius: 7
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf0d0"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 11 }
                                                color: settingsWindow.animationsEnabled ? settingsWindow.accentColor : settingsWindow.fgSubtle } }
                                                ColumnLayout { Layout.fillWidth: true
                                                spacing: 1
                                                Text { text: "Desktop Animations"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 12
                                                weight: Font.DemiBold }
                                                color: "#FFFFFF" }
                                                Text { text: "Smooth window scaling & workspace transitions"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 10 }
                                                color: settingsWindow.fgSubtle } }
                                                Rectangle {
                                                    width: 38
                                                    height: 22
                                                    radius: 11
                                                    color: settingsWindow.animationsEnabled ? settingsWindow.accentColor : "#1A1A26"
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                    Rectangle { width: 16
                                                    height: 16
                                                    radius: 8
                                                    y: 3
                                                    x: settingsWindow.animationsEnabled ? 19 : 3
                                                    color: settingsWindow.animationsEnabled ? "#11111B" : "#BAC2DE"
                                                    Behavior on x { NumberAnimation { duration: 140
                                                    easing.type: Easing.OutCubic } } }
                                                    MouseArea { anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsWindow.toggleAnimations() }
                                                }
                                            }
                                        }
                                    }
                                }

                                // ══════════════════════════════
                                // PAGE 2: POWER & PERFORMANCE
                                // ══════════════════════════════
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 14
                                    visible: settingsWindow.activeTab === "power"

                                    // Active Profile Segmented Selector
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: pwrCardCol.implicitHeight + 24
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder

                                        ColumnLayout {
                                            id: pwrCardCol
                                            anchors { top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 14 }
                                            spacing: 12

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "ACTIVE POWER PROFILE"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 10
                                                weight: Font.Bold }
                                                color: settingsWindow.fgSubtle }
                                                Item { Layout.fillWidth: true }
                                                Rectangle {
                                                    implicitWidth: pBadge.implicitWidth + 14
                                                    implicitHeight: 20
                                                    radius: 10
                                                    color: settingsWindow.currentPowerProfile === "performance" ? "#201018" : (settingsWindow.currentPowerProfile === "balanced" ? "#0E182A" : "#0E2018")
                                                    border.width: 1
                                                    border.color: settingsWindow.currentPowerProfile === "performance" ? settingsWindow.dangerColor : (settingsWindow.currentPowerProfile === "balanced" ? settingsWindow.accentColor : settingsWindow.successColor)
                                                    Text { id: pBadge
                                                    anchors.centerIn: parent
                                                    text: settingsWindow.currentPowerProfile.toUpperCase()
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 9
                                                    weight: Font.Bold }
                                                    color: settingsWindow.currentPowerProfile === "performance" ? settingsWindow.dangerColor : (settingsWindow.currentPowerProfile === "balanced" ? settingsWindow.accentColor : settingsWindow.successColor) }
                                                }
                                            }

                                            // 3-Way Segmented Control
                                            Rectangle {
                                                id: pwrSliderBar
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 40
                                                radius: 10
                                                color: "#040406"
                                                border.width: 1
                                                border.color: "#161620"

                                                Rectangle {
                                                    width: Math.round((pwrSliderBar.width - 6) / 3)
                                                    height: pwrSliderBar.height - 6
                                                    y: 3
                                                    x: {
                                                        let w = (pwrSliderBar.width - 6) / 3
                                                        if (settingsWindow.currentPowerProfile === "power-saver") return Math.round(3 + w * 2)
                                                        if (settingsWindow.currentPowerProfile === "balanced") return Math.round(3 + w)
                                                        return 3
                                                    }
                                                    radius: 8
                                                    color: settingsWindow.accentColor
                                                    Behavior on x { NumberAnimation { duration: 160
                                                    easing.type: Easing.OutCubic } }
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 3
                                                    spacing: 0

                                                    Item {
                                                        Layout.fillWidth: true
                                                        Layout.fillHeight: true
                                                        Row { anchors.centerIn: parent
                                                        spacing: 6
                                                        Text { text: "\uf0e7"
                                                        font { family: settingsWindow.iconFont
                                                        weight: Font.Bold
                                                        pixelSize: 11 }
                                                        color: settingsWindow.currentPowerProfile === "performance" ? "#11111B" : "#CDD6F4" }
                                                        Text { text: "Performance"
                                                        font { family: settingsWindow.mainFont
                                                        pixelSize: 12
                                                        weight: Font.Bold }
                                                        color: settingsWindow.currentPowerProfile === "performance" ? "#11111B" : "#CDD6F4" } }
                                                        MouseArea { anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: settingsWindow.setPowerProfile("performance") }
                                                    }

                                                    Item {
                                                        Layout.fillWidth: true
                                                        Layout.fillHeight: true
                                                        Row { anchors.centerIn: parent
                                                        spacing: 6
                                                        Text { text: "\uf24e"
                                                        font { family: settingsWindow.iconFont
                                                        weight: Font.Bold
                                                        pixelSize: 11 }
                                                        color: settingsWindow.currentPowerProfile === "balanced" ? "#11111B" : "#CDD6F4" }
                                                        Text { text: "Balanced"
                                                        font { family: settingsWindow.mainFont
                                                        pixelSize: 12
                                                        weight: Font.Bold }
                                                        color: settingsWindow.currentPowerProfile === "balanced" ? "#11111B" : "#CDD6F4" } }
                                                        MouseArea { anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: settingsWindow.setPowerProfile("balanced") }
                                                    }

                                                    Item {
                                                        Layout.fillWidth: true
                                                        Layout.fillHeight: true
                                                        Row { anchors.centerIn: parent
                                                        spacing: 6
                                                        Text { text: "\uf06c"
                                                        font { family: settingsWindow.iconFont
                                                        weight: Font.Bold
                                                        pixelSize: 11 }
                                                        color: settingsWindow.currentPowerProfile === "power-saver" ? "#11111B" : "#CDD6F4" }
                                                        Text { text: "Power Saver"
                                                        font { family: settingsWindow.mainFont
                                                        pixelSize: 12
                                                        weight: Font.Bold }
                                                        color: settingsWindow.currentPowerProfile === "power-saver" ? "#11111B" : "#CDD6F4" } }
                                                        MouseArea { anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: settingsWindow.setPowerProfile("power-saver") }
                                                    }
                                                }
                                            }

                                            Text {
                                                text: settingsWindow.currentPowerProfile === "performance" ? "Prioritizes maximum CPU frequency and responsiveness. Thermals and fan curves operate dynamically." : (settingsWindow.currentPowerProfile === "balanced" ? "Standard system profile balancing responsive performance and battery conservation." : "Lowers processor clock ceiling and throttles background tasks to maximize battery life.")
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 11 }
                                                color: settingsWindow.fgMuted
                                                wrapMode: Text.WordWrap
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }

                                    // Hardware & Battery Information
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: pwrDetailsCol.implicitHeight + 20
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder

                                        ColumnLayout {
                                            id: pwrDetailsCol
                                            anchors { top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 14 }
                                            spacing: 10

                                            Text { text: "BATTERY & HARDWARE DETAILS"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 10
                                            weight: Font.Bold }
                                            color: settingsWindow.fgSubtle }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "Battery Status"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 12 }
                                                color: settingsWindow.fgMuted }
                                                Item { Layout.fillWidth: true }
                                                Text { text: `${Math.round(UPower.displayDevice.percentage * 100)}% (${UPower.onBattery ? "Discharging on battery" : "AC Power / Charging"})`
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 12
                                                weight: Font.DemiBold }
                                                color: "#FFFFFF" }
                                            }

                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "CPU Driver"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 12 }
                                                color: settingsWindow.fgMuted }
                                                Item { Layout.fillWidth: true }
                                                Text { text: "intel_pstate (active)"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 12
                                                weight: Font.DemiBold }
                                                color: "#FFFFFF" }
                                            }

                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "Platform Driver"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 12 }
                                                color: settingsWindow.fgMuted }
                                                Item { Layout.fillWidth: true }
                                                Text { text: "asus-wmi / platform_profile"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 12
                                                weight: Font.DemiBold }
                                                color: "#FFFFFF" }
                                            }
                                        }
                                    }
                                }

                                // ══════════════════════════════
                                // PAGE 3: DISPLAY
                                // ══════════════════════════════
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 14
                                    visible: settingsWindow.activeTab === "display"

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: dispCol.implicitHeight + 20
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder

                                        ColumnLayout {
                                            id: dispCol
                                            anchors { top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 14 }
                                            spacing: 12

                                            Text { text: "MONITOR & REFRESH RATE"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 10
                                            weight: Font.Bold }
                                            color: settingsWindow.fgSubtle }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 46
                                                spacing: 12
                                                Rectangle { width: 32
                                                height: 32
                                                radius: 8
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf26c"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 13 }
                                                color: settingsWindow.accentColor } }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text { text: "Primary Panel Refresh Rate"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 13
                                                    weight: Font.DemiBold }
                                                    color: "#FFFFFF" }
                                                    Text { text: settingsWindow.currentRefreshRate >= 120 ? "144Hz Ultra-Smooth Gaming & Desktop Mode" : "60Hz Battery Conservation Mode"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 11 }
                                                    color: settingsWindow.fgSubtle }
                                                }

                                                // 2-option selector
                                                Rectangle {
                                                    width: 140
                                                    height: 32
                                                    radius: 16
                                                    color: "#040406"
                                                    border.width: 1
                                                    border.color: "#1A1A26"
                                                    Rectangle {
                                                        width: 66
                                                        height: 26
                                                        y: 3
                                                        x: settingsWindow.currentRefreshRate >= 120 ? 3 : 71
                                                        radius: 13
                                                        color: settingsWindow.accentColor
                                                        Behavior on x { NumberAnimation { duration: 140
                                                        easing.type: Easing.OutCubic } }
                                                    }
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        spacing: 0
                                                        Item {
                                                            Layout.fillWidth: true
                                                            Layout.fillHeight: true
                                                            Text { anchors.centerIn: parent
                                                            text: "144Hz"
                                                            font { family: settingsWindow.mainFont
                                                            pixelSize: 11
                                                            weight: Font.Bold }
                                                            color: settingsWindow.currentRefreshRate >= 120 ? "#11111B" : "#CDD6F4" }
                                                            MouseArea { anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: settingsWindow.setRefreshRate(144) }
                                                        }
                                                        Item {
                                                            Layout.fillWidth: true
                                                            Layout.fillHeight: true
                                                            Text { anchors.centerIn: parent
                                                            text: "60Hz"
                                                            font { family: settingsWindow.mainFont
                                                            pixelSize: 11
                                                            weight: Font.Bold }
                                                            color: settingsWindow.currentRefreshRate < 120 ? "#11111B" : "#CDD6F4" }
                                                            MouseArea { anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: settingsWindow.setRefreshRate(60) }
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }

                                            // Night Light Row
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 46
                                                spacing: 12
                                                Rectangle { width: 32
                                                height: 32
                                                radius: 8
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf186"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 13 }
                                                color: settingsWindow.nightLightActive ? settingsWindow.accentColor : settingsWindow.fgSubtle } }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text { text: "Night Light (Eye Comfort)"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 13
                                                    weight: Font.DemiBold }
                                                    color: "#FFFFFF" }
                                                    Text { text: settingsWindow.nightLightActive ? "Warm GPU color temperature filter active" : "Natural color profile"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 11 }
                                                    color: settingsWindow.fgSubtle }
                                                }
                                                Rectangle {
                                                    width: 42
                                                    height: 24
                                                    radius: 12
                                                    color: settingsWindow.nightLightActive ? settingsWindow.accentColor : "#1A1A26"
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                    Rectangle { width: 18
                                                    height: 18
                                                    radius: 9
                                                    y: 3
                                                    x: settingsWindow.nightLightActive ? 21 : 3
                                                    color: settingsWindow.nightLightActive ? "#11111B" : "#CDD6F4"
                                                    Behavior on x { NumberAnimation { duration: 140
                                                    easing.type: Easing.OutCubic } } }
                                                    MouseArea { anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsWindow.toggleNightLight() }
                                                }
                                            }
                                        }
                                    }

                                    // Display Specs Box
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: dSpecCol.implicitHeight + 20
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder
                                        ColumnLayout {
                                            id: dSpecCol
                                            anchors { top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 14 }
                                            spacing: 10
                                            Text { text: "DISPLAY SPECIFICATIONS"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 10
                                            weight: Font.Bold }
                                            color: settingsWindow.fgSubtle }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "Output Port"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "eDP-1 (Internal Panel)"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12
                                            weight: Font.DemiBold }
                                            color: "#FFFFFF" } }
                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "Resolution & Aspect"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "1920x1080 (16:9 Full HD)"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12
                                            weight: Font.DemiBold }
                                            color: "#FFFFFF" } }
                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "Variable Refresh Rate (VRR)"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "Adaptive-Sync Capable"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12
                                            weight: Font.DemiBold }
                                            color: settingsWindow.successColor } }
                                        }
                                    }
                                }

                                // ══════════════════════════════
                                // PAGE 4: INPUT & TOUCHPAD
                                // ══════════════════════════════
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 14
                                    visible: settingsWindow.activeTab === "input"

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: inputCol.implicitHeight + 20
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder

                                        ColumnLayout {
                                            id: inputCol
                                            anchors { top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 14 }
                                            spacing: 12

                                            Text { text: "TOUCHPAD SCROLLING & TAPPING"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 10
                                            weight: Font.Bold }
                                            color: settingsWindow.fgSubtle }

                                            // Natural Scroll
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 46
                                                spacing: 12
                                                Rectangle { width: 32
                                                height: 32
                                                radius: 8
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf07d"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 13 }
                                                color: settingsWindow.naturalScrollEnabled ? settingsWindow.accentColor : settingsWindow.fgSubtle } }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text { text: "Natural Scrolling"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 13
                                                    weight: Font.DemiBold }
                                                    color: "#FFFFFF" }
                                                    Text { text: "Content moves in gesture direction matching touchscreen behavior (macOS)"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 11 }
                                                    color: settingsWindow.fgSubtle
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight }
                                                }
                                                Rectangle {
                                                    width: 42
                                                    height: 24
                                                    radius: 12
                                                    color: settingsWindow.naturalScrollEnabled ? settingsWindow.accentColor : "#1A1A26"
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                    Rectangle { width: 18
                                                    height: 18
                                                    radius: 9
                                                    y: 3
                                                    x: settingsWindow.naturalScrollEnabled ? 21 : 3
                                                    color: settingsWindow.naturalScrollEnabled ? "#11111B" : "#CDD6F4"
                                                    Behavior on x { NumberAnimation { duration: 140
                                                    easing.type: Easing.OutCubic } } }
                                                    MouseArea { anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsWindow.toggleNaturalScroll() }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }

                                            // Tap to Click
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 46
                                                spacing: 12
                                                Rectangle { width: 32
                                                height: 32
                                                radius: 8
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf245"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 13 }
                                                color: settingsWindow.tapToClickEnabled ? settingsWindow.accentColor : settingsWindow.fgSubtle } }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text { text: "Tap to Click"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 13
                                                    weight: Font.DemiBold }
                                                    color: "#FFFFFF" }
                                                    Text { text: "Tap on trackpad surface registers as primary click without physical button depression"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 11 }
                                                    color: settingsWindow.fgSubtle
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight }
                                                }
                                                Rectangle {
                                                    width: 42
                                                    height: 24
                                                    radius: 12
                                                    color: settingsWindow.tapToClickEnabled ? settingsWindow.accentColor : "#1A1A26"
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                    Rectangle { width: 18
                                                    height: 18
                                                    radius: 9
                                                    y: 3
                                                    x: settingsWindow.tapToClickEnabled ? 21 : 3
                                                    color: settingsWindow.tapToClickEnabled ? "#11111B" : "#CDD6F4"
                                                    Behavior on x { NumberAnimation { duration: 140
                                                    easing.type: Easing.OutCubic } } }
                                                    MouseArea { anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsWindow.toggleTapToClick() }
                                                }
                                            }
                                        }
                                    }

                                    // Gestures Guide
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: gCol.implicitHeight + 20
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder
                                        ColumnLayout {
                                            id: gCol
                                            anchors { top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 14 }
                                            spacing: 10
                                            Text { text: "TOUCHPAD MULTI-FINGER GESTURES"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 10
                                            weight: Font.Bold }
                                            color: settingsWindow.fgSubtle }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "3-Finger Horizontal Swipe"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "Switch Workspaces (1–10)"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12
                                            weight: Font.DemiBold }
                                            color: "#FFFFFF" } }
                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "3-Finger Vertical Swipe"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "Toggle Active Window Fullscreen"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12
                                            weight: Font.DemiBold }
                                            color: "#FFFFFF" } }
                                        }
                                    }
                                }

                                // ══════════════════════════════
                                // PAGE 5: APPEARANCE & EFFECTS
                                // ══════════════════════════════
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 14
                                    visible: settingsWindow.activeTab === "appearance"

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: appCol.implicitHeight + 20
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder

                                        ColumnLayout {
                                            id: appCol
                                            anchors { top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 14 }
                                            spacing: 12

                                            Text { text: "COMPOSITOR VISUAL EFFECTS"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 10
                                            weight: Font.Bold }
                                            color: settingsWindow.fgSubtle }

                                            // Blur
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 46
                                                spacing: 12
                                                Rectangle { width: 32
                                                height: 32
                                                radius: 8
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf043"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 13 }
                                                color: settingsWindow.blurEnabled ? settingsWindow.accentColor : settingsWindow.fgSubtle } }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text { text: "Window Blur"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 13
                                                    weight: Font.DemiBold }
                                                    color: "#FFFFFF" }
                                                    Text { text: "Dual-cavity background blur for translucent windows and shell popups"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 11 }
                                                    color: settingsWindow.fgSubtle }
                                                }
                                                Rectangle {
                                                    width: 42
                                                    height: 24
                                                    radius: 12
                                                    color: settingsWindow.blurEnabled ? settingsWindow.accentColor : "#1A1A26"
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                    Rectangle { width: 18
                                                    height: 18
                                                    radius: 9
                                                    y: 3
                                                    x: settingsWindow.blurEnabled ? 21 : 3
                                                    color: settingsWindow.blurEnabled ? "#11111B" : "#CDD6F4"
                                                    Behavior on x { NumberAnimation { duration: 140
                                                    easing.type: Easing.OutCubic } } }
                                                    MouseArea { anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsWindow.toggleBlur() }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }

                                            // Animations
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 46
                                                spacing: 12
                                                Rectangle { width: 32
                                                height: 32
                                                radius: 8
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf0d0"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 13 }
                                                color: settingsWindow.animationsEnabled ? settingsWindow.accentColor : settingsWindow.fgSubtle } }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text { text: "Desktop Animations"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 13
                                                    weight: Font.DemiBold }
                                                    color: "#FFFFFF" }
                                                    Text { text: "Bézier curve workspace transitions and window scaling"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 11 }
                                                    color: settingsWindow.fgSubtle }
                                                }
                                                Rectangle {
                                                    width: 42
                                                    height: 24
                                                    radius: 12
                                                    color: settingsWindow.animationsEnabled ? settingsWindow.accentColor : "#1A1A26"
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                    Rectangle { width: 18
                                                    height: 18
                                                    radius: 9
                                                    y: 3
                                                    x: settingsWindow.animationsEnabled ? 21 : 3
                                                    color: settingsWindow.animationsEnabled ? "#11111B" : "#CDD6F4"
                                                    Behavior on x { NumberAnimation { duration: 140
                                                    easing.type: Easing.OutCubic } } }
                                                    MouseArea { anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsWindow.toggleAnimations() }
                                                }
                                            }
                                        }
                                    }

                                    // Theme Specifications
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: thCol.implicitHeight + 20
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder
                                        ColumnLayout {
                                            id: thCol
                                            anchors { top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 14 }
                                            spacing: 10
                                            Text { text: "THEME & GEOMETRY"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 10
                                            weight: Font.Bold }
                                            color: settingsWindow.fgSubtle }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "Active Window Border"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Rectangle { width: 14
                                            height: 14
                                            radius: 7
                                            color: settingsWindow.accentColor }
                                            Text { text: "Catppuccin Sapphire (#89B4FA)"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12
                                            weight: Font.DemiBold }
                                            color: "#FFFFFF" } }
                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "Window Gaps"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "5px Inner / 8px Outer"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12
                                            weight: Font.DemiBold }
                                            color: "#FFFFFF" } }
                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "Corner Rounding"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "8px Rounded Corners"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12
                                            weight: Font.DemiBold }
                                            color: "#FFFFFF" } }
                                        }
                                    }
                                }

                                // ══════════════════════════════
                                // PAGE 6: SYSTEM
                                // ══════════════════════════════
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 14
                                    visible: settingsWindow.activeTab === "system"

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: sysPageCol.implicitHeight + 20
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder

                                        ColumnLayout {
                                            id: sysPageCol
                                            anchors { top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 14 }
                                            spacing: 12

                                            Text { text: "POWER & IDLE CONTROL"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 10
                                            weight: Font.Bold }
                                            color: settingsWindow.fgSubtle }

                                            // Caffeine
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 46
                                                spacing: 12
                                                Rectangle { width: 32
                                                height: 32
                                                radius: 8
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf0f4"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 13 }
                                                color: settingsWindow.caffeineActive ? settingsWindow.accentColor : settingsWindow.fgSubtle } }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text { text: "Caffeine Mode (Keep Awake)"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 13
                                                    weight: Font.DemiBold }
                                                    color: "#FFFFFF" }
                                                    Text { text: settingsWindow.caffeineActive ? "Inhibiting hypridle: screen dimming, blanking, & sleep disabled" : "Normal idle timeouts active"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 11 }
                                                    color: settingsWindow.fgSubtle
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight }
                                                }
                                                Rectangle {
                                                    width: 42
                                                    height: 24
                                                    radius: 12
                                                    color: settingsWindow.caffeineActive ? settingsWindow.accentColor : "#1A1A26"
                                                    Behavior on color { ColorAnimation { duration: 140 } }
                                                    Rectangle { width: 18
                                                    height: 18
                                                    radius: 9
                                                    y: 3
                                                    x: settingsWindow.caffeineActive ? 21 : 3
                                                    color: settingsWindow.caffeineActive ? "#11111B" : "#CDD6F4"
                                                    Behavior on x { NumberAnimation { duration: 140
                                                    easing.type: Easing.OutCubic } } }
                                                    MouseArea { anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settingsWindow.toggleCaffeine() }
                                                }
                                            }
                                        }
                                    }

                                    // OS Metrics
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: osMetCol.implicitHeight + 20
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder
                                        ColumnLayout {
                                            id: osMetCol
                                            anchors { top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 14 }
                                            spacing: 10
                                            Text { text: "OPERATING SYSTEM METRICS"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 10
                                            weight: Font.Bold }
                                            color: settingsWindow.fgSubtle }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "Distribution"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "CachyOS (Arch Linux Rolling)"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12
                                            weight: Font.DemiBold }
                                            color: "#FFFFFF" } }
                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "Kernel Version"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: settingsWindow.kernelVersion
                                            font { family: settingsWindow.monoFont
                                            pixelSize: 11
                                            weight: Font.Bold }
                                            color: settingsWindow.accentColor } }
                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "System Uptime"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: settingsWindow.uptimeStr
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12
                                            weight: Font.DemiBold }
                                            color: "#FFFFFF" } }
                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "Memory Usage"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: settingsWindow.memUsage
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12
                                            weight: Font.DemiBold }
                                            color: "#FFFFFF" } }
                                        }
                                    }
                                }

                                // ══════════════════════════════
                                // PAGE 7: SHORTCUTS & CONFIG
                                // ══════════════════════════════
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 14
                                    visible: settingsWindow.activeTab === "shortcuts"

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: scCol.implicitHeight + 20
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder

                                        ColumnLayout {
                                            id: scCol
                                            anchors { top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 14 }
                                            spacing: 12

                                            Text { text: "PRIMARY CONFIGURATION SHORTCUTS"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 10
                                            weight: Font.Bold }
                                            color: settingsWindow.fgSubtle }

                                            // Shortcut 1: Hyprland
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 46
                                                spacing: 12
                                                Rectangle { width: 32
                                                height: 32
                                                radius: 8
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf121"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 12 }
                                                color: settingsWindow.accentColor } }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text { text: "Hyprland Configuration"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 13
                                                    weight: Font.DemiBold }
                                                    color: "#FFFFFF" }
                                                    Text { text: "~/.config/hypr/hyprland.lua"
                                                    font { family: settingsWindow.monoFont
                                                    pixelSize: 10 }
                                                    color: settingsWindow.fgSubtle }
                                                }
                                                Rectangle {
                                                    implicitWidth: hBtnText.implicitWidth + 20
                                                    implicitHeight: 28
                                                    radius: 14
                                                    color: hscArea.containsMouse ? "#141420" : "#0A0A10"
                                                    border.width: 1
                                                    border.color: hscArea.containsMouse ? settingsWindow.accentColor : "#1B1B26"
                                                    Row { id: hBtnText
                                                    anchors.centerIn: parent
                                                    spacing: 6
                                                    Text { text: "\uf08e"
                                                    font { family: settingsWindow.iconFont
                                                    weight: Font.Bold
                                                    pixelSize: 10 }
                                                    color: settingsWindow.accentColor
                                                    anchors.verticalCenter: parent.verticalCenter }
                                                    Text { text: "Edit in Ghostty"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 11
                                                    weight: Font.Bold }
                                                    color: "#CDD6F4"
                                                    anchors.verticalCenter: parent.verticalCenter } }
                                                    MouseArea { id: hscArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: { settingsWindow.close()
                                                    Quickshell.execDetached(["ghostty", "-e", "vim", Quickshell.env("HOME") + "/.config/hypr/hyprland.lua"]) } }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }

                                            // Shortcut 2: Ghostty
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 46
                                                spacing: 12
                                                Rectangle { width: 32
                                                height: 32
                                                radius: 8
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf120"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 12 }
                                                color: settingsWindow.accentColor } }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text { text: "Ghostty Terminal Emulator"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 13
                                                    weight: Font.DemiBold }
                                                    color: "#FFFFFF" }
                                                    Text { text: "~/.config/ghostty/config"
                                                    font { family: settingsWindow.monoFont
                                                    pixelSize: 10 }
                                                    color: settingsWindow.fgSubtle }
                                                }
                                                Rectangle {
                                                    implicitWidth: gBtnText.implicitWidth + 20
                                                    implicitHeight: 28
                                                    radius: 14
                                                    color: gscArea.containsMouse ? "#141420" : "#0A0A10"
                                                    border.width: 1
                                                    border.color: gscArea.containsMouse ? settingsWindow.accentColor : "#1B1B26"
                                                    Row { id: gBtnText
                                                    anchors.centerIn: parent
                                                    spacing: 6
                                                    Text { text: "\uf08e"
                                                    font { family: settingsWindow.iconFont
                                                    weight: Font.Bold
                                                    pixelSize: 10 }
                                                    color: settingsWindow.accentColor
                                                    anchors.verticalCenter: parent.verticalCenter }
                                                    Text { text: "Edit in Ghostty"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 11
                                                    weight: Font.Bold }
                                                    color: "#CDD6F4"
                                                    anchors.verticalCenter: parent.verticalCenter } }
                                                    MouseArea { id: gscArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: { settingsWindow.close()
                                                    Quickshell.execDetached(["ghostty", "-e", "vim", Quickshell.env("HOME") + "/.config/ghostty/config"]) } }
                                                }
                                            }

                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }

                                            // Shortcut 3: Quickshell
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 46
                                                spacing: 12
                                                Rectangle { width: 32
                                                height: 32
                                                radius: 8
                                                color: "#0E0E14"
                                                Text { anchors.centerIn: parent
                                                text: "\uf121"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 12 }
                                                color: settingsWindow.accentColor } }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text { text: "Quickshell Desktop Shell"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 13
                                                    weight: Font.DemiBold }
                                                    color: "#FFFFFF" }
                                                    Text { text: "~/.config/quickshell/shell.qml"
                                                    font { family: settingsWindow.monoFont
                                                    pixelSize: 10 }
                                                    color: settingsWindow.fgSubtle }
                                                }
                                                Rectangle {
                                                    implicitWidth: qBtnText.implicitWidth + 20
                                                    implicitHeight: 28
                                                    radius: 14
                                                    color: qscArea.containsMouse ? "#141420" : "#0A0A10"
                                                    border.width: 1
                                                    border.color: qscArea.containsMouse ? settingsWindow.accentColor : "#1B1B26"
                                                    Row { id: qBtnText
                                                    anchors.centerIn: parent
                                                    spacing: 6
                                                    Text { text: "\uf08e"
                                                    font { family: settingsWindow.iconFont
                                                    weight: Font.Bold
                                                    pixelSize: 10 }
                                                    color: settingsWindow.accentColor
                                                    anchors.verticalCenter: parent.verticalCenter }
                                                    Text { text: "Edit in Ghostty"
                                                    font { family: settingsWindow.mainFont
                                                    pixelSize: 11
                                                    weight: Font.Bold }
                                                    color: "#CDD6F4"
                                                    anchors.verticalCenter: parent.verticalCenter } }
                                                    MouseArea { id: qscArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: { settingsWindow.close()
                                                    Quickshell.execDetached(["ghostty", "-e", "vim", Quickshell.env("HOME") + "/.config/quickshell/shell.qml"]) } }
                                                }
                                            }
                                        }
                                    }
                                }

                                // ══════════════════════════════
                                // PAGE 8: ABOUT
                                // ══════════════════════════════
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 14
                                    visible: settingsWindow.activeTab === "about"

                                    // Branding Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 90
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 14
                                            Rectangle {
                                                width: 50
                                                height: 50
                                                radius: 12
                                                color: settingsWindow.accentBg
                                                border.width: 1
                                                border.color: settingsWindow.accentColor
                                                Text { anchors.centerIn: parent
                                                text: "\uf013"
                                                font { family: settingsWindow.iconFont
                                                weight: Font.Bold
                                                pixelSize: 24 }
                                                color: settingsWindow.accentColor }
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text { text: "Hyprland Desktop Settings"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 16
                                                weight: Font.Bold }
                                                color: "#FFFFFF" }
                                                Text { text: "Native Linux Desktop Control Center • Quickshell 0.0.1+ • Qt 6.8"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 11 }
                                                color: settingsWindow.fgMuted }
                                                Text { text: "Designed for Wayland compositors & CachyOS Linux"
                                                font { family: settingsWindow.mainFont
                                                pixelSize: 10 }
                                                color: settingsWindow.fgSubtle }
                                            }
                                        }
                                    }

                                    // Hardware Specs
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: abtCol.implicitHeight + 20
                                        radius: 12
                                        color: settingsWindow.cardBg
                                        border.width: 1
                                        border.color: settingsWindow.cardBorder
                                        ColumnLayout {
                                            id: abtCol
                                            anchors { top: parent.top
                                            left: parent.left
                                            right: parent.right
                                            margins: 14 }
                                            spacing: 10
                                            Text { text: "SYSTEM SPECIFICATIONS"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 10
                                            weight: Font.Bold }
                                            color: settingsWindow.fgSubtle }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: "Processor"
                                                    font { family: settingsWindow.mainFont; pixelSize: 12 }
                                                    color: settingsWindow.fgMuted
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: settingsWindow.cpuModel
                                                    font { family: settingsWindow.mainFont; pixelSize: 11; weight: Font.DemiBold }
                                                    color: "#FFFFFF"
                                                }
                                            }
                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "Graphics Card"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: settingsWindow.gpuModel
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 11
                                            weight: Font.DemiBold }
                                            color: "#FFFFFF" } }
                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "Compositor"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "Hyprland 0.57.1 (Aquamarine Wayland)"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 11
                                            weight: Font.DemiBold }
                                            color: "#FFFFFF" } }
                                            Rectangle { Layout.fillWidth: true
                                            height: 1
                                            color: settingsWindow.dividerColor }
                                            RowLayout { Layout.fillWidth: true
                                            Text { text: "Default Terminal"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 12 }
                                            color: settingsWindow.fgMuted }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "Ghostty (GPU Accelerated)"
                                            font { family: settingsWindow.mainFont
                                            pixelSize: 11
                                            weight: Font.DemiBold }
                                            color: settingsWindow.accentColor } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
