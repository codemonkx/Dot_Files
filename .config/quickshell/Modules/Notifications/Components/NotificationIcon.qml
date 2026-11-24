import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

Item {
    id: root

    property var notifData
    property int iconSize: Constants.size3Xl
    property color iconColor: Theme.accent
    property color bgColor: Theme.bgSecondary
    property bool hasAppIcon: (notifData && notifData.appIcon && notifData.appIcon !== "") || (notifData && notifData.image)
    property bool isUrgencyIcon: !hasAppIcon

    function getUrgencyIcon() {
        if (!notifData)
            return "info-filled";

        if (notifData.urgency === 2)
            return "warning";

        if (notifData.urgency === 0)
            return "info";

        return "info-filled";
    }

    SvgIcon {
        anchors.fill: parent
        visible: !root.hasAppIcon
        icon: root.hasAppIcon ? "" : getUrgencyIcon()
        iconSize: root.isUrgencyIcon ? Constants.sizeLg : Constants.size2Xl
        iconColor: root.iconColor
        flat: root.isUrgencyIcon
        bgColor: root.isUrgencyIcon ? "transparent" : root.bgColor
        isCircle: false
    }

    Rectangle {
        id: imageBg

        anchors.fill: parent
        visible: root.hasAppIcon
        color: "transparent"
        radius: Constants.sizeXs

        Image {
            id: appImage

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            horizontalAlignment: Image.AlignLeft
            source: {
                if (!root.notifData)
                    return "";

                if (root.notifData.image)
                    return root.notifData.image;

                if (root.notifData.appIcon && root.notifData.appIcon !== "") {
                    if (root.notifData.appIcon.startsWith("file://"))
                        return root.notifData.appIcon;

                    if (root.notifData.appIcon.startsWith("/"))
                        return "file://" + root.notifData.appIcon;

                    return "image://icon/" + root.notifData.appIcon;
                }
                return "";
            }
            sourceSize: Qt.size(root.width > 0 ? root.width : root.iconSize, root.height > 0 ? root.height : root.iconSize)
            layer.enabled: true

            layer.effect: MultiEffect {
                maskEnabled: true
                // Keep a real 0..1 alpha ramp so the antialiased rounded
                // corners are not promoted to fully opaque.
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1

                maskSource: ShaderEffectSource {
                    visible: false
                    hideSource: true
                    smooth: true

                    sourceItem: Rectangle {
                        width: root.width > 0 ? root.width : root.iconSize
                        height: root.height > 0 ? root.height : root.iconSize
                        radius: Constants.sizeXs
                        antialiasing: true
                        color: Theme.white
                    }

                }

            }

        }

    }

}
