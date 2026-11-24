import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

SystemUsageCard {
    id: root

    property string cpuName: cleanName(SystemStats.cpuModel)
    property string cpuTemp: SystemStats.cpuTemp
    property int cpuUsage: Math.round(SystemStats.cpuUsage)

    function cleanName(name) {
        if (!name)
            return "CPU";

        return name.replace(/\(R\)|\(TM\)/g, "").replace(/\s*(?:Processor|CPU|APU|\d+-Core|\d+\s*cores?|with.*Graphics)\s*/gi, " ").replace(/@\s*\d+(?:\.\d+)?\s*[Gg][Hh][Zz]/g, "").replace(/\s+/g, " ").trim();
    }

    icon: "cpu"
    title: root.cpuName
    usage: root.cpuUsage

    ColumnLayout {
        spacing: Constants.size3Xs
        Layout.fillWidth: true

        SystemUsageMetric {
            label: "temp"
            value: root.cpuTemp
        }

        SystemUsageMetric {
            label: "speed"
            value: SystemStats.cpuFreq
        }

        SystemUsageMetric {
            label: "cores"
            value: SystemStats.cpuCores
        }

    }

}
