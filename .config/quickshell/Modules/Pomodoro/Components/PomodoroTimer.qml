import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    readonly property color phaseColor: PomodoroService.isFocus ? Theme.accent : Theme.accentComplementary
    readonly property string statusText: PomodoroService.running ? "In progress" : (PomodoroService.isIdle ? "Ready to start" : "Paused")

    implicitWidth: timerColumn.implicitWidth
    implicitHeight: timerColumn.implicitHeight

    ColumnLayout {
        id: timerColumn

        anchors.fill: parent
        spacing: Constants.sizeXl

        PomodoroPhaseChips {
            Layout.alignment: Qt.AlignHCenter
            currentPhase: PomodoroService.phase
            onPhaseSelected: (phase) => {
                PomodoroService.setPhase(phase);
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Item {
            implicitWidth: 200
            implicitHeight: 200
            Layout.alignment: Qt.AlignHCenter

            PomodoroRing {
                anchors.fill: parent
                progress: PomodoroService.progress
                accentColor: root.phaseColor
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Constants.size3Xs

                ThemedText {
                    Layout.alignment: Qt.AlignHCenter
                    text: PomodoroService.phaseLabel
                    customSize: Constants.sizeXs + 2
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.9
                    color: root.phaseColor
                }

                ThemedText {
                    Layout.alignment: Qt.AlignHCenter
                    text: PomodoroService.formattedTime
                    customSize: Constants.size5Xl
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                ThemedText {
                    Layout.alignment: Qt.AlignHCenter
                    text: PomodoroService.cyclePosition + " / " + PomodoroService.longBreakEvery
                    customSize: Constants.sizeSm
                    color: Theme.muted
                }

            }

        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Constants.sizeMd

            SvgIconButton {
                icon: "refresh"
                iconSize: Constants.sizeLg
                padding: Constants.sizeSm
                onClicked: PomodoroService.reset()
            }

            SvgIconButton {
                icon: PomodoroService.running ? "player-pause" : "player-play"
                iconSize: Constants.size2Xl
                padding: Constants.sizeSm
                isActive: true
                onClicked: PomodoroService.toggle()
            }

            SvgIconButton {
                visible: !PomodoroService.isFocus
                icon: "player-next"
                iconSize: Constants.sizeLg
                padding: Constants.sizeSm
                onClicked: PomodoroService.skip()
            }

            // Keeps the controls centered when the skip button is hidden
            // during focus sessions.
            Item {
                visible: PomodoroService.isFocus
                implicitWidth: Constants.sizeLg + Constants.sizeSm * 2
                implicitHeight: Constants.sizeLg + Constants.sizeSm * 2
            }

        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Constants.size3Xs

            ThemedText {
                Layout.alignment: Qt.AlignHCenter
                text: root.statusText
                customSize: Constants.sizeXs + 2
                color: Theme.muted
            }

            ThemedText {
                Layout.alignment: Qt.AlignHCenter
                text: PomodoroService.todayCompletedCount + " completed today"
                customSize: Constants.sizeXs + 2
                color: Theme.muted
            }

        }

        Item {
            Layout.fillHeight: true
        }

    }

}
