import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Utils
import qs.Modules.Notifications.Components

Rectangle {
    id: delegateRoot

    property var notifData
    property var notificationService
    property int itemIndex: -1
    property var currentTime
    property bool expanded: false
    property bool isDeletingAnim: false
    property bool flat: false
    readonly property real targetHeight: isDeletingAnim ? 0 : (delegateLayout.implicitHeight + Constants.sizeLg * 2)
    readonly property var parsedNotif: NotificationUtils.parse(notifData)

    function startDeleteAnimation() {
        if (isDeletingAnim)
            return ;

        isDeletingAnim = true;
    }

    width: ListView.view ? ListView.view.width : 400
    height: targetHeight
    color: delegateRoot.flat ? "transparent" : (delegateMouseArea.containsMouse && !delegateRoot.isDeletingAnim ? Theme.bgSecondary : Theme.bgTertiary)
    radius: delegateRoot.flat ? 0 : Constants.sizeXl
    z: isDeletingAnim ? 1 : 2
    clip: true
    opacity: isDeletingAnim ? 0 : 1

    Rectangle {
        id: flatHoverBackground

        visible: delegateRoot.flat
        anchors.fill: parent
        anchors.margins: Constants.size2Xs
        radius: Constants.sizeLg
        color: delegateMouseArea.containsMouse && !delegateRoot.isDeletingAnim ? Theme.bgSecondary : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Constants.animFast
            }

        }

    }

    Item {
        id: delegateContent

        anchors.fill: parent
        x: delegateRoot.isDeletingAnim ? 36 : 0
        scale: delegateRoot.isDeletingAnim ? 0.94 : 1
        transformOrigin: Item.Center

        MouseArea {
            id: delegateMouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !delegateRoot.isDeletingAnim
            onClicked: delegateRoot.startDeleteAnimation()
        }

        RowLayout {
            id: delegateLayout

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Constants.sizeLg
            spacing: Constants.sizeSm

            NotificationIcon {
                id: iconContainer

                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                Layout.topMargin: Constants.size3Xs
                Layout.preferredWidth: iconContainer.isUrgencyIcon ? Constants.sizeLg : Constants.size3Xl
                Layout.preferredHeight: iconContainer.isUrgencyIcon ? Constants.sizeLg : Constants.size3Xl
                notifData: delegateRoot.notifData
                bgColor: "transparent"
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Constants.size3Xs

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Constants.sizeXs

                    ThemedText {
                        id: summaryText

                        text: delegateRoot.parsedNotif.title
                        color: Theme.fg
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        maximumLineCount: delegateRoot.expanded ? 100 : 1
                        wrapMode: Text.Wrap
                    }

                    ThemedText {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: Constants.size2Xs
                        text: {
                            if (!delegateRoot.notifData)
                                return "";

                            let ts = delegateRoot.notifData.timestamp;
                            if (!ts)
                                return "Just now";

                            return TimeUtils.timeAgo(ts, delegateRoot.currentTime);
                        }
                        color: Theme.muted
                        customSize: Constants.sizeXs + 2
                    }

                    SvgIconButton {
                        id: expandButton

                        Layout.alignment: Qt.AlignVCenter
                        padding: Constants.size2Xs
                        iconSize: Constants.sizeXs + 2
                        icon: "chevron-down"
                        iconColor: Theme.muted
                        rotation: delegateRoot.expanded ? 180 : 0
                        visible: bodyText.truncated || summaryText.truncated || delegateRoot.expanded
                        enabled: !delegateRoot.isDeletingAnim
                        flat: true
                        onClicked: {
                            delegateRoot.expanded = !delegateRoot.expanded;
                        }

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Constants.animNormal
                                easing.type: Easing.OutQuint
                            }

                        }

                    }

                }

                ThemedText {
                    id: bodyText

                    text: delegateRoot.parsedNotif.message
                    color: Theme.muted
                    customSize: Constants.sizeXs + 2
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    maximumLineCount: delegateRoot.expanded ? 100 : 2
                    elide: Text.ElideRight
                    visible: text !== ""
                }

            }

        }

        Behavior on x {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutCubic
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutCubic
            }

        }

    }

    Behavior on color {
        ColorAnimation {
            duration: Constants.animFast
        }

    }

    Behavior on height {
        NumberAnimation {
            duration: delegateRoot.isDeletingAnim ? Math.round(180 * Constants.durationFactor) : Constants.animNormal
            easing.type: delegateRoot.isDeletingAnim ? Easing.InOutCubic : Easing.OutQuint
            onRunningChanged: {
                if (!running && delegateRoot.isDeletingAnim) {
                    if (delegateRoot.notificationService) {
                        if (delegateRoot.notifData && delegateRoot.notifData.notificationId)
                            delegateRoot.notificationService.removeNotification(delegateRoot.notifData.notificationId);
                        else if (delegateRoot.itemIndex >= 0)
                            delegateRoot.notificationService.removeHistoryItem(delegateRoot.itemIndex);
                    }
                }
            }
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutQuad
        }

    }

}
