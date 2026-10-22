import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

PanelWindow {
    id: popupWindow

    property bool isOpen: false
    signal closeRequested()


    property var player: null

    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    readonly property real systemVolume: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio.volume : 0.5
    readonly property bool isMuted: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio.muted : false

    function setVolume(ratio) {
        let val = Math.max(0.0, Math.min(1.0, ratio));
        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
            Pipewire.defaultAudioSink.audio.volume = val;
            if (val > 0 && Pipewire.defaultAudioSink.audio.muted) {
                Pipewire.defaultAudioSink.audio.muted = false;
            }
        }
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(val * 100) + "%"]);
        if (val > 0) {
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]);
        }
        if (popupWindow.player && popupWindow.player.volumeSupported) {
            try {
                let entry = (popupWindow.player.desktopEntry || "").toLowerCase();
                if (!entry.includes("brave") && !entry.includes("chrome") && !entry.includes("chromium") && !entry.includes("firefox")) {
                    popupWindow.player.volume = val;
                }
            } catch(e) {}
        }
    }

    function toggleMute() {
        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
        }
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
    }

    property color bgColor: "#121213"
    property color bgColor2: "#1E1E1E"
    property color fgColor: "#CDD6F4"
    property color accentColor: "#89B4FA"
    property color accentColorGlow: "#B4BEFE"
    property string mainFont: "Rowdies"
    property string iconFont: "JetBrainsMono NF"
    property int barHeight: 40

    function formatTime(seconds) {
        if (!seconds || isNaN(seconds) || seconds < 0) return "0:00"
        let totalSecs = Math.floor(seconds)
        let mins = Math.floor(totalSecs / 60)
        let secs = totalSecs % 60
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    Timer {
        id: positionTimer
        interval: 250
        running: popupWindow.isOpen && (popupWindow.player?.isPlaying ?? false) && (!seekContainer || !seekContainer.isSeeking)
        repeat: true
        onTriggered: {
            if (popupWindow.player) {
                try {
                    popupWindow.player.positionChanged()
                } catch(e) {}
                if (seekContainer) {
                    seekContainer.currentPosition = popupWindow.player.position
                }
            }
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            dropUpAnim.stop()
            playerRootItem.opacity = 1.0
            dropDownAnim.restart()
            if (player) {
                try { player.positionChanged() } catch(e) {}
                if (seekContainer) seekContainer.currentPosition = player.position
            }
        } else {
            dropDownAnim.stop()
            dropUpAnim.restart()
        }
    }

    onPlayerChanged: {
        if (player) {
            try { player.positionChanged() } catch(e) {}
            if (seekContainer) seekContainer.currentPosition = player.position
        }
    }

    Connections {
        target: popupWindow.player
        ignoreUnknownSignals: true
        function onPositionChanged() {
            if (seekContainer && !seekContainer.isSeeking && popupWindow.player) {
                seekContainer.currentPosition = popupWindow.player.position
            }
        }
        function onTrackChanged() {
            if (seekContainer && popupWindow.player) {
                seekContainer.currentPosition = popupWindow.player.position
            }
        }
        function onIsPlayingChanged() {
            if (seekContainer && popupWindow.player) {
                seekContainer.currentPosition = popupWindow.player.position
            }
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusiveZone: 0
    
    WlrLayershell.layer: WlrLayer.Overlay
    
    // 1. Tell Wayland to route keyboard events to this window ONLY when it is open
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: isOpen || dropDownAnim.running || dropUpAnim.running

    // Dismiss on click outside
    MouseArea {
        id: backdrop
        anchors.fill: parent
        hoverEnabled: false
        onClicked: popupWindow.closeRequested()
    }

    // 2. Catch Escape to close the popup
    Item {
        anchors.fill: parent
        focus: popupWindow.isOpen

        Keys.onEscapePressed: popupWindow.closeRequested()
    }

    // ─── THE PLAYER WRAPPER ──────
    Item {
        id: playerRootItem
        width: cardContainer.width
        height: cardContainer.height

        x: Math.round((parent.width - width) / 2)

        // Attached directly to the bottom edge of the top bar
        y: -cardContainer.height
        opacity: 0.0

        NumberAnimation {
            id: dropDownAnim
            target: playerRootItem
            property: "y"
            from: -cardContainer.height
            to: 0
            duration: 280
            easing.type: Easing.OutCubic
        }

        ParallelAnimation {
            id: dropUpAnim
            NumberAnimation {
                target: playerRootItem
                property: "y"
                to: -cardContainer.height
                duration: 240
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: playerRootItem
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
                fillColor: popupWindow.bgColor
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
                fillColor: popupWindow.bgColor
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
            width: 440
            height: 215
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 24
            bottomRightRadius: 24
            color: popupWindow.bgColor
            border.width: 0
            border.color: "#2C2C30"

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
                color: popupWindow.bgColor
            }

            // Absorbs clicks on the card itself so clicking empty space won't close it
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    topMargin: 14
                    bottomMargin: 14
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 10

                // ─── Top Header Row ───────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24

                    // Source badge pill
                    Rectangle {
                        implicitWidth: badgeRow.implicitWidth + 18
                        implicitHeight: 24
                        radius: 12
                        color: popupWindow.bgColor2

                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 6

                            // Playing dot
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: (popupWindow.player && popupWindow.player.isPlaying) ? popupWindow.accentColor : popupWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: {
                                    if (!popupWindow.player) return "Media Player"
                                    return popupWindow.player.identity || "Media Player"
                                }
                                font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                color: popupWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Animated visualizer bars when playing
                    Row {
                        spacing: 3
                        Layout.alignment: Qt.AlignVCenter
                        visible: popupWindow.player && popupWindow.player.isPlaying

                        Repeater {
                            model: 5
                            Rectangle {
                                width: 3
                                height: 6
                                radius: 1.5
                                color: popupWindow.accentColor
                                anchors.verticalCenter: parent.verticalCenter

                                SequentialAnimation on height {
                                    loops: Animation.Infinite
                                    running: popupWindow.player && popupWindow.player.isPlaying && popupWindow.isOpen
                                    NumberAnimation { to: [14, 18, 10, 16, 12][index]; duration: [380, 480, 320, 520, 420][index]; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 5; duration: [420, 520, 340, 460, 390][index]; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }

                    Item { width: 10 }

                    // Volume Control in header
                    Row {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (popupWindow.isMuted || popupWindow.systemVolume <= 0) ? "\uf026" : ((popupWindow.systemVolume < 0.5) ? "\uf027" : "\uf028")
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 13 }
                            color: popupWindow.isMuted ? "#66ffffff" : popupWindow.fgColor

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: popupWindow.toggleMute()
                            }
                        }

                        Item {
                            id: volSliderContainer
                            width: 74
                            height: 22
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: volTrack
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                height: 4
                                radius: 2
                                color: "#2C2C30"

                                Rectangle {
                                    anchors {
                                        left: parent.left
                                        top: parent.top
                                        bottom: parent.bottom
                                    }
                                    width: parent.width * Math.min(1.0, Math.max(0.0, popupWindow.isMuted ? 0.0 : popupWindow.systemVolume))
                                    radius: 2
                                    color: popupWindow.isMuted ? "#66ffffff" : popupWindow.fgColor
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: (mouse) => {
                                    popupWindow.setVolume(mouse.x / width)
                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed) {
                                        popupWindow.setVolume(mouse.x / width)
                                    }
                                }
                                onWheel: (wheel) => {
                                    if (wheel.angleDelta.y > 0) {
                                        popupWindow.setVolume(popupWindow.systemVolume + 0.05);
                                    } else {
                                        popupWindow.setVolume(popupWindow.systemVolume - 0.05);
                                    }
                                }
                            }
                        }
                    }

                    Item { width: 8 }

                    // Close button
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: closeArea.containsMouse ? Qt.lighter(popupWindow.bgColor2, 1.5) : popupWindow.bgColor2

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d" // fa-times
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                            color: closeArea.containsMouse ? "#FFFFFF" : popupWindow.fgColor
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popupWindow.closeRequested()
                        }
                    }
                }

                // ─── Middle Section (Cover Art + Info + Seekbar) ─
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 16

                    // Cover Art
                    Rectangle {
                        id: artContainer
                        Layout.preferredWidth: 86
                        Layout.preferredHeight: 86
                        radius: 16
                        color: popupWindow.bgColor2
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.08)

                        Image {
                            id: coverArtImage
                            anchors.fill: parent
                            anchors.margins: 1
                            source: (popupWindow.player && popupWindow.player.trackArtUrl) ? popupWindow.player.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready && source !== ""

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: artMask
                            }
                        }

                        Item {
                            id: artMask
                            anchors.fill: parent
                            layer.enabled: true
                            visible: false
                            Rectangle {
                                anchors.fill: parent
                                radius: 15
                                color: "black"
                            }
                        }

                        Item {
                            anchors.fill: parent
                            visible: !coverArtImage.visible

                            Text {
                                anchors.centerIn: parent
                                text: "\uf001" // fa-music
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 30 }
                                color: Qt.rgba(1, 1, 1, 0.25)
                            }
                        }
                    }

                    // Info & Seekbar Column
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 3

                        // Track Title
                // Track Title (Scrolling Marquee)
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: titleText.implicitHeight
                            clip: true

                            Text {
                                id: titleText
                                text: {
                                    if (!popupWindow.player) return "No Media Playing"
                                    let meta = popupWindow.player.metadata || {}
                                    let t = popupWindow.player.trackTitle || meta["xesam:title"] || meta["xesam:url"]?.split('/').pop() || "Unknown Title"
                                    return t
                                }
                                font { family: popupWindow.mainFont; pixelSize: 15; weight: Font.Bold }
                                color: "#FFFFFF"
                                
                                // Notice we removed `elide: Text.ElideRight` so the text can expand to its full width
                                
                                // Reset position instantly when the song changes
                                onTextChanged: x = 0 

                                // The ping-pong scroll animation
                                SequentialAnimation on x {
                                    loops: Animation.Infinite
                                    // Only run if the text is wider than the container AND the popup is open
                                    running: titleText.implicitWidth > titleText.parent.width && popupWindow.isOpen

                                    // Wait 2 seconds before scrolling
                                    PauseAnimation { duration: 2000 }
                                    
                                    // Scroll left
                                    NumberAnimation {
                                        to: titleText.parent.width - titleText.implicitWidth
                                        // Speed is based on how much overflow there is (35ms per pixel)
                                        duration: Math.max(0, titleText.implicitWidth - titleText.parent.width) * 35
                                        easing.type: Easing.InOutQuad
                                    }
                                    
                                    // Wait 2 seconds at the end
                                    PauseAnimation { duration: 2000 }
                                    
                                    // Scroll back to the start
                                    NumberAnimation {
                                        to: 0
                                        duration: Math.max(0, titleText.implicitWidth - titleText.parent.width) * 35
                                        easing.type: Easing.InOutQuad
                                    }
                                }
                            }
                        }

                        // Artist Name
                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (!popupWindow.player) return "Nothing is playing"
                                let meta = popupWindow.player.metadata || {}
                                return popupWindow.player.trackArtist || meta["xesam:artist"] || "Unknown Artist"
                            }
                            font { family: "Inter"; pixelSize: 12; weight: Font.DemiBold }
                            color: popupWindow.fgColor
                            elide: Text.ElideRight
                        }

                        // Album Name (optional)
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: {
                                if (!popupWindow.player) return ""
                                let meta = popupWindow.player.metadata || {}
                                return popupWindow.player.trackAlbum || meta["xesam:album"] || ""
                            }
                            font { family: "Inter"; pixelSize: 10 }
                            color: "#71717A"
                            elide: Text.ElideRight
                        }

                        Item { height: 2 }

                        // Seekbar / Timeline
                        Item {
                            id: seekContainer
                            Layout.fillWidth: true
                            height: 14

                            property real trackLength: popupWindow.player?.length ?? 0
                            property real currentPosition: popupWindow.player?.position ?? 0
                            property real progress: trackLength > 0 ? Math.min(1.0, Math.max(0.0, currentPosition / trackLength)) : 0
                            property bool isSeeking: false
                            property real seekRatio: 0

                            Rectangle {
                                id: trackBg
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                height: (seekArea.containsMouse || seekContainer.isSeeking) ? 6 : 4
                                radius: 3
                                color: "#2C2C30"

                                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                // Progress Fill
                                Rectangle {
                                    anchors {
                                        left: parent.left
                                        top: parent.top
                                        bottom: parent.bottom
                                    }
                                    width: parent.width * (seekContainer.isSeeking ? seekContainer.seekRatio : seekContainer.progress)
                                    radius: 3
                                    color: (seekArea.containsMouse || seekContainer.isSeeking) ? popupWindow.accentColor : popupWindow.fgColor

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                // Handle thumb
                                Rectangle {
                                    visible: (seekArea.containsMouse || seekContainer.isSeeking) && seekContainer.trackLength > 0
                                    x: Math.max(0, Math.min(parent.width - width, (parent.width * (seekContainer.isSeeking ? seekContainer.seekRatio : seekContainer.progress)) - (width / 2)))
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: "#FFFFFF"
                                }
                            }

                            MouseArea {
                                id: seekArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: (seekContainer.trackLength > 0) ? Qt.PointingHandCursor : Qt.ArrowCursor

                                onPressed: (mouse) => {
                                    if (seekContainer.trackLength > 0 && popupWindow.player) {
                                        seekContainer.isSeeking = true
                                        seekContainer.seekRatio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                    }
                                }

                                onPositionChanged: (mouse) => {
                                    if (seekContainer.isSeeking && seekContainer.trackLength > 0) {
                                        seekContainer.seekRatio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                    }
                                }

                                onReleased: (mouse) => {
                                    if (seekContainer.isSeeking && seekContainer.trackLength > 0 && popupWindow.player) {
                                        let ratio = Math.max(0.0, Math.min(1.0, mouse.x / width))
                                        let newPos = ratio * seekContainer.trackLength
                                        try {
                                            popupWindow.player.position = newPos
                                        } catch(e) {}
                                        seekContainer.currentPosition = newPos
                                        seekContainer.isSeeking = false
                                    }
                                }

                                onCanceled: {
                                    seekContainer.isSeeking = false
                                }
                            }
                        }

                        // Time labels (current / total)
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: popupWindow.formatTime(seekContainer.isSeeking ? (seekContainer.seekRatio * seekContainer.trackLength) : seekContainer.currentPosition)
                                font { family: "Inter"; pixelSize: 10; weight: Font.Medium }
                                color: "#71717A"
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: popupWindow.formatTime(seekContainer.trackLength)
                                font { family: "Inter"; pixelSize: 10; weight: Font.Medium }
                                color: "#71717A"
                            }
                        }
                    }
                }

                // ─── Bottom Controls Row (PERFECTLY CENTERED) ─
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 44
                    spacing: 16

                    // Shuffle Button
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: shuffleArea.containsMouse ? Qt.lighter(popupWindow.bgColor2, 1.4) : "transparent"
                        opacity: (popupWindow.player && popupWindow.player.shuffleSupported) ? 1.0 : 0.35

                        Text {
                            anchors.centerIn: parent
                            text: "\uf074" // fa-random / shuffle
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 13 }
                            color: (popupWindow.player && popupWindow.player.shuffle) ? popupWindow.accentColor : popupWindow.fgColor
                        }

                        MouseArea {
                            id: shuffleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (popupWindow.player && popupWindow.player.shuffleSupported) {
                                    popupWindow.player.shuffle = !popupWindow.player.shuffle
                                }
                            }
                        }
                    }

                    // Previous Button
                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: prevArea.containsMouse ? Qt.lighter(popupWindow.bgColor2, 1.4) : popupWindow.bgColor2
                        opacity: (!popupWindow.player || popupWindow.player.canGoPrevious) ? 1.0 : 0.4

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf048" // fa-step-backward
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 14 }
                            color: prevArea.containsMouse ? "#FFFFFF" : popupWindow.fgColor
                        }

                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (popupWindow.player) popupWindow.player.previous()
                                else Quickshell.execDetached(["playerctl", "previous"])
                            }
                        }
                    }

                    // Play / Pause Button (Hero Accent)
                    Rectangle {
                        width: 44
                        height: 44
                        radius: 22
                        color: playArea.containsMouse ? Qt.lighter(popupWindow.accentColor, 1.1) : popupWindow.accentColor

                        Behavior on color { ColorAnimation { duration: 150 } }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: popupWindow.accentColorGlow
                            shadowBlur: 0.3
                            shadowOpacity: 0.35
                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: (popupWindow.player && popupWindow.player.isPlaying) ? 0 : 1
                            text: (popupWindow.player && popupWindow.player.isPlaying) ? "\uf04c" : "\uf04b" // fa-pause / fa-play
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 16 }
                            color: popupWindow.bgColor
                        }

                        MouseArea {
                            id: playArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (popupWindow.player) popupWindow.player.togglePlaying()
                                else Quickshell.execDetached(["playerctl", "play-pause"])
                            }
                        }
                    }

                    // Next Button
                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: nextArea.containsMouse ? Qt.lighter(popupWindow.bgColor2, 1.4) : popupWindow.bgColor2
                        opacity: (!popupWindow.player || popupWindow.player.canGoNext) ? 1.0 : 0.4

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf051" // fa-step-forward
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 14 }
                            color: nextArea.containsMouse ? "#FFFFFF" : popupWindow.fgColor
                        }

                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (popupWindow.player) popupWindow.player.next()
                                else Quickshell.execDetached(["playerctl", "next"])
                            }
                        }
                    }

                    // Repeat / Loop Button
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: loopArea.containsMouse ? Qt.lighter(popupWindow.bgColor2, 1.4) : "transparent"
                        opacity: (popupWindow.player && popupWindow.player.loopSupported) ? 1.0 : 0.35

                        Text {
                            anchors.centerIn: parent
                            text: "\uf01e" // fa-repeat
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 13 }
                            color: (popupWindow.player && popupWindow.player.loopState !== 0 && popupWindow.player.loopState !== MprisLoopState.None) ? popupWindow.accentColor : popupWindow.fgColor
                        }

                        MouseArea {
                            id: loopArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popupWindow.cycleLoop()
                        }
                    }
                }
            }
        }
    }
}