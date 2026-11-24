import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar
import qs.Modules.Bar.Components

Item {
    id: root

    property var notificationService: null
    property QtObject mainBar: null
    property real extraPadding: Constants.size3Xl
    property bool enableShadow: true
    // Flare & padding specifications matching Convex notch
    readonly property int flareW: Constants.sizeLg + 2
    readonly property int flareH: Constants.sizeLg
    readonly property int contentPadding: Constants.sizeLg
    readonly property int totalHorizPadding: (flareW + contentPadding) * 2
    readonly property int totalVertPadding: contentPadding * 2
    // State & mode flags
    readonly property bool hasActiveNotifications: notifLayer.hasActiveNotifications
    property real notifProgress: (hasActiveNotifications && !notifLayer.isRemovingNotif) ? 1 : 0
    readonly property bool hasActiveOsd: OsdService.isOpen && !hasActiveNotifications && !isOpen
    property real osdProgress: hasActiveOsd ? 1 : 0
    readonly property bool isCenterExpanded: SettingsService.barConvexMode && (AppState.isWidgetOpen("music") || AppState.isWidgetOpen("calendar") || AppState.isWidgetOpen("systemUsage"))
    readonly property string activeContentType: AppState.isWidgetOpen("music") ? "music" : (AppState.isWidgetOpen("calendar") ? "calendar" : (AppState.isWidgetOpen("systemUsage") ? "systemUsage" : ""))
    property bool isOpen: false
    property bool isClosing: false
    property real openProgress: 0
    readonly property bool isOverlayActive: isOpen || (openProgress > 0.001) || isClosing
    readonly property bool isOccupied: isOverlayActive || hasActiveNotifications || hasActiveOsd
    // Geometry calculations
    readonly property real idleW: {
        let contentW = centerSlot.implicitWidth > 0 ? centerSlot.implicitWidth : centerSlot.targetWidth;
        let w = Math.round(contentW + flareW * 2 + root.extraPadding);
        return (w % 2 === 0) ? w : (w + 1);
    }
    readonly property real idleH: BarStyleConfig.barHeight("convex")
    readonly property real notifW: notifLayer.notifW
    readonly property real notifH: notifLayer.notifH
    readonly property real dynamicOsdW: {
        if (OsdService.showProgress)
            return 280 + (flareW * 2);

        if (discreteRow && discreteRow.implicitWidth > 0) {
            let w = Math.round(discreteRow.implicitWidth + (Constants.sizeLg * 2) + (flareW * 2));
            return (w % 2 === 0) ? w : (w + 1);
        }
        return 180 + (flareW * 2);
    }
    property real osdW: dynamicOsdW
    readonly property real expandedW: (centerPanel.item && centerPanel.item.implicitWidth > 0 ? centerPanel.item.implicitWidth : 240) + totalHorizPadding
    readonly property real expandedH: (centerPanel.item && centerPanel.item.implicitHeight > 0 ? centerPanel.item.implicitHeight : 380) + totalVertPadding
    property real smoothIdleW: idleW
    property real smoothNotifW: notifW
    property real smoothNotifH: notifH
    property real smoothExpandedW: expandedW
    property real smoothExpandedH: expandedH
    readonly property real baseW: {
        if (notifProgress > 0)
            return smoothIdleW + (smoothNotifW - smoothIdleW) * notifProgress;

        return smoothIdleW + (osdW - smoothIdleW) * osdProgress;
    }
    readonly property real baseH: idleH + (smoothNotifH - idleH) * notifProgress
    readonly property real currentWidth: Math.round(baseW + (smoothExpandedW - baseW) * openProgress)
    readonly property real currentHeight: Math.round(baseH + (smoothExpandedH - baseH) * openProgress)
    readonly property real currentRadius: Math.round(Constants.sizeLg + (Constants.size3Xl - Constants.sizeLg) * openProgress)

    function syncDimensions() {
        if (width > 0)
            AppState.barConvexWidth = width;

        if (height > 0)
            AppState.barConvexHeight = height;

        if (SettingsService.barConvexMode) {
            let active = hasActiveNotifications && !notifLayer.isRemovingNotif;
            AppState.hasActiveNotification = active;
            AppState.activeNotificationWidth = active ? notifW : 0;
            AppState.activeNotificationHeight = active ? notifH : 0;
        }
    }

    // Music Open / Close handlers
    function openCenter() {
        if (isOpen)
            return ;

        isOpen = true;
        isClosing = false;
        AppState.isConvexOpen = true;
        openProgress = 1;
    }

    function close() {
        closeCenter();
    }

    function closeCenter() {
        if (isClosing)
            return ;

        isClosing = true;
        isOpen = false;
        openProgress = 0;
        if (!HyprlandService.enableAnimations)
            finishClosingCenter();

    }

    function finishClosingCenter() {
        if (isClosing) {
            isClosing = false;
            AppState.isConvexOpen = false;
            if (AppState.isWidgetOpen("music"))
                AppState.closeWidget("music");

            if (AppState.isWidgetOpen("calendar"))
                AppState.closeWidget("calendar");

            if (AppState.isWidgetOpen("systemUsage"))
                AppState.closeWidget("systemUsage");

        }
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    implicitWidth: currentWidth
    width: currentWidth
    height: currentHeight
    onCurrentWidthChanged: syncDimensions()
    onCurrentHeightChanged: syncDimensions()
    Component.onCompleted: syncDimensions()
    onIsCenterExpandedChanged: {
        if (isCenterExpanded)
            root.openCenter();
        else if (root.isOpen)
            root.closeCenter();
    }

    // Prevent clicks on the expanded center notch from reaching the global
    // click-outside handler in ConvexPanels (which would close the widget)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.openProgress > 0.05
    }

    // LAYER 1: BAR CONTENT (Clock / Idle Widget)
    Item {
        id: barContentContainer

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.round(root.smoothIdleW)
        height: root.idleH
        opacity: {
            let p = Math.max(root.openProgress, Math.max(root.notifProgress, root.osdProgress));
            return Math.min(1, Math.max(0, 1 - p / 0.15));
        }
        scale: {
            let p = Math.max(root.openProgress, Math.max(root.notifProgress, root.osdProgress));
            return 1 - 0.04 * Math.min(1, p / 0.15);
        }
        visible: opacity > 0.001
        clip: true

        BarCenterSection {
            id: centerSlot

            anchors.centerIn: parent
            mainBar: root.mainBar ? root.mainBar : root
        }

    }

    // LAYER 2: NOTIFICATION CONTENT
    ConvexNotifLayer {
        id: notifLayer

        notificationService: root.notificationService
        flareW: root.flareW
        isExpandedOpen: root.isOpen
        openProgress: root.openProgress
        notifProgress: root.notifProgress
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, root.smoothNotifW - (root.flareW * 2) - 8)
        height: Math.max(0, root.smoothNotifH - 14)
    }

    // LAYER 3: MUSIC WIDGET (MiniMusicWidget)
    ConvexCenterPanel {
        id: centerPanel

        centerWidget: root
        flareW: root.flareW
        contentPadding: root.contentPadding
        isClosing: root.isClosing
        openProgress: root.openProgress
        isOpen: root.isOpen
        activeContentType: root.activeContentType
    }

    // LAYER 4: OSD CONTENT
    Item {
        id: osdLayer

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, root.width - (root.flareW * 2) - Constants.sizeLg * 2)
        height: root.idleH
        opacity: Math.min(1, Math.max(0, (root.osdProgress - 0.15) / 0.85))
        visible: opacity > 0.001

        // Mode 1: Slider for Volume, Mic, Brightness
        RowLayout {
            anchors.fill: parent
            spacing: Constants.sizeSm
            visible: OsdService.showProgress

            SvgIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: OsdService.icon
                iconColor: OsdService.isMuted ? Theme.muted : Theme.accent
                flat: true
                iconSize: Constants.sizeMd
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                height: Constants.size2Xs + 2
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
                customSize: Constants.sizeSm
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
                iconSize: Constants.sizeMd
            }

            ThemedText {
                Layout.alignment: Qt.AlignVCenter
                text: OsdService.title
                customSize: Constants.sizeSm
                font.weight: Font.Medium
                color: OsdService.isMuted ? Theme.muted : Theme.fg
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                height: Constants.sizeLg + 4
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
                    customSize: Constants.sizeXs + 1
                    font.weight: Font.Bold
                    color: OsdService.isMuted ? Theme.muted : Theme.accent
                }

            }

        }

    }

    // ANIMATIONS & BEHAVIORS
    Behavior on openProgress {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            duration: root.isClosing ? Constants.animNormal : Constants.animExpressive
            easing.type: root.isClosing ? Easing.OutCubic : Easing.OutQuint
            onRunningChanged: {
                if (!running && root.isClosing)
                    root.finishClosingCenter();

            }
        }

    }

    Behavior on notifProgress {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            duration: notifLayer.isRemovingNotif ? Constants.animFast : Constants.animExpressive
            easing.type: notifLayer.isRemovingNotif ? Easing.OutCubic : Easing.OutQuint
            onRunningChanged: {
                if (!running && notifLayer.isRemovingNotif) {
                    notifLayer.isRemovingNotif = false;
                    notifLayer.dismissActiveNotifications();
                }
            }
        }

    }

    Behavior on smoothExpandedW {
        enabled: HyprlandService.enableAnimations && root.openProgress >= 0.85

        NumberAnimation {
            duration: Constants.animSlow
            easing.type: Easing.OutQuint
        }

    }

    Behavior on smoothExpandedH {
        enabled: HyprlandService.enableAnimations && root.openProgress >= 0.85

        NumberAnimation {
            duration: Constants.animSlow
            easing.type: Easing.OutQuint
        }

    }

    Behavior on smoothNotifW {
        enabled: HyprlandService.enableAnimations && root.notifProgress >= 0.85

        NumberAnimation {
            duration: Constants.animSlow
            easing.type: Easing.OutQuint
        }

    }

    Behavior on smoothNotifH {
        enabled: HyprlandService.enableAnimations && root.notifProgress >= 0.85

        NumberAnimation {
            duration: Constants.animSlow
            easing.type: Easing.OutQuint
        }

    }

    Behavior on smoothIdleW {
        enabled: HyprlandService.enableAnimations

        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutCubic
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
