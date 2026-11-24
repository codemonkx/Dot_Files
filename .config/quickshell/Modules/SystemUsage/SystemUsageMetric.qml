import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

RowLayout {
    id: root

    property string label: ""
    property string value: ""

    spacing: Constants.size2Xs

    ThemedText {
        text: root.label.toUpperCase()
        customSize: Constants.sizeXs
        font.bold: true
        color: Theme.muted
        Layout.alignment: Qt.AlignVCenter
    }

    ThemedText {
        text: root.value
        customSize: Constants.sizeXs + 1
        font.weight: Font.Medium
        color: Theme.fg
        Layout.alignment: Qt.AlignVCenter
    }

}
