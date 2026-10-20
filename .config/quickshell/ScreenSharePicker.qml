import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: sharePickerWindow

    property bool isOpen: false
    property bool isSubmitting: false
    property string fifoPath: ""
    property string rawWindowsString: ""
    property bool allowToken: false
    property string activeTab: "screens" // "screens", "windows", "region"

    property var screensList: []
    property var windowsList: []

    // Catppuccin Sapphire Theme Colors
    property color bgColor: "#121213"
    property color bgColor2: "#1E1E22"
    property color bgColor3: "#26262B"
    property color fgColor: "#CDD6F4"
    property color fgMuted: "#888892"
    property color accentColor: "#89B4FA"
    property color accentColorHover: "#A6C8FF"
    property color borderColor: "#2E2E36"

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

    visible: isOpen

    // ─── Finish Process (Writes result to FIFO & unblocks bash) ───
    Process {
        id: finishProc
        running: false
    }

    // ─── Region Selection Process (runs slurp) ───
    Process {
        id: regionProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let geom = text.trim()
                if (geom && geom.length > 0) {
                    sharePickerWindow.submitSelection("region", geom)
                } else {
                    sharePickerWindow.cancelSelection()
                }
            }
        }
    }

    // ─── Query Monitors Process ───
    Process {
        id: monitorsProc
        running: false
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text.trim())
                    let screens = []
                    for (let i = 0; i < data.length; i++) {
                        let m = data[i]
                        screens.push({
                            name: m.name || `Screen ${i+1}`,
                            description: m.description || "",
                            width: m.width || 1920,
                            height: m.height || 1080,
                            refreshRate: Math.round(m.refreshRate || 60),
                            isPrimary: (m.focused === true || i === 0)
                        })
                    }
                    sharePickerWindow.screensList = screens
                } catch(e) {
                    sharePickerWindow.screensList = [{
                        name: "eDP-1",
                        description: "Primary Display",
                        width: 1920,
                        height: 1080,
                        refreshRate: 144,
                        isPrimary: true
                    }]
                }
            }
        }
    }

    // ─── Query Hyprland Clients Fallback ───
    Process {
        id: clientsProc
        running: false
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (sharePickerWindow.windowsList.length > 0) return
                try {
                    let clients = JSON.parse(text.trim())
                    let wins = []
                    for (let i = 0; i < clients.length; i++) {
                        let c = clients[i]
                        if (c.mapped && c.visible) {
                            wins.push({
                                id: c.address || String(c.pid || i),
                                appClass: c.class || "App",
                                title: c.title || c.initialTitle || "Untitled Window",
                                workspace: c.workspace ? c.workspace.name : "1"
                            })
                        }
                    }
                    sharePickerWindow.windowsList = wins
                } catch(e) {}
            }
        }
    }

    function openPicker(fifo, rawWindows) {
        isSubmitting = false
        fifoPath = fifo
        rawWindowsString = rawWindows || ""
        allowToken = false
        activeTab = "screens"

        // Parse XDPH_WINDOW_SHARING_LIST
        let wins = []
        if (rawWindows && rawWindows.indexOf("[HC>]") !== -1) {
            let entries = rawWindows.split("[HE>]")
            for (let i = 0; i < entries.length; i++) {
                let entry = entries[i].trim()
                if (!entry) continue
                let hcParts = entry.split("[HC>]")
                if (hcParts.length < 2) continue
                let winId = hcParts[0].trim()
                let htParts = hcParts[1].split("[HT>]")
                let appClass = htParts[0].trim()
                let title = htParts.length > 1 ? htParts[1].trim() : appClass

                wins.push({
                    id: winId,
                    appClass: appClass,
                    title: title,
                    workspace: ""
                })
            }
        }
        windowsList = wins

        // Refresh hardware monitors
        monitorsProc.running = false
        monitorsProc.running = true

        // If no windows from XDPH, query clients
        if (windowsList.length === 0) {
            clientsProc.running = false
            clientsProc.running = true
        }

        isOpen = true
    }

    function submitSelection(type, val) {
        if (!fifoPath || isSubmitting) {
            isOpen = false
            return
        }
        isSubmitting = true
        let prefix = allowToken ? "[SELECTION]r/" : "[SELECTION]/"
        let out = prefix + type + ":" + val
        finishProc.command = ["sh", "-c", 'printf "%s\\n" "$1" > "$2"', "--", out, fifoPath]
        finishProc.running = false
        finishProc.running = true
        isOpen = false
    }

    function cancelSelection() {
        if (!fifoPath || isSubmitting) {
            isOpen = false
            return
        }
        isSubmitting = true
        finishProc.command = ["sh", "-c", 'printf "%s\\n" "$1" > "$2"', "--", "CANCEL", fifoPath]
        finishProc.running = false
        finishProc.running = true
        isOpen = false
    }

    function startRegionSelect() {
        isOpen = false
        regionProc.command = ["sh", "-c", "slurp -f '%o %x %y %w %h'"]
        regionProc.running = false
        regionProc.running = true
    }

    function getAppIcon(appClass) {
        let cls = (appClass || "").toLowerCase()
        if (cls.indexOf("vesktop") !== -1 || cls.indexOf("discord") !== -1) return "\uf392"
        if (cls.indexOf("brave") !== -1 || cls.indexOf("chrome") !== -1 || cls.indexOf("firefox") !== -1) return "\uf268"
        if (cls.indexOf("ghostty") !== -1 || cls.indexOf("kitty") !== -1 || cls.indexOf("alacritty") !== -1 || cls.indexOf("term") !== -1) return "\uf120"
        if (cls.indexOf("code") !== -1 || cls.indexOf("vim") !== -1 || cls.indexOf("nvim") !== -1 || cls.indexOf("micro") !== -1) return "\uf121"
        if (cls.indexOf("steam") !== -1) return "\uf1b6"
        if (cls.indexOf("spotify") !== -1 || cls.indexOf("music") !== -1) return "\uf001"
        if (cls.indexOf("nautilus") !== -1 || cls.indexOf("thunar") !== -1 || cls.indexOf("file") !== -1) return "\uf07b"
        if (cls.indexOf("obs") !== -1 || cls.indexOf("video") !== -1) return "\uf03d"
        return "\uf2d0" // window-maximize
    }

    // ─── IPC Target ───
    IpcHandler {
        target: "screenshare"
        function open(fifo: string, rawWindows: string) {
            sharePickerWindow.openPicker(fifo, rawWindows)
        }
        function setTab(tab: string) {
            sharePickerWindow.activeTab = tab
        }
        function select(type: string, val: string) {
            sharePickerWindow.submitSelection(type, val)
        }
        function close() {
            sharePickerWindow.cancelSelection()
        }
    }

    // ─── Backdrop (Clicking outside cancels) ───
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.65)

        MouseArea {
            anchors.fill: parent
            onClicked: sharePickerWindow.cancelSelection()
        }
    }

    // ─── Modal Dialog Card ───
    Rectangle {
        id: pickerCard
        anchors.centerIn: parent
        width: 600
        height: 520
        radius: 24
        color: sharePickerWindow.bgColor
        border.width: 1
        border.color: sharePickerWindow.borderColor
        clip: true

        // Trap clicks inside card so they don't hit the backdrop
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: (mouse) => { mouse.accepted = true }
        }

        // Keyboard handler
        Item {
            focus: sharePickerWindow.isOpen
            Keys.onEscapePressed: sharePickerWindow.cancelSelection()
            Keys.onLeftPressed: {
                if (sharePickerWindow.activeTab === "region") sharePickerWindow.activeTab = "windows"
                else if (sharePickerWindow.activeTab === "windows") sharePickerWindow.activeTab = "screens"
            }
            Keys.onRightPressed: {
                if (sharePickerWindow.activeTab === "screens") sharePickerWindow.activeTab = "windows"
                else if (sharePickerWindow.activeTab === "windows") sharePickerWindow.activeTab = "region"
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 22
            }
            spacing: 16

            // ── 1. Header (Icon, Title, Subtitle, Close Button) ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 38
                    height: 38
                    radius: 19
                    color: sharePickerWindow.bgColor2

                    Text {
                        anchors.centerIn: parent
                        text: "\uf03d" // video
                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 16 }
                        color: sharePickerWindow.accentColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Share Your Screen"
                        font { family: "Inter"; pixelSize: 15; weight: Font.Bold }
                        color: "#FFFFFF"
                    }

                    Text {
                        text: "Select a display, application window, or region"
                        font { family: "Inter"; pixelSize: 11 }
                        color: sharePickerWindow.fgMuted
                    }
                }

                // Close Button
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: closeArea.containsMouse ? Qt.lighter(sharePickerWindow.bgColor2, 1.4) : sharePickerWindow.bgColor2

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d" // times
                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                        color: closeArea.containsMouse ? "#FFFFFF" : sharePickerWindow.fgMuted
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sharePickerWindow.cancelSelection()
                    }
                }
            }

            // ── 2. 3-Way Segmented Tab Selector ──
            Rectangle {
                id: tabPillContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 22
                color: sharePickerWindow.bgColor2

                // Sliding active indicator
                Rectangle {
                    id: activeTabPill
                    y: 4
                    height: tabPillContainer.height - 8
                    width: tabScreensItem.width > 0 ? tabScreensItem.width : Math.round((tabPillContainer.width - 8) / 3)
                    x: {
                        if (sharePickerWindow.activeTab === "region") return tabRegionItem.x + 4
                        if (sharePickerWindow.activeTab === "windows") return tabWindowsItem.x + 4
                        return tabScreensItem.x + 4
                    }
                    radius: 18
                    color: sharePickerWindow.accentColor
                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 0

                    // Screens Tab
                    Item {
                        id: tabScreensItem
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "\uf108" // desktop
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                                color: sharePickerWindow.activeTab === "screens" ? sharePickerWindow.bgColor : (screensTabMouse.containsMouse ? "#FFFFFF" : sharePickerWindow.fgMuted)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Displays"
                                font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                color: sharePickerWindow.activeTab === "screens" ? sharePickerWindow.bgColor : (screensTabMouse.containsMouse ? "#FFFFFF" : sharePickerWindow.fgMuted)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: screensTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sharePickerWindow.activeTab = "screens"
                        }
                    }

                    // Windows Tab
                    Item {
                        id: tabWindowsItem
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "\uf2d0" // window-maximize
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                                color: sharePickerWindow.activeTab === "windows" ? sharePickerWindow.bgColor : (windowsTabMouse.containsMouse ? "#FFFFFF" : sharePickerWindow.fgMuted)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: `Windows (${sharePickerWindow.windowsList.length})`
                                font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                color: sharePickerWindow.activeTab === "windows" ? sharePickerWindow.bgColor : (windowsTabMouse.containsMouse ? "#FFFFFF" : sharePickerWindow.fgMuted)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: windowsTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sharePickerWindow.activeTab = "windows"
                        }
                    }

                    // Region Tab
                    Item {
                        id: tabRegionItem
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "\uf05b" // crosshairs
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                                color: sharePickerWindow.activeTab === "region" ? sharePickerWindow.bgColor : (regionTabMouse.containsMouse ? "#FFFFFF" : sharePickerWindow.fgMuted)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Region"
                                font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                color: sharePickerWindow.activeTab === "region" ? sharePickerWindow.bgColor : (regionTabMouse.containsMouse ? "#FFFFFF" : sharePickerWindow.fgMuted)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: regionTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sharePickerWindow.activeTab = "region"
                        }
                    }
                }
            }

            // ── 3. Main Content Views (StackLayout) ──
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: sharePickerWindow.activeTab === "screens" ? 0 : (sharePickerWindow.activeTab === "windows" ? 1 : 2)

                // ── View 0: Screens View ──
                Item {
                    ScrollView {
                        anchors.fill: parent
                        clip: true
                        contentWidth: availableWidth

                        ColumnLayout {
                            width: parent.width
                            spacing: 10

                            Repeater {
                                model: sharePickerWindow.screensList

                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 74
                                    radius: 16
                                    color: screenMouse.containsMouse ? Qt.lighter(sharePickerWindow.bgColor2, 1.25) : sharePickerWindow.bgColor2
                                    border.width: 1
                                    border.color: screenMouse.containsMouse ? sharePickerWindow.accentColor : "transparent"

                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Behavior on border.color { ColorAnimation { duration: 120 } }

                                    RowLayout {
                                        anchors {
                                            fill: parent
                                            leftMargin: 16
                                            rightMargin: 16
                                        }
                                        spacing: 14

                                        Rectangle {
                                            width: 44
                                            height: 44
                                            radius: 12
                                            color: sharePickerWindow.bgColor3

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf108" // desktop
                                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 18 }
                                                color: sharePickerWindow.accentColor
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3

                                            RowLayout {
                                                spacing: 8
                                                Text {
                                                    text: modelData.name
                                                    font { family: "Inter"; pixelSize: 14; weight: Font.Bold }
                                                    color: "#FFFFFF"
                                                }

                                                Rectangle {
                                                    visible: modelData.isPrimary
                                                    implicitWidth: primaryTxt.implicitWidth + 10
                                                    implicitHeight: 18
                                                    radius: 9
                                                    color: Qt.rgba(0.54, 0.71, 0.98, 0.2)

                                                    Text {
                                                        id: primaryTxt
                                                        anchors.centerIn: parent
                                                        text: "Primary"
                                                        font { family: "Inter"; pixelSize: 10; weight: Font.Bold }
                                                        color: sharePickerWindow.accentColor
                                                    }
                                                }
                                            }

                                            Text {
                                                text: `${modelData.width} × ${modelData.height} @ ${modelData.refreshRate}Hz • Full Screen`
                                                font { family: "Inter"; pixelSize: 11 }
                                                color: sharePickerWindow.fgMuted
                                            }
                                        }

                                        // Share Pill Button
                                        Rectangle {
                                            implicitWidth: 70
                                            implicitHeight: 32
                                            radius: 16
                                            color: screenMouse.containsMouse ? sharePickerWindow.accentColor : sharePickerWindow.bgColor3

                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Share"
                                                font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                                color: screenMouse.containsMouse ? sharePickerWindow.bgColor : sharePickerWindow.fgColor
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: screenMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: sharePickerWindow.submitSelection("screen", modelData.name)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── View 1: Windows View ──
                Item {
                    ScrollView {
                        anchors.fill: parent
                        clip: true
                        contentWidth: availableWidth

                        ColumnLayout {
                            width: parent.width
                            spacing: 8

                            Text {
                                visible: sharePickerWindow.windowsList.length === 0
                                text: "No active application windows found"
                                font { family: "Inter"; pixelSize: 12 }
                                color: sharePickerWindow.fgMuted
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 40
                            }

                            Repeater {
                                model: sharePickerWindow.windowsList

                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 64
                                    radius: 16
                                    color: winMouse.containsMouse ? Qt.lighter(sharePickerWindow.bgColor2, 1.25) : sharePickerWindow.bgColor2
                                    border.width: 1
                                    border.color: winMouse.containsMouse ? sharePickerWindow.accentColor : "transparent"

                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Behavior on border.color { ColorAnimation { duration: 120 } }

                                    RowLayout {
                                        anchors {
                                            fill: parent
                                            leftMargin: 14
                                            rightMargin: 14
                                        }
                                        spacing: 12

                                        Rectangle {
                                            width: 38
                                            height: 38
                                            radius: 10
                                            color: sharePickerWindow.bgColor3

                                            Text {
                                                anchors.centerIn: parent
                                                text: sharePickerWindow.getAppIcon(modelData.appClass)
                                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 16 }
                                                color: sharePickerWindow.accentColor
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            RowLayout {
                                                spacing: 6
                                                Text {
                                                    text: (modelData.appClass || "App").toUpperCase()
                                                    font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                                    color: "#FFFFFF"
                                                }

                                                Text {
                                                    visible: modelData.workspace !== ""
                                                    text: `[WS ${modelData.workspace}]`
                                                    font { family: "Inter"; pixelSize: 10 }
                                                    color: sharePickerWindow.fgMuted
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.title || "Window"
                                                font { family: "Inter"; pixelSize: 11 }
                                                color: sharePickerWindow.fgMuted
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // Share Pill Button
                                        Rectangle {
                                            implicitWidth: 64
                                            implicitHeight: 30
                                            radius: 15
                                            color: winMouse.containsMouse ? sharePickerWindow.accentColor : sharePickerWindow.bgColor3

                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Share"
                                                font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                                color: winMouse.containsMouse ? sharePickerWindow.bgColor : sharePickerWindow.fgColor
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: winMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: sharePickerWindow.submitSelection("window", modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── View 2: Region View ──
                Item {
                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: sharePickerWindow.bgColor2

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 14

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 56
                                height: 56
                                radius: 28
                                color: sharePickerWindow.bgColor3

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf05b" // crosshairs
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 22 }
                                    color: sharePickerWindow.accentColor
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Select Custom Screen Region"
                                font { family: "Inter"; pixelSize: 15; weight: Font.Bold }
                                color: "#FFFFFF"
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Drag a box on your display to share only a selected portion"
                                font { family: "Inter"; pixelSize: 12 }
                                color: sharePickerWindow.fgMuted
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 160
                                Layout.preferredHeight: 38
                                radius: 19
                                color: regionBtnMouse.containsMouse ? sharePickerWindow.accentColorHover : sharePickerWindow.accentColor

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text {
                                        text: "\uf047" // arrows-alt
                                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                                        color: sharePickerWindow.bgColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "Draw Area"
                                        font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                        color: sharePickerWindow.bgColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: regionBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: sharePickerWindow.startRegionSelect()
                                }
                            }
                        }
                    }
                }
            }

            // ── 4. Footer (Remember Choice & Cancel Button) ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // "Remember Selection" Checkbox
                Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 5
                        color: sharePickerWindow.allowToken ? sharePickerWindow.accentColor : sharePickerWindow.bgColor2
                        border.width: 1
                        border.color: sharePickerWindow.allowToken ? sharePickerWindow.accentColor : sharePickerWindow.borderColor

                        Text {
                            anchors.centerIn: parent
                            visible: sharePickerWindow.allowToken
                            text: "\uf00c" // check
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 10 }
                            color: sharePickerWindow.bgColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sharePickerWindow.allowToken = !sharePickerWindow.allowToken
                        }
                    }

                    Text {
                        text: "Remember selection for this app"
                        font { family: "Inter"; pixelSize: 11 }
                        color: sharePickerWindow.fgMuted
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sharePickerWindow.allowToken = !sharePickerWindow.allowToken
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Cancel Button
                Rectangle {
                    implicitWidth: 80
                    implicitHeight: 34
                    radius: 17
                    color: cancelMouse.containsMouse ? Qt.lighter(sharePickerWindow.bgColor2, 1.4) : sharePickerWindow.bgColor2

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                        color: sharePickerWindow.fgColor
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sharePickerWindow.cancelSelection()
                    }
                }
            }
        }
    }
}
