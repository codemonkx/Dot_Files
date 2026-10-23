import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

PanelWindow {
    id: screenshotWindow

    property bool isOpen: false
    property string activeMode: "selection" // "selection", "screen", "window"
    property bool includeCursor: false
    property int delaySeconds: 0 // 0, 3, 5
    property int countdownValue: 0
    property bool isCountingDown: false

    // Catppuccin Sapphire Theme Colors
    property color bgColor: "#121213"
    property color bgColor2: "#181825"
    property color bgColor3: "#1E1E2E"
    property color cardBg: "#1E1E28"
    property color fgColor: "#CDD6F4"
    property color fgMuted: "#A6ADC8"
    property color fgSubtle: "#6C7086"
    property color accentColor: "#89B4FA"
    property color accentGlow: "#B4BEFE"
    property color borderColor: "#313244"

    property string mainFont: "Rowdies"
    property string textFont: "Inter"
    property string iconFont: "JetBrainsMono NF"

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

    visible: isOpen || pillSlideAnim.running || flashRect.opacity > 0.001 || countdownOverlay.opacity > 0.001

    // ─── Public Methods ─────────────────────────────────────────
    function open() {
        isCountingDown = false
        countdownValue = 0
        isOpen = true
        keyHandler.forceActiveFocus()
    }

    function close() {
        countdownTimer.stop()
        isCountingDown = false
        countdownValue = 0
        isOpen = false
    }

    function toggle() {
        if (isOpen) close()
        else open()
    }

    function triggerFlash() {
        flashAnim.restart()
    }

    function startCapture() {
        if (delaySeconds > 0) {
            isCountingDown = true
            countdownValue = delaySeconds
            countdownTimer.restart()
        } else {
            executeCapture()
        }
    }

    function executeCapture() {
        countdownTimer.stop()
        isCountingDown = false
        isOpen = false
        delayedLaunchTimer.restart()
    }

    // Delay 90ms to give layer-shell unmap time so overlay isn't captured
    Timer {
        id: delayedLaunchTimer
        interval: 90
        repeat: false
        onTriggered: {
            captureProc.command = [
                "/home/madara/.config/hypr/screenshot.sh",
                screenshotWindow.activeMode,
                screenshotWindow.includeCursor ? "1" : "0",
                "0"
            ]
            captureProc.running = false
            captureProc.running = true
        }
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            countdownValue--
            if (countdownValue <= 0) {
                countdownTimer.stop()
                executeCapture()
            }
        }
    }

    Process {
        id: captureProc
        running: false
    }

    // ─── Global Shortcut & IPC Handler ──────────────────────────
    GlobalShortcut {
        name: "screenshot"
        description: "Toggle GNOME-style Screenshot Overlay"
        onPressed: screenshotWindow.toggle()
    }

    IpcHandler {
        target: "screenshot"
        function toggle() {
            screenshotWindow.toggle()
        }
        function open() {
            screenshotWindow.open()
        }
        function close() {
            screenshotWindow.close()
        }
        function flash() {
            screenshotWindow.triggerFlash()
        }
        function setMode(mode: string) {
            if (mode === "selection" || mode === "screen" || mode === "window") {
                screenshotWindow.activeMode = mode
            }
        }
        function capture(mode: string, cursor: bool) {
            if (mode) screenshotWindow.activeMode = mode
            if (cursor !== undefined) screenshotWindow.includeCursor = cursor
            screenshotWindow.executeCapture()
        }
    }

    // ─── Keyboard Navigation ────────────────────────────────────
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: screenshotWindow.isOpen

        Keys.onEscapePressed: screenshotWindow.close()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_1 || event.key === Qt.Key_S) {
                screenshotWindow.activeMode = "selection"
                event.accepted = true
            } else if (event.key === Qt.Key_2 || event.key === Qt.Key_C) {
                screenshotWindow.activeMode = "screen"
                event.accepted = true
            } else if (event.key === Qt.Key_3 || event.key === Qt.Key_W) {
                screenshotWindow.activeMode = "window"
                event.accepted = true
            } else if (event.key === Qt.Key_P) {
                screenshotWindow.includeCursor = !screenshotWindow.includeCursor
                event.accepted = true
            } else if (event.key === Qt.Key_D) {
                // Cycle delay: 0 -> 3 -> 5 -> 0
                if (screenshotWindow.delaySeconds === 0) screenshotWindow.delaySeconds = 3
                else if (screenshotWindow.delaySeconds === 3) screenshotWindow.delaySeconds = 5
                else screenshotWindow.delaySeconds = 0
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                screenshotWindow.startCapture()
                event.accepted = true
            }
        }
    }

    // ─── Dimmed Backdrop ────────────────────────────────────────
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#000000"
        opacity: screenshotWindow.isOpen ? 0.35 : 0.0
        visible: opacity > 0.001

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: screenshotWindow.close()
        }
    }

    // ─── Countdown Overlay ──────────────────────────────────────
    Rectangle {
        id: countdownOverlay
        anchors.centerIn: parent
        width: 140
        height: 140
        radius: 70
        color: Qt.rgba(0.08, 0.08, 0.12, 0.85)
        border.color: screenshotWindow.accentColor
        border.width: 2
        opacity: screenshotWindow.isCountingDown ? 1.0 : 0.0
        scale: screenshotWindow.isCountingDown ? 1.0 : 0.7
        visible: opacity > 0.001

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
        }

        Text {
            anchors.centerIn: parent
            text: String(screenshotWindow.countdownValue)
            color: screenshotWindow.fgColor
            font {
                family: screenshotWindow.mainFont
                pixelSize: 64
                bold: true
            }
        }
    }

    // ─── Main Toolbar Container ─────────────────────────────────
    Item {
        id: toolbarContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: screenshotWindow.isOpen ? 48 : -100
        opacity: screenshotWindow.isOpen ? 1.0 : 0.0
        width: pillCard.width
        height: pillCard.height + guideBanner.height + 14

        Behavior on anchors.bottomMargin {
            id: pillSlideAnim
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // ─── Guidance Banner ────────────────────────────────────
        Rectangle {
            id: guideBanner
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: guideContent.implicitWidth + 32
            height: 36
            radius: 18
            color: Qt.rgba(0.07, 0.07, 0.10, 0.88)
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1

            RowLayout {
                id: guideContent
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: {
                        if (screenshotWindow.activeMode === "selection") return "Drag a region to capture, or press Enter"
                        if (screenshotWindow.activeMode === "window") return "Hover and click any window to capture"
                        return "Captures the entire active screen display"
                    }
                    color: screenshotWindow.fgColor
                    font {
                        family: screenshotWindow.textFont
                        pixelSize: 12
                        weight: Font.Medium
                    }
                }

                Rectangle {
                    width: 1
                    height: 12
                    color: screenshotWindow.borderColor
                }

                Text {
                    text: "[1] Area  [2] Screen  [3] Window  [Enter] Snap  [Esc] Cancel"
                    color: screenshotWindow.fgSubtle
                    font {
                        family: screenshotWindow.iconFont
                        pixelSize: 11
                    }
                }
            }
        }

        // ─── Floating GNOME-Style Pill ──────────────────────────
        Rectangle {
            id: pillCard
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: pillRow.implicitWidth + 24
            height: 64
            radius: 32
            color: Qt.rgba(0.09, 0.09, 0.14, 0.96)
            border.color: screenshotWindow.borderColor
            border.width: 1

            // Outer subtle glow
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: 33
                color: "transparent"
                border.color: Qt.rgba(0.54, 0.71, 0.98, 0.20)
                border.width: 1
                z: -1
            }

            RowLayout {
                id: pillRow
                anchors.centerIn: parent
                spacing: 8

                // ── Mode Switcher Segment ───────────────────────
                Rectangle {
                    implicitWidth: modeSwitcherRow.implicitWidth + 8
                    implicitHeight: 46
                    radius: 23
                    color: Qt.rgba(0.06, 0.06, 0.09, 0.85)
                    border.color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1

                    RowLayout {
                        id: modeSwitcherRow
                        anchors.centerIn: parent
                        spacing: 4

                        // Selection Mode Button
                        Rectangle {
                            id: btnSelection
                            implicitWidth: selCol.implicitWidth + 24
                            implicitHeight: 38
                            radius: 19
                            color: screenshotWindow.activeMode === "selection" ? screenshotWindow.accentColor : (selMa.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            RowLayout {
                                id: selCol
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "\uf125" // Crop
                                    font {
                                        family: screenshotWindow.iconFont
                                        pixelSize: 15
                                    }
                                    color: screenshotWindow.activeMode === "selection" ? "#11111B" : screenshotWindow.fgColor
                                }

                                Text {
                                    text: "Selection"
                                    font {
                                        family: screenshotWindow.textFont
                                        pixelSize: 13
                                        weight: screenshotWindow.activeMode === "selection" ? Font.Bold : Font.Normal
                                    }
                                    color: screenshotWindow.activeMode === "selection" ? "#11111B" : screenshotWindow.fgColor
                                }
                            }

                            MouseArea {
                                id: selMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: screenshotWindow.activeMode = "selection"
                            }
                        }

                        // Screen Mode Button
                        Rectangle {
                            id: btnScreen
                            implicitWidth: screenCol.implicitWidth + 24
                            implicitHeight: 38
                            radius: 19
                            color: screenshotWindow.activeMode === "screen" ? screenshotWindow.accentColor : (screenMa.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            RowLayout {
                                id: screenCol
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "\uf108" // Desktop
                                    font {
                                        family: screenshotWindow.iconFont
                                        pixelSize: 15
                                    }
                                    color: screenshotWindow.activeMode === "screen" ? "#11111B" : screenshotWindow.fgColor
                                }

                                Text {
                                    text: "Screen"
                                    font {
                                        family: screenshotWindow.textFont
                                        pixelSize: 13
                                        weight: screenshotWindow.activeMode === "screen" ? Font.Bold : Font.Normal
                                    }
                                    color: screenshotWindow.activeMode === "screen" ? "#11111B" : screenshotWindow.fgColor
                                }
                            }

                            MouseArea {
                                id: screenMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: screenshotWindow.activeMode = "screen"
                            }
                        }

                        // Window Mode Button
                        Rectangle {
                            id: btnWindow
                            implicitWidth: winCol.implicitWidth + 24
                            implicitHeight: 38
                            radius: 19
                            color: screenshotWindow.activeMode === "window" ? screenshotWindow.accentColor : (winMa.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            RowLayout {
                                id: winCol
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "\uf2d0" // Window
                                    font {
                                        family: screenshotWindow.iconFont
                                        pixelSize: 15
                                    }
                                    color: screenshotWindow.activeMode === "window" ? "#11111B" : screenshotWindow.fgColor
                                }

                                Text {
                                    text: "Window"
                                    font {
                                        family: screenshotWindow.textFont
                                        pixelSize: 13
                                        weight: screenshotWindow.activeMode === "window" ? Font.Bold : Font.Normal
                                    }
                                    color: screenshotWindow.activeMode === "window" ? "#11111B" : screenshotWindow.fgColor
                                }
                            }

                            MouseArea {
                                id: winMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: screenshotWindow.activeMode = "window"
                            }
                        }
                    }
                }

                // ── Divider 1 ───────────────────────────────────
                Rectangle {
                    implicitWidth: 1
                    implicitHeight: 28
                    color: screenshotWindow.borderColor
                }

                // ── Options: Cursor & Delay ─────────────────────
                RowLayout {
                    spacing: 6

                    // Cursor Toggle
                    Rectangle {
                        implicitWidth: cursorRow.implicitWidth + 18
                        implicitHeight: 38
                        radius: 19
                        color: screenshotWindow.includeCursor ? Qt.rgba(0.54, 0.71, 0.98, 0.22) : (cursorMa.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")
                        border.color: screenshotWindow.includeCursor ? screenshotWindow.accentColor : "transparent"
                        border.width: 1

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        RowLayout {
                            id: cursorRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "\uf245" // Mouse Pointer
                                font {
                                    family: screenshotWindow.iconFont
                                    pixelSize: 14
                                }
                                color: screenshotWindow.includeCursor ? screenshotWindow.accentColor : screenshotWindow.fgMuted
                            }

                            Text {
                                text: "Pointer"
                                font {
                                    family: screenshotWindow.textFont
                                    pixelSize: 12
                                    weight: screenshotWindow.includeCursor ? Font.DemiBold : Font.Normal
                                }
                                color: screenshotWindow.includeCursor ? screenshotWindow.accentColor : screenshotWindow.fgMuted
                            }
                        }

                        MouseArea {
                            id: cursorMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: screenshotWindow.includeCursor = !screenshotWindow.includeCursor
                        }
                    }

                    // Delay Button
                    Rectangle {
                        implicitWidth: delayRow.implicitWidth + 18
                        implicitHeight: 38
                        radius: 19
                        color: screenshotWindow.delaySeconds > 0 ? Qt.rgba(0.54, 0.71, 0.98, 0.22) : (delayMa.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")
                        border.color: screenshotWindow.delaySeconds > 0 ? screenshotWindow.accentColor : "transparent"
                        border.width: 1

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        RowLayout {
                            id: delayRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "\uf017" // Clock
                                font {
                                    family: screenshotWindow.iconFont
                                    pixelSize: 13
                                }
                                color: screenshotWindow.delaySeconds > 0 ? screenshotWindow.accentColor : screenshotWindow.fgMuted
                            }

                            Text {
                                text: screenshotWindow.delaySeconds === 0 ? "Timer Off" : (screenshotWindow.delaySeconds + "s Delay")
                                font {
                                    family: screenshotWindow.textFont
                                    pixelSize: 12
                                    weight: screenshotWindow.delaySeconds > 0 ? Font.DemiBold : Font.Normal
                                }
                                color: screenshotWindow.delaySeconds > 0 ? screenshotWindow.accentColor : screenshotWindow.fgMuted
                            }
                        }

                        MouseArea {
                            id: delayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (screenshotWindow.delaySeconds === 0) screenshotWindow.delaySeconds = 3
                                else if (screenshotWindow.delaySeconds === 3) screenshotWindow.delaySeconds = 5
                                else screenshotWindow.delaySeconds = 0
                            }
                        }
                    }
                }

                // ── Divider 2 ───────────────────────────────────
                Rectangle {
                    implicitWidth: 1
                    implicitHeight: 28
                    color: screenshotWindow.borderColor
                }

                // ── Big Circular Shutter Button ─────────────────
                Rectangle {
                    id: shutterBtn
                    implicitWidth: 46
                    implicitHeight: 46
                    radius: 23
                    color: shutterMa.pressed ? "#6FA0F5" : (shutterMa.containsMouse ? "#A6C8FF" : "#FFFFFF")
                    scale: shutterMa.pressed ? 0.92 : (shutterMa.containsMouse ? 1.08 : 1.0)

                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    // Inner Shutter Ring / Camera Glyph
                    Rectangle {
                        anchors.centerIn: parent
                        width: 38
                        height: 38
                        radius: 19
                        color: "transparent"
                        border.color: "#181825"
                        border.width: 2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf030" // Camera
                            font {
                                family: screenshotWindow.iconFont
                                pixelSize: 18
                            }
                            color: "#181825"
                        }
                    }

                    MouseArea {
                        id: shutterMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: screenshotWindow.startCapture()
                    }
                }

                // ── Close / Dismiss Button ──────────────────────
                Rectangle {
                    id: closeBtn
                    implicitWidth: 38
                    implicitHeight: 38
                    radius: 19
                    color: closeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    scale: closeMa.pressed ? 0.92 : (closeMa.containsMouse ? 1.05 : 1.0)

                    Behavior on scale {
                        NumberAnimation { duration: 150 }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d" // Times / Close
                        font {
                            family: screenshotWindow.iconFont
                            pixelSize: 15
                        }
                        color: screenshotWindow.fgMuted
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: screenshotWindow.close()
                    }
                }
            }
        }
    }

    // ─── Camera Flash Effect Overlay ────────────────────────────
    Rectangle {
        id: flashRect
        anchors.fill: parent
        color: "#FFFFFF"
        opacity: 0.0
        visible: opacity > 0.001

        NumberAnimation {
            id: flashAnim
            target: flashRect
            property: "opacity"
            from: 0.70
            to: 0.0
            duration: 260
            easing.type: Easing.OutQuad
        }
    }
}
