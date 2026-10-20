import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Io
import Quickshell.Services.SystemTray

Scope {
    id: root

    // ─── Global Bar Scale ─────────────────────────────────────
    // Change this value to scale everything in the bar proportionally (e.g. 1.0, 1.2, 1.5)
    property real barScale: 1.2

    // ─── Full Media Player Popup State ────────────────────────
    property bool showFullPlayer: false

    // ─── Calendar Popup State ─────────────────────────────────
    property bool showCalendar: false

    // ─── Control Panel Popup State ────────────────────────────
    property bool showControlPanel: false

    // ─── Notification Panel Popup State ───────────────────────
    property bool showNotificationPanel: false

    // ─── App Launcher State ───────────────────────────────────
    property bool showAppLauncher: false

    // ─── Tray Menu State ──────────────────────────────────────
    property bool showTrayMenu: false

    // ─── Power Menu State ─────────────────────────────────────
    property bool showPowerMenu: false

    // ─── Wallpaper Selector State ─────────────────────────────
    property bool showWallpaperSelector: false

    function toggleAppLauncher() {
        if (!root.showAppLauncher) {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showControlPanel = false
            root.showNotificationPanel = false
            root.showTrayMenu = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
        }
        root.showAppLauncher = !root.showAppLauncher
    }

    signal toggleControlPanelRequested()
    PwObjectTracker {
        id: sinkTracker
        objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ]
    }

    // ─── Theme ───────────────────────────────────────────────
    property color bgColor: "#121213"
    property color bgColor2: "#1E1E1E"
    property color fgColor: "#CDD6F4"
    property color accentColor: "#89B4FA"
    property color accentColorGlow: "#B4BEFE"
    property string mainFont: "Rowdies"
    property string iconFont: "JetBrainsMono NF"
    // ─── Media Player Logic ──────────────────────────────────
    property var activePlayer: findActivePlayer()

    function findActivePlayer() {
        let players = Mpris.players.values
        if (players.length === 0) return null

        // Prefer currently playing
        for (let p of players) {
            if (p.isPlaying) return p
        }
        // Fallback to first available
        return players[0]
    }

    // React to changes
    Connections {
        target: Mpris.players
        function onValuesChanged() { root.activePlayer = findActivePlayer() }
    }

    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true
        function onIsPlayingChanged() { root.activePlayer = findActivePlayer() }
        function onPlaybackStateChanged() { root.activePlayer = findActivePlayer() }
    }

    PanelWindow {
        id: barWindow

        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Math.round(40 * root.barScale)
        color: root.bgColor

        Item {
        anchors.fill: parent

        // ─── LEFT ─────────────────────────────────────────────
        Row {
            id: leftContent
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                leftMargin: Math.round(16 * root.barScale)
            }
            spacing: Math.round(8 * root.barScale)
            clip: true

            Rectangle {
                id: clockPill
                implicitWidth: Math.round(82 * root.barScale)
                implicitHeight: Math.round(26 * root.barScale)
                anchors.verticalCenter: parent.verticalCenter
                color: root.showCalendar ? Qt.lighter(root.bgColor2, 1.4) : (clockMouseArea.containsMouse ? Qt.lighter(root.bgColor2, 1.3) : root.bgColor2)
                radius: Math.round(30 * root.barScale)

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    color: root.showCalendar ? root.accentColorGlow : root.accentColor
                    font { family: root.mainFont; pixelSize: Math.round(13 * root.barScale) }
                    text: Qt.formatDateTime(new Date(), "hh:mm A")

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: parent.text = Qt.formatDateTime(new Date(), "hh:mm A")
                    }
                }

                MouseArea {
                    id: clockMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.showCalendar) {
                            root.showFullPlayer = false
                            root.showControlPanel = false
                            root.showNotificationPanel = false
                            root.showAppLauncher = false
                            root.showTrayMenu = false
                            root.showPowerMenu = false
                            root.showWallpaperSelector = false
                        }
                        root.showCalendar = !root.showCalendar
                    }
                }
            }

            Rectangle {
                implicitWidth: (wsRow.implicitWidth ?? 0) + Math.round(24 * root.barScale)
                implicitHeight: Math.round(26 * root.barScale)
                anchors.verticalCenter: parent.verticalCenter
                color: root.bgColor2
                radius: Math.round(30 * root.barScale)
                
                Row {
                    id: wsRow
                    anchors.centerIn: parent
                    spacing: Math.round(6 * root.barScale)
                    
                    Repeater {
                        model: {
                            let list = Hyprland.workspaces.values.slice()
                            list.sort((a, b) => a.id - b.id)
                            return list
                        }
                        delegate: Item {
                            width: Math.round(18 * root.barScale)
                            height: Math.round(18 * root.barScale)
                            readonly property bool isActive: Hyprland.focusedWorkspace && modelData.id === Hyprland.focusedWorkspace.id
                            
                            Rectangle {
                                id: wsCircle
                                anchors.fill: parent
                                radius: width
                                color: isActive ? root.accentColor : (wsMouse.containsMouse ? Qt.rgba(137/255, 180/255, 250/255, 0.2) : "transparent")
                                border { width: 1; color: isActive ? root.accentColor : (wsMouse.containsMouse ? root.accentColorGlow : Qt.rgba(205/255, 214/255, 244/255, 0.35)) }
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: modelData.id
                                font { family: "Inter"; pixelSize: Math.round(10 * root.barScale); weight: Font.DemiBold }
                                color: isActive ? root.bgColor : root.fgColor
                            }

                            MouseArea {
                                id: wsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch("workspace " + modelData.id)
                            }
                        }
                    }
                }
            }

            // App Launcher Trigger Button
   //         Rectangle {
   //             implicitWidth: Math.round(28 * root.barScale)
   //             implicitHeight: Math.round(26 * root.barScale)
   //             anchors.verticalCenter: parent.verticalCenter
   //             color: root.showAppLauncher ? Qt.lighter(root.bgColor2, 1.4) : (launcherMouseArea.containsMouse ? Qt.lighter(root.bgColor2, 1.3) : root.bgColor2)
   //             radius: Math.round(30 * root.barScale)
