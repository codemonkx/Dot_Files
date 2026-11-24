import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Core
import qs.Core.Services
import qs.Modules.Bar
import qs.Modules.Bar.Components

PanelWindow {
    id: root

    required property var notificationService
    property bool isShellReady: false
    property string activeBarStyle: "convex"
    // The cached settings are read asynchronously, so barStyle still holds its
    // "convex" default for the first frames. Require settingsLoaded so the
    // convex surface (content and mask) never flashes before the saved style
    // is known.
    readonly property bool isConvexMode: SettingsService.settingsLoaded && SettingsService.barConvexMode && !DisplayProfileService.gameModeActive
    readonly property bool isExiting: !isConvexMode
    property int barHeight: BarStyleConfig.barHeight("convex")
    property real animatedBarHeight: barHeight
    property int bezelSize: 0
    property bool hasFullscreen: (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.hasFullscreen) ? HyprlandService.isTrueFullscreen : false
    property real fsTransitionProg: hasFullscreen ? 0 : 1
    readonly property bool needsFocus: root.isConvexMode && AppState.isFocusWidgetOpen && convexPanels.hasAnyDrawerOpen

    function triggerStyleSwitch() {
        root.activeBarStyle = SettingsService.barStyle;
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: needsFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    focusable: needsFocus
    color: "transparent"
    Component.onCompleted: {
        activeBarStyle = SettingsService.barStyle;
        Qt.callLater(() => {
            isShellReady = true;
        });
    }
    onVisibleChanged: {
        if (visible && SettingsService.barStyle === "convex") {
            shellFrameContainer.enableTransitionAnim = false;
            root.activeBarStyle = "convex";
            barContainer.switchOpacity = 1;
            barContainer.scale = 1;
            convexBarTranslate.y = 0;
        }
    }

    Connections {
        function onSettingsLoadedChanged() {
            if (SettingsService.settingsLoaded)
                root.activeBarStyle = SettingsService.barStyle;

        }

        function onBarStyleChanged() {
            root.triggerStyleSwitch();
        }

        target: SettingsService
    }

    Process {
        id: slurpCheckProcess

        command: ["sh", "-c", "pidof slurp"]
        onExited: {
            if (exitCode !== 0) {
                if (AppState.activeWidget !== "")
                    AppState.activeWidget = "";

            }
        }
    }

    HyprlandFocusGrab {
        id: surfaceFocusGrab

        active: root.focusable
        windows: [root]
        onCleared: {
            slurpCheckProcess.running = true;
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    ConvexExclusions {
        hasFullscreen: root.hasFullscreen
        barHeight: root.barHeight
        bezelSize: root.bezelSize
        isExiting: root.isExiting
    }

    Item {
        id: unifiedShadowGroup

        anchors.fill: parent
        opacity: root.isConvexMode ? 1 : 0
        visible: root.isConvexMode || opacity > 0.001
        layer.enabled: HyprlandService.hyprShadow && !DisplayProfileService.gameModeActive && (SystemInfoService.powerProfile !== "power-saver")

        ConvexPanels {
            id: convexPanels

            z: 1
            anchors.fill: parent
            barHeight: root.barHeight
            bezelSize: root.bezelSize
            notificationService: root.notificationService
        }

        ConvexFrameBezel {
            id: shellFrameContainer

            z: 10
            hasFrame: true
            isShellReady: root.isShellReady
            barHeight: Math.round(root.animatedBarHeight)
            activeBarStyle: root.activeBarStyle
            bezelSize: root.bezelSize
            fsTransitionProg: root.fsTransitionProg
        }

        Item {
            id: barContainer

            property QtObject activeItem: convexLoader.item
            property real switchOpacity: 1

            z: 20
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: (activeItem && (activeItem.centerHeight || 0) > root.barHeight) ? activeItem.centerHeight : root.barHeight
            transformOrigin: Item.Top
            opacity: root.fsTransitionProg * switchOpacity
            visible: opacity > 0.01
            transform: [
                Translate {
                    id: convexBarTranslate

                    y: 0
                }
            ]

            Loader {
                id: convexLoader

                anchors.fill: parent
                active: true
                visible: true
                source: "ConvexBar.qml"
                onLoaded: {
                    if (item) {
                        item.notificationService = root.notificationService;
                        item.mainPanelWidget = Qt.binding(() => {
                            return convexPanels.dashboardWidget;
                        });
                        item.controlCenterWidget = Qt.binding(() => {
                            return convexPanels.controlCenterWidget;
                        });
                        item.notificationsCenterWidget = Qt.binding(() => {
                            return convexPanels.notificationsCenterWidget;
                        });
                    }
                }
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutCubic
            }

        }

        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, Theme.isDark ? 1 : Math.min(1, Theme.shadow.a * 1.6))
            blurMax: HyprlandService.hyprShadowRange
            shadowBlur: 1
            shadowVerticalOffset: 0
            shadowHorizontalOffset: 0
        }

    }

    Behavior on fsTransitionProg {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.InOutCubic
        }

    }

    mask: Region {
        // Top border + Bar. Two extra pixels keep the painted bar background's
        // lower edge inside the mask, covering the wallpaper daemon's exposed
        // top-row line at the exclusive-zone boundary.
        Region {
            x: 0
            y: 0
            width: root.isConvexMode ? root.width : 0
            height: root.isConvexMode ? ((root.barHeight + 2) * root.fsTransitionProg) : 0
        }

        // Left border
        Region {
            x: 0
            y: root.barHeight * root.fsTransitionProg
            width: root.isConvexMode ? (root.bezelSize * root.fsTransitionProg) : 0
            height: root.isConvexMode ? root.height : 0
        }

        // Right border
        Region {
            x: root.width - (root.bezelSize * root.fsTransitionProg)
            y: root.barHeight * root.fsTransitionProg
            width: root.isConvexMode ? (root.bezelSize * root.fsTransitionProg) : 0
            height: root.isConvexMode ? root.height : 0
        }

        // Bottom border
        Region {
            x: root.bezelSize * root.fsTransitionProg
            y: root.height - (root.bezelSize * root.fsTransitionProg)
            width: root.isConvexMode ? (root.width - (2 * root.bezelSize * root.fsTransitionProg)) : 0
            height: root.isConvexMode ? (root.bezelSize * root.fsTransitionProg) : 0
        }

        // Active Panels Overlay (Full Screen for Clicks/Focus)
        Region {
            property bool isActive: root.isConvexMode && (convexPanels.hasAnyPanelOpen || convexPanels.isConvexCenterOpen)

            x: 0
            y: 0
            width: isActive ? root.width : 0
            height: isActive ? root.height : 0
        }

        // Convex Center Notch Expanded Region
        Region {
            readonly property bool isConvexExpanded: root.activeBarStyle === "convex" && barContainer.activeItem && (barContainer.activeItem.centerHeight > root.barHeight)
            readonly property real cX: (root.activeBarStyle === "convex" && barContainer.activeItem) ? (barContainer.activeItem.centerX || 0) : 0
            readonly property real cW: (root.activeBarStyle === "convex" && barContainer.activeItem) ? (barContainer.activeItem.centerWidth || 0) : 0
            readonly property real cH: (root.activeBarStyle === "convex" && barContainer.activeItem) ? (barContainer.activeItem.centerHeight || 0) : 0

            x: isConvexExpanded ? (cX - 8) : 0
            y: 0
            width: isConvexExpanded ? (cW + 16) : 0
            height: isConvexExpanded ? (cH + 16) : 0
        }

    }

}
