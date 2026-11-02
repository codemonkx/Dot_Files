import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

// macOS-style curved screen corners for Quickshell
Scope {
    id: screenCorners
    property real cornerRadius: 24
    property color cornerColor: "#000000"

    // ─── 1. Top-Left Corner ──────────────────────────────────────
    PanelWindow {
        id: topLeftCorner
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: screenCorners.cornerRadius
        implicitWidth: screenCorners.cornerRadius
        color: "transparent"
        anchors {
            top: true
            left: true
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillColor: screenCorners.cornerColor
                startX: 0
                startY: screenCorners.cornerRadius
                PathArc {
                    x: screenCorners.cornerRadius
                    y: 0
                    radiusX: screenCorners.cornerRadius
                    radiusY: screenCorners.cornerRadius
                    direction: PathArc.Clockwise
                }
                PathLine { x: 0; y: 0 }
                PathLine { x: 0; y: screenCorners.cornerRadius }
            }
        }
    }

    // ─── 2. Top-Right Corner ─────────────────────────────────────
    PanelWindow {
        id: topRightCorner
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: screenCorners.cornerRadius
        implicitWidth: screenCorners.cornerRadius
        color: "transparent"
        anchors {
            top: true
            right: true
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillColor: screenCorners.cornerColor
                startX: 0
                startY: 0
                PathArc {
                    x: screenCorners.cornerRadius
                    y: screenCorners.cornerRadius
                    radiusX: screenCorners.cornerRadius
                    radiusY: screenCorners.cornerRadius
                    direction: PathArc.Clockwise
                }
                PathLine { x: screenCorners.cornerRadius; y: 0 }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    // ─── 3. Bottom-Left Corner ───────────────────────────────────
    PanelWindow {
        id: bottomLeftCorner
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: screenCorners.cornerRadius
        implicitWidth: screenCorners.cornerRadius
        color: "transparent"
        anchors {
            bottom: true
            left: true
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillColor: screenCorners.cornerColor
                startX: screenCorners.cornerRadius
                startY: screenCorners.cornerRadius
                PathArc {
                    x: 0
                    y: 0
                    radiusX: screenCorners.cornerRadius
                    radiusY: screenCorners.cornerRadius
                    direction: PathArc.Clockwise
                }
                PathLine { x: 0; y: screenCorners.cornerRadius }
                PathLine { x: screenCorners.cornerRadius; y: screenCorners.cornerRadius }
            }
        }
    }

    // ─── 4. Bottom-Right Corner ──────────────────────────────────
    PanelWindow {
        id: bottomRightCorner
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: screenCorners.cornerRadius
        implicitWidth: screenCorners.cornerRadius
        color: "transparent"
        anchors {
            bottom: true
            right: true
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillColor: screenCorners.cornerColor
                startX: 0
                startY: screenCorners.cornerRadius
                PathArc {
                    x: screenCorners.cornerRadius
                    y: 0
                    radiusX: screenCorners.cornerRadius
                    radiusY: screenCorners.cornerRadius
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: screenCorners.cornerRadius; y: screenCorners.cornerRadius }
                PathLine { x: 0; y: screenCorners.cornerRadius }
            }
        }
    }
}
