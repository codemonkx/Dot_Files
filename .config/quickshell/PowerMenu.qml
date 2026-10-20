import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

PanelWindow {
    id: powerMenuWindow

    property bool isOpen: false
    signal closeRequested()
    signal openRequested()

    function toggle() {
        if (isOpen) closeRequested()
        else openRequested()
    }

    function open() {
        openRequested()
    }

    function close() {
        closeRequested()
    }

    // Theme properties matching the top bar & shell
    property color bgColor: "#121213"
    property color bgColor2: "#1E1E1E"
    property color bgColor3: "#262626"
    property color fgColor: "#CDD6F4"
    property color accentColor: "#89B4FA"
    property color accentColorGlow: "#B4BEFE"
    property color dangerColor: "#F38BA8"
    property string mainFont: "Rowdies"
    property string iconFont: "JetBrainsMono NF"
    property int barHeight: 40

    // ─── Global Shortcut & IPC Handler ────────────────────────
    GlobalShortcut {
        name: "powermenu"
        description: "Toggle Quickshell Power Menu"
        onPressed: powerMenuWindow.toggle()
    }

    IpcHandler {
        target: "power"
        function toggle() {
            powerMenuWindow.toggle()
        }
        function open() {
            powerMenuWindow.open()
        }
        function close() {
            powerMenuWindow.close()
        }
    }

    // ─── System Uptime & User Info ────────────────────────────
    property string uptimeStr: ""
    property string userName: "madara"
    property string confirmTarget: "" // "shutdown", "reboot", "logout"

    Process {
        id: userProc
        command: ["whoami"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let u = text.trim()
                if (u.length > 0) powerMenuWindow.userName = u
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim()
                if (txt.startsWith("up ")) {
                    txt = txt.substring(3)
                }
                powerMenuWindow.uptimeStr = txt
            }
        }
    }

    Timer {
        id: confirmResetTimer
        interval: 3500
        onTriggered: powerMenuWindow.confirmTarget = ""
    }

    function handleAction(type) {
        if (type === "lock") {
            closeRequested()
            Quickshell.execDetached(["hyprlock"])
        } else if (type === "suspend") {
            closeRequested()
            Quickshell.execDetached(["systemctl", "suspend"])
        } else if (type === "logout") {
            if (confirmTarget === "logout") {
                confirmTarget = ""
                closeRequested()
                Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
            } else {
                confirmTarget = "logout"
                confirmResetTimer.restart()
            }
        } else if (type === "reboot") {
            if (confirmTarget === "reboot") {
                confirmTarget = ""
                closeRequested()
                Quickshell.execDetached(["systemctl", "reboot"])
            } else {
                confirmTarget = "reboot"
                confirmResetTimer.restart()
            }
        } else if (type === "shutdown") {
            if (confirmTarget === "shutdown") {
                confirmTarget = ""
                closeRequested()
                Quickshell.execDetached(["systemctl", "poweroff"])
            } else {
                confirmTarget = "shutdown"
                confirmResetTimer.restart()
            }
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            confirmTarget = ""
            uptimeProc.running = false
            uptimeProc.running = true
            dropUpAnim.stop()
            panelRootItem.opacity = 1.0
            dropDownAnim.restart()
        } else {
            confirmTarget = ""
            dropDownAnim.stop()
            dropUpAnim.restart()
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

    visible: isOpen || dropDownAnim.running || dropUpAnim.running

    // Dismiss on click outside
    MouseArea {
        id: backdrop
        anchors.fill: parent
        hoverEnabled: false
        onClicked: powerMenuWindow.closeRequested()
    }

    // Escape key handling
    Item {
        focus: powerMenuWindow.isOpen
        Keys.onEscapePressed: powerMenuWindow.closeRequested()
    }

    // ─── THE PANEL ROOT ITEM ──────────────────────────────────
    Item {
        id: panelRootItem
        width: cardContainer.width
        height: cardContainer.height

        // Horizontally centered across the top bar
        x: Math.round((parent.width - width) / 2)

        // Attached directly to the bottom edge of the top bar
        y: -cardContainer.height
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

            ShapePath {
                strokeWidth: 0
                fillColor: powerMenuWindow.bgColor
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

            ShapePath {
                strokeWidth: 0
                fillColor: powerMenuWindow.bgColor
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
        }

        // ─── CARD CONTAINER ───────────────────────────────────
        Rectangle {
            id: cardContainer
            width: 480
            height: 168
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 24
            bottomRightRadius: 24
            color: powerMenuWindow.bgColor
            border.width: 0
            clip: true

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.65
                shadowBlur: 0.6
                shadowVerticalOffset: 4
            }

            // Cover the top line so the card seamlessly merges into the top bar
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: 2
                color: powerMenuWindow.bgColor
            }

            // Absorbs clicks on the card itself
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: mainLayout
                anchors {
                    fill: parent
                    topMargin: 16
                    bottomMargin: 16
                    leftMargin: 18
                    rightMargin: 18
                }
                spacing: 14

                // ─── 1. Header Row (User, Uptime, Close) ───────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    // User Badge
                    Rectangle {
                        implicitWidth: userRow.implicitWidth + 20
                        implicitHeight: 28
                        radius: 14
                        color: powerMenuWindow.bgColor2

                        Row {
                            id: userRow
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "\uf007" // user
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                color: powerMenuWindow.accentColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: powerMenuWindow.userName
                                font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                color: "#FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Uptime Badge
                    Rectangle {
                        implicitWidth: uptimeRow.implicitWidth + 20
                        implicitHeight: 28
                        radius: 14
                        color: powerMenuWindow.bgColor2
                        visible: powerMenuWindow.uptimeStr !== ""

                        Row {
                            id: uptimeRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "\uf017" // clock
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                color: powerMenuWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: powerMenuWindow.uptimeStr
                                font { family: "Inter"; pixelSize: 11; weight: Font.Medium }
                                color: powerMenuWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, 220)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Close Button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: closeArea.containsMouse ? Qt.lighter(powerMenuWindow.bgColor2, 1.4) : powerMenuWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d" // times
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                            color: closeArea.containsMouse ? "#FFFFFF" : powerMenuWindow.fgColor
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: powerMenuWindow.closeRequested()
                        }
                    }
                }

                // ─── 2. Action Buttons Row (5 Buttons) ─────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Repeater {
                        model: [
                            { id: "lock",     label: "Lock",     icon: "\uf023", sub: "hyprlock", danger: false },
                            { id: "suspend",  label: "Sleep",    icon: "\uf186", sub: "suspend",  danger: false },
                            { id: "logout",   label: "Logout",   icon: "\uf2f5", sub: "exit",     danger: false },
                            { id: "reboot",   label: "Reboot",   icon: "\uf021", sub: "restart",  danger: false },
                            { id: "shutdown", label: "Shutdown", icon: "\uf011", sub: "poweroff", danger: true }
                        ]

                        delegate: Rectangle {
                            id: actionBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 82
                            radius: 16

                            readonly property bool isConfirming: powerMenuWindow.confirmTarget === modelData.id
                            readonly property bool isHovered: btnMouse.containsMouse

                            color: {
                                if (isConfirming) return Qt.rgba(1, 0.43, 0.43, 0.22)
                                if (isHovered) return Qt.lighter(powerMenuWindow.bgColor2, 1.35)
                                return powerMenuWindow.bgColor2
                            }

                            border.width: (isConfirming || isHovered) ? 1 : 0
                            border.color: {
                                if (isConfirming) return powerMenuWindow.dangerColor
                                if (isHovered) return (modelData.danger ? powerMenuWindow.dangerColor : powerMenuWindow.accentColor)
                                return "transparent"
                            }

                            scale: btnMouse.pressed ? 0.96 : (isHovered ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                // Action Icon
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 20 }
                                    color: {
                                        if (actionBtn.isConfirming) return powerMenuWindow.dangerColor
                                        if (actionBtn.isHovered) return (modelData.danger ? powerMenuWindow.dangerColor : powerMenuWindow.accentColor)
                                        return (modelData.danger ? Qt.lighter(powerMenuWindow.fgColor, 1.1) : powerMenuWindow.fgColor)
                                    }
                                }

                                // Main Label
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: actionBtn.isConfirming ? "Confirm?" : modelData.label
                                    font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                    color: {
                                        if (actionBtn.isConfirming) return powerMenuWindow.dangerColor
                                        if (actionBtn.isHovered) return "#FFFFFF"
                                        return powerMenuWindow.fgColor
                                    }
                                }

                                // Subtext
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: actionBtn.isConfirming ? "click again" : modelData.sub
                                    font { family: "Inter"; pixelSize: 9; weight: Font.Medium }
                                    color: actionBtn.isConfirming ? powerMenuWindow.dangerColor : Qt.rgba(1, 1, 1, 0.3)
                                }
                            }

                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: powerMenuWindow.handleAction(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
