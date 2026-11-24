import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

Item {
    id: root

    implicitWidth: configColumn.implicitWidth
    implicitHeight: configColumn.implicitHeight

    ColumnLayout {
        id: configColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Constants.sizeSm

        ThemedText {
            text: "Session settings"
            customSize: Constants.sizeMd
            font.weight: Font.Bold
            color: Theme.fg
        }

        Divider {
        }

        SettingSpinBox {
            label: "Focus"
            description: "Minutes per focus session"
            from: 5
            to: 120
            stepSize: 5
            defaultValue: 25
            value: PomodoroService.focusMinutes
            suffix: " min"
            onMoved: (val) => {
                PomodoroService.focusMinutes = Math.round(val);
            }
        }

        SettingSpinBox {
            label: "Short break"
            description: "Minutes between focus sessions"
            from: 1
            to: 30
            stepSize: 1
            defaultValue: 5
            value: PomodoroService.shortBreakMinutes
            suffix: " min"
            onMoved: (val) => {
                PomodoroService.shortBreakMinutes = Math.round(val);
            }
        }

        SettingSpinBox {
            label: "Long break"
            description: "Minutes after a full cycle"
            from: 5
            to: 60
            stepSize: 5
            defaultValue: 15
            value: PomodoroService.longBreakMinutes
            suffix: " min"
            onMoved: (val) => {
                PomodoroService.longBreakMinutes = Math.round(val);
            }
        }

        SettingSpinBox {
            label: "Long break every"
            description: "Focus sessions per cycle"
            from: 2
            to: 12
            stepSize: 1
            defaultValue: 4
            value: PomodoroService.longBreakEvery
            suffix: " sessions"
            onMoved: (val) => {
                PomodoroService.longBreakEvery = Math.round(val);
            }
        }

        Divider {
        }

        SettingToggle {
            label: "Auto-start next phase"
            description: "Start the next timer automatically"
            checked: PomodoroService.autoStart
            onToggled: (checked) => {
                PomodoroService.autoStart = checked;
            }
        }

        SettingToggle {
            label: "Notifications"
            description: "Notify when a phase ends"
            checked: PomodoroService.notifications
            onToggled: (checked) => {
                PomodoroService.notifications = checked;
            }
        }

        SettingToggle {
            label: "Sound"
            description: "Play a chime when a phase ends"
            checked: PomodoroService.soundEnabled
            onToggled: (checked) => {
                PomodoroService.soundEnabled = checked;
            }
        }

        Item {
            Layout.fillHeight: true
        }

    }

}
