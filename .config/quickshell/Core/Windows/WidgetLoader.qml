import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property string widgetId: ""
    property Component sourceComponent
    property bool enabled: true
    property bool exclusive: true
    property bool _isInternalActive: false
    readonly property bool isBarOverlayHandled: AppState.isBarOverlayWidget(widgetId)
    readonly property bool isIslandHandled: !DisplayProfileService.gameModeActive && SettingsService.barIslandMode && isBarOverlayHandled
    readonly property bool isConvexHandled: !DisplayProfileService.gameModeActive && SettingsService.barConvexMode && isBarOverlayHandled
    readonly property bool isGamingHandled: DisplayProfileService.gameModeActive && isBarOverlayHandled
    readonly property bool shouldLoadWindow: enabled && !isIslandHandled && !isConvexHandled && !isGamingHandled
    readonly property bool _isActive: shouldLoadWindow && (exclusive ? AppState.isWidgetOpen(widgetId) : _isInternalActive)
    property bool _isClosing: false
    property bool _pendingOpen: false
    property alias item: loader.item

    on_IsActiveChanged: {
        if (widgetId === "")
            return ;

        if (_isActive) {
            _isClosing = false;
            loader.active = true;
            if (loader.status === Loader.Ready && loader.item)
                loader.item.isOpen = true;

        } else {
            if (loader.item)
                loader.item.isOpen = false;

            _isClosing = true;
        }
    }
    Component.onCompleted: {
        if (root.widgetId !== "")
            socketCleanupProc.running = true;

    }
    Component.onDestruction: {
        server.active = false;
    }

    Process {
        id: socketCleanupProc

        command: ["rm", "-f", "/tmp/quickshell_" + root.widgetId]
        onExited: {
            if (root.widgetId !== "")
                server.active = true;

        }
    }

    Connections {
        function onToggleWidget(id) {
            if (root.widgetId === "" || id !== root.widgetId)
                return ;

            if (root._pendingOpen) {
                root._pendingOpen = false;
                return ;
            }
            if (root._isInternalActive) {
                root._isInternalActive = false;
                return ;
            }
            if (AppState.islandClosing) {
                root._pendingOpen = true;
                return ;
            }
            root._isInternalActive = true;
        }

        function onOpenWidget(id) {
            if (root.widgetId === "" || id !== root.widgetId)
                return ;

            if (root._isInternalActive)
                return ;

            if (AppState.islandClosing)
                // Loading a heavy QML window while the island collapses makes
                // the close animation stutter. Open it once the animation ends.
                root._pendingOpen = true;
            else
                root._isInternalActive = true;
        }

        function onIslandClosingChanged() {
            if (AppState.islandClosing || !root._pendingOpen)
                return ;

            root._pendingOpen = false;
            root._isInternalActive = true;
        }

        target: AppState
        enabled: root.enabled && !root.exclusive && root.shouldLoadWindow
    }

    Loader {
        id: loader

        anchors.fill: parent
        active: false
        sourceComponent: root.sourceComponent
        onStatusChanged: {
            if (status === Loader.Ready && root._isActive && item)
                item.isOpen = true;

        }

        Connections {
            function onFullyClosed() {
                loader.active = false;
                root._isClosing = false;
                if (!root.exclusive)
                    root._isInternalActive = false;

                AppState.closeWidget(root.widgetId);
            }

            target: loader.item
            ignoreUnknownSignals: true
        }

    }

    SocketServer {
        id: server

        path: root.widgetId !== "" ? "/tmp/quickshell_" + root.widgetId : ""
        active: false

        handler: Component {
            Socket {
                onConnectedChanged: {
                    if (connected) {
                        AppState.toggleWidget(root.widgetId);
                        Qt.callLater(() => {
                            connected = false;
                        });
                    }
                }
            }

        }

    }

}
