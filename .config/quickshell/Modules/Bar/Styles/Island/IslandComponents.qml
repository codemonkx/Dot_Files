import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Services
import qs.Modules.Bar.Widgets.SystemTray
import qs.Modules.Calendar as CalendarModule
import qs.Modules.Clipboard as ClipboardModule
import qs.Modules.ControlCenter as ControlCenterModule
import qs.Modules.Dashboard as DashboardModule
import qs.Modules.Launcher as LauncherModule
import qs.Modules.Music as MusicModule
import qs.Modules.NotificationCenter as NotificationCenterModule
import qs.Modules.PowerMenu as PowerMenuModule
import qs.Modules.ScreenCapture as ScreenCaptureModule
import qs.Modules.SystemUsage as SystemUsageModule
import qs.Modules.WallpaperSelector as WallpaperModule

Item {
    id: root

    required property var islandBar
    required property var notificationService

    function getTargetPadding(panel) {
        if (panel === "" || panel === "screenshot" || panel === "powerMenu")
            return 0;

        return Constants.sizeLg;
    }

    function getTargetWidth(panel, item, idleContentW) {
        let pad = getTargetPadding(panel);
        if (item && item.implicitWidth > 0)
            return item.implicitWidth + (pad * 2);

        let w = Math.round(idleContentW) + 24;
        return (w % 2 === 0) ? w : (w + 1);
    }

    function getTargetHeight(panel, item) {
        let pad = getTargetPadding(panel);
        if (item && item.implicitHeight > 0)
            return item.implicitHeight + (pad * 2);

        return 36;
    }

    function getContentWidth(panel, item) {
        let pad = getTargetPadding(panel);
        return Math.max(0, getTargetWidth(panel, item, 0) - (pad * 2));
    }

    function getContentHeight(panel, item) {
        let pad = getTargetPadding(panel);
        return Math.max(0, getTargetHeight(panel, item) - (pad * 2));
    }

    function getTargetRadius(panel) {
        if (panel === "")
            return getTargetHeight("", null) / 2;

        if (panel === "screenshot" || panel === "powerMenu") {
            let optionRadius = Constants.sizeSm;
            return optionRadius + getTargetPadding(panel);
        }
        return Constants.size3Xl;
    }

    function getComponent(panelName) {
        if (panelName.startsWith("systemTray_"))
            return trayComp;

        switch (panelName) {
        case "dashboard":
            return dashboardComp;
        case "controlCenter":
            return controlCenterComp;
        case "notificationsCenter":
            return notificationsCenterComp;
        case "music":
            return musicComp;
        case "calendar":
            return calendarComp;
        case "systemUsage":
            return systemUsageComp;
        case "launcher":
            return launcherComp;
        case "clipboard":
            return clipboardComp;
        case "wallpaper":
            return wallpaperComp;
        case "screenshot":
            return screenshotComp;
        case "powerMenu":
            return powerMenuComp;
        default:
            return null;
        }
    }

    Component {
        id: dashboardComp

        DashboardModule.DashboardContent {
            widget: root.islandBar
        }

    }

    Component {
        id: controlCenterComp

        ControlCenterModule.ControlCenterContent {
            widget: root.islandBar
            notificationService: root.notificationService
        }

    }

    Component {
        id: notificationsCenterComp

        NotificationCenterModule.NotificationCenter {
            notificationService: root.notificationService
            controlCenterOpen: true
        }

    }

    Component {
        id: musicComp

        MusicModule.MiniMusicWidget {
            widget: root.islandBar
        }

    }

    Component {
        id: calendarComp

        CalendarModule.CalendarWidget {
            widget: root.islandBar
        }

    }

    Component {
        id: systemUsageComp

        SystemUsageModule.SystemUsageContent {
            widget: root.islandBar
        }

    }

    Component {
        id: launcherComp

        LauncherModule.LauncherContent {
            widget: root.islandBar
        }

    }

    Component {
        id: clipboardComp

        ClipboardModule.ClipboardContent {
            widget: root.islandBar
        }

    }

    Component {
        id: wallpaperComp

        WallpaperModule.WallpaperSelectorContent {
            widget: root.islandBar
        }

    }

    Component {
        id: screenshotComp

        ScreenCaptureModule.ScreenCaptureContent {
            widget: root.islandBar
        }

    }

    Component {
        id: powerMenuComp

        PowerMenuModule.PowerMenuContent {
            widget: root.islandBar
        }

    }

    Component {
        id: trayComp

        Item {
            id: trayWrap

            readonly property int maxW: 340
            readonly property int maxH: 380
            property real menuImplicitW: 0
            property real menuImplicitH: 0

            implicitWidth: Math.max(220, Math.min(maxW, menuImplicitW))
            implicitHeight: Math.max(120, Math.min(maxH, menuImplicitH))

            TrayMenu {
                id: trayMenu

                anchors.fill: parent
                menuHandle: AppState.resolvedTrayItem ? AppState.resolvedTrayItem.menu : null
                title: AppState.trayTitle(AppState.resolvedTrayItem)
                onBackRequested: AppState.closeWidget(AppState.activeWidget)
                onCloseRequested: AppState.closeWidget(AppState.activeWidget)
                onImplicitWidthChanged: trayWrap.menuImplicitW = implicitWidth
                onImplicitHeightChanged: trayWrap.menuImplicitH = implicitHeight
                Component.onCompleted: {
                    trayWrap.menuImplicitW = implicitWidth;
                    trayWrap.menuImplicitH = implicitHeight;
                }
            }

        }

    }

}
