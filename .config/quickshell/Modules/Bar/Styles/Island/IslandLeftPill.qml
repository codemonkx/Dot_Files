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
    required property Item centerPill
    property real openProgress: 0
    readonly property bool isTarget: islandBar.activeIslandTarget === "left" && (islandBar.isOpen || islandBar.isRemoving)
    readonly property bool isHovered: leftHover.hovered && !islandBar.isOpen && openProgress === 0
    readonly property bool isTranslated: isHovered || isTarget || openProgress > 0
    readonly property bool showWorkspaces: SettingsService.islandShowWorkspaces
    readonly property real logoGlyphW: islandBar.idleGlyph
    readonly property real sidePadding: Constants.sizeXs
    property real workspacesWidth: 0
    readonly property real targetIdleW: showWorkspaces ? (sidePadding * 2 + logoGlyphW + islandBar.idleSpacing + workspacesWidth) : islandBar.idleHeight
    property real smoothIdleW: targetIdleW
    readonly property real idleW: smoothIdleW
    readonly property real idleH: islandBar.idleHeight
    readonly property real idleR: islandBar.idleRadius
    readonly property real panelW: isTarget ? islandComponents.getTargetWidth("dashboard", leftLoader.item, 0) : idleW
    readonly property real panelH: isTarget ? islandComponents.getTargetHeight("dashboard", leftLoader.item) : idleH
    readonly property real panelR: isTarget ? islandComponents.getTargetRadius("dashboard") : idleR
    readonly property alias activeItem: leftLoader.item

    z: isTarget ? 10 : 1
    x: Math.max(islandBar.edgeMargin, Math.round(centerPill.x - islandBar.pillGap - width))
    y: 0
    width: idleW + (panelW - idleW) * openProgress
    height: idleH + (panelH - idleH) * openProgress
    radius: idleR + (panelR - idleR) * openProgress

    HoverHandler {
        id: leftHover

        enabled: !islandBar.isOpen && root.openProgress === 0
        margin: root.isHovered ? 8 : 0
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.openProgress > 0.05
    }

    Item {
        anchors.fill: parent
        opacity: Math.min(1, Math.max(0, 1 - root.openProgress / 0.15))
        visible: opacity > 0.001
        clip: true

        RowLayout {
            id: leftIdleRow

            anchors.centerIn: parent
            spacing: islandBar.idleSpacing

            Item {
                Layout.preferredWidth: root.logoGlyphW
                Layout.preferredHeight: root.logoGlyphW

                AnimatedMinflair {
                    anchors.centerIn: parent
                    iconSize: root.logoGlyphW
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: !islandBar.isOpen
                    onClicked: AppState.toggleWidget("dashboard")
                }

            }

            Workspaces {
                id: workspacesWidget

                Layout.alignment: Qt.AlignVCenter
                compact: true
                bgColor: "transparent"
                containerPadding: 0
                dotSpacing: islandBar.idleSpacing
                visible: root.showWorkspaces
                onImplicitWidthChanged: root.workspacesWidth = implicitWidth
                Component.onCompleted: root.workspacesWidth = implicitWidth
            }

        }

    }

    Item {
        anchors.fill: parent
        anchors.margins: Constants.sizeLg
        opacity: islandBar.isRemoving ? Math.min(1, Math.max(0, (root.openProgress - 0.4) / 0.6)) : Math.min(1, Math.max(0, (root.openProgress - 0.2) / 0.8))
        scale: islandBar.isRemoving ? (0.94 + 0.06 * Math.min(1, Math.max(0, (root.openProgress - 0.3) / 0.7))) : (0.94 + 0.06 * Math.min(1, Math.max(0, (root.openProgress - 0.15) / 0.85)))
        visible: opacity > 0.001
        clip: true

        Loader {
            id: leftLoader

            property real targetW: islandComponents.getContentWidth("dashboard", item)
            property real targetH: islandComponents.getContentHeight("dashboard", item)

            width: targetW > 0 ? targetW : parent.width
            height: targetH > 0 ? targetH : parent.height
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            active: root.isTarget
            sourceComponent: islandComponents.getComponent("dashboard")
            onStatusChanged: {
                if (status === Loader.Ready && item) {
                    if (item.widget !== undefined)
                        item.widget = islandBar;

                }
            }
        }

    }

    transform: Translate {
        x: root.isTranslated ? -4 : 0
        y: root.isTranslated ? 4 : 0

        Behavior on x {
            enabled: HyprlandService.enableAnimations

            NumberAnimation {
                duration: Constants.animNormal
                easing.type: Easing.OutQuint
            }

        }

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

}