//
   //             Behavior on color { ColorAnimation { duration: 150 } }
//
   //             Text {
   //                 anchors.centerIn: parent
   //                 text: "\uf009" // 9-dot app grid
   //                 font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: Math.round(11 * root.barScale) }
   //                 color: root.showAppLauncher ? root.accentColor : root.fgColor
   //             }
//
   //             MouseArea {
   //                 id: launcherMouseArea
   //                 anchors.fill: parent
   //                 hoverEnabled: true
   //                 cursorShape: Qt.PointingHandCursor
   //                 onClicked: root.toggleAppLauncher()
   //             }
   //         }

           Rectangle {
                id: titlePill
                anchors.verticalCenter: parent.verticalCenter
                
                // 1. The Visibility Condition
                // Leave this as 'true' to always show the pill (and just animate width changes).
                // Change it to 'ToplevelManager.activeToplevel?.activated ?? false' to hide it on an empty desktop.
                property bool showPill: true 

                // 2. The Visibility Trick
                visible: opacity > 0
                opacity: showPill ? 1.0 : 0.0

                // 3. Animate the width (uses 'width' instead of 'implicitWidth' for animations)
                clip: true
                width: showPill ? ((titleRow.implicitWidth ?? 0) + Math.round(32 * root.barScale)) : 0
                height: Math.round(26 * root.barScale)
                color: root.bgColor2
                radius: Math.round(30 * root.barScale)
                
                // 4. The Animations
                Behavior on opacity {
                    NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                }
                Behavior on width {
                    NumberAnimation { duration: 300; easing.type: Easing.OutBack } // Bouncy pop!
                }

                RowLayout {
                    id: titleRow
                    anchors.centerIn: parent
                    spacing: Math.round(8 * root.barScale)
                    
                    Text {
                        text: (ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.activated) ? "\uf2d0" : "\uf015"
                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: Math.round(12 * root.barScale) }
                        color: root.accentColor
                    }
                    
                    Text {
                        text: {
                            let top = ToplevelManager.activeToplevel
                            let t = (top && top.activated && top.title) ? top.title : "Home"
                            return t.length > 60 ? t.slice(0, 57) + "…" : t
                        }
                        color: root.fgColor
                        font { family: "Inter"; pixelSize: Math.round(12 * root.barScale); weight: Font.DemiBold }
                        elide: Text.ElideRight
                        Layout.maximumWidth: Math.round(400 * root.barScale)
                    }
                }
            }
        }

        // ─── CENTER (Media) ───────────────────────────────────
        Rectangle {
            id: centerPill
            anchors.centerIn: parent

            // 1. Define your visibility condition here
            property bool showPill: true

            // 2. The Visibility Trick: Only hide it when the opacity hits exactly 0
            visible: opacity > 0
            opacity: showPill ? 1.0 : 0.0

            // 3. Animate the width (expands from 0 to full size)
            // We use 'clip: true' so the text doesn't spill out while it's shrinking
            clip: true
            width: showPill ? Math.min(centerContentRow.implicitWidth + Math.round(32 * root.barScale), maxAvailableWidth) : 0
            height: Math.round(26 * root.barScale)
            color: root.showFullPlayer ? Qt.lighter(root.bgColor2, 1.4) : (btnMouseArea.containsMouse ? Qt.lighter(root.bgColor2, 1.3) : root.bgColor2)
            radius: Math.round(30 * root.barScale)

            readonly property real maxAvailableWidth: parent.width * 0.4

            Behavior on color { ColorAnimation { duration: 150 } }

            MouseArea {
                id: btnMouseArea
                anchors.fill: parent
                hoverEnabled: true 
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        if (root.activePlayer) root.activePlayer.togglePlaying()
                        else Quickshell.execDetached(["playerctl", "play-pause"])
                    } else {
                        if (!root.showFullPlayer) {
                            root.showControlPanel = false
                            root.showNotificationPanel = false
                            root.showAppLauncher = false
                            root.showPowerMenu = false
                            root.showWallpaperSelector = false
                        }
                        root.showFullPlayer = !root.showFullPlayer
                    }
                }
            }

            // 4. The Animations
            Behavior on opacity {
                NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
            }
            Behavior on width {
                NumberAnimation { duration: 300; easing.type: Easing.OutBack } // OutBack gives it a slight, bouncy pop!
            }

            Row {
                id: centerContentRow
                anchors.centerIn: parent
                spacing: Math.round(10 * root.barScale)

                // Fake visualizer
                Row {
                    id: vizRow
                    spacing: Math.round(3 * root.barScale)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.activePlayer && root.activePlayer.isPlaying

                    Repeater {
                        model: 4
                        Rectangle {
                            width: Math.round(3 * root.barScale)
                            height: Math.round(6 * root.barScale)
                            radius: Math.round(2 * root.barScale)
                            color: root.accentColor
                            anchors.verticalCenter: parent.verticalCenter

                            SequentialAnimation on height {
                                loops: Animation.Infinite
                                running: root.activePlayer && root.activePlayer.isPlaying
                                NumberAnimation { to: Math.round([14, 10, 16, 12][index] * root.barScale); duration: [400, 600, 350, 500][index]; easing.type: Easing.InOutSine }
                                NumberAnimation { to: Math.round(6 * root.barScale); duration: [450, 550, 300, 600][index]; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }

                // Song text + debug fallback
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(2 * root.barScale)

                    Text {
                        id: centerText
                        width: Math.min(implicitWidth, centerPill.maxAvailableWidth - (vizRow.visible ? Math.round(70 * root.barScale) : Math.round(40 * root.barScale)))
                        elide: Text.ElideMiddle
                        color: root.fgColor
                        font { family: root.mainFont; pixelSize: Math.round(12 * root.barScale); weight: Font.Medium }
                        verticalAlignment: Text.AlignVCenter

                        text: {
                            if (!root.activePlayer) return "No Media Playing"

                            let meta = root.activePlayer.metadata || {}
                            let url = meta["xesam:url"]
                            let title = meta["xesam:title"] ? meta["xesam:title"] : (url ? url.split('/').pop() : "Unknown")
                            let artist = meta["xesam:artist"] ?? ""

                            let display = artist ? artist + " — " + title : title
                            return display.length > 65 ? display.substring(0, 62) + "…" : display
                        }
                    }

                    // Tiny debug (only shows when nothing playing)
                    Text {
                        // Note: If showPill hides the whole rectangle when there is no active player, 
                        // you won't actually see this debug text anymore.
                        visible: !root.activePlayer && Mpris.players.values.length > 0
                        text: "Paused / Stopped (" + Mpris.players.values.length + " players)"
                        font { pixelSize: Math.round(10 * root.barScale) }
                        color: "#666"
                    }
                }
            }
        }

        // ─── RIGHT ────────────────────────────────────────────
        Row {
            id: rightContent
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                rightMargin: Math.round(16 * root.barScale)
            }
            spacing: Math.round(10 * root.barScale)
            layoutDirection: Qt.RightToLeft
            Rectangle {
                id: notifPill
                implicitWidth: Math.round((notifPanelPopup.unreadCount > 0 ? 50 : 42) * root.barScale)
                implicitHeight: Math.round(26 * root.barScale)
                anchors.verticalCenter: parent.verticalCenter
                color: root.showNotificationPanel ? Qt.lighter(root.bgColor2, 1.4) : (notifMouseArea.containsMouse ? Qt.lighter(root.bgColor2, 1.3) : root.bgColor2)
                radius: Math.round(30 * root.barScale)

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                Row {
                    anchors.centerIn: parent
                    spacing: Math.round(4 * root.barScale)

                    Text {
                        text: notifPanelPopup.dndEnabled ? "\uf1f6" : "\uf0f3" // bell-slash or bell
                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: Math.round(13 * root.barScale) }
                        color: notifPanelPopup.dndEnabled ? notifPanelPopup.accentColor : (root.showNotificationPanel ? root.accentColor : (notifPanelPopup.unreadCount > 0 ? root.accentColorGlow : root.fgColor))
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Unread notification badge dot
                    Rectangle {
                        visible: notifPanelPopup.unreadCount > 0
                        width: Math.round(6 * root.barScale)
                        height: Math.round(6 * root.barScale)
                        radius: width / 2
                        color: root.accentColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: notifMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (!root.showNotificationPanel) {
                            root.showFullPlayer = false
                            root.showControlPanel = false
                            root.showAppLauncher = false
                            root.showPowerMenu = false
                            root.showWallpaperSelector = false
                        }
                        root.showNotificationPanel = !root.showNotificationPanel
                    }
                }
            }

            // --- Combined Status Pill (Volume + Battery + WiFi) ---
            Rectangle {
                id: statusPill
                implicitWidth: (statusRow.implicitWidth ?? 0) + Math.round(32 * root.barScale)
                implicitHeight: Math.round(26 * root.barScale)
                anchors.verticalCenter: parent.verticalCenter
                color: root.showControlPanel ? Qt.lighter(root.bgColor2, 1.4) : (statusMouseArea.containsMouse ? Qt.lighter(root.bgColor2, 1.3) : root.bgColor2)
                radius: Math.round(30 * root.barScale)

                Behavior on color { ColorAnimation { duration: 150 } }

                MouseArea {
                    id: statusMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            root.openSettings();
                            return;
                        }
                        if (!root.showControlPanel) {
                            root.showFullPlayer = false
                            root.showNotificationPanel = false
                            root.showAppLauncher = false
                            root.showPowerMenu = false
                            root.showWallpaperSelector = false
                            controlPanelPopup.currentView = "main"
                        }
                        root.showControlPanel = !root.showControlPanel
                    }

                    onWheel: (wheel) => {
                        let step = wheel.angleDelta.y > 0 ? 0.02 : -0.02
                        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                            let cur = Pipewire.defaultAudioSink.audio.volume ?? 0
                            let newVol = Math.max(0.0, Math.min(1.0, cur + step))
                            Pipewire.defaultAudioSink.audio.volume = newVol
                            if (newVol > 0 && Pipewire.defaultAudioSink.audio.muted) {
                                Pipewire.defaultAudioSink.audio.muted = false
                            }
                        }
                    }
                }
                
                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: Math.round(11 * root.barScale)

                    // Caffeine Active Indicator
                    Text {
                        visible: controlPanelPopup.caffeineActive
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf0f4" // coffee
                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: Math.round(11 * root.barScale) }
                        color: root.accentColor
                        topPadding: 1.5
                    }

                    // Mic Muted Indicator
                    Text {
                        readonly property var defaultSrc: Pipewire.defaultAudioSource
                        readonly property var micAudio: (defaultSrc && defaultSrc.audio) ? defaultSrc.audio : null
                        visible: micAudio ? micAudio.muted : false
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf131" // microphone-slash
                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: Math.round(11 * root.barScale) }
                        color: root.accentColor
                        topPadding: 1.5
                    }

                    // Network Icon (Ethernet / WiFi)
                    Text {
                        id: wifiIcon
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf6ff"
                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: Math.round(13 * root.barScale) }
                        color: root.accentColor
                        topPadding: 1.5
                    }

                    // Volume
                    Text {
                        readonly property var defaultSink: Pipewire.defaultAudioSink
                        readonly property var audio: (defaultSink && defaultSink.audio) ? defaultSink.audio : null

                        text: {
                            if (!audio || audio.muted) return "\uf6a9" // fa-volume-xmark

                            let volPercent = Math.round(audio.volume * 100)

                            if (volPercent <= 0) return "\uf026" // fa-volume-off
                            if (volPercent <= 40) return "\uf027" // fa-volume-low
                            else return "\uf028" // fa-volume-high
                        }
                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: Math.round(13 * root.barScale) }
                        topPadding: 1.5
                        color: (audio && !audio.muted) ? root.accentColor : root.fgColor
                    }

                    // Battery
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(4 * root.barScale)

                        Text {
                            topPadding: 1.5
                            text: UPower.onBattery ? "" : ""
                            font { family: "JetBrainsMono NF"; weight: Font.Bold; pixelSize: Math.round(12 * root.barScale) }
                            color: root.accentColor
                        }

                        Text {
                            topPadding: 1.5
                            text: `${Math.round(UPower.displayDevice.percentage * 100)}%`
                            color: root.fgColor
                            font { family: "Inter"; pixelSize: Math.round(12 * root.barScale); weight: Font.Bold } 
                        }
                    }
                }

                // Network (Ethernet / WiFi) updater
                Timer {
                    interval: 4000
                    running: true
                    repeat: true
                    triggeredOnStart: true
                    onTriggered: {
                        nmcliProcess.running = false
                        nmcliProcess.running = true
                    }
                }

                Process {
                    id: nmcliProcess
                    command: ["sh", "-c", "nmcli -t -f TYPE,STATE device; echo '---WIFI---'; nmcli -t -f ACTIVE,SSID,SIGNAL device wifi list 2>/dev/null"]

                    stdout: StdioCollector {
                        onStreamFinished: {
                            let output = text.trim()
                            if (output === "") {
                                wifiIcon.text = "󰤭"
                                return
                            }

                            let sections = output.split("---WIFI---")
                            let devLines = sections[0] ? sections[0].trim().split("\n") : []
                            let wifiLines = sections[1] ? sections[1].trim().split("\n") : []

                            let ethConnected = false
                            let wifiConnected = false

                            for (let line of devLines) {
                                let parts = line.trim().split(":")
                                if (parts.length >= 2) {
                                    let type = parts[0].toLowerCase()
                                    let state = parts[1].toLowerCase()
                                    if (type === "ethernet" && state.startsWith("connected")) {
                                        ethConnected = true
                                    }
                                    if (type === "wifi" && state.startsWith("connected")) {
                                        wifiConnected = true
                                    }
                                }
                            }

                            for (let line of wifiLines) {
                                let parts = line.trim().split(":")
                                if (parts.length >= 3 && parts[0] === "yes") {
                                    wifiConnected = true
                                    break
                                }
                            }

                            if (ethConnected) {
                                wifiIcon.text = "\uf6ff" // fa-network-wired
                            } else if (wifiConnected) {
                                wifiIcon.text = "\uf1eb" // fa-wifi
                            } else {
                                wifiIcon.text = "󰤭" // disconnected
                            }
                        }
                    }
                }
                
      
            }

   Rectangle {
    // Widened slightly to accommodate the third item
    implicitWidth: sysRow.implicitWidth + Math.round(32 * root.barScale)
    implicitHeight: Math.round(26 * root.barScale)
    anchors.verticalCenter: parent.verticalCenter
    color: root.bgColor2
    radius: Math.round(30 * root.barScale)

    
    // 1. Timer to poll data every 2 seconds
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            ramProc.running = true
            cpuProc.running = true
            tempProc.running = true // Added temperature trigger
            if (!gpuProc.running) {
                gpuProc.running = true
            }
        }
    }

    // 2. Process to fetch RAM usage
    Process {
        id: ramProc
        command: ["sh", "-c", "free -h | awk '/^Mem:/ {print $3}'"]
        running: true 
        stdout: StdioCollector {
            onStreamFinished: ramText.text = this.text.trim() + "B" // This will output something like "4.2GiB"
        }
    }

    // 3. Process to fetch CPU usage
    Process {
        id: cpuProc
        command: ["sh", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2}'"]
        running: true 
        stdout: StdioCollector {
            onStreamFinished: cpuText.text = this.text.trim() + "%"
        }
    }

    // 4. Process to fetch CPU Temperature
    Process {
        id: tempProc
        // Reads raw thermal data, divides by 1000, and converts to integer
        command: ["sh", "-c", "awk '{print int($1/1000)}' /sys/class/thermal/thermal_zone0/temp"]
        running: true 
        stdout: StdioCollector {
            onStreamFinished: tempText.text = this.text.trim() + "°C"
        }
    }

    // 5. Process to fetch GPU usage
    Process {
        id: gpuProc
        command: ["sh", "-c", "if [ \"$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null)\" = \"suspended\" ]; then echo 0; else u=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1); echo \"${u:-0}\"; fi"]
        running: true 
        stdout: StdioCollector {
            onStreamFinished: {
                var v = this.text.trim()
                gpuText.text = (v ? v : "0") + "%"
            }
        }
    }

    // 6. The UI Layout
    Row {
        id: sysRow
        anchors.centerIn: parent
        spacing: Math.round(12 * root.barScale)
        
        // --- CPU Section ---
        Row {
            spacing: Math.round(6 * root.barScale)
            Text { 
                topPadding: 1.3
                text: "\uf2db" 
                font { family: "JetBrainsMono NF"; weight: Font.Bold; pixelSize: Math.round(12 * root.barScale) } 
                color: root.accentColor 
            }
            Text { 
                topPadding: 1.3
                id: cpuText
                text: "..." 
                color: root.fgColor
                font { family: "Inter"; pixelSize: Math.round(12 * root.barScale); weight: Font.Bold } 
            }
        }

        // --- Temp Section ---
        Row {
            spacing: Math.round(6 * root.barScale)
            topPadding: 1.3
            Text { 
                text: "" // Thermometer icon (nf-fa-thermometer_half)
                font { family: "JetBrainsMono NF"; weight: Font.Bold; pixelSize: Math.round(12 * root.barScale) } 
                color: root.accentColor 
            }
            Text { 
                id: tempText
                text: "..." 
                color: root.fgColor
                font { family: "Inter"; pixelSize: Math.round(12 * root.barScale); weight: Font.Bold } 
            }
        }

        // --- GPU Section ---
        Row {
            spacing: Math.round(6 * root.barScale)
            topPadding: 1.3
            Text { 
                text: "󰢮" 
                font { family: "JetBrainsMono NF"; weight: Font.Bold; pixelSize: Math.round(12 * root.barScale) } 
                color: root.accentColor 
            }
            Text { 
                id: gpuText
                text: "..." 
                color: root.fgColor
                font { family: "Inter"; pixelSize: Math.round(12 * root.barScale); weight: Font.Bold } 
            }
        }

        // --- RAM Section ---
        Row {
            spacing: Math.round(6 * root.barScale)
            topPadding: 1.3
            Text { 
                text: "" 
                font { family: "JetBrainsMono NF"; weight: Font.Bold; pixelSize: Math.round(12 * root.barScale) } 
                color: root.accentColor 
            }
            Text { 
                id: ramText
                text: "..." 
                color: root.fgColor
                font { family: "Inter"; pixelSize: Math.round(12 * root.barScale); weight: Font.Bold } 
            }
        }
    }
}

            // ─── SYSTRAY PILL ──────────────────────────────────────
            Rectangle {
                id: trayPill
                visible: SystemTray.items.values.length > 0
                implicitWidth: trayRow.implicitWidth + Math.round(24 * root.barScale)
                implicitHeight: Math.round(26 * root.barScale)
                anchors.verticalCenter: parent.verticalCenter
                color: root.bgColor2
                radius: Math.round(30 * root.barScale)

                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: Math.round(8 * root.barScale)

                    Repeater {
                        model: SystemTray.items.values
                        delegate: Item {
                            id: trayDelegate
                            width: Math.round(20 * root.barScale)
                            height: Math.round(20 * root.barScale)

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.round(4 * root.barScale)
                                color: trayMouseArea.containsMouse ? Qt.lighter(root.bgColor2, 1.5) : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Image {
                                anchors.centerIn: parent
                                width: Math.round(16 * root.barScale)
                                height: Math.round(16 * root.barScale)
                                source: modelData.icon
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                            }

                            MouseArea {
                                id: trayMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        if (root.showTrayMenu && trayMenuPopup.targetItem === modelData) {
                                            root.showTrayMenu = false
                                        } else {
                                            root.showFullPlayer = false
                                            root.showControlPanel = false
                                            root.showNotificationPanel = false
                                            root.showAppLauncher = false
                                            root.showPowerMenu = false
                                            let globalPos = trayDelegate.mapToItem(null, 0, 0)
                                            trayMenuPopup.openMenu(modelData, globalPos.x + trayDelegate.width / 2)
                                        }
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        modelData.secondaryActivate(0, 0)
                                    } else {
                                        if (modelData.itemIsMenu) {
                                            if (root.showTrayMenu && trayMenuPopup.targetItem === modelData) {
                                                root.showTrayMenu = false
                                            } else {
                                                root.showFullPlayer = false
                                                root.showControlPanel = false
                                                root.showNotificationPanel = false
                                                root.showAppLauncher = false
                                                root.showPowerMenu = false
                                                let globalPos = trayDelegate.mapToItem(null, 0, 0)
                                                trayMenuPopup.openMenu(modelData, globalPos.x + trayDelegate.width / 2)
                                            }
                                        } else {
                                            modelData.activate(0, 0)
                                        }
                                    }
                                }

                                onWheel: (wheel) => {
                                    modelData.scroll(wheel.angleDelta.y > 0 ? 1 : -1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

    // ─── Full Media Player Popup ──────────────────────────────
    FullMediaPlayer {
        id: fullMediaPlayer
        isOpen: root.showFullPlayer
        player: root.activePlayer
        barHeight: barWindow.implicitHeight
        bgColor: root.bgColor
        bgColor2: root.bgColor2
        fgColor: root.fgColor
        mainFont: root.mainFont
        iconFont: root.iconFont
        onCloseRequested: root.showFullPlayer = false
    }

    IpcHandler {
        target: "media"
        function toggle() {
            if (!root.showFullPlayer) {
                root.showCalendar = false
                root.showControlPanel = false
                root.showNotificationPanel = false
                root.showAppLauncher = false
                root.showPowerMenu = false
                root.showWallpaperSelector = false
            }
            root.showFullPlayer = !root.showFullPlayer
        }
        function open() {
            root.showCalendar = false
            root.showControlPanel = false
            root.showNotificationPanel = false
            root.showAppLauncher = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showFullPlayer = true
        }
        function close() {
            root.showFullPlayer = false
        }
    }

    // ─── Calendar Popup ───────────────────────────────────────
    CalendarPopup {
        id: calendarPopup
        isOpen: root.showCalendar
        barHeight: barWindow.implicitHeight
        barScale: root.barScale
        bgColor: root.bgColor
        bgColor2: root.bgColor2
        bgColor3: "#262626"
        fgColor: root.fgColor
        accentColor: root.accentColor
        accentColorGlow: root.accentColorGlow
        mainFont: root.mainFont
        textFont: "Inter"
        iconFont: root.iconFont
        onCloseRequested: root.showCalendar = false
    }

    IpcHandler {
        target: "calendar"
        function toggle() {
            if (!root.showCalendar) {
                root.showFullPlayer = false
                root.showControlPanel = false
                root.showNotificationPanel = false
                root.showAppLauncher = false
                root.showTrayMenu = false
                root.showPowerMenu = false
                root.showWallpaperSelector = false
            }
            root.showCalendar = !root.showCalendar
        }
        function open() {
            root.showFullPlayer = false
            root.showControlPanel = false
            root.showNotificationPanel = false
            root.showAppLauncher = false
            root.showTrayMenu = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showCalendar = true
        }
        function close() {
            root.showCalendar = false
        }
    }

    // ─── Control Panel Popup ──────────────────────────────────
    ControlPanel {
        id: controlPanelPopup
        isOpen: root.showControlPanel
        barHeight: barWindow.implicitHeight
        bgColor: root.bgColor
        bgColor2: root.bgColor2
        fgColor: root.fgColor
        accentColor: root.accentColor
        accentColorGlow: root.accentColorGlow
        mainFont: root.mainFont
        iconFont: root.iconFont
        dndEnabled: notifPanelPopup.dndEnabled
        onDndToggleRequested: notifPanelPopup.toggleDnd()
        onOpenNotificationCenterRequested: {
            root.showControlPanel = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showNotificationPanel = true
        }
        onOpenPowerMenuRequested: {
            root.showControlPanel = false
            root.showWallpaperSelector = false
            root.showPowerMenu = true
        }
        onCloseRequested: root.showControlPanel = false
    }

    IpcHandler {
        target: "control"
        function toggle() {
            if (!root.showControlPanel) {
                root.showFullPlayer = false
                root.showCalendar = false
                root.showNotificationPanel = false
                root.showAppLauncher = false
                root.showPowerMenu = false
                root.showWallpaperSelector = false
                controlPanelPopup.currentView = "main"
            }
            root.showControlPanel = !root.showControlPanel
        }
        function open() {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showNotificationPanel = false
            root.showAppLauncher = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showControlPanel = true
            controlPanelPopup.currentView = "main"
        }
        function openWifi() {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showNotificationPanel = false
            root.showAppLauncher = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showControlPanel = true
            controlPanelPopup.openWifiView()
        }
        function openBt() {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showNotificationPanel = false
            root.showAppLauncher = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showControlPanel = true
            controlPanelPopup.openBtView()
        }
        function openAudio() {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showNotificationPanel = false
            root.showAppLauncher = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showControlPanel = true
            controlPanelPopup.openAudioView()
        }
        function openSettings() {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showNotificationPanel = false
            root.showAppLauncher = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showControlPanel = true
            controlPanelPopup.openSettingsView()
        }
        function openSettingsTab(tab: string) {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showNotificationPanel = false
            root.showAppLauncher = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showControlPanel = true
            controlPanelPopup.openSettingsView()
            controlPanelPopup.settingsTab = tab
        }
        function openPowerSettings() { openSettingsTab("power") }
        function openDisplaySettings() { openSettingsTab("display") }
        function openSystemTab() { openSettingsTab("system") }
        function toggleBt() {
            controlPanelPopup.toggleBluetooth()
        }
        function toggleNightLight() {
            controlPanelPopup.toggleNightLight()
        }
        function toggleCaffeine() {
            controlPanelPopup.toggleCaffeine()
        }
        function openWifiPassword() {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showNotificationPanel = false
            root.showAppLauncher = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showControlPanel = true
            controlPanelPopup.openWifiPasswordView("Vasavi pg 4th floor 410", "WPA2")
        }
        function close() {
            root.showControlPanel = false
        }
    }

    // ─── Tray Menu Popup ──────────────────────────────────────
    TrayMenu {
        id: trayMenuPopup
        isOpen: root.showTrayMenu
        barHeight: barWindow.implicitHeight
        bgColor: root.bgColor
        bgColor2: root.bgColor2
        fgColor: root.fgColor
        accentColor: root.accentColor
        accentColorGlow: root.accentColorGlow
        mainFont: root.mainFont
        iconFont: root.iconFont
        onOpenRequested: root.showTrayMenu = true
        onCloseRequested: root.showTrayMenu = false
    }

    IpcHandler {
        target: "tray"
        function openSteam() {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showControlPanel = false
            root.showNotificationPanel = false
            root.showAppLauncher = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showTrayMenu = true
            for (let item of SystemTray.items.values) {
                if (item.id === "steam" || (item.title && item.title.toLowerCase().indexOf("steam") !== -1)) {
                    trayMenuPopup.openMenu(item, 1300)
                    return
                }
            }
            if (SystemTray.items.values.length > 0) {
                trayMenuPopup.openMenu(SystemTray.items.values[0], 1300)
            }
        }
        function openVesktop() {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showControlPanel = false
            root.showNotificationPanel = false
            root.showAppLauncher = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showTrayMenu = true
            for (let item of SystemTray.items.values) {
                if (item.id.toLowerCase().indexOf("vesktop") !== -1 || (item.title && item.title.toLowerCase().indexOf("vesktop") !== -1)) {
                    trayMenuPopup.openMenu(item, 1350)
                    return
                }
            }
            if (SystemTray.items.values.length > 1) {
                trayMenuPopup.openMenu(SystemTray.items.values[1], 1350)
            }
        }
        function close() {
            root.showTrayMenu = false
        }
    }

    IpcHandler {
        target: "notif"
        function toggle() {
            if (!root.showNotificationPanel) {
                root.showFullPlayer = false
                root.showCalendar = false
                root.showControlPanel = false
                root.showAppLauncher = false
                root.showTrayMenu = false
                root.showPowerMenu = false
                root.showWallpaperSelector = false
            }
            root.showNotificationPanel = !root.showNotificationPanel
        }
        function open() {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showControlPanel = false
            root.showAppLauncher = false
            root.showTrayMenu = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showNotificationPanel = true
        }
        function close() {
            root.showNotificationPanel = false
        }
    }

    // ─── Notification Panel Popup ─────────────────────────────
    NotificationPanel {
        id: notifPanelPopup
        isOpen: root.showNotificationPanel
        barHeight: barWindow.implicitHeight
        bgColor: root.bgColor
        bgColor2: root.bgColor2
        fgColor: root.fgColor
        accentColor: root.accentColor
        accentColorGlow: root.accentColorGlow
        mainFont: root.mainFont
        iconFont: root.iconFont
        onCloseRequested: root.showNotificationPanel = false
        onNewNotification: (notif) => {
            toastManager.showToast(notif)
        }
    }

    // ─── Notification Toasts (Heads-Up Banners) ───────────────
    NotificationToasts {
        id: toastManager
        bgColor: root.bgColor
        bgColor2: root.bgColor2
        fgColor: root.fgColor
        accentColor: root.accentColor
        accentColorGlow: root.accentColorGlow
        mainFont: root.mainFont
        iconFont: root.iconFont
        onOpenPanelRequested: {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showControlPanel = false
            root.showAppLauncher = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showNotificationPanel = true
        }
    }

    // ─── App Launcher Popup ───────────────────────────────────
    AppLauncher {
        id: appLauncherPopup
        isOpen: root.showAppLauncher
        barHeight: barWindow.implicitHeight
        bgColor: root.bgColor
        bgColor2: root.bgColor2
        bgColor3: "#262626"
        fgColor: root.fgColor
        accentColor: root.accentColor
        accentColorGlow: root.accentColorGlow
        mainFont: root.mainFont
        iconFont: root.iconFont
        onCloseRequested: root.showAppLauncher = false
        onOpenRequested: {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showControlPanel = false
            root.showNotificationPanel = false
            root.showPowerMenu = false
            root.showWallpaperSelector = false
            root.showAppLauncher = true
        }
    }

    // ─── Power Menu Popup ─────────────────────────────────────
    PowerMenu {
        id: powerMenuPopup
        isOpen: root.showPowerMenu
        barHeight: barWindow.implicitHeight
        bgColor: root.bgColor
        bgColor2: root.bgColor2
        bgColor3: "#262626"
        fgColor: root.fgColor
        accentColor: root.accentColor
        accentColorGlow: root.accentColorGlow
        mainFont: root.mainFont
        iconFont: root.iconFont
        onCloseRequested: root.showPowerMenu = false
        onOpenRequested: {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showControlPanel = false
            root.showNotificationPanel = false
            root.showAppLauncher = false
            root.showTrayMenu = false
            root.showWallpaperSelector = false
            root.showPowerMenu = true
        }
    }

    // ─── Wallpaper Selector Popup ─────────────────────────────
    WallpaperSelector {
        id: wallpaperSelectorPopup
        isOpen: root.showWallpaperSelector
        barHeight: barWindow.implicitHeight
        bgColor: root.bgColor
        bgColor2: root.bgColor2
        bgColor3: "#262626"
        fgColor: root.fgColor
        accentColor: root.accentColor
        accentColorGlow: root.accentColorGlow
        mainFont: root.mainFont
        iconFont: root.iconFont
        onCloseRequested: root.showWallpaperSelector = false
        onOpenRequested: {
            root.showFullPlayer = false
            root.showCalendar = false
            root.showControlPanel = false
            root.showNotificationPanel = false
            root.showAppLauncher = false
            root.showTrayMenu = false
            root.showPowerMenu = false
            root.showWallpaperSelector = true
        }
    }
}