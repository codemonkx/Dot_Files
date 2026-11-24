import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

SystemUsageCard {
    id: root

    property var disks: []
    property int selectedIndex: 0
    readonly property var currentDisk: disks.length > 0 ? disks[Math.min(selectedIndex, disks.length - 1)] : null
    readonly property var diskLabels: root.disks.map((d) => {
        return diskLabel(d);
    })
    readonly property var diskTextMap: {
        let map = {
        };
        for (let i = 0; i < root.diskLabels.length; i++) map[root.diskLabels[i]] = root.diskLabels[i]
        return map;
    }

    function diskLabel(d) {
        if (!d)
            return "";

        let n = d.name;
        if (n.match(/^[0-9a-f]{8}-/i))
            return n.substring(0, 8) + "…";

        return n;
    }

    icon: "disk"
    usage: currentDisk ? currentDisk.usage : 0

    // Metrics for the active disk
    ColumnLayout {
        spacing: Constants.size3Xs
        Layout.fillWidth: true
        visible: root.currentDisk !== null

        SystemUsageMetric {
            label: "used"
            value: root.currentDisk ? root.currentDisk.usedGib.toFixed(1) + " GiB" : "—"
        }

        SystemUsageMetric {
            label: "total"
            value: root.currentDisk ? root.currentDisk.totalGib.toFixed(1) + " GiB" : "—"
        }

        SystemUsageMetric {
            label: "mount"
            value: {
                if (!root.currentDisk)
                    return "—";

                let m = root.currentDisk.mount;
                return m === "/" ? "/" : m.split("/").pop();
            }
        }

    }

    // Title: plain label with a single disk, selector when there are several
    titleSlot: Item {
        width: parent.width
        implicitHeight: root.disks.length > 1 ? Constants.size3Xl : titleLabel.implicitHeight

        ThemedText {
            id: titleLabel

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            visible: root.disks.length <= 1
            text: root.currentDisk ? root.diskLabel(root.currentDisk) : ""
            customSize: Constants.sizeSm
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            color: Theme.fg
        }

        ThemedSelect {
            anchors.left: parent.left
            width: parent.width
            visible: root.disks.length > 1
            comboWidth: width
            customSize: Constants.sizeSm
            fallbackText: "—"
            model: root.diskLabels
            textMap: root.diskTextMap
            currentIndex: root.selectedIndex
            onActivated: (idx) => {
                root.selectedIndex = idx;
            }

            // Keep the index valid when the disk list changes externally
            Connections {
                function onDisksChanged() {
                    if (root.selectedIndex >= root.disks.length)
                        root.selectedIndex = 0;

                }

                target: root
            }

        }

    }

}
