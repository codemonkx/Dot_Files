import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: calendarWindow

    property bool isOpen: false
    signal openRequested()
    signal closeRequested()

    property int barHeight: 40
    property real barScale: 1.2

    // Theme properties matching Bar and Shell
    property color bgColor: "#121213"
    property color bgColor2: "#1E1E1E"
    property color bgColor3: "#262626"
    property color fgColor: "#CDD6F4"
    property color accentColor: "#89B4FA"
    property color accentColorGlow: "#B4BEFE"
    property string mainFont: "Rowdies"
    property string textFont: "Inter"
    property string iconFont: "JetBrainsMono NF"

    // Active calendar navigation state
    property var today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth() // 0-11
    property int selectedDay: today.getDate()

    function prevMonth() {
        if (viewMonth === 0) {
            viewMonth = 11
            viewYear--
        } else {
            viewMonth--
        }
    }

    function nextMonth() {
        if (viewMonth === 11) {
            viewMonth = 0
            viewYear++
        } else {
            viewMonth++
        }
    }

    function goToToday() {
        viewYear = today.getFullYear()
        viewMonth = today.getMonth()
        selectedDay = today.getDate()
    }

    function closeCalendar() {
        closeRequested()
    }

    property real lastOpenTime: 0
    onIsOpenChanged: {
        if (isOpen) {
            lastOpenTime = Date.now()
            today = new Date()
            goToToday()
            dropUpAnim.stop()
            calendarRootItem.opacity = 1.0
            dropDownAnim.restart()
        } else {
            dropDownAnim.stop()
            dropUpAnim.restart()
        }
    }

    // ─── Window Configuration ─────────────────────────────────
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: isOpen || dropDownAnim.running || dropUpAnim.running

    // Dismiss on click outside
    MouseArea {
        id: backdrop
        anchors.fill: parent
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            let elapsed = Date.now() - calendarWindow.lastOpenTime
            if (elapsed < 300) {
                mouse.accepted = true
                return
            }
            let cardLeft = calendarRootItem.x - 10
            let cardRight = calendarRootItem.x + calendarRootItem.width + 10
            let cardTop = calendarRootItem.y - 10
            let cardBottom = calendarRootItem.y + calendarRootItem.height + 10

            if (mouse.x >= cardLeft && mouse.x <= cardRight &&
                mouse.y >= cardTop && mouse.y <= cardBottom) {
                mouse.accepted = true
                return
            }
            if (mouse.button === Qt.LeftButton) {
                calendarWindow.closeCalendar()
            }
        }
    }

    // Escape key handling
    Item {
        focus: calendarWindow.isOpen
        Keys.onEscapePressed: calendarWindow.closeCalendar()
    }

    // ─── Animated Dropdown Container ──────────────────────────
    Item {
        id: calendarRootItem
        width: Math.round(330 * calendarWindow.barScale)
        height: Math.round(370 * calendarWindow.barScale)
        x: Math.round(16 * calendarWindow.barScale)

        property real openY: barHeight + 8
        property real closedY: -height - 20

        y: isOpen ? openY : closedY
        opacity: 0.0

        ParallelAnimation {
            id: dropDownAnim
            NumberAnimation {
                target: calendarRootItem
                property: "y"
                from: calendarRootItem.closedY
                to: calendarRootItem.openY
                duration: 280
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: calendarRootItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            id: dropUpAnim
            NumberAnimation {
                target: calendarRootItem
                property: "y"
                to: calendarRootItem.closedY
                duration: 240
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: calendarRootItem
                property: "opacity"
                to: 0.0
                duration: 180
                easing.type: Easing.InCubic
            }
        }

        Rectangle {
            id: cardContainer
            width: parent.width
            height: parent.height
            color: calendarWindow.bgColor
            radius: Math.round(18 * calendarWindow.barScale)
            clip: true

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.75
                shadowBlur: 0.6
                shadowVerticalOffset: 6
            }

            // Prevent backdrop click through card
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Math.round(16 * calendarWindow.barScale)
                spacing: Math.round(10 * calendarWindow.barScale)

                // ─── Top Header (Current Live Time & Date Badge) ───
                RowLayout {
                    Layout.fillWidth: true

                    Column {
                        spacing: 2
                        Text {
                            text: Qt.formatDateTime(calendarWindow.today, "hh:mm A")
                            font { family: calendarWindow.mainFont; pixelSize: Math.round(18 * calendarWindow.barScale) }
                            color: calendarWindow.accentColor
                        }
                        Text {
                            text: Qt.formatDateTime(calendarWindow.today, "dddd, MMMM dd")
                            font { family: calendarWindow.textFont; pixelSize: Math.round(11 * calendarWindow.barScale); weight: Font.Medium }
                            color: calendarWindow.fgColor
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Jump to Today button
                    Rectangle {
                        implicitWidth: Math.round(58 * calendarWindow.barScale)
                        implicitHeight: Math.round(24 * calendarWindow.barScale)
                        radius: Math.round(12 * calendarWindow.barScale)
                        color: todayBtnArea.containsMouse ? Qt.rgba(137/255, 180/255, 250/255, 0.25) : calendarWindow.bgColor2

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Today"
                            font { family: calendarWindow.textFont; pixelSize: Math.round(10 * calendarWindow.barScale); weight: Font.Bold }
                            color: todayBtnArea.containsMouse ? calendarWindow.accentColorGlow : calendarWindow.accentColor
                        }

                        MouseArea {
                            id: todayBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendarWindow.goToToday()
                        }
                    }
                }

                // ─── Month Navigation Row ─────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: Math.round(32 * calendarWindow.barScale)
                    color: calendarWindow.bgColor2
                    radius: Math.round(10 * calendarWindow.barScale)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(8 * calendarWindow.barScale)
                        anchors.rightMargin: Math.round(8 * calendarWindow.barScale)

                        // Previous Month Button
                        Rectangle {
                            width: Math.round(24 * calendarWindow.barScale)
                            height: Math.round(24 * calendarWindow.barScale)
                            radius: Math.round(6 * calendarWindow.barScale)
                            color: prevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf053" // fa-chevron-left
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: Math.round(10 * calendarWindow.barScale) }
                                color: prevMouse.containsMouse ? calendarWindow.accentColor : calendarWindow.fgColor
                            }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendarWindow.prevMonth()
                            }
                        }

                        // Month Year Label
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: {
                                let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
                                return months[calendarWindow.viewMonth] + " " + calendarWindow.viewYear
                            }
                            font { family: calendarWindow.mainFont; pixelSize: Math.round(13 * calendarWindow.barScale) }
                            color: calendarWindow.fgColor
                        }

                        // Next Month Button
                        Rectangle {
                            width: Math.round(24 * calendarWindow.barScale)
                            height: Math.round(24 * calendarWindow.barScale)
                            radius: Math.round(6 * calendarWindow.barScale)
                            color: nextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf054" // fa-chevron-right
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: Math.round(10 * calendarWindow.barScale) }
                                color: nextMouse.containsMouse ? calendarWindow.accentColor : calendarWindow.fgColor
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendarWindow.nextMonth()
                            }
                        }
                    }
                }

                // ─── Weekday Headers (Mo, Tu, We, Th, Fr, Sa, Su) ──
                Grid {
                    Layout.fillWidth: true
                    columns: 7
                    spacing: 0

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        Item {
                            width: (cardContainer.width - Math.round(32 * calendarWindow.barScale)) / 7
                            height: Math.round(20 * calendarWindow.barScale)

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font { family: calendarWindow.textFont; pixelSize: Math.round(11 * calendarWindow.barScale); weight: Font.Bold }
                                color: (index >= 5) ? calendarWindow.accentColorGlow : calendarWindow.accentColor
                            }
                        }
                    }
                }

                // ─── 42-Cell Days Grid ────────────────────────────
                Grid {
                    id: daysGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    spacing: 0

                    property var daysData: {
                        let list = []
                        let year = calendarWindow.viewYear
                        let month = calendarWindow.viewMonth

                        // First day of current month (Mon = 0)
                        let firstDay = new Date(year, month, 1)
                        let startDayIdx = (firstDay.getDay() + 6) % 7

                        // Total days in current month
                        let totalDays = new Date(year, month + 1, 0).getDate()

                        // Total days in previous month
                        let prevTotalDays = new Date(year, month, 0).getDate()

                        // Leading days from previous month
                        for (let i = startDayIdx - 1; i >= 0; i--) {
                            list.push({ day: prevTotalDays - i, isCurrentMonth: false, isToday: false })
                        }

                        // Current month days
                        let isThisMonthAndYear = (year === calendarWindow.today.getFullYear() && month === calendarWindow.today.getMonth())
                        let todayDate = calendarWindow.today.getDate()

                        for (let d = 1; d <= totalDays; d++) {
                            let isToday = isThisMonthAndYear && (d === todayDate)
                            list.push({ day: d, isCurrentMonth: true, isToday: isToday })
                        }

                        // Trailing days from next month
                        let remaining = 42 - list.length
                        for (let n = 1; n <= remaining; n++) {
                            list.push({ day: n, isCurrentMonth: false, isToday: false })
                        }

                        return list
                    }

                    Repeater {
                        model: daysGrid.daysData
                        delegate: Item {
                            width: (cardContainer.width - Math.round(32 * calendarWindow.barScale)) / 7
                            height: Math.round(34 * calendarWindow.barScale)

                            readonly property bool isToday: modelData.isToday
                            readonly property bool isCurrentMonth: modelData.isCurrentMonth
                            readonly property bool isSelected: isCurrentMonth && (modelData.day === calendarWindow.selectedDay)

                            Rectangle {
                                id: cellCircle
                                width: Math.round(26 * calendarWindow.barScale)
                                height: Math.round(26 * calendarWindow.barScale)
                                anchors.centerIn: parent
                                radius: width / 2

                                color: isToday ? calendarWindow.accentColor : 
                                       (isSelected ? Qt.rgba(137/255, 180/255, 250/255, 0.25) : 
                                       (dayMouse.containsMouse && isCurrentMonth ? Qt.rgba(1, 1, 1, 0.1) : "transparent"))

                                border.width: (isSelected && !isToday) ? 1 : 0
                                border.color: calendarWindow.accentColor

                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font { 
                                    family: calendarWindow.textFont
                                    pixelSize: Math.round(11 * calendarWindow.barScale)
                                    weight: (isToday || isSelected) ? Font.Bold : Font.Normal 
                                }
                                color: isToday ? calendarWindow.bgColor : 
                                       (isCurrentMonth ? calendarWindow.fgColor : Qt.rgba(205/255, 214/255, 244/255, 0.25))
                            }

                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                hoverEnabled: isCurrentMonth
                                cursorShape: isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (isCurrentMonth) {
                                        calendarWindow.selectedDay = modelData.day
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
