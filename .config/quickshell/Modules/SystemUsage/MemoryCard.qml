import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

SystemUsageCard {
    id: root

    property int memUsage: Math.round(SystemStats.memUsage)
    property string memSizeText: SystemStats.memSizeText

    icon: "memory"
    title: "RAM"
    usage: root.memUsage

    ColumnLayout {
        spacing: Constants.size3Xs
        Layout.fillWidth: true

        SystemUsageMetric {
            label: "used"
            value: SystemStats.memUsed.toFixed(1) + " GiB"
        }

        SystemUsageMetric {
            label: "total"
            value: SystemStats.memTotal
        }

    }

}
