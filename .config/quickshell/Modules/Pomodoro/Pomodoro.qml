import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Windows
import qs.Modules.Pomodoro.Components

AppWindow {
    id: root

    widgetId: "pomodoro"
    windowTitle: "Minflair Pomodoro"
    contentPadding: 0

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        AppHeader {
            title: "Pomodoro"
            category: "FOCUS"
            subtitle: PomodoroService.todayCompletedCount + (PomodoroService.todayCompletedCount === 1 ? " pomodoro completed today" : " pomodoros completed today")
            showDivider: false
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Constants.sizeLg
            Layout.rightMargin: Constants.sizeLg
            Layout.bottomMargin: Constants.sizeLg
            spacing: Constants.sizeLg

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                cardRadius: Constants.sizeLg

                PomodoroTimer {
                    anchors.fill: parent
                }

            }

            Card {
                Layout.preferredWidth: 380
                Layout.fillHeight: true
                cardRadius: Constants.sizeLg

                PomodoroConfig {
                    anchors.fill: parent
                }

            }

        }

    }

}
