import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: notificationPanelWindow

    property bool isOpen: false
    signal closeRequested()
    signal newNotification(var notif)

    // Theme properties matching Bar, ControlPanel, and FullMediaPlayer
    property color bgColor: "#121213"
    property color bgColor2: "#1E1E1E"
    property color bgColor3: "#262626"
    property color fgColor: "#CDD6F4"
    property color accentColor: "#89B4FA"
    property color accentColorGlow: "#B4BEFE"
    property string mainFont: "Rowdies"
    property string iconFont: "JetBrainsMono NF"
    property int barHeight: 40

    // ─── Do Not Disturb State ─────────────────────────────────
    property bool dndEnabled: false

    function toggleDnd() {
        dndEnabled = !dndEnabled
    }

    // ─── Notification Storage & Management ────────────────────
    property var notificationList: []
    readonly property int unreadCount: notificationList.length
    property var expandedApps: []

    function toggleAppExpanded(appName) {
        let copy = expandedApps.slice()
        let idx = copy.indexOf(appName)
        if (idx >= 0) {
            copy.splice(idx, 1)
        } else {
            copy.push(appName)
        }
        expandedApps = copy
    }

    function addNotification(item) {
        let copy = notificationList.slice()
        copy.unshift(item)
        notificationList = copy
    }

    function removeNotification(id) {
        let copy = []
        for (let i = 0; i < notificationList.length; i++) {
            if (notificationList[i].id === id) {
                if (notificationList[i].ref) {
                    try { notificationList[i].ref.dismiss() } catch(e) {}
                }
            } else {
                copy.push(notificationList[i])
            }
        }
        notificationList = copy
    }

    function removeAllByApp(appName) {
        let copy = []
        for (let i = 0; i < notificationList.length; i++) {
            if (notificationList[i].appName === appName) {
                if (notificationList[i].ref) {
                    try { notificationList[i].ref.dismiss() } catch(e) {}
                }
            } else {
                copy.push(notificationList[i])
            }
        }
        notificationList = copy
    }

    function clearAll() {
        for (let i = 0; i < notificationList.length; i++) {
            if (notificationList[i].ref) {
                try { notificationList[i].ref.dismiss() } catch(e) {}
            }
        }
        notificationList = []
        expandedApps = []
    }

    // Computed grouping by application name
    readonly property var groupedNotifications: {
        let list = notificationList
        let groups = []
        let groupMap = {}

        for (let i = 0; i < list.length; i++) {
            let item = list[i]
            let name = item.appName && item.appName.trim() !== "" ? item.appName : "Notification"
            if (!groupMap[name]) {
                let g = {
                    appName: name,
                    appIcon: item.appIcon || "",
                    items: [ item ],
                    latestTime: item.timeStr
                }
                groupMap[name] = g
                groups.push(g)
            } else {
                groupMap[name].items.push(item)
                if (!groupMap[name].appIcon && item.appIcon) {
                    groupMap[name].appIcon = item.appIcon
                }
            }
        }
        return groups
    }

    // ─── Quickshell Notification Server ───────────────────────
    NotificationServer {
        id: notifServer
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        persistenceSupported: true

        onNotification: (notif) => {
            notif.tracked = true

            let actionsList = []
            if (notif.actions) {
                for (let i = 0; i < notif.actions.length; i++) {
                    let act = notif.actions[i]
                    actionsList.push({
                        identifier: act.identifier,
                        text: act.text,
                        invoke: function() { act.invoke() }
                    })
                }
            }

            let resolved = ""
            if (notif.appIcon && notif.appIcon.trim() !== "") {
                let iconStr = notif.appIcon.trim()
                if (iconStr.startsWith("/") || iconStr.startsWith("file://")) {
                    resolved = iconStr.startsWith("/") ? ("file://" + iconStr) : iconStr
                } else {
                    let p = Quickshell.iconPath(iconStr)
                    if (p && p !== "") resolved = "file://" + p
                }
            }

            let item = {
                id: notif.id,
                ref: notif,
                appName: notif.appName && notif.appName.trim() !== "" ? notif.appName : "Notification",
                appIcon: resolved,
                summary: notif.summary || "",
                body: notif.body || "",
                image: notif.image || "",
                timeStr: Qt.formatDateTime(new Date(), "hh:mm A"),
                timestamp: Date.now(),
                actions: actionsList
            }

            notificationPanelWindow.addNotification(item)

            if (!notificationPanelWindow.dndEnabled) {
                notificationPanelWindow.newNotification(item)
            }
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            dropUpAnim.stop()
            panelRootItem.opacity = 1.0
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
        onClicked: notificationPanelWindow.closeRequested()
    }

    // Escape key handling
    Item {
        focus: notificationPanelWindow.isOpen
        Keys.onEscapePressed: notificationPanelWindow.closeRequested()
    }

    // ─── THE PANEL ROOT ITEM ──────────────────────────────────
    Item {
        id: panelRootItem
        width: cardContainer.width
        height: cardContainer.height

        // Aligned to the right side above the notification pill
        x: Math.round(notificationPanelWindow.width - width - 16)

        // Attached directly to the bottom edge of the top bar
        y: -cardContainer.height
        opacity: 0.0

        NumberAnimation {
            id: dropDownAnim
            target: panelRootItem
            property: "y"
            from: -cardContainer.height
            to: 0
            duration: 280
            easing.type: Easing.OutCubic
        }

        ParallelAnimation {
            id: dropUpAnim
            NumberAnimation {
                target: panelRootItem
                property: "y"
                to: -cardContainer.height
                duration: 240
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: panelRootItem
                property: "opacity"
                to: 0.0
                duration: 200
                easing.type: Easing.InQuad
            }
        }

        // Left curved fillet joining the card smoothly into the top bar
        Shape {
            width: 16
            height: 16
            transform: Scale { origin.y: 8; yScale: -1 }
            anchors {
                right: cardContainer.left
                top: cardContainer.top
            }
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillColor: notificationPanelWindow.bgColor
                startX: 16
                startY: 0
                PathLine { x: 16; y: 16 }
                PathLine { x: 0; y: 16 }
                PathCubic {
                    x: 16
                    y: 0
                    control1X: 8.836
                    control1Y: 16
                    control2X: 16
                    control2Y: 8.836
                }
            }

            ShapePath {
                strokeWidth: 1
                strokeColor: "#2C2C30"
                fillColor: "transparent"
                startX: 0
                startY: 16
                PathCubic {
                    x: 16
                    y: 0
                    control1X: 8.836
                    control1Y: 16
                    control2X: 16
                    control2Y: 8.836
                }
            }
        }

        // Right curved fillet joining the card smoothly into the top bar
        Shape {
            width: 16
            height: 16
            transform: Scale { origin.y: 8; yScale: -1 }
            anchors {
                left: cardContainer.right
                top: cardContainer.top
            }
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillColor: notificationPanelWindow.bgColor
                startX: 0
                startY: 0
                PathLine { x: 0; y: 16 }
                PathLine { x: 16; y: 16 }
                PathCubic {
                    x: 0
                    y: 0
                    control1X: 7.164
                    control1Y: 16
                    control2X: 0
                    control2Y: 8.836
                }
            }

            ShapePath {
                strokeWidth: 1
                strokeColor: "#2C2C30"
                fillColor: "transparent"
                startX: 16
                startY: 16
                PathCubic {
                    x: 0
                    y: 0
                    control1X: 7.164
                    control1Y: 16
                    control2X: 0
                    control2Y: 8.836
                }
            }
        }

        // ─── CARD CONTAINER ───────────────────────────────────
        Rectangle {
            id: cardContainer
            width: 410
            height: 540
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 24
            bottomRightRadius: 24
            color: notificationPanelWindow.bgColor
            border.width: 0
            border.color: "#2C2C30"

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.55
                shadowBlur: 0.5
                shadowVerticalOffset: 4
            }

            // Cover the top line so the card blends completely into the bar
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: 2
                color: notificationPanelWindow.bgColor
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    topMargin: 16
                    bottomMargin: 16
                    leftMargin: 18
                    rightMargin: 18
                }
                spacing: 12

                // ─── 1. Header Row (Title, Count, DND, Clear All) ─────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    spacing: 8

                    // Title
                    Text {
                        text: "Notifications"
                        font { family: notificationPanelWindow.mainFont; pixelSize: 17 }
                        color: "#FFFFFF"
                    }

                    // Count Badge
                    Rectangle {
                        visible: notificationPanelWindow.unreadCount > 0
                        implicitWidth: countText.implicitWidth + 14
                        implicitHeight: 20
                        radius: 10
                        color: notificationPanelWindow.bgColor2

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: notificationPanelWindow.unreadCount
                            font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                            color: notificationPanelWindow.accentColor
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // DND Toggle Button
                    Rectangle {
                        implicitWidth: dndRow.implicitWidth + 16
                        implicitHeight: 28
                        radius: 14
                        color: notificationPanelWindow.dndEnabled ? notificationPanelWindow.accentColor : (dndMouseArea.containsMouse ? Qt.lighter(notificationPanelWindow.bgColor2, 1.4) : notificationPanelWindow.bgColor2)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: dndRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: notificationPanelWindow.dndEnabled ? "\uf1f6" : "\uf0f3" // bell-slash / bell
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                color: notificationPanelWindow.dndEnabled ? notificationPanelWindow.bgColor : notificationPanelWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "DND"
                                font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                color: notificationPanelWindow.dndEnabled ? notificationPanelWindow.bgColor : notificationPanelWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: dndMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notificationPanelWindow.toggleDnd()
                        }
                    }

                    // Clear All Button
                    Rectangle {
                        visible: notificationPanelWindow.unreadCount > 0
                        implicitWidth: clearRow.implicitWidth + 14
                        implicitHeight: 28
                        radius: 14
                        color: clearMouseArea.containsMouse ? Qt.lighter(notificationPanelWindow.bgColor2, 1.5) : notificationPanelWindow.bgColor2

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: clearRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: "\uf1f8" // trash
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 10 }
                                color: notificationPanelWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Clear"
                                font { family: "Inter"; pixelSize: 11; weight: Font.Medium }
                                color: notificationPanelWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: clearMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notificationPanelWindow.clearAll()
                        }
                    }
                }


                // ─── 3. Notifications List ────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Empty State
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: notificationPanelWindow.unreadCount === 0
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "\uf0f3" // bell
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 38 }
                            color: Qt.rgba(1, 1, 1, 0.15)
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "No Notifications"
                            font { family: notificationPanelWindow.mainFont; pixelSize: 15 }
                            color: "#FFFFFF"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "You're all caught up!"
                            font { family: "Inter"; pixelSize: 12 }
                            color: "#71717A"
                        }
                    }

                    // Notification List View (Grouped by App)
                    ListView {
                        id: notifListView
                        anchors.fill: parent
                        clip: true
                        spacing: 10
                        visible: notificationPanelWindow.unreadCount > 0
                        model: notificationPanelWindow.groupedNotifications

                        delegate: Rectangle {
                            id: groupCard
                            readonly property var groupData: modelData
                            readonly property bool isGroup: groupData.items.length > 1
                            readonly property bool isExpanded: isGroup && (notificationPanelWindow.expandedApps.indexOf(groupData.appName) !== -1)

                            width: notifListView.width
                            height: cardContentLayout.implicitHeight + 22
                            radius: 14
                            color: notificationPanelWindow.bgColor2
                            border.width: 1
                            border.color: isGroup ? "#383840" : "#2C2C30"

                            Behavior on height {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }

                            ColumnLayout {
                                id: cardContentLayout
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    leftMargin: 12
                                    rightMargin: 12
                                    topMargin: 10
                                }
                                spacing: 8

                                // ─── CASE 1: SINGLE NOTIFICATION CARD ─────────────
                                RowLayout {
                                    visible: !groupCard.isGroup
                                    Layout.fillWidth: true
                                    spacing: 8

                                    // App Icon
                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 6
                                        color: notificationPanelWindow.bgColor3
                                        clip: true

                                        Image {
                                            id: singleIconImg
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            source: (!groupCard.isGroup && groupData.items[0].appIcon) ? groupData.items[0].appIcon : ""
                                            fillMode: Image.PreserveAspectFit
                                            visible: status === Image.Ready && source !== ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !singleIconImg.visible
                                            text: "\uf0f3" // bell
                                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 10 }
                                            color: notificationPanelWindow.accentColor
                                        }
                                    }

                                    // App Name
                                    Text {
                                        text: groupData.appName
                                        font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                        color: notificationPanelWindow.accentColor
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Time
                                    Text {
                                        text: (!groupCard.isGroup && groupData.items.length > 0) ? groupData.items[0].timeStr : ""
                                        font { family: "Inter"; pixelSize: 10 }
                                        color: "#71717A"
                                    }

                                    // Close button
                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: singleCloseArea.containsMouse ? Qt.lighter(notificationPanelWindow.bgColor3, 1.5) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf00d" // times
                                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 9 }
                                            color: singleCloseArea.containsMouse ? "#FFFFFF" : notificationPanelWindow.fgColor
                                        }

                                        MouseArea {
                                            id: singleCloseArea
                                             anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (!groupCard.isGroup && groupData.items.length > 0) {
                                                    notificationPanelWindow.removeNotification(groupData.items[0].id)
                                                }
                                            }
                                        }
                                    }
                                }

                                // Single Card Content
                                ColumnLayout {
                                    visible: !groupCard.isGroup
                                    Layout.fillWidth: true
                                    spacing: 5

                                    // Summary
                                    Text {
                                        Layout.fillWidth: true
                                        text: (!groupCard.isGroup && groupData.items.length > 0) ? groupData.items[0].summary : ""
                                        font { family: "Inter"; pixelSize: 13; weight: Font.Bold }
                                        color: "#FFFFFF"
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    // Body
                                    Text {
                                        Layout.fillWidth: true
                                        visible: (!groupCard.isGroup && groupData.items.length > 0 && groupData.items[0].body !== "")
                                        text: (!groupCard.isGroup && groupData.items.length > 0) ? groupData.items[0].body : ""
                                        font { family: "Inter"; pixelSize: 12 }
                                        color: notificationPanelWindow.fgColor
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 4
                                        elide: Text.ElideRight
                                    }

                                    // Image
                                    Image {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 120
                                        visible: (!groupCard.isGroup && groupData.items.length > 0 && groupData.items[0].image !== "" && status === Image.Ready)
                                        source: (!groupCard.isGroup && groupData.items.length > 0) ? groupData.items[0].image : ""
                                        fillMode: Image.PreserveAspectCrop
                                        clip: true
                                    }

                                    // Actions
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        visible: (!groupCard.isGroup && groupData.items.length > 0 && groupData.items[0].actions && groupData.items[0].actions.length > 0)

                                        Repeater {
                                            model: (!groupCard.isGroup && groupData.items.length > 0) ? groupData.items[0].actions : []

                                            delegate: Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 26
                                                radius: 13
                                                color: sActArea.containsMouse ? Qt.lighter(notificationPanelWindow.bgColor3, 1.4) : notificationPanelWindow.bgColor3
                                                border.color: "#2C2C30"
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.text
                                                    font { family: "Inter"; pixelSize: 11; weight: Font.DemiBold }
                                                    color: sActArea.containsMouse ? "#FFFFFF" : notificationPanelWindow.fgColor
                                                    elide: Text.ElideRight
                                                }

                                                MouseArea {
                                                    id: sActArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        modelData.invoke()
                                                        notificationPanelWindow.removeNotification(groupData.items[0].id)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // ─── CASE 2: GROUPED NOTIFICATIONS ───────────────
                                // Group Header
                                RowLayout {
                                    visible: groupCard.isGroup
                                    Layout.fillWidth: true
                                    spacing: 8

                                    // Group App Icon
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 6
                                        color: notificationPanelWindow.bgColor3
                                        clip: true

                                        Image {
                                            id: groupIconImg
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            source: groupData.appIcon ? groupData.appIcon : ""
                                            fillMode: Image.PreserveAspectFit
                                            visible: status === Image.Ready && source !== ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !groupIconImg.visible
                                            text: "\uf0f3" // bell
                                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                            color: notificationPanelWindow.accentColor
                                        }
                                    }

                                    // App Name
                                    Text {
                                        text: groupData.appName
                                        font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                        color: "#FFFFFF"
                                    }

                                    // Count Badge
                                    Rectangle {
                                        implicitWidth: groupCountText.implicitWidth + 12
                                        implicitHeight: 18
                                        radius: 9
                                        color: Qt.rgba(137/255, 180/255, 250/255, 0.16)
                                        border.width: 1
                                        border.color: notificationPanelWindow.accentColor

                                        Text {
                                            id: groupCountText
                                            anchors.centerIn: parent
                                            text: groupData.items.length
                                            font { family: "Inter"; pixelSize: 10; weight: Font.Bold }
                                            color: notificationPanelWindow.accentColor
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Time
                                    Text {
                                        text: groupData.latestTime
                                        font { family: "Inter"; pixelSize: 10 }
                                        color: "#71717A"
                                    }

                                    // Clear All for this Group Button
                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: grpCloseArea.containsMouse ? Qt.lighter(notificationPanelWindow.bgColor3, 1.5) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf00d" // times
                                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 10 }
                                            color: grpCloseArea.containsMouse ? "#FFFFFF" : notificationPanelWindow.fgColor
                                        }

                                        MouseArea {
                                            id: grpCloseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: notificationPanelWindow.removeAllByApp(groupData.appName)
                                        }
                                    }
                                }

                                // Collapsed View: Latest Item + Expand Button
                                ColumnLayout {
                                    visible: groupCard.isGroup && !groupCard.isExpanded
                                    Layout.fillWidth: true
                                    spacing: 6

                                    // Latest Notification Content
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            Layout.fillWidth: true
                                            text: groupData.items.length > 0 ? groupData.items[0].summary : ""
                                            font { family: "Inter"; pixelSize: 13; weight: Font.Bold }
                                            color: "#FFFFFF"
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: groupData.items.length > 0 && groupData.items[0].body !== ""
                                            text: groupData.items.length > 0 ? groupData.items[0].body : ""
                                            font { family: "Inter"; pixelSize: 12 }
                                            color: notificationPanelWindow.fgColor
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Sleek Expand Footer Bar
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 28
                                        radius: 8
                                        color: expMouseArea.containsMouse ? Qt.lighter(notificationPanelWindow.bgColor3, 1.4) : notificationPanelWindow.bgColor3
                                        border.color: "#35353C"
                                        border.width: 1

                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: "\uf107" // angle-down
                                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                                color: notificationPanelWindow.accentColor
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: "+ " + (groupData.items.length - 1) + " more from " + groupData.appName
                                                font { family: "Inter"; pixelSize: 11; weight: Font.Medium }
                                                color: notificationPanelWindow.accentColor
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: expMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: notificationPanelWindow.toggleAppExpanded(groupData.appName)
                                        }
                                    }
                                }

                                // Expanded View: List of all notifications from this group
                                ColumnLayout {
                                    visible: groupCard.isGroup && groupCard.isExpanded
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Repeater {
                                        model: groupCard.isExpanded ? groupData.items : []

                                        delegate: Rectangle {
                                            id: nestedCard
                                            readonly property var nestedItem: modelData
                                            Layout.fillWidth: true
                                            implicitHeight: nestedContent.implicitHeight + 16
                                            radius: 10
                                            color: notificationPanelWindow.bgColor3
                                            border.color: "#2C2C32"
                                            border.width: 1

                                            ColumnLayout {
                                                id: nestedContent
                                                anchors {
                                                    left: parent.left
                                                    right: parent.right
                                                    top: parent.top
                                                    leftMargin: 10
                                                    rightMargin: 10
                                                    topMargin: 8
                                                }
                                                spacing: 4

                                                // Sub Header: Time & Close
                                                RowLayout {
                                                    Layout.fillWidth: true

                                                    Text {
                                                        text: nestedItem.timeStr
                                                        font { family: "Inter"; pixelSize: 10 }
                                                        color: "#71717A"
                                                    }

                                                    Item { Layout.fillWidth: true }

                                                    Rectangle {
                                                        width: 16
                                                        height: 16
                                                        radius: 8
                                                        color: nestCloseArea.containsMouse ? Qt.lighter(notificationPanelWindow.bgColor2, 1.5) : "transparent"

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "\uf00d"
                                                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 8 }
                                                            color: nestCloseArea.containsMouse ? "#FFFFFF" : notificationPanelWindow.fgColor
                                                        }

                                                        MouseArea {
                                                            id: nestCloseArea
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: notificationPanelWindow.removeNotification(nestedItem.id)
                                                        }
                                                    }
                                                }

                                                // Summary
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: nestedItem.summary
                                                    font { family: "Inter"; pixelSize: 12; weight: Font.Bold }
                                                    color: "#FFFFFF"
                                                    wrapMode: Text.Wrap
                                                    maximumLineCount: 2
                                                    elide: Text.ElideRight
                                                }

                                                // Body
                                                Text {
                                                    Layout.fillWidth: true
                                                    visible: nestedItem.body !== ""
                                                    text: nestedItem.body
                                                    font { family: "Inter"; pixelSize: 11 }
                                                    color: notificationPanelWindow.fgColor
                                                    wrapMode: Text.Wrap
                                                    maximumLineCount: 3
                                                    elide: Text.ElideRight
                                                }

                                                // Image
                                                Image {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 100
                                                    visible: nestedItem.image !== "" && status === Image.Ready
                                                    source: nestedItem.image
                                                    fillMode: Image.PreserveAspectCrop
                                                    clip: true
                                                }

                                                // Actions
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6
                                                    visible: nestedItem.actions && nestedItem.actions.length > 0

                                                    Repeater {
                                                        model: nestedItem.actions || []

                                                        delegate: Rectangle {
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: 24
                                                            radius: 12
                                                            color: nActArea.containsMouse ? Qt.lighter(notificationPanelWindow.bgColor2, 1.4) : notificationPanelWindow.bgColor2
                                                            border.color: "#35353C"
                                                            border.width: 1

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: modelData.text
                                                                font { family: "Inter"; pixelSize: 10; weight: Font.DemiBold }
                                                                color: nActArea.containsMouse ? "#FFFFFF" : notificationPanelWindow.fgColor
                                                                elide: Text.ElideRight
                                                            }

                                                            MouseArea {
                                                                id: nActArea
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    modelData.invoke()
                                                                    notificationPanelWindow.removeNotification(nestedItem.id)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Collapse Bar
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 26
                                        radius: 8
                                        color: collMouseArea.containsMouse ? Qt.lighter(notificationPanelWindow.bgColor3, 1.4) : notificationPanelWindow.bgColor3

                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: "\uf106" // angle-up
                                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 10 }
                                                color: "#71717A"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: "Collapse"
                                                font { family: "Inter"; pixelSize: 11; weight: Font.Medium }
                                                color: "#71717A"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: collMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: notificationPanelWindow.toggleAppExpanded(groupData.appName)
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
}
