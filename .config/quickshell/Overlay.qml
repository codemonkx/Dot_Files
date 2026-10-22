import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Widgets

Scope {
    id: root

    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ]
    }

    readonly property int cardHeight: 52
    readonly property int cardWidth: 400

    property string osdMode: "volume" // "volume", "brightness", or "mic"
    property real currentBrightness: 0.5
    property color accentColor: "#89B4FA"
    property color fgColor: "#CDD6F4"
    property bool initialized: false
    property bool isPanelOpen: false

    onIsPanelOpenChanged: {
        if (isPanelOpen) {
            root.hideOsd();
        }
    }

    Timer {
        id: startupTimer
        interval: 1500
        running: true
        onTriggered: {
            root.initialized = true;
        }
    }

    Component.onCompleted: {
        brightProc.running = true;
    }

    // Process to query current brightness
    Process {
        id: brightProc
        command: ["sh", "-c", "brightnessctl -m | awk -F, '{print $4}' | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let val = parseInt(text.trim());
                if (!isNaN(val)) {
                    root.currentBrightness = Math.max(0.01, Math.min(1.0, val / 100.0));
                    if (root.initialized) {
                        root.showBrightnessOsd();
                    }
                }
            }
        }
    }

    // IPC handler for brightness / volume / mic triggering
    IpcHandler {
        target: "osd"
        function brightness() {
            brightProc.running = false;
            brightProc.running = true;
        }
        function volume() {
            root.triggerVolumeOsd();
        }
        function mic() {
            root.triggerMicOsd();
        }
    }

    readonly property real currentVol: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio.volume : 0
    readonly property bool currentMuted: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio.muted : false
    readonly property real currentMicVol: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) ? Pipewire.defaultAudioSource.audio.volume : 0
    readonly property bool currentMicMuted: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) ? Pipewire.defaultAudioSource.audio.muted : false

    onCurrentVolChanged: {
        root.triggerVolumeOsd();
    }
    onCurrentMutedChanged: {
        root.triggerVolumeOsd();
    }
    onCurrentMicVolChanged: {
        root.triggerMicOsd();
    }
    onCurrentMicMutedChanged: {
        root.triggerMicOsd();
    }

    Connections {
        target: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio : null
        ignoreUnknownSignals: true
        function onVolumeChanged() {
            root.triggerVolumeOsd();
        }
        function onMutedChanged() {
            root.triggerVolumeOsd();
        }
    }

    Connections {
        target: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) ? Pipewire.defaultAudioSource.audio : null
        ignoreUnknownSignals: true
        function onVolumeChanged() {
            root.triggerMicOsd();
        }
        function onMutedChanged() {
            root.triggerMicOsd();
        }
    }

    function triggerMicOsd() {
        if (!initialized || isPanelOpen) return;
        root.osdMode = "mic";
        showOsdCommon();
    }

    function triggerVolumeOsd() {
        if (!initialized || isPanelOpen) return;
        root.osdMode = "volume";
        showOsdCommon();
    }

    function showBrightnessOsd() {
        if (!initialized || isPanelOpen) return;
        root.osdMode = "brightness";
        showOsdCommon();
    }

    function showOsdCommon() {
        hideTimer.stop();
        if (exitAnim.running) {
            exitAnim.stop();
        }

        osdWindow.visible = true;

        if (osdContainer.y !== 0 || osdContainer.opacity < 1.0) {
            appearAnim.restart();
        }

        hideTimer.restart();
    }

    function hideOsd() {
        if (!osdWindow.visible) return;
        appearAnim.stop();
        exitAnim.restart();
    }

    Timer {
        id: hideTimer
        interval: 1800
        onTriggered: root.hideOsd()
    }

    PanelWindow {
        id: osdWindow
        anchors {
            top: true
        }
        margins {
            top: 0
        }
        exclusiveZone: 0
        implicitWidth: 440
        implicitHeight: 80
        color: "transparent"
        visible: false
        WlrLayershell.layer: WlrLayer.Overlay

        Item {
            id: osdContainer
            anchors.horizontalCenter: parent.horizontalCenter
            width: 432
            height: root.cardHeight + 20

            y: -root.cardHeight - 10
            opacity: 0.0

            ParallelAnimation {
                id: appearAnim
                NumberAnimation {
                    target: osdContainer
                    property: "opacity"
                    to: 1.0
                    duration: 200
                }
                NumberAnimation {
                    target: osdContainer
                    property: "y"
                    to: 0
                    duration: 280
                    easing.type: Easing.OutCubic
                }
            }

            ParallelAnimation {
                id: exitAnim
                NumberAnimation {
                    target: osdContainer
                    property: "opacity"
                    to: 0.0
                    duration: 180
                }
                NumberAnimation {
                    target: osdContainer
                    property: "y"
                    to: -root.cardHeight - 10
                    duration: 200
                    easing.type: Easing.InCubic
                }
                onFinished: {
                    osdWindow.visible = false;
                }
            }

            // Left curved fillet joining the card smoothly into the top bar
            Shape {
                width: 16
                height: 16
                transform: Scale { origin.y: 8; yScale: -1 }
                anchors {
                    right: osdCard.left
                    top: osdCard.top
                }
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: "#121213"
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
                    left: osdCard.right
                    top: osdCard.top
                }
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: "#121213"
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
                id: osdCard
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.cardWidth
                height: root.cardHeight
                color: "#121213"
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

                // Seamless top blend over the top border line
                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    height: 2
                    color: "#121213"
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 20
                        rightMargin: 20
                        topMargin: 2
                    }
                    spacing: 16

                    // Icon (Speaker, Sun, or Mic)
                    Text {
                        id: osdIcon
                        font.family: "JetBrainsMono NF"
                        font.pixelSize: 22
                        color: {
                            if (root.osdMode === "brightness") return root.accentColor;
                            if (root.osdMode === "mic") return (root.currentMicMuted || root.currentMicVol <= 0) ? "#66ffffff" : root.accentColor;
                            return (root.currentMuted || root.currentVol <= 0) ? "#66ffffff" : root.accentColor;
                        }
                        text: {
                            if (root.osdMode === "brightness") {
                                if (root.currentBrightness < 0.33) return "󰃞";
                                if (root.currentBrightness < 0.66) return "󰃟";
                                return "󰃠";
                            }
                            if (root.osdMode === "mic") {
                                if (root.currentMicMuted || root.currentMicVol <= 0) return "󰍭";
                                return "󰍬";
                            }
                            if (root.currentMuted || root.currentVol <= 0) return "󰝟";
                            if (root.currentVol < 0.33) return "󰕿";
                            if (root.currentVol < 0.66) return "󰖀";
                            return "󰕾";
                        }
                    }

                    // Elegant Slider
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: "#2A2A2E"

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            radius: 3
                            color: {
                                if (root.osdMode === "brightness") return root.accentColor;
                                if (root.osdMode === "mic") return root.currentMicMuted ? "#66ffffff" : root.accentColor;
                                return root.currentMuted ? "#66ffffff" : root.accentColor;
                            }
                            width: parent.width * Math.min(1.0, Math.max(0.0, root.osdMode === "brightness" ? root.currentBrightness : (root.osdMode === "mic" ? root.currentMicVol : root.currentVol)))

                            Behavior on width {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }

                            // Clean circular thumb
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.horizontalCenter: parent.right
                                width: 12
                                height: 12
                                radius: 6
                                color: root.accentColor
                                visible: ((root.osdMode === "brightness") || (root.osdMode === "mic" && !root.currentMicMuted) || (root.osdMode === "volume" && !root.currentMuted)) && width > 0
                            }
                        }
                    }

                    // Percentage Text
                    Text {
                        Layout.preferredWidth: 45
                        horizontalAlignment: Text.AlignRight
                        font.family: "Inter"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: {
                            if (root.osdMode === "brightness") return root.fgColor;
                            if (root.osdMode === "mic") return root.currentMicMuted ? "#66ffffff" : root.fgColor;
                            return root.currentMuted ? "#66ffffff" : root.fgColor;
                        }
                        text: {
                            if (root.osdMode === "brightness") {
                                return Math.round(root.currentBrightness * 100) + "%";
                            }
                            if (root.osdMode === "mic") {
                                if (root.currentMicMuted) return "Muted";
                                return Math.round(root.currentMicVol * 100) + "%";
                            }
                            if (root.currentMuted) return "Muted";
                            return Math.round(root.currentVol * 100) + "%";
                        }
                    }
                }
            }
        }
    }
}