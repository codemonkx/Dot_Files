import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

Item {
    id: root

    property string label: ""
    property string description: ""
    property int labelSize: Constants.sizeSm
    property bool isSubSetting: false
    // Rows without label/description are just a control container (e.g. inline selectors)
    readonly property bool isEmptyRow: label === "" && description === ""
    default property alias content: controlContainer.data

    implicitHeight: mainLayout.implicitHeight
    Layout.fillWidth: true

    RowLayout {
        id: mainLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: root.isEmptyRow ? 0 : Constants.sizeLg

        ColumnLayout {
            visible: !root.isEmptyRow
            spacing: Constants.size3Xs
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

            ThemedText {
                text: root.label
                customSize: root.labelSize
                font.weight: Font.Medium
                color: root.enabled ? Theme.fg : Theme.muted
            }

            ThemedText {
                text: root.description
                customSize: Constants.sizeXs + 3
                color: Theme.muted
                visible: root.description !== ""
            }

        }

        Item {
            Layout.fillWidth: true
        }

        Item {
            id: controlContainer

            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }

    }

}
