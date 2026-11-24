import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

SystemUsageCard {
    id: root

    property int selectedIndex: 0
    readonly property var gpus: SystemStats.gpus.length > 0 ? SystemStats.gpus : (SystemStats.hasGpu ? [{
        "name": SystemStats.gpuName,
        "temp": SystemStats.gpuTemp,
        "usage": SystemStats.gpuUsage,
        "vram": SystemStats.gpuVram
    }] : [])
    readonly property var currentGpu: gpus.length > 0 ? gpus[Math.min(selectedIndex, gpus.length - 1)] : null
    readonly property var gpuLabels: root.gpus.map((gpu) => {
        return root.gpuLabel(gpu);
    })
    readonly property var gpuTextMap: {
        let map = {
        };
        for (let i = 0; i < root.gpuLabels.length; i++) map[root.gpuLabels[i]] = root.gpuLabels[i]
        return map;
    }

    function cleanName(name) {
        if (!name)
            return "GPU";

        return name.replace(/\(R\)|\(TM\)/g, "").replace(/\s*(?:Corporation|Graphics\s*Controller|Graphics|Laptop\s*GPU|Mobile|PCIe|DirectX)\s*/gi, " ").replace(/\s+/g, " ").trim();
    }

    function gpuLabel(gpu) {
        return gpu ? cleanName(gpu.name) : "";
    }

    visible: root.gpus.length > 0
    icon: "gpu"
    usage: root.currentGpu ? Math.round(root.currentGpu.usage || 0) : 0

    ColumnLayout {
        spacing: Constants.size3Xs
        Layout.fillWidth: true

        SystemUsageMetric {
            label: "temp"
            value: root.currentGpu ? (root.currentGpu.temp || "0°C") : "0°C"
        }

        SystemUsageMetric {
            label: "vram"
            value: root.currentGpu ? (root.currentGpu.vram || "GPU Active") : "GPU Active"
            visible: root.currentGpu && root.currentGpu.vram !== "None"
        }

    }

    // Title: plain label with a single GPU, selector when there are several
    titleSlot: Item {
        width: parent.width
        implicitHeight: root.gpus.length > 1 ? Constants.size3Xl : titleLabel.implicitHeight

        ThemedText {
            id: titleLabel

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            visible: root.gpus.length <= 1
            text: root.currentGpu ? root.gpuLabel(root.currentGpu) : ""
            customSize: Constants.sizeSm
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            color: Theme.fg
        }

        ThemedSelect {
            anchors.left: parent.left
            width: parent.width
            visible: root.gpus.length > 1
            comboWidth: width
            customSize: Constants.sizeSm
            fallbackText: "—"
            model: root.gpuLabels
            textMap: root.gpuTextMap
            currentIndex: root.selectedIndex
            onActivated: (idx) => {
                root.selectedIndex = idx;
            }

            // Keep the index valid when the GPU list changes externally
            Connections {
                function onGpusChanged() {
                    if (root.selectedIndex >= root.gpus.length)
                        root.selectedIndex = 0;

                }

                target: root
            }

        }

    }

}
