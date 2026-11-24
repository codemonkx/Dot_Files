import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Core.Services

Item {
    id: root

    property bool authenticating: false
    property bool authFailed: false
    property bool unlocking: false

    signal authSucceeded()
    signal toggleLockRequested()
    signal unlockRequested()

    function reset() {
        root.authFailed = false;
        root.authenticating = false;
        root.unlocking = false;
    }

    function submitPassword(pwd) {
        if (root.authenticating)
            return ;

        authProc.running = false;
        root.authenticating = true;
        root.authFailed = false;
        authProc.command = ["python3", Quickshell.shellDir + "/Scripts/system/auth.py"];
        authProc.running = true;
        authProc.write(pwd + "\n");
    }

    Component.onCompleted: {
        socketCleanupProc.running = true;
    }
    Component.onDestruction: {
        server.active = false;
    }

    Timer {
        id: socketRecoveryTimer

        interval: 350
        running: true
        repeat: false
        onTriggered: {
            server.active = false;
            server.active = true;
        }
    }

    IpcHandler {
        function toggle() {
            root.toggleLockRequested();
        }

        function unlock() {
            root.unlockRequested();
        }

        target: "lockScreen"
    }

    Process {
        id: socketCleanupProc

        command: ["rm", "-f", "/tmp/quickshell_lockScreen"]
        onExited: {
            server.active = true;
        }
    }

    SocketServer {
        id: server

        path: "/tmp/quickshell_lockScreen"
        active: false

        handler: Component {
            Socket {
                onConnectedChanged: {
                    if (connected) {
                        root.toggleLockRequested();
                        Qt.callLater(() => {
                            connected = false;
                        });
                    }
                }
            }

        }

    }

    Process {
        id: authProc

        onExited: function(exitCode) {
            if (!root.authenticating)
                return ;

            root.authenticating = false;
            if (exitCode === 0) {
                root.unlocking = true;
                root.authSucceeded();
            } else {
                root.authFailed = true;
            }
        }
    }

}
