import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

PanelWindow {
    id: clipboardWindow

    property bool isOpen: false
    signal closeRequested()
    signal openRequested()

    onOpenRequested: isOpen = true
    onCloseRequested: isOpen = false

    function toggle() {
        if (isOpen) close()
        else open()
    }

    function open() {
        isOpen = true
    }

    function close() {
        isOpen = false
    }

    // Theme properties matching Catppuccin Sapphire Desktop Shell
    property color bgColor: "#121213"
    property color bgColor2: "#181822"
    property color bgColor3: "#22222E"
    property color cardBg: "#1E1E28"
    property color cardHover: "#282838"
    property color fgColor: "#CDD6F4"
    property color fgMuted: "#A6ADC8"
    property color fgSubtle: "#6C7086"
    property color accentColor: "#89B4FA"
    property color accentColorGlow: "#B4BEFE"
    property color dangerColor: "#F38BA8"
    property color borderColor: "#2E2E3A"

    property string mainFont: "Rowdies"
    property string textFont: "Inter"
    property string iconFont: "JetBrainsMono NF"

    // State & Data
    property var rawItems: []
    property string searchText: ""
    property string activeFilter: "all" // "all", "text", "image", "url", "code"
    property int selectedIndex: 0
    property bool confirmWipe: false

    readonly property var filteredItems: {
        if (!rawItems || rawItems.length === 0) return []
        if (activeFilter === "all") return rawItems
        return rawItems.filter(item => {
            if (activeFilter === "image") return item.type === "image"
            if (activeFilter === "text") return item.type === "text"
            if (activeFilter === "url") return item.type === "url"
            if (activeFilter === "code") return item.type === "code"
            return true
        })
    }

    onActiveFilterChanged: {
        selectedIndex = 0
        if (clipList) clipList.positionViewAtBeginning()
    }

    onSearchTextChanged: {
        selectedIndex = 0
        debounceTimer.restart()
    }

    Timer {
        id: debounceTimer
        interval: 100
        repeat: false
        onTriggered: refresh()
    }

    Timer {
        id: wipeResetTimer
        interval: 3500
        repeat: false
        onTriggered: clipboardWindow.confirmWipe = false
    }

    function refresh() {
        listProc.running = false
        listProc.command = ["/home/madara/.config/hypr/clipboard.sh", "list", searchText, "80"]
        listProc.running = true
    }

    Process {
        id: listProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    clipboardWindow.rawItems = JSON.parse(text.trim())
                } catch(e) {
                    clipboardWindow.rawItems = []
                }
            }
        }
    }

    function pasteItem(id) {
        close()
        Quickshell.execDetached(["/home/madara/.config/hypr/clipboard.sh", "paste", id])
    }

    function copyItem(id) {
        Quickshell.execDetached(["/home/madara/.config/hypr/clipboard.sh", "copy", id])
    }

    function deleteItem(id) {
        Quickshell.execDetached(["/home/madara/.config/hypr/clipboard.sh", "delete", id])
        refresh()
    }

    function wipeAll() {
        if (!confirmWipe) {
            confirmWipe = true
            wipeResetTimer.restart()
            return
        }
        confirmWipe = false
        Quickshell.execDetached(["/home/madara/.config/hypr/clipboard.sh", "wipe"])
        rawItems = []
    }

    onIsOpenChanged: {
        console.log("ClipboardManager isOpen is now:", isOpen)
        if (isOpen) {
            confirmWipe = false
            searchText = ""
            activeFilter = "all"
            selectedIndex = 0
            if (searchInput) {
                searchInput.text = ""
                focusTimer.restart()
            }
            refresh()
            dropUpAnim.stop()
            panelCard.opacity = 1.0
            dropDownAnim.restart()
        } else {
            confirmWipe = false
            dropDownAnim.stop()
            dropUpAnim.restart()
        }
    }

    Timer {
        id: focusTimer
        interval: 40
        onTriggered: {
            if (searchInput) searchInput.forceActiveFocus()
        }
    }

    // ─── Global Shortcut & IPC Handler ──────────────────────────
    GlobalShortcut {
        name: "clipboard"
        description: "Toggle Quickshell Clipboard Manager"
        onPressed: clipboardWindow.toggle()
    }

    IpcHandler {
        target: "clipboard"
        function toggle() {
            console.log("IPC clipboard toggle called!")
            clipboardWindow.toggle()
        }
        function open() {
            console.log("IPC clipboard open called!")
            clipboardWindow.open()
        }
        function close() {
            console.log("IPC clipboard close called!")
            clipboardWindow.close()
        }
        function refresh() {
            clipboardWindow.refresh()
        }
        function paste(id: string) {
            clipboardWindow.pasteItem(id)
        }
        function copy(id: string) {
            clipboardWindow.copyItem(id)
        }
        function wipe() {
            clipboardWindow.wipeAll()
        }
    }

    // ─── Window Configuration ───────────────────────────────────
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

    // ─── Dimmed Backdrop ────────────────────────────────────────
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#000000"
        opacity: clipboardWindow.isOpen ? 0.40 : 0.0
        visible: opacity > 0.001

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: clipboardWindow.closeRequested()
        }
    }

    // ─── Floating Modal Panel ───────────────────────────────────
    Rectangle {
        id: panelCard
        anchors.centerIn: parent
        width: 620
        height: 640
        radius: 20
        color: clipboardWindow.bgColor
        border.color: clipboardWindow.borderColor
        border.width: 1
        clip: true

        scale: 0.94
        opacity: 0.0

        ParallelAnimation {
            id: dropDownAnim
            NumberAnimation { target: panelCard; property: "scale"; from: 0.94; to: 1.0; duration: 240; easing.type: Easing.OutBack }
            NumberAnimation { target: panelCard; property: "opacity"; from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            id: dropUpAnim
            NumberAnimation { target: panelCard; property: "scale"; from: 1.0; to: 0.95; duration: 160; easing.type: Easing.InCubic }
            NumberAnimation { target: panelCard; property: "opacity"; from: 1.0; to: 0.0; duration: 150; easing.type: Easing.InCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {} // Block clicks through to backdrop
        }

        // Inner glowing top accent border line
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: clipboardWindow.accentColor
            opacity: 0.8
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // ─── Top Header Bar ─────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Icon Capsule
                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: Qt.rgba(0.54, 0.71, 0.98, 0.15)
                    border.color: Qt.rgba(0.54, 0.71, 0.98, 0.3)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "\uf0ea" // Clipboard
                        font {
                            family: clipboardWindow.iconFont
                            pixelSize: 16
                        }
                        color: clipboardWindow.accentColor
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Clipboard History"
                        font {
                            family: clipboardWindow.mainFont
                            pixelSize: 17
                            bold: true
                        }
                        color: clipboardWindow.fgColor
                    }
                    Text {
                        text: clipboardWindow.rawItems.length + " clips saved"
                        font {
                            family: clipboardWindow.textFont
                            pixelSize: 11
                        }
                        color: clipboardWindow.fgSubtle
                    }
                }

                Item { Layout.fillWidth: true }

                // Wipe / Clear All Button
                Rectangle {
                    implicitWidth: wipeRow.implicitWidth + 18
                    implicitHeight: 32
                    radius: 16
                    color: clipboardWindow.confirmWipe ? clipboardWindow.dangerColor : (wipeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                    border.color: clipboardWindow.confirmWipe ? clipboardWindow.dangerColor : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1

                    RowLayout {
                        id: wipeRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "\uf1f8" // Trash
                            font {
                                family: clipboardWindow.iconFont
                                pixelSize: 12
                            }
                            color: clipboardWindow.confirmWipe ? "#11111B" : (wipeMa.containsMouse ? clipboardWindow.dangerColor : clipboardWindow.fgMuted)
                        }
                        Text {
                            text: clipboardWindow.confirmWipe ? "Confirm Wipe?" : "Clear All"
                            font {
                                family: clipboardWindow.textFont
                                pixelSize: 12
                                weight: Font.Medium
                            }
                            color: clipboardWindow.confirmWipe ? "#11111B" : (wipeMa.containsMouse ? clipboardWindow.dangerColor : clipboardWindow.fgMuted)
                        }
                    }

                    MouseArea {
                        id: wipeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipboardWindow.wipeAll()
                    }
                }

                // Close Button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: closeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04)

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d" // Times / Close
                        font {
                            family: clipboardWindow.iconFont
                            pixelSize: 14
                        }
                        color: clipboardWindow.fgMuted
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipboardWindow.closeRequested()
                    }
                }
            }

            // ─── Search Bar ─────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: 12
                color: clipboardWindow.bgColor2
                border.color: searchInput.activeFocus ? clipboardWindow.accentColor : clipboardWindow.borderColor
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: "\uf002" // Search
                        font {
                            family: clipboardWindow.iconFont
                            pixelSize: 14
                        }
                        color: searchInput.activeFocus ? clipboardWindow.accentColor : clipboardWindow.fgSubtle
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: clipboardWindow.fgColor
                        font {
                            family: clipboardWindow.textFont
                            pixelSize: 13
                        }
                        clip: true
                        selectByMouse: true
                        selectedTextColor: "#11111B"
                        selectionColor: clipboardWindow.accentColor

                        Text {
                            text: "Type to search clipboard history..."
                            color: clipboardWindow.fgSubtle
                            font: parent.font
                            visible: !parent.text && !parent.inputMethodComposing
                        }

                        onTextChanged: clipboardWindow.searchText = text

                        Keys.onEscapePressed: clipboardWindow.closeRequested()

                        Keys.onDownPressed: {
                            if (clipboardWindow.filteredItems.length > 0) {
                                clipboardWindow.selectedIndex = Math.min(clipboardWindow.filteredItems.length - 1, clipboardWindow.selectedIndex + 1)
                                clipList.positionViewAtIndex(clipboardWindow.selectedIndex, ListView.Contain)
                            }
                        }

                        Keys.onUpPressed: {
                            if (clipboardWindow.filteredItems.length > 0) {
                                clipboardWindow.selectedIndex = Math.max(0, clipboardWindow.selectedIndex - 1)
                                clipList.positionViewAtIndex(clipboardWindow.selectedIndex, ListView.Contain)
                            }
                        }

                        Keys.onReturnPressed: {
                            if (clipboardWindow.filteredItems.length > 0 && clipboardWindow.selectedIndex >= 0 && clipboardWindow.selectedIndex < clipboardWindow.filteredItems.length) {
                                clipboardWindow.pasteItem(clipboardWindow.filteredItems[clipboardWindow.selectedIndex].id)
                            }
                        }

                        Keys.onDeletePressed: {
                            if (clipboardWindow.filteredItems.length > 0 && clipboardWindow.selectedIndex >= 0 && clipboardWindow.selectedIndex < clipboardWindow.filteredItems.length) {
                                clipboardWindow.deleteItem(clipboardWindow.filteredItems[clipboardWindow.selectedIndex].id)
                            }
                        }
                    }

                    // Clear search button
                    Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        color: Qt.rgba(1, 1, 1, 0.08)
                        visible: searchInput.text.length > 0

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d"
                            font { family: clipboardWindow.iconFont; pixelSize: 11 }
                            color: clipboardWindow.fgMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: searchInput.text = ""
                        }
                    }
                }
            }

            // ─── Filter Pills ───────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { label: "All", filter: "all", icon: "\uf0ca" },
                        { label: "Text", filter: "text", icon: "\uf036" },
                        { label: "Images", filter: "image", icon: "\uf03e" },
                        { label: "Links", filter: "url", icon: "\uf0c1" },
                        { label: "Code", filter: "code", icon: "\uf121" }
                    ]

                    delegate: Rectangle {
                        implicitWidth: pillContent.implicitWidth + 20
                        implicitHeight: 28
                        radius: 14
                        color: clipboardWindow.activeFilter === modelData.filter ? clipboardWindow.accentColor : (pillMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                        border.color: clipboardWindow.activeFilter === modelData.filter ? clipboardWindow.accentColor : Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1

                        RowLayout {
                            id: pillContent
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: modelData.icon
                                font { family: clipboardWindow.iconFont; pixelSize: 11 }
                                color: clipboardWindow.activeFilter === modelData.filter ? "#11111B" : (pillMa.containsMouse ? clipboardWindow.fgColor : clipboardWindow.fgMuted)
                            }

                            Text {
                                text: modelData.label
                                font {
                                    family: clipboardWindow.textFont
                                    pixelSize: 11
                                    weight: clipboardWindow.activeFilter === modelData.filter ? Font.Bold : Font.Normal
                                }
                                color: clipboardWindow.activeFilter === modelData.filter ? "#11111B" : (pillMa.containsMouse ? clipboardWindow.fgColor : clipboardWindow.fgMuted)
                            }
                        }

                        MouseArea {
                            id: pillMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: clipboardWindow.activeFilter = modelData.filter
                        }
                    }
                }
            }

            // ─── Clips List ─────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: clipboardWindow.bgColor2
                border.color: clipboardWindow.borderColor
                border.width: 1
                clip: true

                ListView {
                    id: clipList
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6
                    model: clipboardWindow.filteredItems

                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    // Empty State
                    Item {
                        anchors.centerIn: parent
                        visible: clipList.count === 0
                        width: parent.width
                        height: 180

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "\uf0ea"
                                font { family: clipboardWindow.iconFont; pixelSize: 36 }
                                color: Qt.rgba(1, 1, 1, 0.15)
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: clipboardWindow.searchText.length > 0 ? "No matching clips found" : "Clipboard history is empty"
                                font { family: clipboardWindow.textFont; pixelSize: 13; weight: Font.Medium }
                                color: clipboardWindow.fgMuted
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Items you copy with Ctrl+C will appear here automatically"
                                font { family: clipboardWindow.textFont; pixelSize: 11 }
                                color: clipboardWindow.fgSubtle
                            }
                        }
                    }

                    delegate: Rectangle {
                        id: clipCard
                        width: clipList.width
                        height: modelData.type === "image" ? 84 : 64
                        radius: 10
                        color: index === clipboardWindow.selectedIndex ? Qt.rgba(0.54, 0.71, 0.98, 0.18) : (cardMa.containsMouse ? clipboardWindow.cardHover : clipboardWindow.cardBg)
                        border.color: index === clipboardWindow.selectedIndex ? clipboardWindow.accentColor : Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                clipboardWindow.selectedIndex = index
                                clipboardWindow.pasteItem(modelData.id)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            // ── Type Icon or Thumbnail ─────────
                            Rectangle {
                                width: modelData.type === "image" ? 64 : 38
                                height: modelData.type === "image" ? 64 : 38
                                radius: 8
                                color: clipboardWindow.bgColor3
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: modelData.thumb ? ("file://" + modelData.thumb) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: modelData.type === "image" && modelData.thumb !== ""
                                    asynchronous: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: modelData.type !== "image" || modelData.thumb === ""
                                    text: {
                                        if (modelData.type === "url") return "\uf0c1" // Link
                                        if (modelData.type === "code") return "\uf121" // Code
                                        if (modelData.type === "image") return "\uf03e" // Image
                                        return "\uf036" // Text
                                    }
                                    font {
                                        family: clipboardWindow.iconFont
                                        pixelSize: 15
                                    }
                                    color: {
                                        if (modelData.type === "url") return "#89DCEB"
                                        if (modelData.type === "code") return "#A6E3A1"
                                        if (modelData.type === "image") return "#F9E2AF"
                                        return clipboardWindow.accentColor
                                    }
                                }
                            }

                            // ── Preview Details ────────────────
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    // Badge
                                    Rectangle {
                                        implicitWidth: badgeText.implicitWidth + 10
                                        implicitHeight: 18
                                        radius: 4
                                        color: Qt.rgba(1, 1, 1, 0.08)

                                        Text {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: modelData.format || "TEXT"
                                            font { family: clipboardWindow.textFont; pixelSize: 9; weight: Font.Bold }
                                            color: clipboardWindow.fgMuted
                                        }
                                    }

                                    Text {
                                        text: modelData.size || ""
                                        font { family: clipboardWindow.textFont; pixelSize: 10 }
                                        color: clipboardWindow.fgSubtle
                                    }

                                    Item { Layout.fillWidth: true }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.preview || ""
                                    color: index === clipboardWindow.selectedIndex ? clipboardWindow.accentColorGlow : clipboardWindow.fgColor
                                    font {
                                        family: modelData.type === "code" ? clipboardWindow.iconFont : clipboardWindow.textFont
                                        pixelSize: 12
                                        weight: modelData.type === "url" ? Font.Medium : Font.Normal
                                    }
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.WordWrap
                                }
                            }

                            // ── Action Buttons (Paste, Copy, Delete) ──
                            RowLayout {
                                spacing: 6
                                opacity: cardMa.containsMouse || index === clipboardWindow.selectedIndex ? 1.0 : 0.0

                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                // Quick Paste Button
                                Rectangle {
                                    implicitWidth: pasteRow.implicitWidth + 14
                                    implicitHeight: 28
                                    radius: 14
                                    color: pasteMa.containsMouse ? clipboardWindow.accentColor : Qt.rgba(0.54, 0.71, 0.98, 0.15)
                                    border.color: clipboardWindow.accentColor
                                    border.width: 1

                                    RowLayout {
                                        id: pasteRow
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text {
                                            text: "\uf0ea"
                                            font { family: clipboardWindow.iconFont; pixelSize: 10 }
                                            color: pasteMa.containsMouse ? "#11111B" : clipboardWindow.accentColor
                                        }
                                        Text {
                                            text: "Paste"
                                            font { family: clipboardWindow.textFont; pixelSize: 11; weight: Font.Bold }
                                            color: pasteMa.containsMouse ? "#11111B" : clipboardWindow.accentColor
                                        }
                                    }

                                    MouseArea {
                                        id: pasteMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: clipboardWindow.pasteItem(modelData.id)
                                    }
                                }

                                // Quick Copy Button
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: copyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf0c5" // Copy
                                        font { family: clipboardWindow.iconFont; pixelSize: 11 }
                                        color: clipboardWindow.fgMuted
                                    }

                                    MouseArea {
                                        id: copyMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: clipboardWindow.copyItem(modelData.id)
                                    }
                                }

                                // Delete Single Clip Button
                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: delMa.containsMouse ? Qt.rgba(0.95, 0.54, 0.66, 0.25) : Qt.rgba(1, 1, 1, 0.06)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf00d"
                                        font { family: clipboardWindow.iconFont; pixelSize: 11 }
                                        color: delMa.containsMouse ? clipboardWindow.dangerColor : clipboardWindow.fgSubtle
                                    }

                                    MouseArea {
                                        id: delMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: clipboardWindow.deleteItem(modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ─── Bottom Keyboard Shortcuts Hint ─────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "[Enter] Paste"
                    font { family: clipboardWindow.iconFont; pixelSize: 11 }
                    color: clipboardWindow.fgSubtle
                }

                Text {
                    text: "•"
                    font { family: clipboardWindow.iconFont; pixelSize: 11 }
                    color: clipboardWindow.borderColor
                }

                Text {
                    text: "[↑/↓] Navigate"
                    font { family: clipboardWindow.iconFont; pixelSize: 11 }
                    color: clipboardWindow.fgSubtle
                }

                Text {
                    text: "•"
                    font { family: clipboardWindow.iconFont; pixelSize: 11 }
                    color: clipboardWindow.borderColor
                }

                Text {
                    text: "[Del] Remove"
                    font { family: clipboardWindow.iconFont; pixelSize: 11 }
                    color: clipboardWindow.fgSubtle
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "[Esc] Close"
                    font { family: clipboardWindow.iconFont; pixelSize: 11 }
                    color: clipboardWindow.fgSubtle
                }
            }
        }
    }
}
