import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: wallpaperBgWindow

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Background
    exclusiveZone: -1
    color: "#121213"

    property string currentPath: ""
    property string pendingPath: ""
    property bool activeIsA: true
    property bool isInitialized: false

    // Initial read of active wallpaper
    Process {
        id: readInitProc
        running: true
        command: ["cat", Quickshell.env("HOME") + "/.config/hypr/current_wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = text.trim()
                if (!p || p.length === 0) {
                    p = Quickshell.env("HOME") + "/Pictures/wall.jpg"
                }
                wallpaperBgWindow.currentPath = p
                wallpaperBgWindow.activeIsA = true
                imgA.source = "file://" + p
                imgA.opacity = 1.0
                imgA.scale = 1.0
                imgB.opacity = 0.0
                wallpaperBgWindow.isInitialized = true
            }
        }
    }

    function transitionTo(path) {
        if (!path || path === currentPath) return
        pendingPath = path
        currentPath = path

        if (activeIsA) {
            imgB.scale = 1.05
            imgB.opacity = 0.0
            imgB.source = "file://" + path
        } else {
            imgA.scale = 1.05
            imgA.opacity = 0.0
            imgA.source = "file://" + path
        }
    }

    IpcHandler {
        target: "wallpaperbg"
        function set(path: string) {
            wallpaperBgWindow.transitionTo(path)
        }
    }

    // ─── Image A ──────────────────────────────────────────────
    Image {
        id: imgA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        opacity: 0.0
        scale: 1.0

        onStatusChanged: {
            if (status === Image.Ready && wallpaperBgWindow.isInitialized && !wallpaperBgWindow.activeIsA) {
                fadeAnimA.restart()
                scaleAnimA.restart()
                fadeAnimB_out.restart()
                wallpaperBgWindow.activeIsA = true
            }
        }

        NumberAnimation {
            id: fadeAnimA
            target: imgA
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 650
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            id: scaleAnimA
            target: imgA
            property: "scale"
            from: 1.05
            to: 1.0
            duration: 850
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: fadeAnimA_out
            target: imgA
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 650
            easing.type: Easing.InOutCubic
        }
    }

    // ─── Image B ──────────────────────────────────────────────
    Image {
        id: imgB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        opacity: 0.0
        scale: 1.0

        onStatusChanged: {
            if (status === Image.Ready && wallpaperBgWindow.isInitialized && wallpaperBgWindow.activeIsA) {
                fadeAnimB.restart()
                scaleAnimB.restart()
                fadeAnimA_out.restart()
                wallpaperBgWindow.activeIsA = false
            }
        }

        NumberAnimation {
            id: fadeAnimB
            target: imgB
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 650
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            id: scaleAnimB
            target: imgB
            property: "scale"
            from: 1.05
            to: 1.0
            duration: 850
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: fadeAnimB_out
            target: imgB
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 650
            easing.type: Easing.InOutCubic
        }
    }
}
