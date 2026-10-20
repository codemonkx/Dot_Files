import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: trayMenuWindow

    property bool isOpen: false
    signal openRequested()
    signal closeRequested()

    property var targetItem: null
    property real targetX: 0
    property int barHeight: 40

    property color bgColor: "#121213"
    property color bgColor2: "#1E1E1E"
    property color fgColor: "#CDD6F4"
    property color accentColor: "#89B4FA"
    property color accentColorGlow: "#B4BEFE"
    property string mainFont: "Inter"
    property string iconFont: "JetBrainsMono NF"

    // Submenu navigation stack
    property var menuStack: []
    property var currentMenuHandle: null
    property string currentMenuTitle: ""

    function formatAppTitle(item) {
        if (!item) return "Options"
        if (item.title && item.title.trim() !== "") return item.title
        let id = (item.id || "").toLowerCase()
        if (id.indexOf("vesktop") !== -1) return "Vesktop"
        if (id.indexOf("discord") !== -1) return "Discord"
        if (id.indexOf("steam") !== -1) return "Steam"
        return item.id ? (item.id.charAt(0).toUpperCase() + item.id.slice(1)) : "Options"
    }

    function openMenu(item, xPos) {
        if (!item || !item.hasMenu || !item.menu) return
        targetItem = item
        targetX = xPos || 0
        menuStack = []
        currentMenuHandle = item.menu
        currentMenuTitle = formatAppTitle(item)
        if (!isOpen) {
            isOpen = true
            openRequested()
        } else {
            dropUpAnim.stop()
            menuRootItem.opacity = 1.0
            dropDownAnim.restart()
        }
    }

    function closeMenu() {
        isOpen = false
        closeRequested()
    }

    function openSubmenu(entry) {
        menuStack.push({ handle: currentMenuHandle, title: currentMenuTitle })
        currentMenuHandle = entry
        currentMenuTitle = (entry.text || "").replace(/&/g, "").trim()
    }

    function popSubmenu() {
        if (menuStack.length > 0) {
            let prev = menuStack.pop()
            currentMenuHandle = prev.handle
            currentMenuTitle = prev.title
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            dropUpAnim.stop()
            menuRootItem.opacity = 1.0
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
        onClicked: trayMenuWindow.closeMenu()
    }

    // Escape key handling
    Item {
        focus: trayMenuWindow.isOpen
        Keys.onEscapePressed: trayMenuWindow.closeMenu()
    }

    // ─── Menu Backend ─────────────────────────────────────────
    QsMenuOpener {
        id: menuOpener
        menu: trayMenuWindow.currentMenuHandle
    }

    // ─── Animated Dropdown Container ──────────────────────────
    Item {
        id: menuRootItem
        width: cardContainer.width
        height: cardContainer.height

        // Horizontally aligned with the clicked tray icon, clamped to avoid clipping fillets
        x: {
            let w = cardContainer.width
            let target = trayMenuWindow.targetX
            if (target <= 0) target = trayMenuWindow.width - w - 30
            let desired = target - w / 2
            return Math.max(20, Math.min(trayMenuWindow.width - w - 20, desired))
        }
        y: -cardContainer.height
        opacity: 0.0

        NumberAnimation {
            id: dropDownAnim
            target: menuRootItem
            property: "y"
            from: -cardContainer.height
            to: 0
            duration: 280
            easing.type: Easing.OutCubic
        }

        ParallelAnimation {
            id: dropUpAnim
            NumberAnimation {
                target: menuRootItem
                property: "y"
                to: -cardContainer.height
                duration: 240
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: menuRootItem
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
                fillColor: trayMenuWindow.bgColor
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
                fillColor: trayMenuWindow.bgColor
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

        // ─── CARD CONTAINER (Directly attached to the top bar) ─────
        Rectangle {
            id: cardContainer
            width: 250
            height: Math.min(trayMenuWindow.height - 60, headerCol.height + listFlickable.contentHeight + 24)
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 20
            bottomRightRadius: 20
            color: trayMenuWindow.bgColor
            border.width: 1
            border.color: "#2C2C30"

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.55
                shadowBlur: 0.5
                shadowVerticalOffset: 4
            }

            // Cover the top border line so the card seamlessly merges into the top bar
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: 2
                color: trayMenuWindow.bgColor
            }

            Behavior on height {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                id: mainLayout
                anchors.fill: parent
                anchors.margins: 10
                anchors.topMargin: 10
                spacing: 8

                // Header Column
                ColumnLayout {
                    id: headerCol
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        spacing: 8

                        // Back button for submenus
                        Rectangle {
                            visible: trayMenuWindow.menuStack.length > 0
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            color: backMouseArea.containsMouse ? trayMenuWindow.bgColor2 : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf060"
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                color: trayMenuWindow.accentColor
                            }

                            MouseArea {
                                id: backMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: trayMenuWindow.popSubmenu()
                            }
                        }

                        // App Icon
                        Image {
                            visible: (trayMenuWindow.targetItem?.icon ?? "") !== ""
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            source: trayMenuWindow.targetItem?.icon || ""
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                        }

                        // Title
                        Text {
                            Layout.fillWidth: true
                            text: trayMenuWindow.currentMenuTitle
                            font { family: trayMenuWindow.mainFont; pixelSize: 13; weight: Font.Bold }
                            color: "#FFFFFF"
                            elide: Text.ElideRight
                        }

                        // Close button
                        Rectangle {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            radius: 11
                            color: closeMouseArea.containsMouse ? trayMenuWindow.bgColor2 : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "\uf00d"
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                color: closeMouseArea.containsMouse ? "#FFFFFF" : "#888888"
                            }

                            MouseArea {
                                id: closeMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: trayMenuWindow.closeMenu()
                            }
                        }
                    }

                    // Header Separator
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#262628"
                    }
                }

                // Scrollable Item List
                Flickable {
                    id: listFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: itemsCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: itemsCol
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: menuOpener.children ? menuOpener.children.values : []

                            delegate: Item {
                                id: itemDelegate
                                width: itemsCol.width
                                height: modelData.isSeparator ? 9 : 32

                                // Separator line
                                Rectangle {
                                    visible: modelData.isSeparator
                                    anchors.centerIn: parent
                                    width: parent.width - 8
                                    height: 1
                                    color: "#28282B"
                                }

                                // Interactive Item Card
                                Rectangle {
                                    id: itemCard
                                    visible: !modelData.isSeparator
                                    anchors.fill: parent
                                    radius: 8
                                    color: !modelData.enabled ? "transparent" : (itemMouseArea.containsMouse ? trayMenuWindow.bgColor2 : "transparent")
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        // Checkmark icon (for checkable items)
                                        Text {
                                            visible: modelData.buttonType !== undefined && modelData.buttonType !== 0
                                            text: modelData.checkState ? "\uf00c" : ""
                                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                            color: trayMenuWindow.accentColor
                                            Layout.preferredWidth: 14
                                        }

                                        // Item Icon (if available)
                                        Image {
                                            visible: (modelData.icon ?? "") !== ""
                                            source: modelData.icon || ""
                                            Layout.preferredWidth: 15
                                            Layout.preferredHeight: 15
                                            fillMode: Image.PreserveAspectFit
                                            mipmap: true
                                        }

                                        // Item Text Label
                                        Text {
                                            Layout.fillWidth: true
                                            text: (modelData.text || "").replace(/&/g, "").trim()
                                            font { family: trayMenuWindow.mainFont; pixelSize: 12; weight: Font.Medium }
                                            color: !modelData.enabled ? "#555555" : (itemMouseArea.containsMouse ? "#FFFFFF" : trayMenuWindow.fgColor)
                                            elide: Text.ElideRight
                                        }

                                        // Submenu Chevron
                                        Text {
                                            visible: modelData.hasChildren
                                            text: "\uf054"
                                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 9 }
                                            color: itemMouseArea.containsMouse ? trayMenuWindow.accentColor : "#666666"
                                        }
                                    }

                                    MouseArea {
                                        id: itemMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: modelData.enabled
                                        cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                        onClicked: {
                                            if (!modelData.enabled) return
                                            if (modelData.hasChildren) {
                                                trayMenuWindow.openSubmenu(modelData)
                                            } else {
                                                try {
                                                    modelData.triggered()
                                                } catch(e) {
                                                    console.log("Error triggering tray menu item:", e)
                                                }
                                                trayMenuWindow.closeMenu()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Scrollbar Thumb
            Rectangle {
                id: scrollThumb
                visible: listFlickable.contentHeight > listFlickable.height
                anchors.right: parent.right
                anchors.rightMargin: 3
                width: 3
                radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.25)
                y: listFlickable.y + (listFlickable.visibleArea.yPosition * listFlickable.height)
                height: Math.max(16, listFlickable.visibleArea.heightRatio * listFlickable.height)
            }
        }
    }
}
