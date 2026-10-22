import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: toastWindow

    property color bgColor: "#121213"
    property color bgColor2: "#1E1E1E"
    property color fgColor: "#CDD6F4"
    property color accentColor: "#89B4FA"
    property color accentColorGlow: "#B4BEFE"
    property string mainFont: "Rowdies"
    property string iconFont: "JetBrainsMono NF"

    signal openPanelRequested()

    anchors {
        top: true
    }
    margins {
        top: 0
    }

    implicitWidth: 440
    implicitHeight: Math.max(1, toastColumn.implicitHeight + 20)
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay

    property var activeToasts: []

    function showToast(notif) {
        let toastObj = {
            id: notif.id,
            appName: notif.appName || "Notification",
            appIcon: notif.appIcon || "",
            summary: notif.summary || "",
            body: notif.body || "",
            image: notif.image || "",
            actions: notif.actions || [],
            timeStr: notif.timeStr || "Just now",
            ref: notif.ref
        }

        // Keep maximum of 3 concurrent toasts on screen
        let copy = activeToasts.slice(0, 2)
        copy.unshift(toastObj)
        activeToasts = copy
    }

    function removeToast(id) {
        let copy = []
        for (let i = 0; i < activeToasts.length; i++) {
            if (activeToasts[i].id !== id) {
                copy.push(activeToasts[i])
            }
        }
        activeToasts = copy
    }

    visible: activeToasts.length > 0

    Column {
        id: toastColumn
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 432
        spacing: 10

        Repeater {
            model: toastWindow.activeToasts

            delegate: Item {
                id: toastDelegate
                property var toastData: modelData
                width: 432
                height: toastCard.height

                // Dropdown animation
                y: -toastCard.height
                opacity: 0.0

                Component.onCompleted: {
                    appearAnim.start()
                }

                ParallelAnimation {
                    id: appearAnim
                    NumberAnimation { target: toastDelegate; property: "opacity"; to: 1.0; duration: 200 }
                    NumberAnimation { target: toastDelegate; property: "y"; from: -toastCard.height; to: 0; duration: 280; easing.type: Easing.OutCubic }
                }

                ParallelAnimation {
                    id: exitAnim
                    NumberAnimation { target: toastDelegate; property: "opacity"; to: 0.0; duration: 180 }
                    NumberAnimation { target: toastDelegate; property: "y"; to: -toastCard.height; duration: 200; easing.type: Easing.InCubic }
                    onFinished: {
                        toastWindow.removeToast(toastDelegate.toastData.id)
                    }
                }

                function dismiss() {
                    if (!exitAnim.running) {
                        exitAnim.restart()
                    }
                }

                // Left curved fillet joining the card smoothly into the top bar
                Shape {
                    width: 16
                    height: 16
                    transform: Scale { origin.y: 8; yScale: -1 }
                    anchors {
                        right: toastCard.left
                        top: toastCard.top
                    }
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: 0
                        fillColor: toastWindow.bgColor
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
                        left: toastCard.right
                        top: toastCard.top
                    }
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: 0
                        fillColor: toastWindow.bgColor
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

                Rectangle {
                    id: toastCard
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 400
                    height: cardLayout.implicitHeight + 24
                    color: toastWindow.bgColor
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: 18
                    bottomRightRadius: 18
                    border.width: 0
                    border.color: "transparent"

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#000000"
                        shadowOpacity: 0.65
                        shadowBlur: 0.6
                        shadowVerticalOffset: 4
                    }

                    // Cover the top border line so the card seamlessly merges into the top bar
                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                        }
                        height: 2
                        color: toastWindow.bgColor
                    }

                    // Auto dismiss timer (5 seconds), pauses on mouse hover
                    Timer {
                        id: dismissTimer
                        interval: 5000
                        running: !cardMouseArea.containsMouse
                        onTriggered: toastDelegate.dismiss()
                    }

                    // Progress bar indicator along the bottom
                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            leftMargin: 16
                            rightMargin: 16
                            bottomMargin: 4
                        }
                        height: 2
                        color: Qt.rgba(1, 1, 1, 0.08)
                        radius: 1

                        Rectangle {
                            id: progressFill
                            height: parent.height
                            radius: 1
                            color: toastWindow.accentColor
                            width: parent.width

                            NumberAnimation on width {
                                from: progressFill.parent.width
                                to: 0
                                duration: 5000
                                running: dismissTimer.running
                            }
                        }
                    }

                    MouseArea {
                        id: cardMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            toastWindow.openPanelRequested()
                            toastDelegate.dismiss()
                        }
                    }

                    ColumnLayout {
                        id: cardLayout
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 14
                            rightMargin: 14
                            topMargin: 12
                        }
                        spacing: 6

                        // ─── Header: App Icon, App Name, Time, Close ────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // App Icon
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 6
                                color: toastWindow.bgColor2
                                clip: true

                                Image {
                                    id: appIconImg
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: modelData.appIcon ? modelData.appIcon : ""
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready && source !== ""
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !appIconImg.visible
                                    text: "\uf0f3" // bell
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                    color: toastWindow.accentColor
                                }
                            }

                            // App Name
                            Text {
                                text: modelData.appName
                                font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                color: toastWindow.accentColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Timestamp
                            Text {
                                text: modelData.timeStr
                                font { family: "Inter"; pixelSize: 10 }
                                color: "#71717A"
                            }

                            // Close Button
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: closeMouseArea.containsMouse ? Qt.lighter(toastWindow.bgColor2, 1.5) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf00d" // times
                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 10 }
                                    color: closeMouseArea.containsMouse ? "#FFFFFF" : toastWindow.fgColor
                                }

                                MouseArea {
                                    id: closeMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: toastDelegate.dismiss()
                                }
                            }
                        }

                        // ─── Summary / Title ─────────────────────────
                        Text {
                            Layout.fillWidth: true
                            text: modelData.summary
                            font { family: "Inter"; pixelSize: 13; weight: Font.Bold }
                            color: "#FFFFFF"
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        // ─── Body Text ───────────────────────────────
                        Text {
                            Layout.fillWidth: true
                            visible: modelData.body !== ""
                            text: modelData.body
                            font { family: "Inter"; pixelSize: 12 }
                            color: toastWindow.fgColor
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        // ─── Attached Image Preview (if present) ─────
                        Image {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            visible: modelData.image !== "" && status === Image.Ready
                            source: modelData.image
                            fillMode: Image.PreserveAspectCrop
                            clip: true
                        }

                        // ─── Action Buttons ──────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: modelData.actions && modelData.actions.length > 0

                            Repeater {
                                model: modelData.actions

                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 26
                                    radius: 13
                                    color: toastWindow.bgColor2
                                    border.color: "#2C2C30"
                                    border.width: 0 

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.text
                                        font { family: "Inter"; pixelSize: 11; weight: Font.DemiBold }
                                        color: actionArea.containsMouse ? "#FFFFFF" : toastWindow.fgColor
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: actionArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            modelData.invoke()
                                            toastDelegate.dismiss()
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
