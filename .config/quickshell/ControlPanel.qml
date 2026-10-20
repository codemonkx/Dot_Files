import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth

PanelWindow {
    id: controlPanelWindow

    property bool isOpen: false
    signal closeRequested()
    signal openNotificationCenterRequested()
    signal dndToggleRequested()
    signal openPowerMenuRequested()

    // Theme properties matching Bar and FullMediaPlayer
    property color bgColor: "#121213"
    property color bgColor2: "#1E1E1E"
    property color bgColor3: "#262626"
    property color fgColor: "#CDD6F4"
    property color accentColor: "#89B4FA"
    property color accentColorGlow: "#B4BEFE"
    property string mainFont: "Rowdies"
    property string iconFont: "JetBrainsMono NF"
    property int barHeight: 40

    PwObjectTracker {
        objects: [
            Pipewire.defaultAudioSink,
            Pipewire.defaultAudioSource
        ]
    }


    // ─── Network & System States ──────────────────────────────
    property bool wifiEnabled: true
    property string wifiSsid: "Wi-Fi"
    property bool btEnabled: false
    property bool dndEnabled: false
    property real brightnessPercent: 0.5 // 0.0 to 1.0

    // View state: "main", "wifi", "wifi_password", "bluetooth", "audio", "settings"
    property string currentView: "main"
    property real lastViewChangeTime: 0
    onCurrentViewChanged: {
        lastViewChangeTime = Date.now()
    }
    property var wifiNetworks: []
    property bool wifiScanning: false
    property string targetWifiSsid: ""
    property string targetWifiSecurity: ""
    property bool wifiConnecting: false
    property string wifiError: ""
    property bool showWifiPassword: false
    property var btDevices: []
    property bool btScanning: false
    property var audioSinks: []
    property bool audioScanning: false
    property var audioSources: []
    property bool audioSourcesScanning: false
    property string audioTab: "output" // "output" or "input"

    // Settings view properties
    property string currentPowerProfile: "performance"
    property bool caffeineActive: false
    property bool nightLightActive: false
    property int currentRefreshRate: 144
    property bool blurEnabled: true
    property bool animationsEnabled: true
    property bool naturalScrollEnabled: true
    property bool tapToClickEnabled: true
    property bool settingsLoading: false
    readonly property real micVolume: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) ? Pipewire.defaultAudioSource.audio.volume : 0.45
    readonly property bool micMuted: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) ? Pipewire.defaultAudioSource.audio.muted : false
    property string settingsTab: "power"

    readonly property real volumePercent: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio.volume : 0
    readonly property bool volumeMuted: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio.muted : false

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

    visible: isOpen || dropDownAnim.running || dropUpAnim.running

    // Dismiss on left-click outside. Right-click is also absorbed here so it doesn't
    // fall through to the compositor (which would cause the layer-shell window to close).
    MouseArea {
        id: backdrop
        anchors.fill: parent
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (mouse) => {
            let now = Date.now()
            let elapsed = now - lastViewChangeTime
            if (elapsed < 300) {
                mouse.accepted = true
            }
        }
        onReleased: (mouse) => {
            let now = Date.now()
            let elapsed = now - lastViewChangeTime
            if (elapsed < 300) {
                mouse.accepted = true
            }
        }
        onClicked: (mouse) => {
            let now = Date.now()
            let elapsed = now - lastViewChangeTime

            // Determine if click was inside or near the card bounds
            let cardLeft = panelRootItem.x - 20
            let cardRight = panelRootItem.x + cardContainer.width + 20
            let cardTop = 0
            let cardBottom = Math.max(cardContainer.height, 560) + 20

            let insideCard = (mouse.x >= cardLeft && mouse.x <= cardRight &&
                              mouse.y >= cardTop && mouse.y <= cardBottom)

            if (insideCard) {
                // Click is inside panel area — absorb silently, DO NOT close panel
                mouse.accepted = true
                return
            }

            // If the view was opened or changed within the last 300ms, ignore stray backdrop clicks
            if (elapsed < 300) {
                console.log("Backdrop click ignored: only", elapsed, "ms since view change")
                mouse.accepted = true
                return
            }

            if (mouse.button === Qt.LeftButton) {
                controlPanelWindow.closeRequested()
            }
        }
    }

    // Keyboard shortcut (Escape to back or close)
    Item {
        focus: controlPanelWindow.isOpen
        Keys.onEscapePressed: {
            if (controlPanelWindow.currentView === "wifi_password") {
                controlPanelWindow.wifiError = ""
                controlPanelWindow.currentView = "wifi"
            } else if (controlPanelWindow.currentView !== "main") {
                controlPanelWindow.currentView = "main"
            } else {
                controlPanelWindow.closeRequested()
            }
        }
    }

    // Refresh state when opened
    onIsOpenChanged: {
        lastViewChangeTime = Date.now()
        console.log("ControlPanel isOpen changed to:", isOpen, "currentView:", currentView)
        if (isOpen) {
            dropUpAnim.stop()
            panelRootItem.opacity = 1.0
            dropDownAnim.restart()
            wifiStatusProc.running = true
            wifiSsidProc.running = true
            btStatusProc.running = true
            brightGetProc.running = true
            audioSinksProc.running = true
            audioSourcesProc.running = true
            settingsQueryProc.running = true
        } else {
            dropDownAnim.stop()
            dropUpAnim.restart()
            currentView = "main"
            wifiError = ""
            wifiConnecting = false
        }
    }

    onCloseRequested: {
        console.log("ControlPanel closeRequested! currentView:", currentView)
        console.trace()
    }

    // ─── Backend Processes ────────────────────────────────────
    // 1. Wi-Fi Check
    Process {
        id: wifiStatusProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = text.trim().toLowerCase()
                controlPanelWindow.wifiEnabled = (s === "enabled")
            }
        }
    }

    // 2. Wi-Fi SSID
    Process {
        id: wifiSsidProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID dev wifi | awk -F: '$1==\"yes\"{print $2}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = text.trim()
                controlPanelWindow.wifiSsid = s !== "" ? s : "Disconnected"
            }
        }
    }

    // 3. Wi-Fi Toggle
    Process {
        id: wifiToggleProc
        command: ["nmcli", "radio", "wifi", controlPanelWindow.wifiEnabled ? "off" : "on"]
        onExited: {
            wifiStatusProc.running = true
            wifiSsidProc.running = true
            if (controlPanelWindow.currentView === "wifi") {
                controlPanelWindow.refreshWifiNetworks()
            }
        }
    }

    // 4. Bluetooth Check
    Process {
        id: btStatusProc
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'"]
        onExited: (code) => {
            controlPanelWindow.btEnabled = (code === 0)
        }
    }

    // 5. Bluetooth Toggle
    Process {
        id: btToggleProc
        command: ["sh", "-c", "if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then bluetoothctl power off; else rfkill unblock bluetooth 2>/dev/null; bluetoothctl power on; fi"]
        onExited: {
            btStatusProc.running = true
            if (controlPanelWindow.currentView === "bluetooth") {
                controlPanelWindow.refreshBtDevices()
            }
        }
    }

    // 6. Wi-Fi Scan & List
    Process {
        id: wifiScanProc
        command: ["sh", "-c", "echo '===SAVED==='; nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2==\"802-11-wireless\"{print $1}'; echo '===WIFI==='; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                controlPanelWindow.wifiScanning = false
                let sections = text.split("===WIFI===")
                let savedNames = []
                if (sections.length > 0) {
                    let savedLines = sections[0].replace("===SAVED===", "").trim().split("\n")
                    for (let s of savedLines) {
                        let t = s.trim()
                        if (t) savedNames.push(t)
                    }
                }
                let wifiLines = (sections.length > 1 ? sections[1] : "").trim().split("\n")
                let map = {}
                for (let i = 0; i < wifiLines.length; i++) {
                    let line = wifiLines[i]
                    if (!line || line.indexOf(":") === -1) continue
                    let parts = line.split(":")
                    if (parts.length < 4) continue
                    let inUse = parts[0].trim() === "*"
                    let ssid = parts[1].trim()
                    if (!ssid) continue
                    let sig = parseInt(parts[2].trim()) || 0
                    let sec = parts[3].trim()
                    let isSaved = savedNames.indexOf(ssid) !== -1
                    if (!map[ssid] || inUse || sig > map[ssid].signal) {
                        map[ssid] = { ssid: ssid, connected: inUse, signal: sig, security: sec, saved: isSaved }
                    }
                }
                let list = []
                for (let k in map) {
                    list.push(map[k])
                }
                list.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || (b.saved ? 1 : 0) - (a.saved ? 1 : 0) || b.signal - a.signal)
                controlPanelWindow.wifiNetworks = list
            }
        }
    }

    // 7. Bluetooth Device List
    Process {
        id: btListProc
        command: ["sh", "-c", "echo '===CONN==='; bluetoothctl devices Connected 2>/dev/null | awk '{print $2}'; echo '===PAIRED==='; bluetoothctl devices Paired 2>/dev/null | awk '{print $2}'; echo '===ALL==='; bluetoothctl devices 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let textStr = text
                let connSection = textStr.indexOf("===CONN===")
                let pairedSection = textStr.indexOf("===PAIRED===")
                let allSection = textStr.indexOf("===ALL===")
                
                let connMacs = []
                let pairedMacs = []
                let allLines = []
                
                if (connSection !== -1 && pairedSection !== -1) {
                    connMacs = textStr.substring(connSection + 10, pairedSection).trim().split("\n").map(s => s.trim()).filter(s => s.length > 0)
                }
                if (pairedSection !== -1 && allSection !== -1) {
                    pairedMacs = textStr.substring(pairedSection + 12, allSection).trim().split("\n").map(s => s.trim()).filter(s => s.length > 0)
                }
                if (allSection !== -1) {
                    allLines = textStr.substring(allSection + 9).trim().split("\n")
                }

                let list = []
                for (let i = 0; i < allLines.length; i++) {
                    let line = allLines[i].trim()
                    if (!line || !line.startsWith("Device ")) continue
                    let rest = line.substring(7).trim()
                    let spaceIdx = rest.indexOf(" ")
                    if (spaceIdx === -1) continue
                    let mac = rest.substring(0, spaceIdx).trim()
                    let name = rest.substring(spaceIdx + 1).trim()
                    let isConn = connMacs.indexOf(mac) !== -1
                    let isPaired = pairedMacs.indexOf(mac) !== -1
                    list.push({ mac: mac, name: name, connected: isConn, paired: isPaired })
                }
                list.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || (b.paired ? 1 : 0) - (a.paired ? 1 : 0))
                controlPanelWindow.btDevices = list
            }
        }
    }

    // 8. Bluetooth Active Scan Process
    Process {
        id: btScanProc
        command: ["timeout", "8", "bluetoothctl", "scan", "on"]
        onExited: {
            controlPanelWindow.btScanning = false
            btListProc.running = true
        }
    }

    // 9. Wi-Fi Connect / Auth Process
    Process {
        id: wifiAuthProc
        stdout: StdioCollector { id: wifiAuthOut }
        stderr: StdioCollector { id: wifiAuthErr }
        onExited: (code) => {
            controlPanelWindow.wifiConnecting = false
            if (code === 0) {
                controlPanelWindow.wifiError = ""
                controlPanelWindow.currentView = "wifi"
                wifiConnectTimer.restart()
            } else {
                let err = (wifiAuthErr.text || wifiAuthOut.text || "").trim()
                err = err.replace(/^Error:\s*/i, "")
                if (!err) err = "Connection failed. Please check your password."
                controlPanelWindow.wifiError = err
            }
        }
    }

    Timer {
        id: wifiConnectTimer
        interval: 1800
        onTriggered: {
            wifiStatusProc.running = true
            wifiSsidProc.running = true
            refreshWifiNetworks()
        }
    }

    Timer {
        id: btRefreshTimer
        interval: 1800
        onTriggered: {
            refreshBtDevices()
        }
    }

    Timer {
        id: passFocusTimer
        interval: 80
        onTriggered: {
            if (passInput) passInput.forceActiveFocus()
        }
    }

    function refreshWifiNetworks() {
        wifiScanning = true
        wifiScanProc.running = true
    }

    function openWifiView() {
        lastViewChangeTime = Date.now()
        console.log("openWifiView() called, currentView was:", currentView)
        currentView = "wifi"
        wifiStatusProc.running = true
        wifiSsidProc.running = true
        refreshWifiNetworks()
        console.log("openWifiView() done, currentView now:", currentView)
    }

    function openWifiPasswordView(ssid, sec) {
        targetWifiSsid = ssid
        targetWifiSecurity = sec || "WPA/WPA2"
        wifiError = ""
        wifiConnecting = false
        showWifiPassword = false
        currentView = "wifi_password"
        passFocusTimer.restart()
    }

    function connectWifiWithPassword(password) {
        if (!targetWifiSsid) return
        wifiConnecting = true
        wifiError = ""
        wifiAuthProc.command = ["nmcli", "dev", "wifi", "connect", targetWifiSsid, "password", password]
        wifiAuthProc.running = true
    }

    function handleWifiItemClick(net) {
        if (net.connected) return
        if (net.saved) {
            wifiConnecting = true
            wifiError = ""
            wifiAuthProc.command = ["nmcli", "connection", "up", "id", net.ssid]
            wifiAuthProc.running = true
            return
        }
        let sec = (net.security || "").toUpperCase()
        if (!sec || sec === "" || sec === "NONE" || sec === "--") {
            wifiConnecting = true
            wifiError = ""
            wifiAuthProc.command = ["nmcli", "dev", "wifi", "connect", net.ssid]
            wifiAuthProc.running = true
            return
        }
        openWifiPasswordView(net.ssid, net.security)
    }

    function disconnectWifi(ssid) {
        Quickshell.execDetached(["sh", "-c", `nmcli connection down id "${ssid}" 2>/dev/null || nmcli dev disconnect wlan0 2>/dev/null`])
        wifiConnectTimer.restart()
    }

    function forgetWifi(ssid) {
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", ssid])
        wifiConnectTimer.restart()
    }

    function refreshBtDevices() {
        btScanning = true
        btListProc.running = true
        btScanProc.running = true
    }

    function openBtView() {
        lastViewChangeTime = Date.now()
        currentView = "bluetooth"
        btStatusProc.running = true
        refreshBtDevices()
    }

    function toggleBtDevice(mac, isConnected, isPaired) {
        if (isConnected) {
            Quickshell.execDetached(["bluetoothctl", "disconnect", mac])
        } else if (isPaired) {
            Quickshell.execDetached(["bluetoothctl", "connect", mac])
        } else {
            Quickshell.execDetached(["sh", "-c", `bluetoothctl pair ${mac} && bluetoothctl trust ${mac} && bluetoothctl connect ${mac}`])
        }
        btRefreshTimer.restart()
    }

    function removeBtDevice(mac) {
        Quickshell.execDetached(["bluetoothctl", "remove", mac])
        btRefreshTimer.restart()
    }

    // 10. Audio Sinks Query Process
    Process {
        id: audioSinksProc
        command: ["sh", "-c", "echo '===DEFAULT==='; pactl get-default-sink 2>/dev/null; echo '===SINKS==='; pactl -f json list sinks 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                controlPanelWindow.audioScanning = false
                let textStr = text
                let defSection = textStr.indexOf("===DEFAULT===")
                let sinksSection = textStr.indexOf("===SINKS===")
                if (defSection === -1 || sinksSection === -1) return
                let defSink = textStr.substring(defSection + 14, sinksSection).trim()
                let sinksJson = textStr.substring(sinksSection + 12).trim()
                try {
                    let rawList = JSON.parse(sinksJson)
                    let list = []
                    for (let i = 0; i < rawList.length; i++) {
                        let s = rawList[i]
                        let name = s.name || ""
                        let desc = s.description || name
                        let isDefSink = (name === defSink)
                        let ports = s.ports || []

                        if (ports.length > 1) {
                            for (let j = 0; j < ports.length; j++) {
                                let p = ports[j]
                                let isCurrentPort = isDefSink && (s.active_port === p.name)
                                let pDesc = p.description || p.name
                                let pNameLower = p.name.toLowerCase()
                                let icon = "\uf028"
                                if (pNameLower.includes("headphone") || pNameLower.includes("headset")) {
                                    icon = "\uf025"
                                }
                                list.push({
                                    sinkName: name,
                                    portName: p.name,
                                    title: desc + " (" + pDesc + ")",
                                    subtitle: isCurrentPort ? "Active Output" : (p.availability === "not available" ? "Not plugged in" : "Available"),
                                    isDefault: isCurrentPort,
                                    icon: icon,
                                    available: p.availability !== "not available"
                                })
                            }
                        } else {
                            let props = s.properties || {}
                            let ff = (props["device.form_factor"] || "").toLowerCase()
                            let iconName = (props["device.icon_name"] || "").toLowerCase()
                            let bus = (props["device.bus"] || "").toLowerCase()
                            let icon = "\uf028"
                            if (ff.includes("headphone") || ff.includes("headset") || iconName.includes("headphone") || desc.toLowerCase().includes("headphone")) {
                                icon = "\uf025"
                            } else if (bus.includes("bluetooth") || name.includes("bluez")) {
                                icon = "\uf294"
                            } else if (name.toLowerCase().includes("hdmi") || desc.toLowerCase().includes("hdmi")) {
                                icon = "\uf26c"
                            }
                            list.push({
                                sinkName: name,
                                portName: "",
                                title: desc,
                                subtitle: isDefSink ? "Active Output" : "Available",
                                isDefault: isDefSink,
                                icon: icon,
                                available: true
                            })
                        }
                    }
                    list.sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0) || (b.available ? 1 : 0) - (a.available ? 1 : 0))
                    controlPanelWindow.audioSinks = list
                } catch (e) {
                    console.log("Error parsing audio sinks:", e)
                }
            }
        }
    }

    // 10b. Audio Sources (Microphone) Query Process
    Process {
        id: audioSourcesProc
        command: ["sh", "-c", "echo '===DEFAULT==='; pactl get-default-source 2>/dev/null; echo '===SOURCES==='; pactl -f json list sources 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                controlPanelWindow.audioSourcesScanning = false
                let textStr = text
                let defSection = textStr.indexOf("===DEFAULT===")
                let sourcesSection = textStr.indexOf("===SOURCES===")
                if (defSection === -1 || sourcesSection === -1) return
                let defSource = textStr.substring(defSection + 14, sourcesSection).trim()
                let sourcesJson = textStr.substring(sourcesSection + 14).trim()
                try {
                    let rawList = JSON.parse(sourcesJson)
                    let list = []
                    for (let i = 0; i < rawList.length; i++) {
                        let s = rawList[i]
                        let name = s.name || ""
                        if (s.monitor_source || name.indexOf(".monitor") !== -1) continue
                        let desc = s.description || name
                        let isDefSource = (name === defSource)
                        let ports = s.ports || []

                        if (ports.length > 1) {
                            for (let j = 0; j < ports.length; j++) {
                                let p = ports[j]
                                let isCurrentPort = isDefSource && (s.active_port === p.name)
                                let pDesc = p.description || p.name
                                let pNameLower = p.name.toLowerCase()
                                let icon = "\uf130"
                                if (pNameLower.includes("headset") || pNameLower.includes("headphone")) {
                                    icon = "\uf025"
                                }
                                list.push({
                                    sourceName: name,
                                    portName: p.name,
                                    title: desc + " (" + pDesc + ")",
                                    subtitle: isCurrentPort ? "Active Microphone" : (p.availability === "not available" ? "Not plugged in" : "Available"),
                                    isDefault: isCurrentPort,
                                    icon: icon,
                                    available: p.availability !== "not available"
                                })
                            }
                        } else {
                            let props = s.properties || {}
                            let ff = (props["device.form_factor"] || "").toLowerCase()
                            let bus = (props["device.bus"] || "").toLowerCase()
                            let icon = "\uf130"
                            if (ff.includes("headphone") || ff.includes("headset")) {
                                icon = "\uf025"
                            } else if (bus.includes("bluetooth") || name.includes("bluez")) {
                                icon = "\uf294"
                            } else if (props["device.class"] === "webcam" || name.toLowerCase().includes("webcam") || desc.toLowerCase().includes("camera")) {
                                icon = "\uf03d"
                            }
                            list.push({
                                sourceName: name,
                                portName: "",
                                title: desc,
                                subtitle: isDefSource ? "Active Microphone" : "Available",
                                isDefault: isDefSource,
                                icon: icon,
                                available: true
                            })
                        }
                    }
                    list.sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0) || (b.available ? 1 : 0) - (a.available ? 1 : 0))
                    controlPanelWindow.audioSources = list
                } catch (e) {
                    console.log("Error parsing audio sources:", e)
                }
            }
        }
    }

    Timer {
        id: audioRefreshTimer
        interval: 200
        onTriggered: {
            if (controlPanelWindow.audioTab === "input") {
                refreshAudioSources()
            } else {
                refreshAudioSinks()
            }
        }
    }

    function refreshAudioSinks() {
        audioScanning = true
        audioSinksProc.running = true
    }

    function refreshAudioSources() {
        audioSourcesScanning = true
        audioSourcesProc.running = true
    }

    function openAudioView() {
        lastViewChangeTime = Date.now()
        currentView = "audio"
        audioTab = "output"
        refreshAudioSinks()
    }

    function openMicView() {
        lastViewChangeTime = Date.now()
        currentView = "audio"
        audioTab = "input"
        refreshAudioSources()
    }

    function selectAudioSink(item) {
        if (!item) return
        Quickshell.execDetached(["pactl", "set-default-sink", item.sinkName])
        if (item.portName && item.portName !== "") {
            Quickshell.execDetached(["pactl", "set-sink-port", item.sinkName, item.portName])
        }
        audioRefreshTimer.restart()
    }

    function selectAudioSource(item) {
        if (!item) return
        Quickshell.execDetached(["pactl", "set-default-source", item.sourceName])
        if (item.portName && item.portName !== "") {
            Quickshell.execDetached(["pactl", "set-source-port", item.sourceName, item.portName])
        }
        audioRefreshTimer.restart()
    }

    // 11. Settings Query Process
    Process {
        id: settingsQueryProc
        command: ["sh", "-c", "echo '===POWER==='; powerprofilesctl get 2>/dev/null || echo 'performance'; echo '===REFRESH==='; hyprctl monitors 2>/dev/null | grep -o '1920x1080@[0-9]*' | head -1 | cut -d@ -f2 || echo '144'; echo '===CAFFEINE==='; ps -C hypridle -o state= 2>/dev/null | grep -q 'T' && echo '1' || echo '0'; echo '===NIGHTLIGHT==='; hyprctl getoption decoration:screen_shader 2>/dev/null | grep -q 'str: .\\+' && echo '1' || echo '0'; echo '===BLUR==='; hyprctl getoption decoration:blur:enabled 2>/dev/null | grep -q 'int: 1' && echo '1' || echo '0'; echo '===ANIM==='; hyprctl getoption animations:enabled 2>/dev/null | grep -q 'int: 1' && echo '1' || echo '0'; echo '===NATURAL==='; hyprctl getoption input:touchpad:natural_scroll 2>/dev/null | grep -q 'int: 1' && echo '1' || echo '0'; echo '===TAP==='; hyprctl getoption input:touchpad:tap-to-click 2>/dev/null | grep -q 'int: 1' && echo '1' || echo '0'"]
        stdout: StdioCollector {
            onStreamFinished: {
                controlPanelWindow.settingsLoading = false
                let pMatch = text.match(/===POWER===\s*([^\n\r]+)/)
                if (pMatch) controlPanelWindow.currentPowerProfile = pMatch[1].trim()

                let rMatch = text.match(/===REFRESH===\s*([^\n\r]+)/)
                if (rMatch) controlPanelWindow.currentRefreshRate = parseInt(rMatch[1].trim()) || 144

                let cMatch = text.match(/===CAFFEINE===\s*([^\n\r]+)/)
                if (cMatch) controlPanelWindow.caffeineActive = (cMatch[1].trim() === "1")

                let nlMatch = text.match(/===NIGHTLIGHT===\s*([^\n\r]+)/)
                if (nlMatch) controlPanelWindow.nightLightActive = (nlMatch[1].trim() === "1")

                let bMatch = text.match(/===BLUR===\s*([^\n\r]+)/)
                if (bMatch) controlPanelWindow.blurEnabled = (bMatch[1].trim() === "1")

                let aMatch = text.match(/===ANIM===\s*([^\n\r]+)/)
                if (aMatch) controlPanelWindow.animationsEnabled = (aMatch[1].trim() === "1")

                let nMatch = text.match(/===NATURAL===\s*([^\n\r]+)/)
                if (nMatch) controlPanelWindow.naturalScrollEnabled = (nMatch[1].trim() === "1")

                let tMatch = text.match(/===TAP===\s*([^\n\r]+)/)
                if (tMatch) controlPanelWindow.tapToClickEnabled = (tMatch[1].trim() === "1")
            }
        }
    }

    function refreshSettings() {
        settingsLoading = true
        settingsQueryProc.running = true
    }

    function openSettingsView() {
        lastViewChangeTime = Date.now()
        currentView = "settings"
        settingsTab = "power"
        refreshSettings()
    }

    function setPowerProfile(mode) {
        controlPanelWindow.currentPowerProfile = mode
        Quickshell.execDetached(["powerprofilesctl", "set", mode])
    }

    function toggleCaffeine() {
        controlPanelWindow.caffeineActive = !controlPanelWindow.caffeineActive
        if (controlPanelWindow.caffeineActive) {
            Quickshell.execDetached(["killall", "-STOP", "hypridle"])
        } else {
            Quickshell.execDetached(["killall", "-CONT", "hypridle"])
        }
    }

    function setRefreshRate(hz) {
        controlPanelWindow.currentRefreshRate = hz
        Quickshell.execDetached(["hyprctl", "keyword", "monitor", `eDP-1,1920x1080@${hz},0x0,1`])
    }

    function toggleNightLight() {
        controlPanelWindow.nightLightActive = !controlPanelWindow.nightLightActive
        if (controlPanelWindow.nightLightActive) {
            Quickshell.execDetached(["hyprctl", "keyword", "decoration:screen_shader", Quickshell.env("HOME") + "/.config/hypr/shaders/night-light.frag"])
        } else {
            Quickshell.execDetached(["hyprctl", "keyword", "decoration:screen_shader", ""])
        }
    }

    function toggleBlur() {
        controlPanelWindow.blurEnabled = !controlPanelWindow.blurEnabled
        Quickshell.execDetached(["hyprctl", "keyword", "decoration:blur:enabled", controlPanelWindow.blurEnabled ? "1" : "0"])
    }

    function toggleAnimations() {
        controlPanelWindow.animationsEnabled = !controlPanelWindow.animationsEnabled
        Quickshell.execDetached(["hyprctl", "keyword", "animations:enabled", controlPanelWindow.animationsEnabled ? "1" : "0"])
    }

    function toggleNaturalScroll() {
        controlPanelWindow.naturalScrollEnabled = !controlPanelWindow.naturalScrollEnabled
        Quickshell.execDetached(["hyprctl", "keyword", "input:touchpad:natural_scroll", controlPanelWindow.naturalScrollEnabled ? "1" : "0"])
    }

    function toggleTapToClick() {
        tapToClickEnabled = !tapToClickEnabled
        Quickshell.execDetached(["hyprctl", "keyword", "input:touchpad:tap-to-click", tapToClickEnabled ? "1" : "0"])
    }

    function setMicVolume(ratio) {
        let val = Math.max(0.0, Math.min(1.0, ratio))
        if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) {
            Pipewire.defaultAudioSource.audio.volume = val
            if (val > 0 && Pipewire.defaultAudioSource.audio.muted) {
                Pipewire.defaultAudioSource.audio.muted = false
            }
        }
    }

    function toggleMicMute() {
        if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) {
            Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
        }
    }

    // 6. Brightness Query
    Process {
        id: brightGetProc
        command: ["sh", "-c", "brightnessctl -m | awk -F, '{print $4}' | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let val = parseInt(text.trim())
                if (!isNaN(val) && !brightMouseArea.pressed) {
                    controlPanelWindow.brightnessPercent = Math.max(0.01, Math.min(1.0, val / 100.0))
                }
            }
        }
    }

    // Helper functions
    function toggleWifi() {
        wifiToggleProc.running = true
    }

    function toggleBluetooth() {
        controlPanelWindow.btEnabled = !controlPanelWindow.btEnabled
        btToggleProc.running = true
    }

    function toggleDnd() {
        controlPanelWindow.dndToggleRequested()
    }

    function setBrightness(ratio) {
        let pct = Math.max(1, Math.min(100, Math.round(ratio * 100)))
        controlPanelWindow.brightnessPercent = pct / 100.0
        Quickshell.execDetached(["brightnessctl", "set", pct + "%"])
    }

    function setVolume(ratio) {
        let val = Math.max(0.0, Math.min(1.0, ratio))
        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
            Pipewire.defaultAudioSink.audio.volume = val
            if (val > 0 && Pipewire.defaultAudioSink.audio.muted) {
                Pipewire.defaultAudioSink.audio.muted = false
            }
        }
    }

    function toggleMute() {
        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
        }
    }

    // ─── THE PANEL ROOT ITEM ──────────────────────────────────
    Item {
        id: panelRootItem
        width: cardContainer.width
        height: cardContainer.height

        // Aligned to the right side above the status pill
        x: Math.round(controlPanelWindow.width - width - 16)

        // Attached directly to the bottom edge of the top bar
        y: isOpen ? 0 : -cardContainer.height
        opacity: 0.0

        NumberAnimation {
            id: dropDownAnim
            target: panelRootItem
            property: "y"
            from: -cardContainer.height
            to: 0
            duration: 280
            easing.type: Easing.OutCubic
        }

        ParallelAnimation {
            id: dropUpAnim
            NumberAnimation {
                target: panelRootItem
                property: "y"
                to: -cardContainer.height
                duration: 240
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: panelRootItem
                property: "opacity"
                to: 0.0
                duration: 200
                easing.type: Easing.InQuad
            }
        }

        // Left curved fillet joining the card smoothly into the top bar
        Shape {
            width: 16
            height: 16
            transform: Scale { origin.y: 8; yScale: -1 }
            anchors {
                right: cardContainer.left
                top: cardContainer.top
            }
            preferredRendererType: Shape.CurveRenderer
            
            // Solid fill
            ShapePath {
                strokeWidth: 0
                fillColor: controlPanelWindow.bgColor
                startX: 16
                startY: 0
                PathLine { x: 16; y: 16 }
                PathLine { x: 0; y: 16 }
                PathCubic {
                    x: 16
                    y: 0
                    control1X: 8.836
                    control1Y: 16
                    control2X: 16
                    control2Y: 8.836
                }
            }
            
            // Border line
            ShapePath {
                strokeWidth: 1
                strokeColor: "#2C2C30"
                fillColor: "transparent"
                startX: 0
                startY: 16
                PathCubic {
                    x: 16
                    y: 0
                    control1X: 8.836
                    control1Y: 16
                    control2X: 16
                    control2Y: 8.836
                }
            }
        }

        // Right curved fillet joining the card smoothly into the top bar
        Shape {
            width: 16
            height: 16
            transform: Scale { origin.y: 8; yScale: -1 }
            anchors {
                left: cardContainer.right
                top: cardContainer.top
            }
            preferredRendererType: Shape.CurveRenderer
            
            // Solid fill
            ShapePath {
                strokeWidth: 0
                fillColor: controlPanelWindow.bgColor
                startX: 0
                startY: 0
                PathLine { x: 0; y: 16 }
                PathLine { x: 16; y: 16 }
                PathCubic {
                    x: 0
                    y: 0
                    control1X: 7.164
                    control1Y: 16
                    control2X: 0
                    control2Y: 8.836
                }
            }
            
            // Border line
            ShapePath {
                strokeWidth: 1
                strokeColor: "#2C2C30"
                fillColor: "transparent"
                startX: 16
                startY: 16
                PathCubic {
                    x: 0
                    y: 0
                    control1X: 7.164
                    control1Y: 16
                    control2X: 0
                    control2Y: 8.836
                }
            }
        }

        // ─── CARD CONTAINER ───────────────────────────────────
        Rectangle {
            id: cardContainer
            width: 360
            height: controlPanelWindow.currentView === "main" ? Math.max(316, Math.round(mainViewLayout.implicitHeight + 40)) : (controlPanelWindow.currentView === "settings" ? Math.max(316, Math.round(settingsViewLayout.implicitHeight + 40)) : 380)
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 24
            bottomRightRadius: 24
            color: controlPanelWindow.bgColor
            border.width: 0
            border.color: "#2C2C30"
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.55
                shadowBlur: 0.5
                shadowVerticalOffset: 4
            }

            // Cover the 1px top border so the card blends completely into the bar
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: 2
                color: controlPanelWindow.bgColor
            }

            // Absorbs all clicks on the card background so clicking empty space won't close it
            // The ColumnLayout children (pills, sliders) are declared AFTER this and have higher
            // Z-order, so their MouseAreas still intercept events before this absorber does.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                hoverEnabled: false
                onPressed: (mouse) => { mouse.accepted = true }
                onReleased: (mouse) => { mouse.accepted = true }
                onClicked: (mouse) => { mouse.accepted = true }
            }

            ColumnLayout {
                id: mainViewLayout
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 20
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 14
                visible: controlPanelWindow.currentView === "main"

                // ─── 1. Header Row (Battery & Actions) ─────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    // Battery status pill
                    Rectangle {
                        implicitWidth: batteryRow.implicitWidth + 20
                        implicitHeight: 28
                        radius: 14
                        color: controlPanelWindow.bgColor2

                        Row {
                            id: batteryRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: {
                                    let pct = Math.round(UPower.displayDevice.percentage * 100)
                                    if (UPower.onBattery) {
                                        if (pct <= 20) return "\uf244" // empty
                                        if (pct <= 50) return "\uf243" // quarter
                                        if (pct <= 75) return "\uf242" // half
                                        return "\uf240" // full
                                    }
                                    return "\uf0e7" // bolt / charging
                                }
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                                color: controlPanelWindow.accentColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: {
                                    let pct = Math.round(UPower.displayDevice.percentage * 100)
                                    return `${pct}%`
                                }
                                font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                color: controlPanelWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Settings button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: settingsBtnArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.4) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf013" // gear
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                            color: controlPanelWindow.fgColor
                        }

                        MouseArea {
                            id: settingsBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.openSettingsView()
                        }
                    }

                    // Lock Screen button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: lockArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.4) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf023" // lock
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                            color: controlPanelWindow.fgColor
                        }

                        MouseArea {
                            id: lockArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["loginctl", "lock-session"])
                                controlPanelWindow.closeRequested()
                            }
                        }
                    }

                    // Power Menu button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: powerBtnArea.containsMouse ? Qt.rgba(1, 0.43, 0.43, 0.25) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf011" // power-off
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                            color: powerBtnArea.containsMouse ? "#FF6E6E" : controlPanelWindow.fgColor
                        }

                        MouseArea {
                            id: powerBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                controlPanelWindow.closeRequested()
                                controlPanelWindow.openPowerMenuRequested()
                            }
                        }
                    }

                    // Close button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: closeArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.4) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d" // times
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                            color: closeArea.containsMouse ? "#FFFFFF" : controlPanelWindow.fgColor
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.closeRequested()
                        }
                    }
                }

                // ─── 2. GNOME-Style Quick Toggles Grid (2x2) ──
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10

                    // ── Wi-Fi Toggle Pill ──
                    Rectangle {
                        id: wifiPill
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 16
                        color: controlPanelWindow.wifiEnabled ? controlPanelWindow.accentColor : controlPanelWindow.bgColor2

                        Behavior on color { ColorAnimation { duration: 180 } }

                        // Background catcher: right click anywhere opens Wi-Fi view
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onPressed: (mouse) => { mouse.accepted = true }
                            onReleased: (mouse) => { mouse.accepted = true }
                            onClicked: (mouse) => {
                                mouse.accepted = true
                                controlPanelWindow.openWifiView()
                            }
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 8
                                rightMargin: 12
                            }
                            spacing: 6

                            // Left zone: Icon Toggle Button
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: wifiIconArea.containsMouse ? (controlPanelWindow.wifiEnabled ? Qt.darker(controlPanelWindow.accentColor, 1.15) : Qt.lighter(controlPanelWindow.bgColor2, 1.25)) : "transparent"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf1eb" // wifi
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 16 }
                                    color: controlPanelWindow.wifiEnabled ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                }

                                MouseArea {
                                    id: wifiIconArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onPressed: (mouse) => { mouse.accepted = true }
                                    onReleased: (mouse) => { mouse.accepted = true }
                                    onClicked: (mouse) => {
                                        mouse.accepted = true
                                        if (mouse.button === Qt.RightButton) {
                                            controlPanelWindow.openWifiView()
                                        } else {
                                            controlPanelWindow.toggleWifi()
                                        }
                                    }
                                }
                            }

                            // Right zone: Title, SSID/Status, and Chevron
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 6

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: "Wi-Fi"
                                            font { family: "Inter"; pixelSize: 13; weight: Font.Bold }
                                            color: controlPanelWindow.wifiEnabled ? controlPanelWindow.bgColor : "#FFFFFF"
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: controlPanelWindow.wifiEnabled ? controlPanelWindow.wifiSsid : "Off"
                                            font { family: "Inter"; pixelSize: 11 }
                                            color: controlPanelWindow.wifiEnabled ? Qt.darker(controlPanelWindow.bgColor, 1.4) : controlPanelWindow.fgColor
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: "\uf054" // chevron-right
                                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                        color: controlPanelWindow.wifiEnabled ? Qt.darker(controlPanelWindow.bgColor, 1.3) : controlPanelWindow.fgColor
                                        opacity: wifiDetailsArea.containsMouse ? 1.0 : 0.6
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                    }
                                }

                                MouseArea {
                                    id: wifiDetailsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onPressed: (mouse) => { mouse.accepted = true }
                                    onReleased: (mouse) => { mouse.accepted = true }
                                    onClicked: (mouse) => {
                                        mouse.accepted = true
                                        controlPanelWindow.openWifiView()
                                    }
                                }
                            }
                        }
                    }

                    // ── Bluetooth Toggle Pill ──
                    Rectangle {
                        id: btPill
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 16
                        color: controlPanelWindow.btEnabled ? controlPanelWindow.accentColor : controlPanelWindow.bgColor2

                        Behavior on color { ColorAnimation { duration: 180 } }

                        // Background catcher: right click anywhere opens Bluetooth view
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onPressed: (mouse) => { mouse.accepted = true }
                            onReleased: (mouse) => { mouse.accepted = true }
                            onClicked: (mouse) => {
                                mouse.accepted = true
                                controlPanelWindow.openBtView()
                            }
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 8
                                rightMargin: 12
                            }
                            spacing: 6

                            // Left zone: Icon Toggle Button
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: btIconArea.containsMouse ? (controlPanelWindow.btEnabled ? Qt.darker(controlPanelWindow.accentColor, 1.15) : Qt.lighter(controlPanelWindow.bgColor2, 1.25)) : "transparent"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf294" // bluetooth
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 16 }
                                    color: controlPanelWindow.btEnabled ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                }

                                MouseArea {
                                    id: btIconArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onPressed: (mouse) => { mouse.accepted = true }
                                    onReleased: (mouse) => { mouse.accepted = true }
                                    onClicked: (mouse) => {
                                        mouse.accepted = true
                                        if (mouse.button === Qt.RightButton) {
                                            controlPanelWindow.openBtView()
                                        } else {
                                            controlPanelWindow.toggleBluetooth()
                                        }
                                    }
                                }
                            }

                            // Right zone: Title, Status, and Chevron
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 6

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: "Bluetooth"
                                            font { family: "Inter"; pixelSize: 13; weight: Font.Bold }
                                            color: controlPanelWindow.btEnabled ? controlPanelWindow.bgColor : "#FFFFFF"
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: controlPanelWindow.btEnabled ? "On" : "Off"
                                            font { family: "Inter"; pixelSize: 11 }
                                            color: controlPanelWindow.btEnabled ? Qt.darker(controlPanelWindow.bgColor, 1.4) : controlPanelWindow.fgColor
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: "\uf054" // chevron-right
                                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                        color: controlPanelWindow.btEnabled ? Qt.darker(controlPanelWindow.bgColor, 1.3) : controlPanelWindow.fgColor
                                        opacity: btDetailsArea.containsMouse ? 1.0 : 0.6
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                    }
                                }

                                MouseArea {
                                    id: btDetailsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onPressed: (mouse) => { mouse.accepted = true }
                                    onReleased: (mouse) => { mouse.accepted = true }
                                    onClicked: (mouse) => {
                                        mouse.accepted = true
                                        controlPanelWindow.openBtView()
                                    }
                                }
                            }
                        }
                    }

                    // ── Do Not Disturb Toggle Pill ──
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 16
                        color: controlPanelWindow.dndEnabled ? controlPanelWindow.accentColor : controlPanelWindow.bgColor2

                        Behavior on color { ColorAnimation { duration: 180 } }

                        MouseArea {
                            id: dndArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.toggleDnd()
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 14
                                rightMargin: 14
                            }
                            spacing: 12

                            Text {
                                text: controlPanelWindow.dndEnabled ? "\uf1f6" : "\uf0f3" // bell-slash or bell
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 15 }
                                color: controlPanelWindow.dndEnabled ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Do Not Disturb"
                                    font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                    color: controlPanelWindow.dndEnabled ? controlPanelWindow.bgColor : "#FFFFFF"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: controlPanelWindow.dndEnabled ? "Silent" : "Off"
                                    font { family: "Inter"; pixelSize: 11 }
                                    color: controlPanelWindow.dndEnabled ? Qt.darker(controlPanelWindow.bgColor, 1.4) : controlPanelWindow.fgColor
                                }
                            }
                        }
                    }

                    // ── Notification Center Toggle Pill ──
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 16
                        color: controlPanelWindow.bgColor2

                        MouseArea {
                            id: notifArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                controlPanelWindow.closeRequested()
                                controlPanelWindow.openNotificationCenterRequested()
                            }
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 14
                                rightMargin: 14
                            }
                            spacing: 12

                            Text {
                                text: "\uf0f3" // bell
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 15 }
                                color: controlPanelWindow.fgColor
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Notifications"
                                    font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                    color: "#FFFFFF"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "Open Center"
                                    font { family: "Inter"; pixelSize: 11 }
                                    color: controlPanelWindow.fgColor
                                }
                            }
                        }
                    }
                }

                // ─── 3. Sliders Section (GNOME Pill Sliders) ───
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // ── Sound / Volume Bar ──
                    Rectangle {
                        id: volumeSliderContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: 23
                        color: controlPanelWindow.bgColor2

                        // Filled portion
                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: parent.width * Math.min(1.0, Math.max(0.0, controlPanelWindow.volumeMuted ? 0 : controlPanelWindow.volumePercent))
                            radius: 23
                            color: controlPanelWindow.volumeMuted ? "#404040" : controlPanelWindow.accentColor

                            Behavior on width { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Content inside slider (Icon left, Percentage right, Chevron far right)
                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 16
                                rightMargin: 14
                            }
                            spacing: 8

                            // Speaker mute/unmute icon button
                            Item {
                                width: 24
                                height: 24

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (controlPanelWindow.volumeMuted || controlPanelWindow.volumePercent <= 0) return "\uf026" // mute
                                        if (controlPanelWindow.volumePercent < 0.5) return "\uf027" // down
                                        return "\uf028" // up
                                    }
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 15 }
                                    color: (!controlPanelWindow.volumeMuted && controlPanelWindow.volumePercent > 0.15) ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controlPanelWindow.toggleMute()
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: controlPanelWindow.volumeMuted ? "Muted" : `${Math.round(controlPanelWindow.volumePercent * 100)}%`
                                font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                color: (!controlPanelWindow.volumeMuted && controlPanelWindow.volumePercent > 0.80) ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                            }

                            // Audio device switcher button / chevron
                            Item {
                                width: 18
                                height: 24

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf054" // chevron-right
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                    color: (!controlPanelWindow.volumeMuted && controlPanelWindow.volumePercent > 0.90) ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                    opacity: 0.75
                                }
                            }
                        }

                        // Drag & click handler for volume slider
                        MouseArea {
                            id: volumeMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton || mouse.x > width - 42) {
                                    controlPanelWindow.openAudioView()
                                    return
                                }
                                if (mouse.x < 42) {
                                    controlPanelWindow.toggleMute()
                                    return
                                }
                                let ratio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                controlPanelWindow.setVolume(ratio)
                            }

                            onPositionChanged: (mouse) => {
                                if (pressed && (mouse.buttons & Qt.LeftButton)) {
                                    let ratio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                    controlPanelWindow.setVolume(ratio)
                                }
                            }
                        }
                    }

                    // ── Microphone Bar ──
                    Rectangle {
                        id: mainMicSliderContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: 23
                        color: controlPanelWindow.bgColor2

                        // Filled portion
                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: parent.width * Math.min(1.0, Math.max(0.0, controlPanelWindow.micMuted ? 0 : controlPanelWindow.micVolume))
                            radius: 23
                            color: controlPanelWindow.micMuted ? "#404040" : controlPanelWindow.accentColor

                            Behavior on width { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Content inside slider (Icon left, Percentage right)
                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 16
                                rightMargin: 16
                            }
                            spacing: 8

                            // Mic mute/unmute icon button
                            Item {
                                width: 24
                                height: 24

                                Text {
                                    anchors.centerIn: parent
                                    text: controlPanelWindow.micMuted ? "\uf131" : "\uf130"
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 15 }
                                    color: (!controlPanelWindow.micMuted && controlPanelWindow.micVolume > 0.15) ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controlPanelWindow.toggleMicMute()
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: controlPanelWindow.micMuted ? "Muted" : `${Math.round(controlPanelWindow.micVolume * 100)}%`
                                font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                color: (!controlPanelWindow.micMuted && controlPanelWindow.micVolume > 0.85) ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                            }

                            // Audio input / microphone switcher button / chevron
                            Item {
                                width: 18
                                height: 24

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf054" // chevron-right
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                    color: (!controlPanelWindow.micMuted && controlPanelWindow.micVolume > 0.90) ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                    opacity: 0.75
                                }
                            }
                        }

                        // Drag & click handler for mic slider
                        MouseArea {
                            id: mainMicMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton || mouse.x > width - 42) {
                                    controlPanelWindow.openMicView()
                                    return
                                }
                                if (mouse.x < 42) {
                                    controlPanelWindow.toggleMicMute()
                                    return
                                }
                                let ratio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                controlPanelWindow.setMicVolume(ratio)
                            }

                            onPositionChanged: (mouse) => {
                                if (pressed && (mouse.buttons & Qt.LeftButton)) {
                                    let ratio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                    controlPanelWindow.setMicVolume(ratio)
                                }
                            }
                        }
                    }

                    // ── Brightness Bar ──
                    Rectangle {
                        id: brightnessSliderContainer
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: 23
                        color: controlPanelWindow.bgColor2

                        // Filled portion
                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: parent.width * Math.min(1.0, Math.max(0.0, controlPanelWindow.brightnessPercent))
                            radius: 23
                            color: controlPanelWindow.accentColor

                            Behavior on width { NumberAnimation { duration: 100 } }
                        }

                        // Content inside slider (Icon left, Percentage right)
                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 16
                                rightMargin: 16
                            }

                            Item {
                                width: 24
                                height: 24

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf185" // sun
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 15 }
                                    color: (controlPanelWindow.brightnessPercent > 0.15) ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: `${Math.round(controlPanelWindow.brightnessPercent * 100)}%`
                                font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                color: (controlPanelWindow.brightnessPercent > 0.85) ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                            }
                        }

                        // Drag & click handler for brightness slider
                        MouseArea {
                            id: brightMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: (mouse) => {
                                let ratio = Math.max(0.01, Math.min(1.0, mouse.x / width))
                                controlPanelWindow.setBrightness(ratio)
                            }

                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    let ratio = Math.max(0.01, Math.min(1.0, mouse.x / width))
                                    controlPanelWindow.setBrightness(ratio)
                                }
                            }
                        }
                    }
                }
            }

            // ─── Wi-Fi Subview Layout ─────────────────────────
            ColumnLayout {
                id: wifiViewLayout
                anchors {
                    fill: parent
                    topMargin: 16
                    bottomMargin: 14
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 10
                visible: controlPanelWindow.currentView === "wifi"

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: backWifiArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.3) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf060" // arrow-left
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                            color: controlPanelWindow.fgColor
                        }

                        MouseArea {
                            id: backWifiArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.currentView = "main"
                        }
                    }

                    Text {
                        text: "Wi-Fi Networks"
                        font { family: "Inter"; pixelSize: 14; weight: Font.Bold }
                        color: "#FFFFFF"
                    }

                    Item { Layout.fillWidth: true }

                    // Refresh Button
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: refreshWifiArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.3) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf021" // sync
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                            color: controlPanelWindow.wifiScanning ? controlPanelWindow.accentColor : controlPanelWindow.fgColor
                            rotation: controlPanelWindow.wifiScanning ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 300 } }
                        }

                        MouseArea {
                            id: refreshWifiArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.refreshWifiNetworks()
                        }
                    }

                    // On/Off Switch Pill
                    Rectangle {
                        width: 48
                        height: 26
                        radius: 13
                        color: controlPanelWindow.wifiEnabled ? controlPanelWindow.accentColor : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: controlPanelWindow.wifiEnabled ? "On" : "Off"
                            font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                            color: controlPanelWindow.wifiEnabled ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.toggleWifi()
                        }
                    }
                }

                // Networks List or Empty State
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: wifiListView
                        anchors.fill: parent
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: controlPanelWindow.wifiNetworks
                        visible: controlPanelWindow.wifiNetworks.length > 0

                        delegate: Rectangle {
                            required property var modelData
                            width: wifiListView.width
                            height: 48
                            radius: 12
                            color: modelData.connected ? Qt.rgba(137/255, 180/255, 250/255, 0.15) : (itemHover.containsMouse ? controlPanelWindow.bgColor3 : controlPanelWindow.bgColor2)
                            border.width: modelData.connected ? 1 : 0
                            border.color: controlPanelWindow.accentColor

                            MouseArea {
                                id: itemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controlPanelWindow.handleWifiItemClick(modelData)
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                spacing: 10

                                Text {
                                    text: "\uf1eb"
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 14 }
                                    color: modelData.connected ? controlPanelWindow.accentColor : controlPanelWindow.fgColor
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.ssid
                                        font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                        color: "#FFFFFF"
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.connected ? "Connected" : (modelData.saved ? ("Saved • " + modelData.signal + "%") : (modelData.signal + "%" + (modelData.security ? " • " + modelData.security : "")))
                                        font { family: "Inter"; pixelSize: 10 }
                                        color: modelData.connected ? controlPanelWindow.accentColor : controlPanelWindow.fgColor
                                        elide: Text.ElideRight
                                    }
                                }

                                // Security lock icon for secured networks (not connected)
                                Text {
                                    visible: modelData.security && modelData.security !== "" && !modelData.connected
                                    text: "\uf023" // lock
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 10 }
                                    color: controlPanelWindow.fgColor
                                    opacity: 0.7
                                }

                                // Forget / Delete button for saved networks (not active)
                                Rectangle {
                                    visible: modelData.saved && !modelData.connected
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: forgetArea.containsMouse ? Qt.rgba(224/255, 108/255, 117/255, 0.25) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf1f8" // trash-can
                                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                        color: forgetArea.containsMouse ? "#E06C75" : controlPanelWindow.fgColor
                                        opacity: forgetArea.containsMouse ? 1.0 : 0.6
                                    }

                                    MouseArea {
                                        id: forgetArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: controlPanelWindow.forgetWifi(modelData.ssid)
                                    }
                                }

                                // Disconnect button if active
                                Rectangle {
                                    visible: modelData.connected
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: disconnWifiArea.containsMouse ? Qt.rgba(224/255, 108/255, 117/255, 0.25) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf011" // power-off
                                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                        color: disconnWifiArea.containsMouse ? "#E06C75" : controlPanelWindow.fgColor
                                    }

                                    MouseArea {
                                        id: disconnWifiArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: controlPanelWindow.disconnectWifi(modelData.ssid)
                                    }
                                }

                                // Connected checkmark badge
                                Text {
                                    visible: modelData.connected
                                    text: "\uf00c" // check
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                                    color: controlPanelWindow.accentColor
                                }
                            }
                        }
                    }

                    // Empty / Scanning State
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: controlPanelWindow.wifiNetworks.length === 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: controlPanelWindow.wifiScanning ? "\uf021" : "\uf1eb"
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 24 }
                            color: controlPanelWindow.fgColor
                            opacity: 0.6
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: !controlPanelWindow.wifiEnabled ? "Wi-Fi is turned off" : (controlPanelWindow.wifiScanning ? "Scanning networks..." : "No networks found")
                            font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                            color: controlPanelWindow.fgColor
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            visible: !controlPanelWindow.wifiEnabled
                            width: 80
                            height: 28
                            radius: 14
                            color: controlPanelWindow.accentColor

                            Text {
                                anchors.centerIn: parent
                                text: "Turn On"
                                font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                color: controlPanelWindow.bgColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controlPanelWindow.toggleWifi()
                            }
                        }
                    }
                }
            }

            // ─── Wi-Fi Password Prompt Subview Layout ─────────
            ColumnLayout {
                id: wifiPasswordLayout
                anchors {
                    fill: parent
                    topMargin: 16
                    bottomMargin: 16
                    leftMargin: 18
                    rightMargin: 18
                }
                spacing: 12
                visible: controlPanelWindow.currentView === "wifi_password"

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: backWifiPassArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.3) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf060" // arrow-left
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                            color: controlPanelWindow.fgColor
                        }

                        MouseArea {
                            id: backWifiPassArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                controlPanelWindow.wifiError = ""
                                controlPanelWindow.currentView = "wifi"
                            }
                        }
                    }

                    Text {
                        text: "Enter Wi-Fi Password"
                        font { family: "Inter"; pixelSize: 14; weight: Font.Bold }
                        color: "#FFFFFF"
                    }

                    Item { Layout.fillWidth: true }
                }

                // Selected Network Info Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 14
                    color: controlPanelWindow.bgColor2

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 14
                            rightMargin: 14
                        }
                        spacing: 12

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: controlPanelWindow.bgColor3

                            Text {
                                anchors.centerIn: parent
                                text: "\uf1eb" // wifi
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 14 }
                                color: controlPanelWindow.accentColor
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: controlPanelWindow.targetWifiSsid
                                font { family: "Inter"; pixelSize: 13; weight: Font.Bold }
                                color: "#FFFFFF"
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: controlPanelWindow.targetWifiSecurity || "WPA/WPA2 Personal"
                                font { family: "Inter"; pixelSize: 10 }
                                color: controlPanelWindow.fgColor
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Password Input Container
                Rectangle {
                    id: passInputContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: 14
                    color: controlPanelWindow.bgColor2
                    border.width: passInput.activeFocus ? 1.5 : 1
                    border.color: passInput.activeFocus ? controlPanelWindow.accentColor : "#2C2C30"

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 14
                            rightMargin: 12
                        }
                        spacing: 10

                        Text {
                            text: "\uf023" // lock
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                            color: passInput.activeFocus ? controlPanelWindow.accentColor : controlPanelWindow.fgColor
                        }

                        TextInput {
                            id: passInput
                            Layout.fillWidth: true
                            verticalAlignment: TextInput.AlignVCenter
                            font { family: "Inter"; pixelSize: 13; weight: Font.Medium }
                            color: "#FFFFFF"
                            selectionColor: controlPanelWindow.accentColor
                            selectedTextColor: controlPanelWindow.bgColor
                            echoMode: controlPanelWindow.showWifiPassword ? TextInput.Normal : TextInput.Password
                            clip: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Enter Password..."
                                font: parent.font
                                color: "#666666"
                                visible: !parent.text
                            }

                            onAccepted: {
                                if (text.trim().length > 0 && !controlPanelWindow.wifiConnecting) {
                                    controlPanelWindow.connectWifiWithPassword(text.trim())
                                }
                            }
                        }

                        // Toggle show/hide password
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: controlPanelWindow.showWifiPassword ? "\uf070" : "\uf06e" // eye-slash / eye
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                                color: eyeArea.containsMouse ? "#FFFFFF" : controlPanelWindow.fgColor
                            }

                            MouseArea {
                                id: eyeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controlPanelWindow.showWifiPassword = !controlPanelWindow.showWifiPassword
                            }
                        }
                    }
                }

                // Error / Connecting status message
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8
                        visible: controlPanelWindow.wifiConnecting || controlPanelWindow.wifiError !== ""

                        Text {
                            text: controlPanelWindow.wifiConnecting ? "\uf110" : "\uf06a" // spinner or exclamation
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                            color: controlPanelWindow.wifiConnecting ? controlPanelWindow.accentColor : "#E06C75"
                        }

                        Text {
                            Layout.fillWidth: true
                            text: controlPanelWindow.wifiConnecting ? "Connecting to " + controlPanelWindow.targetWifiSsid + "..." : controlPanelWindow.wifiError
                            font { family: "Inter"; pixelSize: 11; weight: Font.Medium }
                            color: controlPanelWindow.wifiConnecting ? controlPanelWindow.accentColor : "#E06C75"
                            elide: Text.ElideRight
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Action Buttons (Cancel & Connect)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    spacing: 12

                    // Cancel Button
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 14
                        color: cancelArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.3) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                            color: controlPanelWindow.fgColor
                        }

                        MouseArea {
                            id: cancelArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                controlPanelWindow.wifiError = ""
                                passInput.text = ""
                                controlPanelWindow.currentView = "wifi"
                            }
                        }
                    }

                    // Connect Button
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 14
                        opacity: (passInput.text.trim().length === 0 || controlPanelWindow.wifiConnecting) ? 0.5 : 1.0
                        color: connectArea.containsMouse ? Qt.lighter(controlPanelWindow.accentColor, 1.1) : controlPanelWindow.accentColor

                        Text {
                            anchors.centerIn: parent
                            text: controlPanelWindow.wifiConnecting ? "Connecting..." : "Connect"
                            font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                            color: controlPanelWindow.bgColor
                        }

                        MouseArea {
                            id: connectArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: (passInput.text.trim().length > 0 && !controlPanelWindow.wifiConnecting) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (passInput.text.trim().length > 0 && !controlPanelWindow.wifiConnecting) {
                                    controlPanelWindow.connectWifiWithPassword(passInput.text.trim())
                                }
                            }
                        }
                    }
                }
            }

            // ─── Bluetooth Subview Layout ─────────────────────
            ColumnLayout {
                id: btViewLayout
                anchors {
                    fill: parent
                    topMargin: 16
                    bottomMargin: 14
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 10
                visible: controlPanelWindow.currentView === "bluetooth"

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: backBtArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.3) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf060" // arrow-left
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                            color: controlPanelWindow.fgColor
                        }

                        MouseArea {
                            id: backBtArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.currentView = "main"
                        }
                    }

                    Text {
                        text: "Bluetooth Devices"
                        font { family: "Inter"; pixelSize: 14; weight: Font.Bold }
                        color: "#FFFFFF"
                    }

                    Item { Layout.fillWidth: true }

                    // Refresh Button
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: refreshBtArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.3) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf021" // sync
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                            color: controlPanelWindow.btScanning ? controlPanelWindow.accentColor : controlPanelWindow.fgColor
                            rotation: controlPanelWindow.btScanning ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 300 } }
                        }

                        MouseArea {
                            id: refreshBtArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.refreshBtDevices()
                        }
                    }

                    // On/Off Switch Pill
                    Rectangle {
                        width: 48
                        height: 26
                        radius: 13
                        color: controlPanelWindow.btEnabled ? controlPanelWindow.accentColor : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: controlPanelWindow.btEnabled ? "On" : "Off"
                            font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                            color: controlPanelWindow.btEnabled ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.toggleBluetooth()
                        }
                    }
                }

                // Device List or Empty State
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: btListView
                        anchors.fill: parent
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: controlPanelWindow.btDevices
                        visible: controlPanelWindow.btDevices.length > 0

                        delegate: Rectangle {
                            required property var modelData
                            width: btListView.width
                            height: 48
                            radius: 12
                            color: modelData.connected ? Qt.rgba(137/255, 180/255, 250/255, 0.15) : (itemHoverBt.containsMouse ? controlPanelWindow.bgColor3 : controlPanelWindow.bgColor2)
                            border.width: modelData.connected ? 1 : 0
                            border.color: controlPanelWindow.accentColor

                            MouseArea {
                                id: itemHoverBt
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controlPanelWindow.toggleBtDevice(modelData.mac, modelData.connected, modelData.paired)
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                spacing: 10

                                Text {
                                    text: {
                                        let n = (modelData.name || "").toLowerCase()
                                        if (n.includes("buds") || n.includes("head") || n.includes("ear") || n.includes("airpod") || n.includes("headset")) return "\uf025" // headphones
                                        if (n.includes("gamepad") || n.includes("controller") || n.includes("xbox") || n.includes("ps4") || n.includes("ps5") || n.includes("dualshock")) return "\uf11b" // gamepad
                                        if (n.includes("mouse")) return "\uf8cd" // mouse
                                        if (n.includes("keyboard")) return "\uf11c" // keyboard
                                        if (n.includes("phone") || n.includes("galaxy") || n.includes("iphone") || n.includes("pixel") || n.includes("vivo") || n.includes("oneplus")) return "\uf3cd" // phone
                                        return "\uf294" // bluetooth
                                    }
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 14 }
                                    color: modelData.connected ? controlPanelWindow.accentColor : controlPanelWindow.fgColor
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                        color: "#FFFFFF"
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.connected ? "Connected" : (modelData.paired ? "Paired • Tap to connect" : "Available • Tap to pair")
                                        font { family: "Inter"; pixelSize: 10 }
                                        color: modelData.connected ? controlPanelWindow.accentColor : controlPanelWindow.fgColor
                                        elide: Text.ElideRight
                                    }
                                }

                                // Forget / Unpair button for paired devices (when not connected)
                                Rectangle {
                                    visible: modelData.paired && !modelData.connected
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: forgetBtArea.containsMouse ? Qt.rgba(224/255, 108/255, 117/255, 0.25) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf1f8" // trash-can
                                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                        color: forgetBtArea.containsMouse ? "#E06C75" : controlPanelWindow.fgColor
                                        opacity: forgetBtArea.containsMouse ? 1.0 : 0.6
                                    }

                                    MouseArea {
                                        id: forgetBtArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: controlPanelWindow.removeBtDevice(modelData.mac)
                                    }
                                }

                                // Disconnect button if active
                                Rectangle {
                                    visible: modelData.connected
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: disconnBtArea.containsMouse ? Qt.rgba(224/255, 108/255, 117/255, 0.25) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf011" // power-off
                                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                        color: disconnBtArea.containsMouse ? "#E06C75" : controlPanelWindow.fgColor
                                    }

                                    MouseArea {
                                        id: disconnBtArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: controlPanelWindow.toggleBtDevice(modelData.mac, true, true)
                                    }
                                }

                                // Connected checkmark badge
                                Text {
                                    visible: modelData.connected
                                    text: "\uf00c" // check
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                                    color: controlPanelWindow.accentColor
                                }
                            }
                        }
                    }

                    // Empty / Scanning State
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: controlPanelWindow.btDevices.length === 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: controlPanelWindow.btScanning ? "\uf021" : "\uf294"
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 24 }
                            color: controlPanelWindow.fgColor
                            opacity: 0.6
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: !controlPanelWindow.btEnabled ? "Bluetooth is turned off" : (controlPanelWindow.btScanning ? "Scanning for devices..." : "No devices found")
                            font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                            color: controlPanelWindow.fgColor
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            visible: !controlPanelWindow.btEnabled
                            width: 80
                            height: 28
                            radius: 14
                            color: controlPanelWindow.accentColor

                            Text {
                                anchors.centerIn: parent
                                text: "Turn On"
                                font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                color: controlPanelWindow.bgColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controlPanelWindow.toggleBluetooth()
                            }
                        }
                    }
                }
            }

            // ─── Audio Devices Subview Layout (Output & Input) ──────────
            ColumnLayout {
                id: audioViewLayout
                anchors {
                    fill: parent
                    topMargin: 16
                    bottomMargin: 14
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 12
                visible: controlPanelWindow.currentView === "audio"

                // ── Header (Back Button, Dynamic Title, Refresh) ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: backAudioArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.3) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf060" // arrow-left
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                            color: controlPanelWindow.fgColor
                        }

                        MouseArea {
                            id: backAudioArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.currentView = "main"
                        }
                    }

                    Text {
                        text: controlPanelWindow.audioTab === "input" ? "Microphone Devices" : "Audio Output Devices"
                        font { family: "Inter"; pixelSize: 14; weight: Font.Bold }
                        color: "#FFFFFF"
                    }

                    Item { Layout.fillWidth: true }

                    // Refresh Button
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: refreshAudioArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.3) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf021" // sync
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                            color: (controlPanelWindow.audioTab === "input" ? controlPanelWindow.audioSourcesScanning : controlPanelWindow.audioScanning) ? controlPanelWindow.accentColor : controlPanelWindow.fgColor
                            rotation: (controlPanelWindow.audioTab === "input" ? controlPanelWindow.audioSourcesScanning : controlPanelWindow.audioScanning) ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 300 } }
                        }

                        MouseArea {
                            id: refreshAudioArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (controlPanelWindow.audioTab === "input") {
                                    controlPanelWindow.refreshAudioSources()
                                } else {
                                    controlPanelWindow.refreshAudioSinks()
                                }
                            }
                        }
                    }
                }

                // ── 2-Way Sliding Segmented Tab Pill (Output vs Input) ──
                Rectangle {
                    id: audioTabContainer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 19
                    color: controlPanelWindow.bgColor2

                    // Active Sliding Indicator Pill
                    Rectangle {
                        id: audioTabPill
                        y: 3
                        height: parent.height - 6
                        width: Math.round((parent.width - 6) / 2)
                        x: controlPanelWindow.audioTab === "input" ? Math.round(3 + (parent.width - 6) / 2) : 3
                        radius: 16
                        color: controlPanelWindow.accentColor
                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 0

                        // Output Tab
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "\uf028" // volume-high
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                                    color: controlPanelWindow.audioTab === "output" ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Output (Speakers)"
                                    font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                    color: controlPanelWindow.audioTab === "output" ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    controlPanelWindow.audioTab = "output"
                                    controlPanelWindow.refreshAudioSinks()
                                }
                            }
                        }

                        // Input Tab
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "\uf130" // microphone
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                                    color: controlPanelWindow.audioTab === "input" ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Input (Mic)"
                                    font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                    color: controlPanelWindow.audioTab === "input" ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    controlPanelWindow.audioTab = "input"
                                    controlPanelWindow.refreshAudioSources()
                                }
                            }
                        }
                    }
                }

                // ── Device List (Outputs or Inputs) ──
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Sinks List (Audio Output)
                    ListView {
                        id: audioSinksListView
                        anchors.fill: parent
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: controlPanelWindow.audioTab === "output" ? controlPanelWindow.audioSinks : []
                        visible: controlPanelWindow.audioTab === "output" && controlPanelWindow.audioSinks.length > 0

                        delegate: Rectangle {
                            required property var modelData
                            width: audioSinksListView.width
                            height: 48
                            radius: 12
                            color: modelData.isDefault ? Qt.rgba(137/255, 180/255, 250/255, 0.15) : (itemHoverSink.containsMouse ? controlPanelWindow.bgColor3 : controlPanelWindow.bgColor2)
                            border.width: modelData.isDefault ? 1 : 0
                            border.color: controlPanelWindow.accentColor

                            MouseArea {
                                id: itemHoverSink
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controlPanelWindow.selectAudioSink(modelData)
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                spacing: 10

                                Text {
                                    text: modelData.icon || "\uf028"
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 14 }
                                    color: modelData.isDefault ? controlPanelWindow.accentColor : controlPanelWindow.fgColor
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                        color: "#FFFFFF"
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.subtitle
                                        font { family: "Inter"; pixelSize: 10 }
                                        color: modelData.isDefault ? controlPanelWindow.accentColor : controlPanelWindow.fgColor
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    visible: modelData.isDefault
                                    text: "\uf00c" // check
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                                    color: controlPanelWindow.accentColor
                                }
                            }
                        }
                    }

                    // Sources List (Microphone Input)
                    ListView {
                        id: audioSourcesListView
                        anchors.fill: parent
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: controlPanelWindow.audioTab === "input" ? controlPanelWindow.audioSources : []
                        visible: controlPanelWindow.audioTab === "input" && controlPanelWindow.audioSources.length > 0

                        delegate: Rectangle {
                            required property var modelData
                            width: audioSourcesListView.width
                            height: 48
                            radius: 12
                            color: modelData.isDefault ? Qt.rgba(137/255, 180/255, 250/255, 0.15) : (itemHoverSource.containsMouse ? controlPanelWindow.bgColor3 : controlPanelWindow.bgColor2)
                            border.width: modelData.isDefault ? 1 : 0
                            border.color: controlPanelWindow.accentColor

                            MouseArea {
                                id: itemHoverSource
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controlPanelWindow.selectAudioSource(modelData)
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                spacing: 10

                                Text {
                                    text: modelData.icon || "\uf130"
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 14 }
                                    color: modelData.isDefault ? controlPanelWindow.accentColor : controlPanelWindow.fgColor
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                        color: "#FFFFFF"
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.subtitle
                                        font { family: "Inter"; pixelSize: 10 }
                                        color: modelData.isDefault ? controlPanelWindow.accentColor : controlPanelWindow.fgColor
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    visible: modelData.isDefault
                                    text: "\uf00c" // check
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                                    color: controlPanelWindow.accentColor
                                }
                            }
                        }
                    }

                    // Empty / Scanning State
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: (controlPanelWindow.audioTab === "output" && controlPanelWindow.audioSinks.length === 0) || (controlPanelWindow.audioTab === "input" && controlPanelWindow.audioSources.length === 0)

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: (controlPanelWindow.audioTab === "input" ? controlPanelWindow.audioSourcesScanning : controlPanelWindow.audioScanning) ? "\uf021" : (controlPanelWindow.audioTab === "input" ? "\uf130" : "\uf028")
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 24 }
                            color: controlPanelWindow.fgColor
                            opacity: 0.6
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: (controlPanelWindow.audioTab === "input" ? (controlPanelWindow.audioSourcesScanning ? "Scanning microphones..." : "No microphones found") : (controlPanelWindow.audioScanning ? "Scanning audio devices..." : "No audio devices found"))
                            font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                            color: controlPanelWindow.fgColor
                        }
                    }
                }
            }

            // ─── Settings Subview Layout ──────────────────────
            ColumnLayout {
                id: settingsViewLayout
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 20
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 14
                visible: controlPanelWindow.currentView === "settings"

                // ─── 1. Header Row (Back Pill & Actions) ─────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    // Back capsule pill (mirrors Battery pill aesthetic)
                    Rectangle {
                        implicitWidth: backRow.implicitWidth + 22
                        implicitHeight: 28
                        radius: 14
                        color: backSettingsArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.35) : controlPanelWindow.bgColor2

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            id: backRow
                            anchors.centerIn: parent
                            spacing: 7

                            Text {
                                text: "\uf060" // arrow-left
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                color: controlPanelWindow.accentColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Settings"
                                font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                color: controlPanelWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: backSettingsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.currentView = "main"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Refresh Button (28x28 circle)
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: refreshSettingsArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.4) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf021" // sync
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                            color: controlPanelWindow.settingsLoading ? controlPanelWindow.accentColor : controlPanelWindow.fgColor
                            rotation: controlPanelWindow.settingsLoading ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 300 } }
                        }

                        MouseArea {
                            id: refreshSettingsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.refreshSettings()
                        }
                    }

                    // Close Button (28x28 circle)
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: closeSettingsArea.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.4) : controlPanelWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d" // times
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                            color: closeSettingsArea.containsMouse ? "#FFFFFF" : controlPanelWindow.fgColor
                        }

                        MouseArea {
                            id: closeSettingsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.closeRequested()
                        }
                    }
                }

                // ─── 2. GNOME-Style Quick Toggles Grid (2x3) ───
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10

                    // ── 1. Night Light Pill ──
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 16
                        color: controlPanelWindow.nightLightActive ? controlPanelWindow.accentColor : controlPanelWindow.bgColor2
                        Behavior on color { ColorAnimation { duration: 180 } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.toggleNightLight()
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 14
                                rightMargin: 14
                            }
                            spacing: 12

                            Text {
                                text: "\uf186" // moon
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 15 }
                                color: controlPanelWindow.nightLightActive ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Night Light"
                                    font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                    color: controlPanelWindow.nightLightActive ? controlPanelWindow.bgColor : "#FFFFFF"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: controlPanelWindow.nightLightActive ? "Active" : "Warm Filter"
                                    font { family: "Inter"; pixelSize: 11 }
                                    color: controlPanelWindow.nightLightActive ? Qt.darker(controlPanelWindow.bgColor, 1.4) : controlPanelWindow.fgColor
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // ── 2. Caffeine Mode Pill ──
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 16
                        color: controlPanelWindow.caffeineActive ? controlPanelWindow.accentColor : controlPanelWindow.bgColor2
                        Behavior on color { ColorAnimation { duration: 180 } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.toggleCaffeine()
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 14
                                rightMargin: 14
                            }
                            spacing: 12

                            Text {
                                text: "\uf0f4" // coffee
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 15 }
                                color: controlPanelWindow.caffeineActive ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Caffeine"
                                    font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                    color: controlPanelWindow.caffeineActive ? controlPanelWindow.bgColor : "#FFFFFF"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: controlPanelWindow.caffeineActive ? "Inhibit Sleep" : "Off"
                                    font { family: "Inter"; pixelSize: 11 }
                                    color: controlPanelWindow.caffeineActive ? Qt.darker(controlPanelWindow.bgColor, 1.4) : controlPanelWindow.fgColor
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // ── 3. Refresh Rate Pill ──
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 16
                        color: controlPanelWindow.currentRefreshRate >= 120 ? controlPanelWindow.accentColor : controlPanelWindow.bgColor2
                        Behavior on color { ColorAnimation { duration: 180 } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.setRefreshRate(controlPanelWindow.currentRefreshRate >= 120 ? 60 : 144)
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 14
                                rightMargin: 14
                            }
                            spacing: 12

                            Text {
                                text: "\uf26c" // display
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 15 }
                                color: controlPanelWindow.currentRefreshRate >= 120 ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Refresh Rate"
                                    font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                    color: controlPanelWindow.currentRefreshRate >= 120 ? controlPanelWindow.bgColor : "#FFFFFF"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: controlPanelWindow.currentRefreshRate >= 120 ? "144Hz Smooth" : "60Hz Saver"
                                    font { family: "Inter"; pixelSize: 11 }
                                    color: controlPanelWindow.currentRefreshRate >= 120 ? Qt.darker(controlPanelWindow.bgColor, 1.4) : controlPanelWindow.fgColor
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // ── 4. Window Blur Pill ──
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 16
                        color: controlPanelWindow.blurEnabled ? controlPanelWindow.accentColor : controlPanelWindow.bgColor2
                        Behavior on color { ColorAnimation { duration: 180 } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.toggleBlur()
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 14
                                rightMargin: 14
                            }
                            spacing: 12

                            Text {
                                text: "\uf043" // tint
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 15 }
                                color: controlPanelWindow.blurEnabled ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Window Blur"
                                    font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                    color: controlPanelWindow.blurEnabled ? controlPanelWindow.bgColor : "#FFFFFF"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: controlPanelWindow.blurEnabled ? "Enabled" : "Off"
                                    font { family: "Inter"; pixelSize: 11 }
                                    color: controlPanelWindow.blurEnabled ? Qt.darker(controlPanelWindow.bgColor, 1.4) : controlPanelWindow.fgColor
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // ── 5. Natural Scroll Pill ──
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 16
                        color: controlPanelWindow.naturalScrollEnabled ? controlPanelWindow.accentColor : controlPanelWindow.bgColor2
                        Behavior on color { ColorAnimation { duration: 180 } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.toggleNaturalScroll()
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 14
                                rightMargin: 14
                            }
                            spacing: 12

                            Text {
                                text: "\uf07d" // arrows-up-down
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 15 }
                                color: controlPanelWindow.naturalScrollEnabled ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Natural Scroll"
                                    font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                    color: controlPanelWindow.naturalScrollEnabled ? controlPanelWindow.bgColor : "#FFFFFF"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: controlPanelWindow.naturalScrollEnabled ? "macOS Scroll" : "Standard"
                                    font { family: "Inter"; pixelSize: 11 }
                                    color: controlPanelWindow.naturalScrollEnabled ? Qt.darker(controlPanelWindow.bgColor, 1.4) : controlPanelWindow.fgColor
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // ── 6. Tap to Click Pill ──
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 16
                        color: controlPanelWindow.tapToClickEnabled ? controlPanelWindow.accentColor : controlPanelWindow.bgColor2
                        Behavior on color { ColorAnimation { duration: 180 } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanelWindow.toggleTapToClick()
                        }

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 14
                                rightMargin: 14
                            }
                            spacing: 12

                            Text {
                                text: "\uf245" // hand-pointer
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 15 }
                                color: controlPanelWindow.tapToClickEnabled ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Tap to Click"
                                    font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                    color: controlPanelWindow.tapToClickEnabled ? controlPanelWindow.bgColor : "#FFFFFF"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: controlPanelWindow.tapToClickEnabled ? "Enabled" : "Physical Only"
                                    font { family: "Inter"; pixelSize: 11 }
                                    color: controlPanelWindow.tapToClickEnabled ? Qt.darker(controlPanelWindow.bgColor, 1.4) : controlPanelWindow.fgColor
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                // ─── 3. 3-Way Power Profile Pill (Matching Pill Slider Dimensions) ───
                Rectangle {
                    id: powerSegBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: 23
                    color: controlPanelWindow.bgColor2

                    // Sliding blue active pill
                    Rectangle {
                        id: powerActivePill
                        width: Math.round((powerSegBar.width - 8) / 3)
                        height: powerSegBar.height - 8
                        y: 4
                        x: {
                            let w = (powerSegBar.width - 8) / 3
                            if (controlPanelWindow.currentPowerProfile === "power-saver") return Math.round(4 + w * 2)
                            if (controlPanelWindow.currentPowerProfile === "balanced") return Math.round(4 + w)
                            return 4
                        }
                        radius: 19
                        color: controlPanelWindow.accentColor
                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 0

                        // Performance
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "\uf0e7"
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                    color: controlPanelWindow.currentPowerProfile === "performance" ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Performance"
                                    font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                    color: controlPanelWindow.currentPowerProfile === "performance" ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controlPanelWindow.setPowerProfile("performance")
                            }
                        }

                        // Balanced
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "\uf24e"
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                    color: controlPanelWindow.currentPowerProfile === "balanced" ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Balanced"
                                    font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                    color: controlPanelWindow.currentPowerProfile === "balanced" ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controlPanelWindow.setPowerProfile("balanced")
                            }
                        }

                        // Saver
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "\uf06c"
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                    color: controlPanelWindow.currentPowerProfile === "power-saver" ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Saver"
                                    font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                    color: controlPanelWindow.currentPowerProfile === "power-saver" ? controlPanelWindow.bgColor : controlPanelWindow.fgColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: controlPanelWindow.setPowerProfile("power-saver")
                            }
                        }
                    }
                }

                // ─── 4. Quick Config Shortcuts ───
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 18
                        color: hyprBtnHover.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.35) : controlPanelWindow.bgColor2

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: "\uf121"
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                color: controlPanelWindow.accentColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "hyprland.conf"
                                font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                color: controlPanelWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: hyprBtnHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                controlPanelWindow.closeRequested()
                                Quickshell.execDetached(["ghostty", "-e", "vim", Quickshell.env("HOME") + "/.config/hypr/hyprland.conf"])
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 18
                        color: qsBtnHover.containsMouse ? Qt.lighter(controlPanelWindow.bgColor2, 1.35) : controlPanelWindow.bgColor2

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: "\uf121"
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                color: controlPanelWindow.accentColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "quickshell"
                                font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                color: controlPanelWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: qsBtnHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                controlPanelWindow.closeRequested()
                                Quickshell.execDetached(["ghostty", "-e", "vim", Quickshell.env("HOME") + "/.config/quickshell/shell.qml"])
                            }
                        }
                    }
                }
            }
        }
    }
}