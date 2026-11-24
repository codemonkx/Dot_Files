import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.Core
import qs.Core.Components
import qs.Core.Services

RowLayout {
    id: playerControls

    property int currentLoopState: 0
    property bool isShuffleActive: false

    Layout.fillWidth: true
    Layout.topMargin: 0
    spacing: 0

    SvgIconButton {
        icon: "player-shuffle"
        iconSize: Constants.sizeSm
        flat: true
        iconColor: playerControls.isShuffleActive ? Theme.accent : (MprisService.activePlayer !== null ? Theme.fg : Theme.muted)
        disabled: MprisService.activePlayer === null
        onClicked: {
            MprisService.toggleShuffle();
        }
    }

    Item {
        Layout.fillWidth: true
    }

    SvgIconButton {
        icon: "player-previous"
        iconSize: Constants.sizeMd
        flat: true
        iconColor: MprisService.activePlayer !== null ? Theme.fg : Theme.muted
        disabled: MprisService.activePlayer === null
        onClicked: {
            if (MprisService.activePlayer)
                MprisService.activePlayer.previous();

        }
    }

    Item {
        Layout.fillWidth: true
    }

    // PROMINENT PLAY/PAUSE
    Rectangle {
        width: Constants.size3Xl
        height: Constants.size3Xl
        radius: Constants.size2Xl
        color: Theme.accent
        scale: playHover.hovered ? 1.05 : 1
        layer.enabled: true

        SvgIcon {
            anchors.centerIn: parent
            icon: MprisService.isPlaying ? "player-pause" : "player-play"
            iconSize: Constants.sizeLg
            iconColor: Theme.bg
            flat: true
        }

        MouseArea {
            id: playHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (MprisService.activePlayer !== null) {
                    if (mouse.button === Qt.LeftButton)
                        MprisService.activePlayer.togglePlaying();
                    else if (mouse.button === Qt.RightButton)
                        MprisService.killConfiguredPlayer();
                } else {
                    MprisService.launchPlayer();
                }
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Constants.animFast
            }

        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.accent
            blurMax: Constants.sizeMd * 2
            shadowBlur: 1
            shadowVerticalOffset: 0
            shadowHorizontalOffset: 0
            opacity: 0.5
        }

    }

    Item {
        Layout.fillWidth: true
    }

    SvgIconButton {
        icon: "player-next"
        iconSize: Constants.sizeMd
        flat: true
        iconColor: MprisService.activePlayer !== null ? Theme.fg : Theme.muted
        disabled: MprisService.activePlayer === null
        onClicked: {
            if (MprisService.activePlayer)
                MprisService.activePlayer.next();

        }
    }

    Item {
        Layout.fillWidth: true
    }

    SvgIconButton {
        icon: playerControls.currentLoopState === 1 ? "player-loop-once" : "player-loop"
        iconSize: Constants.sizeSm
        flat: true
        iconColor: (playerControls.currentLoopState !== 0) ? Theme.accent : (MprisService.activePlayer !== null ? Theme.fg : Theme.muted)
        disabled: MprisService.activePlayer === null
        onClicked: {
            MprisService.cycleLoop();
        }
    }

}
