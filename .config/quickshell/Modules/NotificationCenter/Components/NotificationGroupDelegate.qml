import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Utils
import qs.Modules.Notifications.Components

Item {
    id: root

    property var groupData
    property var notificationService
    property var currentTime
    property bool expanded: false
    readonly property int notificationCount: groupData && groupData.items ? groupData.items.length : 0
    readonly property bool isGroup: notificationCount > 1
    readonly property var latest: groupData ? groupData.latest : null
    readonly property var latestParsed: NotificationUtils.parse(latest)
    readonly property var restItems: isGroup ? groupData.items.filter(function(n) {
        return n !== latest;
    }) : []

    signal toggleRequested()
    signal clearGroupRequested()

    width: ListView.view ? ListView.view.width : 400
    implicitHeight: root.isGroup ? card.implicitHeight : singleDelegate.height
    height: implicitHeight

    NotificationItemDelegate {
        id: singleDelegate

        width: root.width
        visible: !root.isGroup
        currentTime: root.currentTime
        itemIndex: -1
        notifData: root.isGroup ? null : (root.groupData ? root.groupData.items[0] : null)
        notificationService: root.notificationService
    }

    Rectangle {
        id: card

        width: root.width
        visible: root.isGroup
        implicitHeight: cardColumn.implicitHeight
        height: implicitHeight
        color: Theme.bgTertiary
        radius: Constants.sizeXl
        clip: true

        Column {
            id: cardColumn

            width: parent.width

            Item {
                id: cover

                width: cardColumn.width
                implicitHeight: coverLayout.implicitHeight + Constants.sizeLg * 2
                height: implicitHeight

                Rectangle {
                    anchors.fill: parent
                    color: coverHover.hovered ? Theme.bgSecondary : "transparent"
                    radius: Constants.sizeXl

                    Behavior on color {
                        ColorAnimation {
                            duration: Constants.animFast
                        }

                    }

                }

                HoverHandler {
                    id: coverHover

                    cursorShape: Qt.PointingHandCursor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleRequested()
                }

                ColumnLayout {
                    id: coverLayout

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Constants.sizeLg
                    spacing: Constants.size2Xs

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Constants.sizeXs

                        NotificationIcon {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredHeight: Constants.size2Xl
                            Layout.preferredWidth: Constants.size2Xl
                            bgColor: "transparent"
                            notifData: root.groupData ? root.groupData.iconData : null
                        }

                        ThemedText {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            color: Theme.accent
                            customSize: Constants.sizeXs + 2
                            elide: Text.ElideRight
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.5
                            font.weight: Font.DemiBold
                            text: root.groupData ? root.groupData.appName : ""
                        }

                        ThemedText {
                            Layout.alignment: Qt.AlignVCenter
                            color: Theme.muted
                            customSize: Constants.sizeXs + 2
                            text: root.latest ? TimeUtils.timeAgo(root.latest.timestamp, root.currentTime) : ""
                        }

                        Rectangle {
                            id: clearButton

                            Layout.alignment: Qt.AlignVCenter
                            color: "transparent"
                            implicitHeight: Constants.size2Xl
                            implicitWidth: Constants.size2Xl
                            opacity: coverHover.hovered ? 1 : 0
                            radius: Constants.sizeXs

                            SvgIcon {
                                anchors.centerIn: parent
                                flat: true
                                icon: "trash"
                                iconColor: clearMouse.containsMouse ? Theme.accentComplementary : Theme.muted
                                iconSize: Constants.sizeSm
                            }

                            MouseArea {
                                id: clearMouse

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: coverHover.hovered
                                hoverEnabled: true
                                onClicked: root.clearGroupRequested()
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Constants.animFast
                                }

                            }

                        }

                    }

                    ThemedText {
                        Layout.fillWidth: true
                        color: Theme.fg
                        elide: Text.ElideRight
                        font.weight: Font.Medium
                        maximumLineCount: 2
                        text: root.latestParsed.title
                        visible: text !== ""
                        wrapMode: Text.Wrap
                    }

                    ThemedText {
                        Layout.fillWidth: true
                        color: Theme.muted
                        customSize: Constants.sizeXs + 2
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        text: root.latestParsed.message
                        visible: text !== ""
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Constants.size2Xs
                        spacing: Constants.size2Xs

                        ThemedText {
                            Layout.alignment: Qt.AlignVCenter
                            color: Theme.accent
                            customSize: Constants.sizeXs + 2
                            font.weight: Font.Medium
                            text: root.expanded ? "Show less" : (root.restItems.length + (root.restItems.length === 1 ? " more notification" : " more notifications"))
                        }

                        SvgIcon {
                            Layout.alignment: Qt.AlignVCenter
                            flat: true
                            icon: "chevron-down"
                            iconColor: Theme.accent
                            iconSize: Constants.sizeXs + 2
                            rotation: root.expanded ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Constants.animNormal
                                    easing.type: Easing.OutQuint
                                }

                            }

                        }

                        Item {
                            Layout.fillWidth: true
                        }

                    }

                }

            }

            Item {
                id: restWrapper

                width: cardColumn.width
                clip: true
                height: root.expanded ? restColumn.implicitHeight : 0

                Column {
                    id: restColumn

                    width: parent.width

                    Repeater {
                        model: root.restItems

                        delegate: Column {
                            width: restColumn.width

                            Rectangle {
                                x: Constants.sizeLg
                                width: parent.width - Constants.sizeLg * 2
                                height: 1
                                color: Theme.border
                            }

                            NotificationItemDelegate {
                                width: parent.width
                                flat: true
                                currentTime: root.currentTime
                                itemIndex: -1
                                notifData: modelData
                                notificationService: root.notificationService
                            }

                        }

                    }

                }

                Behavior on height {
                    NumberAnimation {
                        duration: Constants.animNormal
                        easing.type: Easing.OutQuint
                    }

                }

            }

        }

    }

}
