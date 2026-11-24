import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Core.Services

Item {
    id: root

    property bool hasFullscreen: false
    property int barHeight: Constants.size4Xl
    property int bezelSize: Constants.sizeXs
    property bool isExiting: false
    readonly property bool isExclusionActive: !DisplayProfileService.gameModeActive && SettingsService.barConvexMode && !root.hasFullscreen && !root.isExiting

    PanelWindow {
        // Keep the surface mapped so style switches never destroy a layer
        // window (Quickshell can crash while tearing one down). Visibility is
        // controlled through the exclusive zone and the empty mask.

        id: bottomExclusion

        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        WlrLayershell.layer: WlrLayer.Bottom
        color: "transparent"
        focusable: false
        WlrLayershell.exclusiveZone: root.isExclusionActive ? root.bezelSize : 0
        implicitHeight: root.bezelSize

        mask: Region {
        }

    }

    PanelWindow {
        id: leftExclusion

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        WlrLayershell.layer: WlrLayer.Bottom
        color: "transparent"
        focusable: false
        WlrLayershell.exclusiveZone: root.isExclusionActive ? root.bezelSize : 0
        implicitWidth: root.bezelSize

        mask: Region {
        }

    }

    PanelWindow {
        id: rightExclusion

        anchors.top: true
        anchors.bottom: true
        anchors.right: true
        WlrLayershell.layer: WlrLayer.Bottom
        color: "transparent"
        focusable: false
        WlrLayershell.exclusiveZone: root.isExclusionActive ? root.bezelSize : 0
        implicitWidth: root.bezelSize

        mask: Region {
        }

    }

}
