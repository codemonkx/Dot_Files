import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

Item {
    id: root

    property string currentPhase: "focus"
    readonly property var phases: [{
        "id": "focus",
        "label": "Focus"
    }, {
        "id": "shortBreak",
        "label": "Short break"
    }, {
        "id": "longBreak",
        "label": "Long break"
    }]

    signal phaseSelected(string phase)

    implicitWidth: chipRow.implicitWidth
    implicitHeight: chipRow.implicitHeight

    RowLayout {
        id: chipRow

        anchors.fill: parent
        spacing: Constants.sizeXs

        Repeater {
            model: root.phases

            delegate: Rectangle {
                id: chip

                required property var modelData
                readonly property bool active: root.currentPhase === modelData.id

                implicitWidth: chipLabel.implicitWidth + Constants.sizeXl
                implicitHeight: Constants.size2Xl + Constants.size2Xs
                radius: height / 2
                color: active ? Theme.bgAccent : (chipMouse.containsMouse ? Theme.bgSecondary : "transparent")
                border.width: 1
                border.color: active ? Theme.accent : Theme.border
                scale: chipMouse.pressed ? 0.97 : 1

                ThemedText {
                    id: chipLabel

                    anchors.centerIn: parent
                    text: chip.modelData.label
                    customSize: Constants.sizeXs + 2
                    font.weight: Font.DemiBold
                    color: chip.active ? Theme.accent : Theme.muted
                }

                MouseArea {
                    id: chipMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.phaseSelected(chip.modelData.id)
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Constants.animFast
                    }

                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Constants.animFast
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Constants.animFast
                        easing.type: Easing.OutBack
                    }

                }

            }

        }

    }

}
