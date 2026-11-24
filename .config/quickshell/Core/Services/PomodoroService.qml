import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Item {
    id: root

    readonly property int tickInterval: 250
    readonly property int saveDelay: 500
    readonly property string statePath: Quickshell.env("HOME") + "/.cache/quickshell/pomodoro_state.json"
    property bool stateLoaded: false
    property string phase: "focus"
    property bool running: false
    property real endsAt: 0
    property real remainingMs: 25 * 60000
    property real sessionTotalMs: 25 * 60000
    property int focusCountInCycle: 0
    property int completedToday: 0
    property string completedDate: ""
    // User configuration
    property int focusMinutes: 25
    property int shortBreakMinutes: 5
    property int longBreakMinutes: 15
    property int longBreakEvery: 4
    property bool autoStart: true
    property bool notifications: true
    property bool soundEnabled: true
    readonly property bool isFocus: phase === "focus"
    readonly property bool isIdle: !running && (remainingMs >= sessionTotalMs - 1 || remainingMs <= 0)
    readonly property int todayCompletedCount: completedDate === dateKey() ? completedToday : 0
    readonly property int cyclePosition: Math.min(focusCountInCycle, longBreakEvery)
    readonly property real progress: sessionTotalMs > 0 ? Math.max(0, Math.min(1, 1 - remainingMs / sessionTotalMs)) : 0
    readonly property string phaseLabel: phase === "focus" ? "FOCUS" : (phase === "shortBreak" ? "SHORT BREAK" : "LONG BREAK")
    readonly property string formattedTime: {
        let totalSeconds = Math.ceil(Math.max(0, remainingMs) / 1000);
        let minutes = Math.floor(totalSeconds / 60);
        let seconds = totalSeconds % 60;
        return (minutes < 10 ? "0" : "") + minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
    }

    signal phaseCompleted(string finishedPhase)

    function minutesForPhase(targetPhase) {
        if (targetPhase === "shortBreak")
            return shortBreakMinutes;

        if (targetPhase === "longBreak")
            return longBreakMinutes;

        return focusMinutes;
    }

    function dateKey() {
        let now = new Date();
        return now.getFullYear() + "-" + (now.getMonth() + 1) + "-" + now.getDate();
    }

    function normalizedCompletedToday() {
        return completedDate === dateKey() ? completedToday : 0;
    }

    function start() {
        if (!stateLoaded) {
            loadState();
            return ;
        }
        if (running)
            return ;

        let duration = minutesForPhase(phase) * 60000;
        if (remainingMs <= 0 || sessionTotalMs <= 0) {
            sessionTotalMs = duration;
            remainingMs = sessionTotalMs;
        }
        endsAt = Date.now() + remainingMs;
        running = true;
        saveDebounced();
    }

    function pause() {
        if (!running)
            return ;

        remainingMs = Math.max(0, endsAt - Date.now());
        running = false;
        saveDebounced();
    }

    function toggle() {
        if (running)
            pause();
        else
            start();
    }

    function reset() {
        running = false;
        endsAt = 0;
        sessionTotalMs = minutesForPhase(phase) * 60000;
        remainingMs = sessionTotalMs;
        saveDebounced();
    }

    function setPhase(targetPhase) {
        if (targetPhase !== "focus" && targetPhase !== "shortBreak" && targetPhase !== "longBreak")
            return ;

        // Clicking the active phase must not wipe the current session.
        // Restarting is explicit: use reset().
        if (phase === targetPhase)
            return ;

        phase = targetPhase;
        running = false;
        endsAt = 0;
        sessionTotalMs = minutesForPhase(phase) * 60000;
        remainingMs = sessionTotalMs;
        saveDebounced();
    }

    function skip() {
        // Skipping is only allowed on breaks. A focus session can only be
        // abandoned with reset(), which never counts towards the total.
        if (phase === "focus")
            return ;

        advance(false, false);
    }

    function nextPhaseFor(finishedPhase) {
        if (finishedPhase !== "focus")
            return "focus";

        return focusCountInCycle >= longBreakEvery ? "longBreak" : "shortBreak";
    }

    function advance(completed, announce) {
        if (announce === undefined)
            announce = true;

        let finishedPhase = phase;
        running = false;
        endsAt = 0;
        if (finishedPhase === "focus" && completed) {
            completedToday = normalizedCompletedToday() + 1;
            completedDate = dateKey();
            focusCountInCycle += 1;
        }
        let nextPhase = nextPhaseFor(finishedPhase);
        if (finishedPhase === "longBreak")
            focusCountInCycle = 0;

        phase = nextPhase;
        sessionTotalMs = minutesForPhase(phase) * 60000;
        remainingMs = sessionTotalMs;
        if (completed)
            phaseCompleted(finishedPhase);

        if (announce)
            notifyPhaseEnd(finishedPhase, nextPhase);

        if (autoStart)
            start();

        saveDebounced();
    }

    function tick() {
        if (!running)
            return ;

        remainingMs = Math.max(0, endsAt - Date.now());
        if (remainingMs <= 0.001)
            advance(true);

    }

    function notifyPhaseEnd(finishedPhase, nextPhase) {
        if (!notifications && !soundEnabled)
            return ;

        let body = "";
        let soundFile = "/usr/share/sounds/freedesktop/stereo/complete.oga";
        let canberraId = "complete";
        if (finishedPhase === "focus") {
            body = nextPhase === "longBreak" ? "Great work. Take a long break of " + longBreakMinutes + " minutes." : "Focus session complete. Take a " + shortBreakMinutes + " minute break.";
            soundFile = "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga";
            canberraId = "alarm-clock-elapsed";
        } else {
            body = "Break finished. Time to focus for " + focusMinutes + " minutes.";
        }
        let iconPath = Quickshell.shellDir + "/assets/alarm.svg";
        // Every value travels as an argument (argv for notify-send, "$1"/"$2" for
        // the sound fallback), so nothing is interpolated into shell code.
        if (notifications) {
            notificationProc.command = ["notify-send", "-a", "Pomodoro", "-i", iconPath, "Pomodoro", body];
            notificationProc.running = false;
            notificationProc.running = true;
        }
        if (soundEnabled) {
            soundProc.command = ["sh", "-c", "paplay \"$1\" 2>/dev/null || canberra-gtk-play -i \"$2\" 2>/dev/null || true", "minflair-pomodoro", soundFile, canberraId];
            soundProc.running = false;
            soundProc.running = true;
        }
    }

    function saveDebounced() {
        if (!stateLoaded)
            return ;

        saveTimer.restart();
    }

    function writeState() {
        let data = {
            "phase": phase,
            "running": running,
            "endsAt": endsAt,
            "remainingMs": remainingMs,
            "sessionTotalMs": sessionTotalMs,
            "focusCountInCycle": focusCountInCycle,
            "completedToday": completedToday,
            "completedDate": completedDate,
            "focusMinutes": focusMinutes,
            "shortBreakMinutes": shortBreakMinutes,
            "longBreakMinutes": longBreakMinutes,
            "longBreakEvery": longBreakEvery,
            "autoStart": autoStart,
            "notifications": notifications,
            "soundEnabled": soundEnabled
        };
        saver.command = ["sh", "-c", "mkdir -p ~/.cache/quickshell && cat << 'EOF' > ~/.cache/quickshell/pomodoro_state.json.tmp\n" + JSON.stringify(data) + "\nEOF\nmv -f ~/.cache/quickshell/pomodoro_state.json.tmp ~/.cache/quickshell/pomodoro_state.json"];
        saver.running = false;
        saver.running = true;
    }

    function applyState(data) {
        if (!data)
            return ;

        if (typeof data.focusMinutes === "number")
            focusMinutes = Math.max(1, Math.min(120, Math.round(data.focusMinutes)));

        if (typeof data.shortBreakMinutes === "number")
            shortBreakMinutes = Math.max(1, Math.min(60, Math.round(data.shortBreakMinutes)));

        if (typeof data.longBreakMinutes === "number")
            longBreakMinutes = Math.max(1, Math.min(90, Math.round(data.longBreakMinutes)));

        if (typeof data.longBreakEvery === "number")
            longBreakEvery = Math.max(1, Math.min(12, Math.round(data.longBreakEvery)));

        if (typeof data.autoStart === "boolean")
            autoStart = data.autoStart;

        if (typeof data.notifications === "boolean")
            notifications = data.notifications;

        if (typeof data.soundEnabled === "boolean")
            soundEnabled = data.soundEnabled;

        if (data.phase === "focus" || data.phase === "shortBreak" || data.phase === "longBreak")
            phase = data.phase;

        if (typeof data.focusCountInCycle === "number")
            focusCountInCycle = Math.max(0, Math.round(data.focusCountInCycle));

        if (typeof data.completedToday === "number")
            completedToday = Math.max(0, Math.round(data.completedToday));

        if (typeof data.completedDate === "string")
            completedDate = data.completedDate;

        if (typeof data.sessionTotalMs === "number" && data.sessionTotalMs > 0)
            sessionTotalMs = data.sessionTotalMs;
        else
            sessionTotalMs = minutesForPhase(phase) * 60000;
        if (data.running === true && typeof data.endsAt === "number" && data.endsAt > Date.now()) {
            running = true;
            endsAt = data.endsAt;
            remainingMs = Math.max(0, endsAt - Date.now());
        } else {
            running = false;
            endsAt = 0;
            if (typeof data.remainingMs === "number")
                remainingMs = Math.max(0, Math.min(sessionTotalMs, data.remainingMs));
            else
                remainingMs = sessionTotalMs;
        }
        // A session that expired while the shell was not running stays paused at zero.
        if (!running && remainingMs < 1000)
            remainingMs = 0;

    }

    function loadState() {
        if (stateLoaded || loader.running)
            return ;

        loader.running = true;
    }

    function handleDurationChange(targetPhase) {
        if (phase === targetPhase && isIdle) {
            sessionTotalMs = minutesForPhase(targetPhase) * 60000;
            remainingMs = sessionTotalMs;
        }
        saveDebounced();
    }

    Component.onCompleted: loadState()
    onFocusMinutesChanged: handleDurationChange("focus")
    onShortBreakMinutesChanged: handleDurationChange("shortBreak")
    onLongBreakMinutesChanged: handleDurationChange("longBreak")
    onLongBreakEveryChanged: saveDebounced()
    onAutoStartChanged: saveDebounced()
    onNotificationsChanged: saveDebounced()
    onSoundEnabledChanged: saveDebounced()

    Timer {
        id: tickTimer

        interval: root.tickInterval
        repeat: true
        running: root.running
        onTriggered: root.tick()
    }

    Timer {
        id: saveTimer

        interval: root.saveDelay
        repeat: false
        onTriggered: root.writeState()
    }

    Process {
        id: loader

        command: ["cat", root.statePath]
        onExited: function(exitCode) {
            let raw = loaderOutput.text ? loaderOutput.text.trim() : "";
            if (exitCode === 0 && raw.length > 0) {
                try {
                    root.applyState(JSON.parse(raw));
                } catch (e) {
                    console.error("Error loading pomodoro state: " + e);
                }
            }
            root.stateLoaded = true;
            root.saveDebounced();
        }

        stdout: StdioCollector {
            id: loaderOutput
        }

    }

    Process {
        id: saver
    }

    Process {
        id: notificationProc
    }

    Process {
        id: soundProc
    }

}
