import QtQuick
import QtQuick.Shapes
import qs.Core

Item {
    id: root

    property real progress: 0
    property color trackColor: Theme.border
    property color accentColor: Theme.accent
    property int thickness: Constants.sizeXs
    property int diameter: 200
    readonly property real radius: Math.max(0, Math.min(width, height) / 2 - thickness / 2)

    implicitWidth: diameter
    implicitHeight: diameter

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Inactive track
        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 0
                sweepAngle: 359.99
            }

        }

        // Elapsed time
        ShapePath {
            strokeColor: root.progress > 0.0001 ? root.accentColor : "transparent"
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 359.99 * Math.max(0, Math.min(1, root.progress))
            }

        }

    }

}
