import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

PanelWindow {
    id: wallpaperWindow

    property bool isOpen: false
    signal closeRequested()
    signal openRequested()

    function toggle() {
        if (isOpen) closeRequested()
        else openRequested()
    }

    function open() {
        openRequested()
    }

    function close() {
        closeRequested()
    }

    // Theme properties matching the top bar & shell
    property color bgColor: "#121213"
    property color bgColor2: "#1E1E1E"
    property color bgColor3: "#262626"
    property color fgColor: "#CDD6F4"
    property color accentColor: "#89B4FA"
    property color accentColorGlow: "#B4BEFE"
    property color successColor: "#A6E3A1"
    property color errorColor: "#F38BA8"
    property string mainFont: "Rowdies"
    property string iconFont: "JetBrainsMono NF"
    property int barHeight: 40

    // ─── Global Shortcut & IPC Handler ────────────────────────
    GlobalShortcut {
        name: "wallpapers"
        description: "Toggle Quickshell Wallpaper Selector"
        onPressed: wallpaperWindow.toggle()
    }

    IpcHandler {
        target: "wallpaper"
        function toggle() {
            wallpaperWindow.toggle()
        }
        function open() {
            wallpaperWindow.open()
        }
        function close() {
            wallpaperWindow.close()
        }
        function openAddFolder() {
            wallpaperWindow.open()
            wallpaperWindow.showAddFolderModal = true
        }
    }

    // ─── State Management ─────────────────────────────────────
    property var allWallpapers: []
    property var categories: ["All"]
    property string selectedCategory: "All"
    property string currentWallpaperPath: ""
    property string statusMessage: ""

    // Folder Management State
    property bool showAddFolderModal: false
    property bool isBrowsingFolder: false
    property var customFolders: []
    property string folderInputText: ""
    property string addFolderError: ""

    readonly property var filteredWallpapers: {
        if (selectedCategory === "All") return allWallpapers
        let list = []
        for (let i = 0; i < allWallpapers.length; i++) {
            if (allWallpapers[i].category === selectedCategory) {
                list.push(allWallpapers[i])
            }
        }
        return list
    }

    // Fetch wallpapers list
    Process {
        id: fetchProc
        command: [Quickshell.env("HOME") + "/.config/hypr/get_wallpapers.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text.trim())
                    if (data.wallpapers) wallpaperWindow.allWallpapers = data.wallpapers
                    if (data.categories) wallpaperWindow.categories = data.categories
                    if (data.current) wallpaperWindow.currentWallpaperPath = data.current
                    if (data.folders) wallpaperWindow.customFolders = data.folders
                } catch (e) {
                    console.log("Error parsing wallpapers JSON: " + e)
                }
            }
        }
    }

    // Apply wallpaper
    Process {
        id: applyProc
    }

    // Add folder process
    Process {
        id: addFolderProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let res = JSON.parse(text.trim())
                    if (res.success) {
                        wallpaperWindow.statusMessage = res.message || "Folder Added!"
                        wallpaperWindow.addFolderError = ""
                        wallpaperWindow.folderInputText = ""
                        statusClearTimer.restart()
                        fetchProc.running = false
                        fetchProc.running = true
                    } else {
                        wallpaperWindow.addFolderError = res.error || "Failed to add folder"
                    }
                } catch(e) {
                    wallpaperWindow.addFolderError = "Error adding folder"
                }
            }
        }
    }

    // Remove folder process
    Process {
        id: removeFolderProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let res = JSON.parse(text.trim())
                    if (res.success) {
                        wallpaperWindow.statusMessage = res.message || "Folder Removed"
                        statusClearTimer.restart()
                        fetchProc.running = false
                        fetchProc.running = true
                    }
                } catch(e) {}
            }
        }
    }

    // Browse folder process (calls zenity file selection)
    Process {
        id: browseProc
        running: false
        command: [Quickshell.env("HOME") + "/.config/hypr/manage_wallpaper_folders.py", "browse"]
        stdout: StdioCollector {
            onStreamFinished: {
                wallpaperWindow.isBrowsingFolder = false
                try {
                    let res = JSON.parse(text.trim())
                    if (res.success && res.path) {
                        wallpaperWindow.folderInputText = res.path
                        wallpaperWindow.addFolderError = ""
                    }
                } catch(e) {}
            }
        }
    }

    FolderDialog {
        id: folderDialog
        title: "Select Wallpaper Folder"
        currentFolder: "file://" + Quickshell.env("HOME") + "/Pictures"
        onAccepted: {
            let path = folderDialog.selectedFolder.toString()
            if (path.startsWith("file://")) {
                path = path.substring(7)
            }
            wallpaperWindow.folderInputText = decodeURIComponent(path)
            wallpaperWindow.addFolderError = ""
        }
    }

    Timer {
        id: statusClearTimer
        interval: 2500
        onTriggered: wallpaperWindow.statusMessage = ""
    }

    function applyWallpaper(path) {
        if (!path) return
        wallpaperWindow.currentWallpaperPath = path
        wallpaperWindow.statusMessage = "Wallpaper Applied!"
        statusClearTimer.restart()
        applyProc.command = [Quickshell.env("HOME") + "/.config/hypr/set_wallpaper.sh", path]
        applyProc.running = false
        applyProc.running = true
    }

    function applyRandomWallpaper() {
        let pool = filteredWallpapers.length > 0 ? filteredWallpapers : allWallpapers
        if (pool.length === 0) return
        let randIdx = Math.floor(Math.random() * pool.length)
        applyWallpaper(pool[randIdx].path)
    }

    function addFolder(path) {
        if (!path || path.trim() === "") {
            addFolderError = "Please specify a folder path"
            return
        }
        addFolderError = ""
        addFolderProc.command = [Quickshell.env("HOME") + "/.config/hypr/manage_wallpaper_folders.py", "add", path.trim()]
        addFolderProc.running = false
        addFolderProc.running = true
    }

    function removeFolder(path) {
        if (!path) return
        removeFolderProc.command = [Quickshell.env("HOME") + "/.config/hypr/manage_wallpaper_folders.py", "remove", path]
        removeFolderProc.running = false
        removeFolderProc.running = true
    }

    function launchFolderPicker() {
        wallpaperWindow.isBrowsingFolder = true
        browseProc.running = false
        browseProc.running = true
    }

    onIsOpenChanged: {
        if (isOpen) {
            statusMessage = ""
            addFolderError = ""
            fetchProc.running = false
            fetchProc.running = true
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
    WlrLayershell.keyboardFocus: (isOpen && !isBrowsingFolder) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: (isOpen && !isBrowsingFolder) || dropDownAnim.running || dropUpAnim.running

    // Dismiss on click outside
    MouseArea {
        id: backdrop
        anchors.fill: parent
        hoverEnabled: false
        onClicked: wallpaperWindow.closeRequested()
    }

    // Escape key handling
    Item {
        focus: wallpaperWindow.isOpen && !wallpaperWindow.isBrowsingFolder
        Keys.onEscapePressed: {
            if (wallpaperWindow.showAddFolderModal) {
                wallpaperWindow.showAddFolderModal = false
            } else {
                wallpaperWindow.closeRequested()
            }
        }
    }

    // ─── THE PANEL ROOT ITEM ──────────────────────────────────
    Item {
        id: panelRootItem
        width: cardContainer.width
        height: cardContainer.height

        // Horizontally centered across the top bar
        x: Math.round((parent.width - width) / 2)

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
                fillColor: wallpaperWindow.bgColor
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
                fillColor: wallpaperWindow.bgColor
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
        }

        // ─── CARD CONTAINER ───────────────────────────────────
        Rectangle {
            id: cardContainer
            width: 760
            height: 520
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 24
            bottomRightRadius: 24
            color: wallpaperWindow.bgColor
            border.width: 0
            clip: true

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.65
                shadowBlur: 0.6
                shadowVerticalOffset: 4
            }

            // Cover the top line so the card seamlessly merges into the top bar
            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                height: 2
                color: wallpaperWindow.bgColor
            }

            // Absorbs clicks on the card itself
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: mainLayout
                anchors {
                    fill: parent
                    topMargin: 16
                    bottomMargin: 16
                    leftMargin: 18
                    rightMargin: 18
                }
                spacing: 12

                // ─── 1. Header Row (Title, Count, Add Folder, Random, Close) ─
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    spacing: 8

                    // Title & Icon Badge
                    Rectangle {
                        implicitWidth: titleRow.implicitWidth + 22
                        implicitHeight: 30
                        radius: 15
                        color: wallpaperWindow.bgColor2

                        Row {
                            id: titleRow
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "\uf03e" // fa-image
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 13 }
                                color: wallpaperWindow.accentColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Wallpapers"
                                font { family: "Inter"; pixelSize: 13; weight: Font.Bold }
                                color: "#FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                width: 1
                                height: 12
                                color: "#3A3A3A"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: `${wallpaperWindow.allWallpapers.length} items`
                                font { family: "Inter"; pixelSize: 11; weight: Font.Medium }
                                color: wallpaperWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Status Message Pill (e.g. "Wallpaper Applied!" or "Folder Added!")
                    Rectangle {
                        visible: wallpaperWindow.statusMessage !== ""
                        implicitWidth: statusText.implicitWidth + 20
                        implicitHeight: 28
                        radius: 14
                        color: Qt.rgba(0.66, 0.71, 0.4, 0.22)
                        border.width: 1
                        border.color: wallpaperWindow.successColor

                        Text {
                            id: statusText
                            anchors.centerIn: parent
                            text: wallpaperWindow.statusMessage
                            font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                            color: wallpaperWindow.successColor
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Add Folder Button
                    Rectangle {
                        implicitWidth: addFolderRow.implicitWidth + 20
                        implicitHeight: 30
                        radius: 15
                        color: addFolderArea.containsMouse || wallpaperWindow.showAddFolderModal ? wallpaperWindow.accentColor : wallpaperWindow.bgColor2

                        Behavior on color { ColorAnimation { duration: 130 } }

                        Row {
                            id: addFolderRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "\uf07b" // fa-folder
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                color: (addFolderArea.containsMouse || wallpaperWindow.showAddFolderModal) ? "#121213" : wallpaperWindow.accentColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: wallpaperWindow.showAddFolderModal ? "Wallpapers" : "Add Folder"
                                font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                color: (addFolderArea.containsMouse || wallpaperWindow.showAddFolderModal) ? "#121213" : "#FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: addFolderArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wallpaperWindow.showAddFolderModal = !wallpaperWindow.showAddFolderModal
                                wallpaperWindow.addFolderError = ""
                            }
                        }
                    }

                    // Random Wallpaper Button
                    Rectangle {
                        visible: !wallpaperWindow.showAddFolderModal
                        implicitWidth: randomRow.implicitWidth + 20
                        implicitHeight: 30
                        radius: 15
                        color: randomArea.containsMouse ? Qt.lighter(wallpaperWindow.bgColor2, 1.4) : wallpaperWindow.bgColor2

                        Row {
                            id: randomRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "\uf074" // fa-random / shuffle
                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                color: randomArea.containsMouse ? wallpaperWindow.accentColor : wallpaperWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Random"
                                font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                color: randomArea.containsMouse ? "#FFFFFF" : wallpaperWindow.fgColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: randomArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wallpaperWindow.applyRandomWallpaper()
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: closeArea.containsMouse ? Qt.lighter(wallpaperWindow.bgColor2, 1.4) : wallpaperWindow.bgColor2

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d" // times
                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                            color: closeArea.containsMouse ? "#FFFFFF" : wallpaperWindow.fgColor
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wallpaperWindow.closeRequested()
                        }
                    }
                }

                // ─── 2. MAIN VIEW STACK (Wallpapers vs Add Folder View) ─
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // ─── VIEW A: WALLPAPERS GALLERY ───────────────────
                    ColumnLayout {
                        anchors.fill: parent
                        visible: !wallpaperWindow.showAddFolderModal
                        spacing: 12

                        // Categories Scrollable Filter Bar
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            color: "transparent"

                            Flickable {
                                id: catFlickable
                                anchors.fill: parent
                                contentWidth: catRow.implicitWidth
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true

                                Row {
                                    id: catRow
                                    spacing: 8
                                    anchors.verticalCenter: parent.verticalCenter

                                    Repeater {
                                        model: wallpaperWindow.categories

                                        delegate: Rectangle {
                                            id: catBtn
                                            implicitWidth: catLabel.implicitWidth + 20
                                            implicitHeight: 26
                                            radius: 13

                                            readonly property bool isSelected: wallpaperWindow.selectedCategory === modelData
                                            readonly property bool isHovered: catMouse.containsMouse

                                            color: {
                                                if (isSelected) return wallpaperWindow.accentColor
                                                if (isHovered) return Qt.lighter(wallpaperWindow.bgColor2, 1.35)
                                                return wallpaperWindow.bgColor2
                                            }

                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            Text {
                                                id: catLabel
                                                anchors.centerIn: parent
                                                text: modelData
                                                font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                                color: catBtn.isSelected ? "#121213" : (catBtn.isHovered ? "#FFFFFF" : wallpaperWindow.fgColor)
                                            }

                                            MouseArea {
                                                id: catMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: wallpaperWindow.selectedCategory = modelData
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Wallpaper Grid View
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 16
                            color: "#161617"
                            clip: true

                            GridView {
                                id: wallGrid
                                anchors {
                                    fill: parent
                                    margins: 10
                                }
                                cellWidth: 234
                                cellHeight: 142
                                model: wallpaperWindow.filteredWallpapers
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                delegate: Item {
                                    width: wallGrid.cellWidth
                                    height: wallGrid.cellHeight

                                    readonly property bool isCurrent: wallpaperWindow.currentWallpaperPath === modelData.path
                                    readonly property bool isHovered: itemMouse.containsMouse

                                    Rectangle {
                                        id: cardItem
                                        anchors {
                                            fill: parent
                                            margins: 5
                                        }
                                        radius: 12
                                        color: wallpaperWindow.bgColor2
                                        border.width: isCurrent ? 2 : (isHovered ? 1 : 0)
                                        border.color: isCurrent ? wallpaperWindow.accentColor : "#444444"
                                        clip: true

                                        Behavior on border.color { ColorAnimation { duration: 120 } }

                                        // Wallpaper Thumbnail Image
                                        Image {
                                            anchors.fill: parent
                                            source: "file://" + modelData.path
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            sourceSize: Qt.size(240, 140)
                                            cache: true
                                            smooth: true

                                            Rectangle {
                                                anchors.fill: parent
                                                color: isHovered ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(0, 0, 0, 0.28)
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }

                                            // Bottom dark gradient overlay for text readability
                                            Rectangle {
                                                anchors {
                                                    left: parent.left
                                                    right: parent.right
                                                    bottom: parent.bottom
                                                }
                                                height: 38
                                                gradient: Gradient {
                                                    GradientStop { position: 0.0; color: "transparent" }
                                                    GradientStop { position: 1.0; color: Qt.rgba(0.05, 0.05, 0.05, 0.88) }
                                                }
                                            }
                                        }

                                        // Active Checkmark Badge
                                        Rectangle {
                                            visible: isCurrent
                                            anchors {
                                                top: parent.top
                                                right: parent.right
                                                margins: 6
                                            }
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: wallpaperWindow.accentColor

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uf00c" // checkmark
                                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                                color: "#121213"
                                            }
                                        }

                                        // Category tag (top left on hover)
                                        Rectangle {
                                            visible: isHovered && !isCurrent
                                            anchors {
                                                top: parent.top
                                                left: parent.left
                                                margins: 6
                                            }
                                            implicitWidth: catTagText.implicitWidth + 10
                                            implicitHeight: 18
                                            radius: 9
                                            color: Qt.rgba(0.1, 0.1, 0.1, 0.75)

                                            Text {
                                                id: catTagText
                                                anchors.centerIn: parent
                                                text: modelData.category
                                                font { family: "Inter"; pixelSize: 9; weight: Font.Bold }
                                                color: "#FFFFFF"
                                            }
                                        }

                                        // Title text
                                        Text {
                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                bottom: parent.bottom
                                                margins: 8
                                            }
                                            text: modelData.name
                                            font { family: "Inter"; pixelSize: 10; weight: Font.Bold }
                                            color: isHovered || isCurrent ? "#FFFFFF" : wallpaperWindow.fgColor
                                            elide: Text.ElideRight
                                        }

                                        MouseArea {
                                            id: itemMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wallpaperWindow.applyWallpaper(modelData.path)
                                        }
                                    }
                                }
                            }

                            // Empty state (if no wallpapers in filter)
                            Text {
                                anchors.centerIn: parent
                                visible: wallpaperWindow.filteredWallpapers.length === 0
                                text: "No wallpapers found in this category"
                                font { family: "Inter"; pixelSize: 13; weight: Font.Medium }
                                color: wallpaperWindow.fgColor
                            }
                        }

                        // Footer Row
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20

                            Text {
                                text: "Current: " + (wallpaperWindow.currentWallpaperPath ? wallpaperWindow.currentWallpaperPath.split("/").pop() : "None")
                                font { family: "Inter"; pixelSize: 10; weight: Font.Medium }
                                color: wallpaperWindow.fgColor
                                elide: Text.ElideRight
                                Layout.maximumWidth: 460
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "Click any image to apply • Esc to close"
                                font { family: "Inter"; pixelSize: 10; weight: Font.Medium }
                                color: Qt.darker(wallpaperWindow.fgColor, 1.3)
                            }
                        }
                    }

                    // ─── VIEW B: MANAGE & ADD FOLDERS ─────────────────
                    Rectangle {
                        anchors.fill: parent
                        visible: wallpaperWindow.showAddFolderModal
                        radius: 16
                        color: "#161617"
                        clip: true

                        ColumnLayout {
                            anchors {
                                fill: parent
                                margins: 20
                            }
                            spacing: 14

                            // Section Title & Info
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: Qt.rgba(0.95, 0.9, 0.74, 0.15)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\uf07b" // fa-folder
                                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 14 }
                                        color: wallpaperWindow.accentColor
                                    }
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        text: "Manage Wallpaper Folders"
                                        font { family: "Inter"; pixelSize: 14; weight: Font.Bold }
                                        color: "#FFFFFF"
                                    }
                                    Text {
                                        text: "Add any folder containing wallpapers (.jpg, .png, .webp). They will be automatically indexed."
                                        font { family: "Inter"; pixelSize: 11; weight: Font.Normal }
                                        color: wallpaperWindow.fgColor
                                    }
                                }
                            }

                            // Input Box with Browse & Add Buttons
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                radius: 12
                                color: wallpaperWindow.bgColor2
                                border.width: 1
                                border.color: folderTextInput.activeFocus ? wallpaperWindow.accentColor : "#333333"

                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: 12
                                        rightMargin: 6
                                    }
                                    spacing: 8

                                    Text {
                                        text: "\uf07c" // fa-folder-open
                                        font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 13 }
                                        color: wallpaperWindow.fgColor
                                    }

                                    TextInput {
                                        id: folderTextInput
                                        Layout.fillWidth: true
                                        text: wallpaperWindow.folderInputText
                                        onTextChanged: wallpaperWindow.folderInputText = text
                                        font { family: "Inter"; pixelSize: 12; weight: Font.Medium }
                                        color: "#FFFFFF"
                                        selectByMouse: true
                                        clip: true
                                        onAccepted: wallpaperWindow.addFolder(text)

                                        Text {
                                            anchors.fill: parent
                                            text: "Enter folder path (e.g. ~/Downloads/Wallpapers or /media/walls)..."
                                            font { family: "Inter"; pixelSize: 12 }
                                            color: "#666666"
                                            visible: !folderTextInput.text && !folderTextInput.activeFocus
                                        }
                                    }

                                    // Clear input button
                                    Rectangle {
                                        visible: folderTextInput.text.length > 0
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: clearInputMouse.containsMouse ? "#3A3A3A" : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf00d" // times
                                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 10 }
                                            color: wallpaperWindow.fgColor
                                        }

                                        MouseArea {
                                            id: clearInputMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                folderTextInput.text = ""
                                                wallpaperWindow.folderInputText = ""
                                            }
                                        }
                                    }

                                    // Browse File Manager Button
                                    Rectangle {
                                        implicitWidth: browseRow.implicitWidth + 18
                                        implicitHeight: 34
                                        radius: 8
                                        color: browseMouse.containsMouse ? "#3A3A3A" : "#2B2B2B"

                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Row {
                                            id: browseRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: "\uf07c" // browse
                                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                                color: wallpaperWindow.fgColor
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: "Browse..."
                                                font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                                color: "#FFFFFF"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: browseMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wallpaperWindow.launchFolderPicker()
                                        }
                                    }

                                    // Add Button
                                    Rectangle {
                                        implicitWidth: addBtnRow.implicitWidth + 20
                                        implicitHeight: 34
                                        radius: 8
                                        color: addBtnMouse.containsMouse ? wallpaperWindow.accentColorGlow : wallpaperWindow.accentColor

                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Row {
                                            id: addBtnRow
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: "\uf067" // plus
                                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                                color: "#121213"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: "Add"
                                                font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                                color: "#121213"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: addBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wallpaperWindow.addFolder(folderTextInput.text)
                                        }
                                    }
                                }
                            }

                            // Error or Success Banner
                            Text {
                                visible: wallpaperWindow.addFolderError !== ""
                                text: "⚠️ " + wallpaperWindow.addFolderError
                                font { family: "Inter"; pixelSize: 11; weight: Font.Medium }
                                color: wallpaperWindow.errorColor
                            }

                            // Quick Suggestions
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "Quick Add:"
                                    font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                    color: wallpaperWindow.fgColor
                                }

                                Repeater {
                                    model: [
                                        { name: "Pictures", path: Quickshell.env("HOME") + "/Pictures" },
                                        { name: "Downloads", path: Quickshell.env("HOME") + "/Downloads" },
                                        { name: "Documents", path: Quickshell.env("HOME") + "/Documents" }
                                    ]

                                    delegate: Rectangle {
                                        implicitWidth: chipRow.implicitWidth + 14
                                        implicitHeight: 24
                                        radius: 12
                                        color: chipMouse.containsMouse ? Qt.lighter(wallpaperWindow.bgColor2, 1.4) : wallpaperWindow.bgColor2

                                        Row {
                                            id: chipRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            Text {
                                                text: "\uf07b"
                                                font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 9 }
                                                color: wallpaperWindow.accentColor
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: modelData.name
                                                font { family: "Inter"; pixelSize: 10; weight: Font.Medium }
                                                color: "#FFFFFF"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: chipMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                folderTextInput.text = modelData.path
                                                wallpaperWindow.folderInputText = modelData.path
                                                wallpaperWindow.addFolder(modelData.path)
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#2A2A2A"
                            }

                            // Configured Folders List Header
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "CONFIGURED FOLDERS"
                                    font { family: "Inter"; pixelSize: 10; weight: Font.Bold }
                                    color: Qt.darker(wallpaperWindow.fgColor, 1.2)
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: `${wallpaperWindow.customFolders.length} configured ${wallpaperWindow.customFolders.length === 1 ? 'folder' : 'folders'}`
                                    font { family: "Inter"; pixelSize: 10; weight: Font.Medium }
                                    color: Qt.darker(wallpaperWindow.fgColor, 1.2)
                                }
                            }

                            // Configured Folders Scroll View
                            ScrollView {
                                id: foldersScroll
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                ColumnLayout {
                                    width: foldersScroll.availableWidth
                                    spacing: 8

                                    // Configured wallpaper folders
                                    Repeater {
                                        model: wallpaperWindow.customFolders

                                        delegate: Rectangle {
                                            width: foldersScroll.availableWidth
                                            height: 42
                                            radius: 10
                                            color: wallpaperWindow.bgColor2

                                            RowLayout {
                                                anchors {
                                                    fill: parent
                                                    leftMargin: 12
                                                    rightMargin: 12
                                                }
                                                spacing: 10

                                                Text {
                                                    text: "\uf07b"
                                                    font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 12 }
                                                    color: wallpaperWindow.accentColor
                                                }

                                                ColumnLayout {
                                                    spacing: 1
                                                    Text {
                                                        text: modelData.name
                                                        font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                                        color: "#FFFFFF"
                                                    }
                                                    Text {
                                                        text: `${modelData.path} • ${modelData.count} wallpapers`
                                                        font { family: "Inter"; pixelSize: 9 }
                                                        color: wallpaperWindow.fgColor
                                                    }
                                                }

                                                Item { Layout.fillWidth: true }

                                                // Remove Button
                                                Rectangle {
                                                    implicitWidth: removeRow.implicitWidth + 14
                                                    implicitHeight: 24
                                                    radius: 12
                                                    color: removeMouse.containsMouse ? Qt.rgba(0.92, 0.41, 0.38, 0.3) : Qt.rgba(0.3, 0.3, 0.3, 0.4)
                                                    border.width: 1
                                                    border.color: removeMouse.containsMouse ? wallpaperWindow.errorColor : "transparent"

                                                    Behavior on color { ColorAnimation { duration: 120 } }

                                                    Row {
                                                        id: removeRow
                                                        anchors.centerIn: parent
                                                        spacing: 4

                                                        Text {
                                                            text: "\uf2ed" // trash
                                                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 9 }
                                                            color: removeMouse.containsMouse ? wallpaperWindow.errorColor : wallpaperWindow.fgColor
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                        Text {
                                                            text: "Remove"
                                                            font { family: "Inter"; pixelSize: 10; weight: Font.Bold }
                                                            color: removeMouse.containsMouse ? wallpaperWindow.errorColor : wallpaperWindow.fgColor
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: removeMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: wallpaperWindow.removeFolder(modelData.path)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Empty state if no custom folders
                                    Text {
                                        visible: wallpaperWindow.customFolders.length === 0
                                        text: "No custom folders added yet. You can add any directory above."
                                        font { family: "Inter"; pixelSize: 11; weight: Font.Normal }
                                        color: Qt.darker(wallpaperWindow.fgColor, 1.2)
                                        Layout.topMargin: 4
                                    }
                                }
                            }

                            // Back to Wallpapers button
                            RowLayout {
                                Layout.fillWidth: true

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    implicitWidth: backBtnRow.implicitWidth + 24
                                    implicitHeight: 32
                                    radius: 16
                                    color: backBtnMouse.containsMouse ? Qt.lighter(wallpaperWindow.bgColor2, 1.5) : wallpaperWindow.bgColor2

                                    Row {
                                        id: backBtnRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: "\uf060" // arrow-left
                                            font { family: "Font Awesome 6 Free"; weight: Font.Bold; pixelSize: 11 }
                                            color: "#FFFFFF"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "Done / Back to Wallpapers"
                                            font { family: "Inter"; pixelSize: 11; weight: Font.Bold }
                                            color: "#FFFFFF"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: backBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            wallpaperWindow.showAddFolderModal = false
                                            wallpaperWindow.addFolderError = ""
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
