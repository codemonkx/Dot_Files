import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar.Components

IslandBackground {
    id: root

    required property QtObject islandBar
    required property QtObject islandComponents
    required property Item islandContainer
    required property var notificationService
    property real openProgress: 0
    readonly property bool isTarget: islandBar.activeIslandTarget === "center" && (islandBar.isOpen || islandBar.isRemoving)
    readonly property bool hasActiveNotifications: notifLayer.hasActiveNotifications
    readonly property bool isRemovingNotif: notifLayer.isRemovingNotif
    property real notifProgress: (hasActiveNotifications && !isRemovingNotif) ? 1 : 0
    readonly property bool hasActiveOsd: OsdService.isOpen && !hasActiveNotifications && openProgress === 0
    property real osdProgress: hasActiveOsd ? 1 : 0
    readonly property real dynamicOsdW: {
        if (OsdService.showProgress)
            return 260;

        if (discreteRow && discreteRow.implicitWidth > 0)
            return Math.round(discreteRow.implicitWidth + (Constants.sizeSm + 4) * 2);

        return 175;
    }
    property real osdW: dynamicOsdW
    readonly property bool singlePill: islandBar.singlePill
    property real idleRowWidth: 0
    readonly property bool isHovered: centerHover.hovered && !islandBar.isOpen && openProgress === 0 && !hasActiveNotifications && !hasActiveOsd
    readonly property bool isTranslated: isHovered || isTarget || openProgress > 0 || (hasActiveNotifications && notifProgress > 0) || (hasActiveOsd && osdProgress > 0)
    readonly property real notifW: notifLayer.notifW
    readonly property real notifH: notifLayer.notifH
    readonly property real notifR: Constants.sizeXl
    readonly property real idleW: singlePill ? (idleRowWidth + Constants.sizeXl) : (clockContent.implicitWidth + Constants.sizeXl)
    readonly property real idleH: islandBar.idleHeight
    readonly property real idleR: islandBar.idleRadius
    property real smoothIdleW: idleW
    readonly property real panelW: isTarget ? islandComponents.getTargetWidth(islandBar.effectivePanel, centerLoader.item, 0) : smoothIdleW
    readonly property real panelH: isTarget ? islandComponents.getTargetHeight(islandBar.effectivePanel, centerLoader.item) : idleH
    readonly property real panelR: isTarget ? islandComponents.getTargetRadius(islandBar.effectivePanel) : idleR
    readonly property real baseW: {
        if (notifProgress > 0)
            return smoothIdleW + (notifW - smoothIdleW) * notifProgress;

        return smoothIdleW + (osdW - smoothIdleW) * osdProgress;
    }
    readonly property real baseH: idleH + (notifH - idleH) * notifProgress
    readonly property real baseR: idleR + (notifR - idleR) * notifProgress
    property real smoothPanelW: panelW
    property real smoothPanelH: panelH
    property real smoothPanelR: panelR
    readonly property alias activeItem: centerLoader.item

    function restartDisplayTimer() {
        notifLayer.restartDisplayTimer();
    }

    z: isTarget ? 10 : 1
    x: Math.round((islandContainer.width - width) / 2)
    y: 0
    width: baseW + (smoothPanelW - baseW) * openProgress
    height: baseH + (smoothPanelH - baseH) * openProgress
    radius: baseR + (smoothPanelR - baseR) * openProgress

    HoverHandler {
        id: centerHover

        enabled: !islandBar.isOpen && root.openProgress === 0 && !root.hasActiveNotifications
        margin: root.isHovered ? 8 : 0
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.openProgress > 0.05
    }

    RowLayout {
        id: idleRow

        anchors.centerIn: parent
        spacing: root.singlePill ? Constants.sizeXs : islandBar.idleSpacing
        opacity: Math.min(1, Math.max(0, 1 - Math.max(root.openProgress, Math.max(root.notifProgress, root.osdProgress)) / 0.15))
        visible: opacity > 0.001
        onImplicitWidthChanged: root.idleRowWidth = implicitWidth
        Component.onCompleted: root.idleRowWidth = implicitWidth

        Loader {
            active: root.singlePill
            visible: active
            Layout.alignment: Qt.AlignVCenter
            sourceComponent: starComponent
        }

        IslandClock {
            id: clockContent

            Layout.alignment: Qt.AlignVCenter
            clickable: !islandBar.isOpen && !root.hasActiveNotifications && !root.hasActiveOsd
        }

        Loader {
            active: root.singlePill && MprisService.isPlaying
            visible: active
            Layout.alignment: Qt.AlignVCenter
            sourceComponent: cavaComponent
        }

    }

    IslandNotifLayer {
        id: notifLayer

        notificationService: root.notificationService
        isHostPanel: islandBar.isHostPanel
        openProgress: root.openProgress
        notifProgress: root.notifProgress
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
    }

    Item {
        id: islandOsdContent

        anchors.fill: parent
        anchors.leftMargin: Constants.sizeSm + 4
        anchors.rightMargin: Constants.sizeSm + 4
        opacity: Math.min(1, Math.max(0, (root.osdProgress - 0.15) / 0.85))
        visible: opacity > 0.001

        // Mode 1: Slider for Volume, Mic, Brightness
        RowLayout {
            anchors.fill: parent
            spacing: Constants.sizeXs
            visible: OsdService.showProgress

            SvgIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: OsdService.icon
                iconColor: OsdService.isMuted ? Theme.muted : Theme.accent
                flat: true
                iconSize: Constants.sizeSm + 2
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                height: Constants.size2Xs + 1
                radius: height / 2
                color: Theme.bgSecondary

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: OsdService.isMuted ? Theme.muted : Theme.accent
                    width: Math.max(0, Math.min(1, OsdService.level)) * parent.width

                    Behavior on width {
                        NumberAnimation {
                            duration: Constants.animFast
                            easing.type: Easing.OutQuad
                        }

                    }

                }

            }

            ThemedText {
                Layout.alignment: Qt.AlignVCenter
                text: OsdService.valueText
                customSize: Constants.sizeXs + 1
                font.weight: Font.DemiBold
                color: OsdService.isMuted ? Theme.muted : Theme.fg
            }

        }

        // Mode 2: Clean centered badge for Caps Lock, Touchpad, Keyboard
        RowLayout {
            id: discreteRow

            anchors.centerIn: parent
            spacing: Constants.sizeSm
            visible: !OsdService.showProgress

            SvgIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: OsdService.icon
                iconColor: OsdService.isMuted ? Theme.muted : Theme.accent
                flat: true
                iconSize: Constants.sizeSm + 2
            }

            ThemedText {
                Layout.alignment: Qt.AlignVCenter
                text: OsdService.title
                customSize: Constants.sizeXs + 1
                font.weight: Font.Medium
                color: OsdService.isMuted ? Theme.muted : Theme.fg
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                height: Constants.sizeLg + 2
                radius: height / 2
                color: Theme.bgTertiary
                border.width: 1
                border.color: OsdService.isMuted ? Theme.border : Theme.accent
                implicitWidth: badgeLabel.implicitWidth + Constants.sizeSm
                implicitHeight: height

                ThemedText {
                    id: badgeLabel

                    anchors.centerIn: parent
                    text: OsdService.valueText
                    customSize: Constants.sizeXs
                    font.weight: Font.Bold
                    color: OsdService.isMuted ? Theme.muted : Theme.accent
                }

            }

        }

    }

    Item {
        anchors.fill: parent
        anchors.margins: islandComponents.getTargetPadding(islandBar.effectivePanel)
        opacity: islandBar.isRemoving ? Math.min(1, Math.max(0, (root.openProgress - 0.4) / 0.6)) : Math.min(1, Math.max(0, (root.openProgress - 0.2) / 0.8))
        scale: islandBar.isRemoving ? (0.94 + 0.06 * Math.min(1, Math.max(0, (root.openProgress - 0.3) / 0.7))) : (0.94 + 0.06 * Math.min(1, Math.max(0, (root.openProgress - 0.15) / 0.85)))
        visible: opacity > 0.001
        clip: true

        Loader {
            id: centerLoader

            property real targetW: islandComponents.getContentWidth(islandBar.effectivePanel, item)
            property real targetH: islandComponents.getContentHeight(islandBar.effectivePanel, item)

            width: targetW > 0 ? targetW : parent.width
            height: targetH > 0 ? targetH : parent.height
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            active: root.isTarget
            sourceComponent: islandComponents.getComponent(islandBar.effectivePanel)
            opacity: status === Loader.Ready ? 1 : 0
            onStatusChanged: {
                if (status === Loader.Ready && item) {
                    if (item.widget !== undefined)
                        item.widget = islandBar;

                    islandBar.triggerFocus();
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    Component {
        id: starComponent

        Item {
            implicitWidth: Constants.sizeXl
            implicitHeight: Constants.sizeXl

            AnimatedMinflair {
                anchors.centerIn: parent
                iconSize: Constants.sizeXl
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: !islandBar.isOpen
                onClicked: AppState.toggleWidget("dashboard")
            }

        }

    }

    Component {
        id: cavaComponent

        Item {
            implicitWidth: Constants.sizeSm + Constants.size3Xs
            implicitHeight: Constants.sizeLg

            MiniCavaBars {
                anchors.centerIn: parent
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                enabled: !islandBar.isOpen
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        if (MprisService.activePlayer)
                            MprisService.activePlayer.togglePlaying();

                    } else {
                        AppState.toggleWidget("music");
                    }
                }
            }

        }

    }

    transform: Translate {
        y: root.isTranslated ? 4 : 0

        Behavior on y {
            enabled: HyprlandService.enableAnimations

            NumberAnimation {
                duration: Constants.animNormal
                easing.type: Easing.OutQuint
            }

        }

    }

    Behavior on smoothIdleW {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutQuint
        }

    }

    Behavior on smoothPanelW {
        enabled: HyprlandService.enableAnimations && root.openProgress >= 0.85

        NumberAnimation {
            duration: Constants.animSlow
            easing.type: Easing.OutQuint
        }

    }

    Behavior on smoothPanelH {
        enabled: HyprlandService.enableAnimations && root.openProgress >= 0.85

        NumberAnimation {
            duration: Constants.animSlow
            easing.type: Easing.OutQuint
        }

    }

    Behavior on smoothPanelR {
        enabled: HyprlandService.enableAnimations && root.openProgress >= 0.85

        NumberAnimation {
            duration: Constants.animSlow
            easing.type: Easing.OutQuint
        }

    }

    Behavior on notifProgress {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            duration: root.isRemovingNotif ? Constants.animFast : Constants.animNormal
            easing.type: Easing.OutCubic
            onRunningChanged: {
                if (!running && root.isRemovingNotif) {
                    notifLayer.isRemovingNotif = false;
                    notifLayer.dismissActiveNotifications();
                }
            }
        }

    }

    Behavior on openProgress {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            duration: islandBar.isRemoving ? Constants.animNormal : Constants.animExpressive
            easing.type: islandBar.isRemoving ? Easing.OutCubic : Easing.OutQuint
            onRunningChanged: {
                if (!running && islandBar.isRemoving)
                    islandBar.checkFinishClosing();

            }
        }

    }

    Behavior on osdProgress {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            duration: root.hasActiveOsd ? Constants.animFast : Constants.animNormal
            easing.type: Easing.OutCubic
        }

    }

    Behavior on osdW {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutQuint
        }

    }

}
