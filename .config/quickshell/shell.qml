//@ pragma UseQApplication
// shell.qml
import Quickshell
import QtQuick

Scope {
    WallpaperBackground {}

    Bar {
        id: mainBar
    }

    Rounded {}
    Overlay {
        isPanelOpen: mainBar.showControlPanel || mainBar.showFullPlayer || mainBar.showNotificationPanel || mainBar.showCalendar || mainBar.showAppLauncher || mainBar.showPowerMenu || mainBar.showWallpaperSelector
    }
    ScreenSharePicker {}
    ScreenshotOverlay {}
}