import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Services

Item {
    id: root

    property var widget: null
    readonly property real defaultWidth: 650

    implicitWidth: defaultWidth
    implicitHeight: mainLayout.implicitHeight
    width: implicitWidth
    height: implicitHeight

    ColumnLayout {
        id: mainLayout

        anchors.fill: parent
        spacing: Constants.sizeLg

        // Row 1: CPU + Memory
        RowLayout {
            spacing: Constants.sizeLg
            Layout.fillWidth: true

            StorageCard {
                implicitWidth: 380
                Layout.fillHeight: true
                disks: SystemStats.disks
            }

            MemoryCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

        }

        // Row 2: Storage (with disk selector) + GPU
        RowLayout {
            spacing: Constants.sizeLg
            Layout.fillWidth: true

            CpuCard {
                Layout.fillWidth: true
                implicitWidth: 290
                Layout.fillHeight: true
            }

            GpuCard {
                Layout.fillWidth: visible
                Layout.fillHeight: true
                visible: SystemStats.hasGpu
            }

        }

    }

}
