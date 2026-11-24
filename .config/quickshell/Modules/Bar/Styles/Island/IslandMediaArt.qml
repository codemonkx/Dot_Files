import QtQuick
import QtQuick.Effects
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar.Components

Item {
    id: root

    property bool clickable: true
    property real artSize: Constants.sizeXl
    readonly property bool hasPlayingMedia: MprisService.activePlayer !== null && (((MprisService.activePlayer.trackTitle || "").trim() !== "") || ((MprisService.activePlayer.trackArtist || "").trim() !== ""))
    readonly property bool showMedia: (SettingsService.islandRightMode === "music") || (SettingsService.islandRightMode === "auto" && hasPlayingMedia)

    clip: true

    // Media Album Art
    Item {
        id: mediaArtBox

        width: root.artSize
        height: root.artSize
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showMedia

        Image {
            id: artImage

            anchors.fill: parent
            source: MprisService.activePlayer ? (MprisService.activePlayer.trackArtUrl || "") : ""
            fillMode: Image.PreserveAspectCrop
            mipmap: true
            asynchronous: true
            visible: false
        }

        // Rendered at 4x so the circular mask is not limited to 20 device pixels.
        Rectangle {
            id: artMask

            width: mediaArtBox.width * 4
            height: mediaArtBox.height * 4
            radius: width / 2
            antialiasing: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: artImage
            maskEnabled: true
            // MultiEffect thresholds the mask alpha with smoothstep. With the
            // default 0/0 the antialiased edge becomes fully opaque, so keep a
            // real 0..1 ramp to preserve the circle's smooth border.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
            visible: artImage.status === Image.Ready && (artImage.source + "").trim() !== ""

            maskSource: ShaderEffectSource {
                visible: false
                hideSource: true
                smooth: true
                sourceItem: artMask
            }

        }

        SvgIcon {
            anchors.centerIn: parent
            icon: "music"
            iconSize: Constants.sizeLg
            iconColor: Theme.fg
            visible: artImage.status !== Image.Ready || (artImage.source + "").trim() === ""
            flat: true
        }

    }

    // Mini Equalizer Bars (Dynamic Island style)
    MiniCavaBars {
        id: visualizerRow

        anchors.left: mediaArtBox.right
        anchors.leftMargin: Constants.sizeXs
        anchors.verticalCenter: parent.verticalCenter
        maxBarHeight: Constants.sizeXl
        opacity: (root.showMedia && MprisService.isPlaying && root.width > 36) ? 1 : 0
        visible: opacity > 0.001

        Behavior on opacity {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutCubic
            }

        }

    }

    // Tune SVG Icon (Control Center)
    SvgIcon {
        anchors.centerIn: parent
        icon: "tune"
        iconSize: Constants.sizeLg
        iconColor: Theme.fg
        visible: !root.showMedia
        flat: true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: root.clickable
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton && root.showMedia && MprisService.activePlayer) {
                MprisService.activePlayer.togglePlaying();
            } else {
                if (root.showMedia)
                    AppState.toggleWidget("music");
                else
                    AppState.toggleWidget("controlCenter");
            }
        }
    }

}
