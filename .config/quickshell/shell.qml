import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs.Core
import qs.Core.Services
import qs.Core.Windows
import qs.Modules.Bar
import qs.Modules.Bar.Styles.Convex
import qs.Modules.Bar.Styles.Gaming

ShellRoot {
    id: root

    readonly property bool isGaming: DisplayProfileService.gameModeActive
    readonly property bool isConvex: SettingsService.barStyle === "convex"

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSource, Pipewire.defaultAudioSink]
    }

    IpcHandler {
        function toggle(widgetId: string) {
            AppState.toggleWidget(widgetId);
        }

        function open(widgetId: string) {
            AppState.openWidget(widgetId);
        }

        function close(widgetId: string) {
            AppState.closeWidget(widgetId);
        }

        target: "widgets"
    }

    IpcHandler {
        function showVolume(volume: string, isMuted: string) {
            OsdService.displayVolume(volume, isMuted);
        }

        function showMic(volume: string, isMuted: string) {
            OsdService.displayMic(volume, isMuted);
        }

        function showBrightness(percent: string) {
            OsdService.displayBrightness(percent);
        }

        function showMessage(title: string, value: string, icon: string) {
            let isMuted = (value === "OFF" || value === "Disabled" || title.indexOf("Disconnected") !== -1);
            OsdService.displayMessage(title, value, icon, !isMuted);
        }

        target: "osd"
    }

    NotificationService {
        id: globalNotificationService
    }

    PanelWindow {
        id: barSurface

        readonly property int barHeight: BarStyleConfig.barHeight(SettingsService.barStyle)
        readonly property int barMarginTop: BarStyleConfig.barMarginTop(SettingsService.barStyle)
        readonly property int barMarginSide: BarStyleConfig.barMarginSide(SettingsService.barStyle)

        WlrLayershell.layer: WlrLayer.Top
        // Game Mode has its own bar and exclusive zone. This metrics-only
        // surface must not reserve space on top of the gaming bar.
        WlrLayershell.exclusionMode: root.isGaming ? ExclusionMode.Ignore : ExclusionMode.Auto
        color: "transparent"
        focusable: false
        implicitHeight: !SettingsService.settingsLoaded ? 0 : (barMarginTop + barHeight)
        visible: SettingsService.settingsLoaded

        anchors {
            top: true
            left: true
            right: true
        }

        mask: Region {
        }

    }

    PanelWindow {
        id: gamingBarSurface

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: root.isGaming ? Constants.gamingBarHeight : 0
        color: root.isGaming ? Theme.bg : "transparent"
        focusable: false
        implicitHeight: Constants.gamingBarHeight
        visible: SettingsService.settingsLoaded

        anchors {
            top: true
            left: true
            right: true
        }

        GamingBar {
            anchors.fill: parent
            notificationService: globalNotificationService
            visible: root.isGaming
            enabled: root.isGaming
        }

        mask: Region {
            Region {
                x: 0
                y: 0
                width: root.isGaming ? gamingBarSurface.width : 0
                height: root.isGaming ? Constants.gamingBarHeight : 0
            }

        }

    }

    // Both bar windows stay mapped while the shell runs. WlrLayershell destroys
    // its backing window when it becomes invisible, and Quickshell/Qt can crash
    // while tearing that window down, so style switches must not hide them.
    // Each window deactivates itself through its mask/content instead.
    BarOverlayWindow {
        notificationService: globalNotificationService
        barSurface: barSurface
        visible: SettingsService.settingsLoaded
    }

    ConvexDesktop {
        id: convexDesktopSurface

        notificationService: globalNotificationService
        visible: SettingsService.settingsLoaded
    }

    GamingOverlay {
        id: gamingOverlaySurface

        notificationService: globalNotificationService
    }

    ShellModules {
        id: shellModules
    }

}
