import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    readonly property int gpuUsage: {
        let maxUsage = SystemStats.gpuUsage;
        for (let i = 0; i < SystemStats.gpus.length; i++)
            maxUsage = Math.max(maxUsage, SystemStats.gpus[i].usage || 0);
        return Math.round(maxUsage);
    }
    readonly property string gpuTempText: {
        let temp = SystemStats.gpuTemp;
        for (let i = 0; i < SystemStats.gpus.length; i++) {
            let current = SystemStats.gpus[i].temp || "";
            if (current !== "" && current !== "0°C")
                temp = current;
        }
        return temp;
    }

    implicitHeight: SettingsService.barWidgetHeight
    implicitWidth: statsRow.implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        id: statsRow

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Constants.size2Xs

        Row {
            spacing: 5
            Layout.alignment: Qt.AlignVCenter

            ThemedText {
                text: "CPU"
                customSize: 9
                color: Theme.muted
                anchors.verticalCenter: parent.verticalCenter
            }
            ThemedText {
                text: Math.round(SystemStats.cpuUsage) + "%"
                customSize: 11
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: 1
            height: 12
            color: Theme.muted
            opacity: 0.4
            Layout.alignment: Qt.AlignVCenter
        }

        Row {
            spacing: 5
            Layout.alignment: Qt.AlignVCenter

            ThemedText {
                text: "RAM"
                customSize: 9
                color: Theme.muted
                anchors.verticalCenter: parent.verticalCenter
            }
            ThemedText {
                text: Math.round(SystemStats.memUsage) + "%"
                customSize: 11
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: 1
            height: 12
            color: Theme.muted
            opacity: 0.4
            Layout.alignment: Qt.AlignVCenter
        }

        Row {
            spacing: 5
            Layout.alignment: Qt.AlignVCenter

            ThemedText {
                text: "GPU"
                customSize: 9
                color: Theme.muted
                anchors.verticalCenter: parent.verticalCenter
            }
            ThemedText {
                text: root.gpuUsage + "%"
                customSize: 11
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: 1
            height: 12
            color: Theme.muted
            opacity: 0.4
            Layout.alignment: Qt.AlignVCenter
        }

        Row {
            spacing: 5
            Layout.alignment: Qt.AlignVCenter

            ThemedText {
                text: "TEMP"
                customSize: 9
                color: Theme.muted
                anchors.verticalCenter: parent.verticalCenter
            }
            ThemedText {
                text: SystemStats.cpuTemp
                customSize: 11
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: 1
            height: 12
            color: Theme.muted
            opacity: 0.4
            Layout.alignment: Qt.AlignVCenter
        }

        Row {
            spacing: 5
            Layout.alignment: Qt.AlignVCenter

            SvgIcon {
                icon: SystemInfoService.isPluggedIn ? "battery-charging" : "battery"
                iconColor: SystemInfoService.isPluggedIn ? Theme.accent : Theme.fg
                iconSize: Constants.sizeSm
                flat: true
                anchors.verticalCenter: parent.verticalCenter
            }
            ThemedText {
                text: SystemInfoService.batteryLevel + "%"
                customSize: 11
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: AppState.toggleWidget("systemUsage")
    }

    ToolTip {
        parent: root
        visible: mouseArea.containsMouse
        text: "CPU " + SystemStats.cpuTemp + "   •   GPU " + root.gpuTempText + "\nClick for full system usage"
        delay: 300
    }

}
