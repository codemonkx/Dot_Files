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

    // ─── Windows 11 Fluent Dark / Catppuccin Sapphire Palette ───
    property color winBg: "#121213"
    property color winBgMica: "#121213"
    property color winSearchBg: "#1E1E1E"
    property color winCardBg: "#1E1E1E"
    property color winCardHover: "#28282D"
    property color winCardSelected: "#313244"
    property color winBorder: "#313244"
    property color winSubtleBorder: "#25252A"
    property color fgColor: "#CDD6F4"
    property color fgMuted: "#A6ADC8"
    property color fgSubtle: "#6C7086"
    property color accentColor: "#89B4FA" // Sapphire Accent
    property color accentGlow: "#B4BEFE"
    property color dangerColor: "#F38BA8"
    property color pinColor: "#F9E2AF"

    property string mainFont: "Inter"
    property string textFont: "Inter"
    property string iconFont: "JetBrainsMono NF"

    // ─── Tabs & State ───
    property string activeTab: "clipboard" // "clipboard", "emoji", "kaomoji", "symbols"
    property var rawItems: []
    property string searchText: ""
    property int selectedIndex: 0
    property bool confirmWipe: false

    // Windows Caret / Cursor Positioning
    property int cardTargetX: Math.round((clipboardWindow.width > 0 ? clipboardWindow.width : 1920) - 380) / 2
    property int cardTargetY: Math.round((clipboardWindow.height > 0 ? clipboardWindow.height : 1080) - 460) / 2

    function updatePosition(targetX, targetY) {
        let sw = (clipboardWindow.screen && clipboardWindow.screen.width > 0) ? clipboardWindow.screen.width : (clipboardWindow.width > 200 ? clipboardWindow.width : 1920)
        let sh = (clipboardWindow.screen && clipboardWindow.screen.height > 0) ? clipboardWindow.screen.height : (clipboardWindow.height > 200 ? clipboardWindow.height : 1080)
        let cw = 380
        let ch = 460

        let x = targetX - 20
        let y = targetY + 12

        // If overflowing bottom, flip above typing cursor / caret
        if (y + ch > sh - 16) {
            y = targetY - ch - 12
        }

        // Clamp Y inside screen
        if (y + ch > sh - 16) y = sh - ch - 16
        if (y < 16) y = 16

        // Clamp X inside screen
        if (x + cw > sw - 16) {
            x = sw - cw - 16
        }
        if (x < 16) x = 16

        cardTargetX = Math.round(x)
        cardTargetY = Math.round(y)
    }

    Process {
        id: posProc
        running: false
        command: ["/home/madara/.config/hypr/clipboard.sh", "get-pos"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parts = text.trim().split(",")
                    if (parts.length === 2) {
                        let px = parseInt(parts[0])
                        let py = parseInt(parts[1])
                        if (!isNaN(px) && !isNaN(py)) {
                            clipboardWindow.updatePosition(px, py)
                        }
                    }
                } catch(e) {}
            }
        }
    }

    readonly property var filteredItems: {
        if (!rawItems || rawItems.length === 0) return []
        if (!searchText || searchText.trim() === "") return rawItems
        let q = searchText.trim().toLowerCase()
        return rawItems.filter(item => {
            if (item.type === "image") {
                return (item.format && item.format.toLowerCase().includes(q)) || (item.dims && item.dims.includes(q))
            }
            return (item.preview && item.preview.toLowerCase().includes(q)) || (item.full_text && item.full_text.toLowerCase().includes(q))
        })
    }

    onActiveTabChanged: {
        selectedIndex = 0
        searchText = ""
        if (searchInput) searchInput.text = ""
    }

    onSearchTextChanged: {
        selectedIndex = 0
        if (activeTab === "clipboard") {
            debounceTimer.restart()
        }
    }

    Timer {
        id: debounceTimer
        interval: 120
        repeat: false
        onTriggered: refresh()
    }

    Timer {
        id: wipeResetTimer
        interval: 3000
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

    function togglePin(id) {
        Quickshell.execDetached(["/home/madara/.config/hypr/clipboard.sh", "toggle-pin", id])
        refresh()
    }

    function wipeUnpinned() {
        if (!confirmWipe) {
            confirmWipe = true
            wipeResetTimer.restart()
            return
        }
        confirmWipe = false
        Quickshell.execDetached(["/home/madara/.config/hypr/clipboard.sh", "wipe"])
        refresh()
    }

    function pasteText(txt) {
        close()
        Quickshell.execDetached(["/home/madara/.config/hypr/clipboard.sh", "paste-text", txt])
    }

    onIsOpenChanged: {
        if (isOpen) {
            if (!activeTab || activeTab === "") activeTab = "clipboard"
            confirmWipe = false
            searchText = ""
            selectedIndex = 0
            if (searchInput) {
                searchInput.text = ""
                focusTimer.restart()
            }
            refresh()
            dropUpAnim.stop()
            dropDownAnim.restart()
        } else {
            confirmWipe = false
            activeTab = "clipboard"
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
        description: "Toggle Quickshell Windows Clipboard Manager"
        onPressed: clipboardWindow.toggle()
    }

    IpcHandler {
        target: "clipboard"
        function toggle() { 
            if (clipboardWindow.isOpen) {
                clipboardWindow.close()
            } else {
                posProc.running = false
                posProc.running = true
                clipboardWindow.open()
            }
        }
        function toggleAt(targetX: int, targetY: int) {
            if (clipboardWindow.isOpen) {
                clipboardWindow.close()
            } else {
                clipboardWindow.updatePosition(targetX, targetY)
                clipboardWindow.open()
            }
        }
        function open() { 
            clipboardWindow.activeTab = "clipboard"
            posProc.running = false
            posProc.running = true
            clipboardWindow.open() 
        }
        function openAt(targetX: int, targetY: int) {
            clipboardWindow.activeTab = "clipboard"
            clipboardWindow.updatePosition(targetX, targetY)
            clipboardWindow.open()
        }
        function close() { clipboardWindow.close() }
        function refresh() { clipboardWindow.refresh() }
        function paste(id: string) { clipboardWindow.pasteItem(id) }
        function copy(id: string) { clipboardWindow.copyItem(id) }
        function wipe() { clipboardWindow.wipeUnpinned() }
        function openEmoji() {
            clipboardWindow.activeTab = "emoji"
            posProc.running = false
            posProc.running = true
            clipboardWindow.open()
        }
        function openEmojiAt(targetX: int, targetY: int) {
            clipboardWindow.activeTab = "emoji"
            clipboardWindow.updatePosition(targetX, targetY)
            clipboardWindow.open()
        }
        function openTab(tab: string) {
            clipboardWindow.activeTab = tab
            posProc.running = false
            posProc.running = true
            clipboardWindow.open()
        }
        function openTabAt(tab: string, targetX: int, targetY: int) {
            clipboardWindow.activeTab = tab
            clipboardWindow.updatePosition(targetX, targetY)
            clipboardWindow.open()
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
        opacity: clipboardWindow.isOpen ? 0.45 : 0.0
        visible: opacity > 0.001

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: clipboardWindow.closeRequested()
        }
    }

    // ─── Windows 11 Fluent Flyout Card ──────────────────────────
    Rectangle {
        id: panelCard
        x: clipboardWindow.cardTargetX
        y: clipboardWindow.cardTargetY
        width: 380
        height: 460
        radius: 12
        color: clipboardWindow.winBg
        border.color: clipboardWindow.winBorder
        border.width: 1
        clip: true

        scale: 0.95
        opacity: 0.0

        ParallelAnimation {
            id: dropDownAnim
            NumberAnimation { target: panelCard; property: "scale"; from: 0.95; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: panelCard; property: "opacity"; from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            id: dropUpAnim
            NumberAnimation { target: panelCard; property: "scale"; from: 1.0; to: 0.95; duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { target: panelCard; property: "opacity"; from: 1.0; to: 0.0; duration: 140; easing.type: Easing.InCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {} // Block clicks through to backdrop
        }

        // Top Subtle Fluent Glow
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ─── 1. Top Windows Tab Bar ─────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                // Tab 1: Clipboard
                Rectangle {
                    implicitWidth: 38
                    implicitHeight: 34
                    radius: 6
                    color: clipboardWindow.activeTab === "clipboard" ? Qt.rgba(1, 1, 1, 0.08) : (tabClipMa.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: "\uf0ea" // Clipboard
                        font { family: clipboardWindow.iconFont; pixelSize: 15 }
                        color: clipboardWindow.activeTab === "clipboard" ? clipboardWindow.accentColor : clipboardWindow.fgMuted
                    }

                    // Windows underline indicator
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 18
                        height: 2
                        radius: 1
                        color: clipboardWindow.accentColor
                        visible: clipboardWindow.activeTab === "clipboard"
                    }

                    MouseArea {
                        id: tabClipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipboardWindow.activeTab = "clipboard"
                    }
                }

                // Tab 2: Emoji
                Rectangle {
                    implicitWidth: 38
                    implicitHeight: 34
                    radius: 6
                    color: clipboardWindow.activeTab === "emoji" ? Qt.rgba(1, 1, 1, 0.08) : (tabEmojiMa.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: "\uf118" // Smile
                        font { family: clipboardWindow.iconFont; pixelSize: 15 }
                        color: clipboardWindow.activeTab === "emoji" ? clipboardWindow.accentColor : clipboardWindow.fgMuted
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 18
                        height: 2
                        radius: 1
                        color: clipboardWindow.accentColor
                        visible: clipboardWindow.activeTab === "emoji"
                    }

                    MouseArea {
                        id: tabEmojiMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipboardWindow.activeTab = "emoji"
                    }
                }

                // Tab 3: Kaomoji (•‿•)
                Rectangle {
                    implicitWidth: 54
                    implicitHeight: 34
                    radius: 6
                    color: clipboardWindow.activeTab === "kaomoji" ? Qt.rgba(1, 1, 1, 0.08) : (tabKaoMa.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: "(•‿•)"
                        font { family: clipboardWindow.textFont; pixelSize: 12; weight: Font.Medium }
                        color: clipboardWindow.activeTab === "kaomoji" ? clipboardWindow.accentColor : clipboardWindow.fgMuted
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 24
                        height: 2
                        radius: 1
                        color: clipboardWindow.accentColor
                        visible: clipboardWindow.activeTab === "kaomoji"
                    }

                    MouseArea {
                        id: tabKaoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipboardWindow.activeTab = "kaomoji"
                    }
                }

                // Tab 4: Symbols (Ω)
                Rectangle {
                    implicitWidth: 38
                    implicitHeight: 34
                    radius: 6
                    color: clipboardWindow.activeTab === "symbols" ? Qt.rgba(1, 1, 1, 0.08) : (tabSymMa.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: "Ω"
                        font { family: clipboardWindow.textFont; pixelSize: 14; weight: Font.Bold }
                        color: clipboardWindow.activeTab === "symbols" ? clipboardWindow.accentColor : clipboardWindow.fgMuted
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 18
                        height: 2
                        radius: 1
                        color: clipboardWindow.accentColor
                        visible: clipboardWindow.activeTab === "symbols"
                    }

                    MouseArea {
                        id: tabSymMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipboardWindow.activeTab = "symbols"
                    }
                }

                Item { Layout.fillWidth: true }

                // Windows Style Close Button (✕)
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 6
                    color: closeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font { family: clipboardWindow.iconFont; pixelSize: 13 }
                        color: closeMa.containsMouse ? "#FFFFFF" : clipboardWindow.fgMuted
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

            // ─── 2. Windows 11 Search Bar ───────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 6
                color: clipboardWindow.winSearchBg
                border.color: searchInput.activeFocus ? clipboardWindow.accentColor : clipboardWindow.winSubtleBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: "\uf002"
                        font { family: clipboardWindow.iconFont; pixelSize: 12 }
                        color: searchInput.activeFocus ? clipboardWindow.accentColor : clipboardWindow.fgSubtle
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: clipboardWindow.fgColor
                        font { family: clipboardWindow.textFont; pixelSize: 12 }
                        clip: true
                        selectByMouse: true
                        selectedTextColor: "#11111B"
                        selectionColor: clipboardWindow.accentColor

                        Text {
                            text: {
                                if (clipboardWindow.activeTab === "emoji") return "Search emoji..."
                                if (clipboardWindow.activeTab === "kaomoji") return "Search kaomoji..."
                                if (clipboardWindow.activeTab === "symbols") return "Search symbols..."
                                return "Search clipboard..."
                            }
                            color: clipboardWindow.fgSubtle
                            font: parent.font
                            visible: !parent.text && !parent.inputMethodComposing
                        }

                        onTextChanged: clipboardWindow.searchText = text

                        Keys.onEscapePressed: clipboardWindow.closeRequested()

                        Keys.onDownPressed: {
                            if (clipboardWindow.activeTab === "clipboard" && clipboardWindow.filteredItems.length > 0) {
                                clipboardWindow.selectedIndex = Math.min(clipboardWindow.filteredItems.length - 1, clipboardWindow.selectedIndex + 1)
                                clipList.positionViewAtIndex(clipboardWindow.selectedIndex, ListView.Contain)
                            }
                        }

                        Keys.onUpPressed: {
                            if (clipboardWindow.activeTab === "clipboard" && clipboardWindow.filteredItems.length > 0) {
                                clipboardWindow.selectedIndex = Math.max(0, clipboardWindow.selectedIndex - 1)
                                clipList.positionViewAtIndex(clipboardWindow.selectedIndex, ListView.Contain)
                            }
                        }

                        Keys.onReturnPressed: {
                            if (clipboardWindow.activeTab === "clipboard" && clipboardWindow.filteredItems.length > 0) {
                                let item = clipboardWindow.filteredItems[clipboardWindow.selectedIndex]
                                if (item) clipboardWindow.pasteItem(item.id)
                            }
                        }

                        Keys.onDeletePressed: {
                            if (clipboardWindow.activeTab === "clipboard" && clipboardWindow.filteredItems.length > 0) {
                                let item = clipboardWindow.filteredItems[clipboardWindow.selectedIndex]
                                if (item) clipboardWindow.deleteItem(item.id)
                            }
                        }
                    }

                    // Clear button
                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        color: Qt.rgba(1, 1, 1, 0.08)
                        visible: searchInput.text.length > 0

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d"
                            font { family: clipboardWindow.iconFont; pixelSize: 9 }
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

            // ─── 3. Section Header (Clipboard Title & Clear All) ──
            RowLayout {
                Layout.fillWidth: true
                visible: clipboardWindow.activeTab === "clipboard"
                height: 24

                Text {
                    text: "Clipboard"
                    font { family: clipboardWindow.textFont; pixelSize: 13; weight: Font.Bold }
                    color: clipboardWindow.fgColor
                }

                Item { Layout.fillWidth: true }

                // Windows Style "Clear all" Button
                Rectangle {
                    implicitWidth: clearText.implicitWidth + 14
                    implicitHeight: 24
                    radius: 4
                    color: clipboardWindow.confirmWipe ? clipboardWindow.dangerColor : (clearMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: clipboardWindow.confirmWipe ? "Confirm clear?" : "Clear all"
                        font { family: clipboardWindow.textFont; pixelSize: 11; weight: Font.Medium }
                        color: clipboardWindow.confirmWipe ? "#11111B" : (clearMa.containsMouse ? clipboardWindow.fgColor : clipboardWindow.fgMuted)
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clipboardWindow.wipeUnpinned()
                    }
                }
            }

            // ─── 4. Main Body: Switchable Content Area ───────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ── TAB A: CLIPBOARD HISTORY ──
                ListView {
                    id: clipList
                    anchors.fill: parent
                    visible: clipboardWindow.activeTab === "clipboard"
                    clip: true
                    model: clipboardWindow.filteredItems
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 4
                    }

                    // Windows Empty State
                    Item {
                        anchors.centerIn: parent
                        visible: clipList.count === 0
                        width: parent.width - 40
                        height: 200

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "\uf0ea"
                                font { family: clipboardWindow.iconFont; pixelSize: 42 }
                                color: Qt.rgba(1, 1, 1, 0.18)
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: clipboardWindow.searchText.length > 0 ? "No results found" : "Your clipboard is empty"
                                font { family: clipboardWindow.textFont; pixelSize: 13; weight: Font.Bold }
                                color: clipboardWindow.fgColor
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Copy text or images to view them here."
                                font { family: clipboardWindow.textFont; pixelSize: 11 }
                                color: clipboardWindow.fgSubtle
                            }
                        }
                    }

                    delegate: Rectangle {
                        id: winCard
                        width: clipList.width
                        implicitHeight: {
                            if (modelData.type === "image") return 110
                            return Math.min(110, Math.max(50, cardContentCol.implicitHeight + 16))
                        }
                        radius: 8
                        color: index === clipboardWindow.selectedIndex ? clipboardWindow.winCardSelected : (cardHoverMa.containsMouse ? clipboardWindow.winCardHover : clipboardWindow.winCardBg)
                        border.color: index === clipboardWindow.selectedIndex ? clipboardWindow.accentColor : (modelData.pinned ? Qt.rgba(0.97, 0.88, 0.68, 0.4) : clipboardWindow.winSubtleBorder)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        // Card Click Area (Pastes Item)
                        MouseArea {
                            id: cardHoverMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                clipboardWindow.selectedIndex = index
                                clipboardWindow.pasteItem(modelData.id)
                            }
                        }

                        // Content Layout
                        ColumnLayout {
                            id: cardContentCol
                            anchors.fill: parent
                            anchors.margins: 10
                            anchors.rightMargin: 64 // Space for pin & delete buttons
                            spacing: 6

                            // Image Clip
                            Item {
                                visible: modelData.type === "image"
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Image {
                                    anchors.fill: parent
                                    source: modelData.thumb ? ("file://" + modelData.thumb) : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }
                            }

                            // Text / URL / Code Clip
                            Text {
                                visible: modelData.type !== "image"
                                Layout.fillWidth: true
                                text: modelData.preview || ""
                                color: index === clipboardWindow.selectedIndex ? clipboardWindow.accentGlow : clipboardWindow.fgColor
                                font {
                                    family: modelData.type === "code" ? clipboardWindow.iconFont : clipboardWindow.textFont
                                    pixelSize: 12
                                    weight: modelData.type === "url" ? Font.Medium : Font.Normal
                                }
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                lineHeight: 1.25
                            }

                            // Meta pill row
                            RowLayout {
                                visible: modelData.type === "image" || modelData.type === "url" || modelData.type === "code"
                                spacing: 6
                                Rectangle {
                                    implicitWidth: badgeTxt.implicitWidth + 8
                                    implicitHeight: 16
                                    radius: 3
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    Text {
                                        id: badgeTxt
                                        anchors.centerIn: parent
                                        text: modelData.type === "image" ? (modelData.dims || "IMAGE") : modelData.type.toUpperCase()
                                        font { family: clipboardWindow.textFont; pixelSize: 9; weight: Font.Bold }
                                        color: clipboardWindow.fgMuted
                                    }
                                }
                                Text {
                                    text: modelData.size || ""
                                    font { family: clipboardWindow.textFont; pixelSize: 10 }
                                    color: clipboardWindow.fgSubtle
                                }
                            }
                        }

                        // Windows 11 Card Top-Right Action Buttons
                        RowLayout {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 8
                            anchors.rightMargin: 8
                            spacing: 4

                            // 📌 Pin Button (Windows Feature)
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 4
                                color: modelData.pinned ? Qt.rgba(0.97, 0.88, 0.68, 0.2) : (pinBtnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                                border.color: modelData.pinned ? clipboardWindow.pinColor : "transparent"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf08d" // Pin
                                    font { family: clipboardWindow.iconFont; pixelSize: 11 }
                                    color: modelData.pinned ? clipboardWindow.pinColor : (pinBtnMa.containsMouse ? clipboardWindow.fgColor : clipboardWindow.fgSubtle)
                                }

                                MouseArea {
                                    id: pinBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: clipboardWindow.togglePin(modelData.id)
                                }
                            }

                            // 🗑 Delete Button
                            Rectangle {
                                width: 26
                                height: 26
                                radius: 4
                                color: delBtnMa.containsMouse ? Qt.rgba(0.95, 0.54, 0.66, 0.25) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf00d" // Times / Delete
                                    font { family: clipboardWindow.iconFont; pixelSize: 11 }
                                    color: delBtnMa.containsMouse ? clipboardWindow.dangerColor : clipboardWindow.fgSubtle
                                }

                                MouseArea {
                                    id: delBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: clipboardWindow.deleteItem(modelData.id)
                                }
                            }
                        }
                    }
                }

                // ── TAB B: EMOJI PICKER (Windows Expression Panel) ──
                Item {
                    id: emojiView
                    anchors.fill: parent
                    visible: clipboardWindow.activeTab === "emoji"

                    readonly property var emojiData: [
                        // Smileys
                        "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "🥹", "😊",
                        "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙",
                        "😋", "😛", "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔",
                        "🫡", "🤐", "🤨", "😐", "😑", "😶", "😏", "😒", "🙄", "😬",
                        "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🤢",
                        // Gestures & People
                        "👍", "👎", "👏", "🙌", "👐", "🤲", "🤝", "🙏", "✌️", "🤞",
                        "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "👋", "🤚",
                        "💪", "🦾", "👀", "🧠", "❤️", "🧡", "💛", "💚", "💙", "💜",
                        "🖤", "🤍", "🤎", "💔", "❤️‍🔥", "💖", "✨", "⭐", "🌟", "🔥",
                        // Objects & Tech
                        "💻", "📱", "⌨️", "🖱️", "🖥️", "📷", "🎮", "🕹️", "🎧", "🎵",
                        "🚀", "⚡", "💡", "🛠️", "⚙️", "🔒", "🔑", "📦", "📌", "🎉"
                    ]

                    GridView {
                        id: emojiGrid
                        anchors.fill: parent
                        clip: true
                        cellWidth: Math.floor(width / 6)
                        cellHeight: 46
                        boundsBehavior: Flickable.StopAtBounds

                        model: {
                            if (!clipboardWindow.searchText || clipboardWindow.searchText.trim() === "") return emojiView.emojiData
                            let q = clipboardWindow.searchText.trim()
                            return emojiView.emojiData.filter(e => e.includes(q))
                        }

                        delegate: Rectangle {
                            width: emojiGrid.cellWidth - 4
                            height: emojiGrid.cellHeight - 4
                            radius: 6
                            color: emMa.containsMouse ? clipboardWindow.winCardHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font { pixelSize: 22 }
                            }

                            MouseArea {
                                id: emMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: clipboardWindow.pasteText(modelData)
                            }
                        }
                    }
                }

                // ── TAB C: KAOMOJI (•‿•) ──
                Item {
                    id: kaomojiView
                    anchors.fill: parent
                    visible: clipboardWindow.activeTab === "kaomoji"

                    readonly property var kaomojiData: [
                        "¯\\_(ツ)_/¯", "(•‿•)", "(╯°□°)╯︵ ┻━┻", "(ง •_•)ง", "(✿◡‿◡)",
                        "(づ｡◕‿‿◕｡)づ", "ಠ_ಠ", "(☞ﾟヮﾟ)☞", "☜(ﾟヮﾟ☜)", "(;´༎ຶД༎ຶ`)",
                        "(¬‿¬)", "ʕ•ᴥ•ʔ", "(^///^)", "ヘ( ^o^)ノ", "(┬┬﹏┬┬)",
                        "( •̀ ω •́ )✧", "(=^・^=)", "(*/ω＼*)", "(´▽`ʃ♡ƪ)", "(~_~;)"
                    ]

                    ListView {
                        anchors.fill: parent
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds

                        model: {
                            if (!clipboardWindow.searchText || clipboardWindow.searchText.trim() === "") return kaomojiView.kaomojiData
                            let q = clipboardWindow.searchText.trim()
                            return kaomojiView.kaomojiData.filter(k => k.includes(q))
                        }

                        delegate: Rectangle {
                            width: parent.width
                            height: 40
                            radius: 6
                            color: kaoMa.containsMouse ? clipboardWindow.winCardHover : clipboardWindow.winCardBg
                            border.color: clipboardWindow.winSubtleBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font { family: clipboardWindow.textFont; pixelSize: 13; weight: Font.Medium }
                                color: clipboardWindow.fgColor
                            }

                            MouseArea {
                                id: kaoMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: clipboardWindow.pasteText(modelData)
                            }
                        }
                    }
                }

                // ── TAB D: SYMBOLS (Ω) ──
                Item {
                    id: symbolsView
                    anchors.fill: parent
                    visible: clipboardWindow.activeTab === "symbols"

                    readonly property var symbolData: [
                        "±", "×", "÷", "≠", "≈", "≤", "≥", "√", "∞", "∫",
                        "π", "∑", "∆", "µ", "°", "‰", "€", "$", "£", "¥",
                        "₹", "¢", "©", "®", "™", "§", "¶", "•", "…", "—",
                        "–", "«", "»", "“", "”", "‘", "’", "†", "‡", "↵",
                        "←", "↑", "→", "↓", "↔", "↕", "⇒", "⇔", "✓", "✗"
                    ]

                    GridView {
                        id: symGrid
                        anchors.fill: parent
                        clip: true
                        cellWidth: Math.floor(width / 6)
                        cellHeight: 46
                        boundsBehavior: Flickable.StopAtBounds

                        model: {
                            if (!clipboardWindow.searchText || clipboardWindow.searchText.trim() === "") return symbolsView.symbolData
                            let q = clipboardWindow.searchText.trim()
                            return symbolsView.symbolData.filter(s => s.includes(q))
                        }

                        delegate: Rectangle {
                            width: symGrid.cellWidth - 4
                            height: symGrid.cellHeight - 4
                            radius: 6
                            color: symMa.containsMouse ? clipboardWindow.winCardHover : clipboardWindow.winCardBg
                            border.color: clipboardWindow.winSubtleBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font { family: clipboardWindow.textFont; pixelSize: 16; weight: Font.Medium }
                                color: clipboardWindow.fgColor
                            }

                            MouseArea {
                                id: symMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: clipboardWindow.pasteText(modelData)
                            }
                        }
                    }
                }
            }

            // ─── 5. Bottom Keyboard Hints (Subtle) ───────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                opacity: 0.7

                Text {
                    text: "[Enter] Paste"
                    font { family: clipboardWindow.textFont; pixelSize: 10 }
                    color: clipboardWindow.fgSubtle
                }
                Text { text: "•"; font.pixelSize: 10; color: clipboardWindow.winBorder }
                Text {
                    text: "[Del] Remove"
                    font { family: clipboardWindow.textFont; pixelSize: 10 }
                    color: clipboardWindow.fgSubtle
                }
                Text { text: "•"; font.pixelSize: 10; color: clipboardWindow.winBorder }
                Text {
                    text: "📌 Pin to keep"
                    font { family: clipboardWindow.textFont; pixelSize: 10 }
                    color: clipboardWindow.fgSubtle
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "[Esc] Close"
                    font { family: clipboardWindow.textFont; pixelSize: 10 }
                    color: clipboardWindow.fgSubtle
                }
            }
        }
    }
}
