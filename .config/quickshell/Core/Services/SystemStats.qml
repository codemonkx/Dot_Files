import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
pragma Singleton

Item {
    id: root

    property string osName: "Linux"
    property string hostModel: ""
    property string kernel: "Loading..."
    property string hostname: "Loading..."
    property string username: "Loading..."
    property string shell: "Loading..."
    property string wm: "Hyprland (Wayland)"
    property string packages: "Loading..."
    property string display: "Loading..."
    property string cpuModel: "Loading..."
    property string cpuCores: "Loading..."
    property string memTotal: "0 GB"
    property string diskTotal: "0 GB"
    property string gpuName: "None"
    property bool hasGpu: false
    property var gpus: []
    property real cpuUsage: 0
    property string cpuTemp: "55°C"
    property string cpuFreq: "0.00 GHz"
    property real memUsage: 0
    property real memUsed: 0
    property string memSizeText: "0.0 / 0.0 GiB"
    property real gpuUsage: 0
    property string gpuTemp: "0°C"
    property string gpuVram: "GPU Active"
    property var disks: []

    function updateDaemon() {
        statsProc.command = ["python3", Quickshell.shellDir + "/Scripts/system/get_processes.py", String(SystemInfoService.performanceInterval), "cpu", "--daemon", "--no-processes"];
        statsProc.running = false;
        statsProc.running = true;
    }

    Component.onCompleted: {
        if (!staticInfoProc.running)
            staticInfoProc.running = true;

        updateDaemon();
    }

    Connections {
        function onPerformanceIntervalChanged() {
            updateDaemon();
        }

        target: SystemInfoService
    }

    Process {
        id: staticInfoProc

        command: ["python3", Quickshell.shellDir + "/Scripts/system/get_system_info.py"]
        running: true
        onExited: (exitCode) => {
            if (exitCode === 0) {
                try {
                    let info = JSON.parse(staticStdout.text.trim());
                    root.osName = info.os || "Linux";
                    root.hostModel = info.host || "";
                    root.kernel = info.kernel || "";
                    root.hostname = info.hostname || "";
                    root.username = info.username || "";
                    root.shell = info.shell || "";
                    root.wm = info.wm || "Hyprland (Wayland)";
                    root.packages = info.packages || "";
                    root.display = info.display || "";
                    root.cpuModel = info.cpu_model || "";
                    root.cpuCores = info.cpu_cores || "";
                    root.memTotal = info.ram_total || "0 GB";
                    root.diskTotal = info.disk_total || "0 GB";
                    root.gpuName = info.gpus || "None";
                    root.hasGpu = root.gpuName !== "" && root.gpuName !== "None" && root.gpuName !== "Integrated Graphics";
                } catch (e) {
                    console.error("Error parsing get_system_info.py JSON: " + e);
                }
            }
        }

        stdout: StdioCollector {
            id: staticStdout
        }

    }

    Process {
        id: statsProc

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let parsedData = JSON.parse(data.trim());
                    if (parsedData.system) {
                        let sys = parsedData.system;
                        root.cpuUsage = sys.cpu_usage || 0;
                        root.memUsage = sys.mem_usage || 0;
                        root.memUsed = sys.mem_used_gb || 0;
                        root.memSizeText = root.memUsed.toFixed(1) + " / " + root.memTotal;
                        root.cpuTemp = sys.cpu_temp || "55°C";
                        root.cpuFreq = sys.cpu_freq || "N/A";
                        if (sys.cpu_cores)
                            root.cpuCores = sys.cpu_cores;

                    }
                    if (Array.isArray(parsedData.gpus)) {
                        root.gpus = parsedData.gpus;
                        if (root.gpus.length > 0) {
                            let gpu = root.gpus[0];
                            root.gpuName = gpu.name || root.gpuName;
                            root.hasGpu = true;
                            root.gpuUsage = gpu.usage || 0;
                            root.gpuTemp = gpu.temp || "0°C";
                            root.gpuVram = gpu.vram || "GPU Active";
                        }
                    } else if (parsedData.gpu) {
                        let gpu = parsedData.gpu;
                        root.gpus = [gpu];
                        if (gpu.name && root.gpuName === "None")
                            root.gpuName = gpu.name;

                        root.hasGpu = gpu.has_gpu || root.hasGpu;
                        root.gpuUsage = gpu.usage || 0;
                        root.gpuTemp = gpu.temp || "0°C";
                        root.gpuVram = gpu.vram || "GPU Active";
                    }
                    if (parsedData.storage && Array.isArray(parsedData.storage))
                        root.disks = parsedData.storage.map((s) => {
                        return ({
                            "name": s.device,
                            "mount": s.mount,
                            "usage": s.usage || 0,
                            "sizeText": s.used_gib.toFixed(1) + " / " + s.total_gib.toFixed(1) + " GiB",
                            "usedGib": s.used_gib,
                            "totalGib": s.total_gib
                        });
                    });

                } catch (e) {
                    console.error("Error parsing stats JSON: " + e);
                }
            }
        }

    }

}
