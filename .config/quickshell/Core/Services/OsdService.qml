import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Core
import qs.Core.Services
pragma Singleton

Item {
    id: osdService

    property bool isOpen: false
    property string title: "Volume"
    property string valueText: "0%"
    property string icon: "volume"
    property real level: 0
    property bool isMuted: false
    property bool showProgress: true
    property bool _ready: false

    function trigger(title, valText, level, icon, isMuted) {
        osdService.title = title;
        osdService.valueText = valText;
        osdService.level = Math.max(0, Math.min(1, level));
        osdService.icon = icon;
        osdService.isMuted = isMuted;
        osdService.showProgress = true;
        osdService.isOpen = true;
        hideTimer.interval = 1500;
        hideTimer.restart();
    }

    function displayMessage(title, valText, icon, isAccent) {
        osdService.title = title;
        osdService.valueText = valText;
        osdService.icon = icon || "info";
        osdService.showProgress = false;
        osdService.isMuted = (isAccent === false);
        osdService.isOpen = true;
        hideTimer.interval = 2000;
        hideTimer.restart();
    }

    function displayToggle(title, valText, icon, isActive) {
        let active = (isActive === true || isActive === "true" || isActive === "1" || valText === "ON" || valText === "Enabled");
        let level = active ? 1 : 0;
        let isMuted = !active;
        osdService.trigger(title, valText, level, icon, isMuted);
    }

    function displayVolume(volume, isMuted) {
        let vol = 0;
        let muted = false;
        if (volume !== undefined && volume !== null && volume !== "") {
            vol = parseInt(volume);
            if (isNaN(vol))
                vol = 0;

        } else {
            let sink = Pipewire.defaultAudioSink;
            vol = (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0;
        }
        if (isMuted !== undefined && isMuted !== null && isMuted !== "") {
            muted = (isMuted === true || isMuted === "true" || isMuted === "yes" || isMuted === "1");
        } else {
            let sink = Pipewire.defaultAudioSink;
            muted = (sink && sink.audio) ? sink.audio.muted : false;
        }
        let iconName = (muted || vol === 0) ? "volume-off" : "volume";
        let text = muted ? "Muted" : (vol + "%");
        osdService.trigger("Volume", text, muted ? 0 : (vol / 100), iconName, muted);
    }

    function displayMic(volume, isMuted) {
        if (isMuted === undefined && (typeof volume === "boolean" || volume === "true" || volume === "false" || volume === "yes" || volume === "no" || volume === "1" || volume === "0")) {
            isMuted = volume;
            volume = undefined;
        }
        let vol = 0;
        if (volume !== undefined && volume !== null && volume !== "") {
            vol = parseInt(volume);
            if (isNaN(vol))
                vol = AudioService.micVolume;

        } else {
            vol = AudioService.micVolume;
        }
        let muted = false;
        if (isMuted !== undefined && isMuted !== null && isMuted !== "")
            muted = (isMuted === true || isMuted === "true" || isMuted === "yes" || isMuted === "1");
        else
            muted = AudioService.micMuted;
        let iconName = (muted || vol === 0) ? "microphone-off" : "microphone";
        let text = muted ? "Muted" : (vol + "%");
        osdService.trigger("Microphone", text, muted ? 0 : (vol / 100), iconName, muted);
    }

    function displayBrightness(percent) {
        let val = parseInt(percent);
        if (isNaN(val))
            val = 0;

        val = Math.max(0, Math.min(100, val));
        osdService.trigger("Brightness", val + "%", val / 100, "sun", false);
    }

    Timer {
        id: initDelayTimer

        interval: 1200
        running: true
        repeat: false
        onTriggered: {
            osdService._ready = true;
        }
    }

    Timer {
        id: hideTimer

        interval: 1500
        repeat: false
        onTriggered: {
            osdService.isOpen = false;
        }
    }

    Connections {
        function onVolumeChanged() {
            if (osdService._ready)
                osdService.displayVolume();

        }

        function onMutedChanged() {
            if (osdService._ready)
                osdService.displayVolume();

        }

        target: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio : null
    }

    Connections {
        function onMicMutedChanged() {
            if (osdService._ready)
                osdService.displayMic();

        }

        target: AudioService
    }

}
