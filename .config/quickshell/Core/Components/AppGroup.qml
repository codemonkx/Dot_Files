import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

Card {
    id: root

    property string title: ""
    property string icon: ""
    property string badge: ""
    property bool showDividers: true
    // Vertical rhythm between the group's children. Groups that draw their own
    // dividers can tighten it without changing the default spacing.
    property int contentSpacing: Constants.size2Xl
    default property alias groupContent: contentLayout.data

    Layout.fillWidth: true
    contentPadding: Constants.sizeLg
    cardRadius: Constants.sizeSm
    useBorder: true

    ColumnLayout {
        id: mainLayout

        width: parent.width
        spacing: Constants.sizeLg

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs
            visible: root.title !== ""

            SvgIcon {
                visible: root.icon !== "" && root.icon !== "ghost"
                icon: root.icon
                iconSize: Constants.sizeMd
                iconColor: Theme.muted
                flat: true
            }

            ThemedText {
                text: root.title.toUpperCase()
                customSize: Constants.sizeXs + 2
                font.weight: Font.Bold
                font.letterSpacing: 0.9
                color: Theme.muted
                Layout.fillWidth: true
            }

            ThemedText {
                visible: root.badge !== ""
                text: root.badge
                customSize: Constants.sizeXs + 2
                color: Theme.muted
            }

        }

        Item {
            Layout.fillWidth: true
            implicitHeight: contentLayout.implicitHeight
            clip: true

            ColumnLayout {
                id: contentLayout

                anchors.fill: parent
                spacing: root.contentSpacing
            }

            Repeater {
                model: contentLayout.children.length

                Divider {
                    property var targetChild: contentLayout.children[index]

                    width: parent.width
                    y: targetChild ? targetChild.y + targetChild.height + ((Constants.size2Xl - 1) / 2) : 0
                    visible: {
                        if (!root.showDividers || contentLayout.implicitHeight <= 0)
                            return false;

                        if (!targetChild || !targetChild.visible || ('delegate' in targetChild && 'model' in targetChild))
                            return false;

                        for (let i = index + 1; i < contentLayout.children.length; i++) {
                            let c = contentLayout.children[i];
                            if (c.visible && !('delegate' in c && 'model' in c))
                                return true;

                        }
                        return false;
                    }
                }

            }

        }

    }

}
