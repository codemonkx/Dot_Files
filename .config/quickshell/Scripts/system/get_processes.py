#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import os
import pwd
import re
import shutil
import subprocess
import time

uid_to_user = {}
_gpus_meta_cache = None  # list of {name, vendor, pci, is_discrete, nv_idx}


def get_user_by_uid(uid):
    if uid not in uid_to_user:
        try:
            uid_to_user[uid] = pwd.getpwuid(uid).pw_name
        except Exception:
            uid_to_user[uid] = str(uid)
    return uid_to_user[uid]


def format_memory(bytes_val):
    if bytes_val >= 1024 * 1024 * 1024:
        return f"{bytes_val / (1024 * 1024 * 1024):.1f} GB"
    elif bytes_val >= 1024 * 1024:
        return f"{bytes_val / (1024 * 1024):.0f} MB"
    elif bytes_val >= 1024:
        return f"{bytes_val / 1024:.0f} KB"
    else:
        return f"{bytes_val} B"


def get_system_cpu_ticks():
    try:
        with open("/proc/stat", "r") as f:
            line = f.readline()
        if line.startswith("cpu "):
            parts = line.split()
            # user nice system idle iowait irq softirq steal
            fields = [int(p) for p in parts[1:9]]
            total = sum(fields)
            idle = fields[3] + fields[4]  # idle + iowait
            return {"total": total, "idle": idle}
    except Exception:
        pass
    return {"total": 0, "idle": 0}


def get_all_processes_ticks():
    proc_data = {}
    page_size = os.sysconf("SC_PAGE_SIZE")
    for pid_str in os.listdir("/proc"):
        if pid_str.isdigit():
            pid = int(pid_str)
            try:
                stat_info = os.stat(f"/proc/{pid}")
                uid = stat_info.st_uid

                with open(f"/proc/{pid}/stat", "r") as f:
                    stat_content = f.read()

                parts = stat_content.split(")")
                if len(parts) >= 2:
                    comm = parts[0].split("(")[1]
                    rest = parts[1].split()
                    utime = int(rest[11])
                    stime = int(rest[12])
                    rss_pages = int(rest[21])

                    cmdline = ""
                    try:
                        with open(f"/proc/{pid}/cmdline", "r") as cf:
                            raw_cmd = cf.read()
                            cmdline = raw_cmd.replace("\x00", " ").strip()
                    except Exception:
                        pass
                    if not cmdline:
                        cmdline = comm

                    proc_data[pid] = {
                        "comm": comm,
                        "utime": utime,
                        "stime": stime,
                        "rss_bytes": rss_pages * page_size,
                        "uid": uid,
                        "cmdline": cmdline,
                    }
            except (
                FileNotFoundError,
                ProcessLookupError,
                PermissionError,
                IndexError,
                ValueError,
            ):
                continue
    return proc_data


def get_system_mem():
    try:
        with open("/proc/meminfo", "r") as f:
            meminfo = {}
            for line in f:
                parts = line.split(":")
                if len(parts) == 2:
                    meminfo[parts[0].strip()] = parts[1].strip()
        total_kb = float(meminfo["MemTotal"].split()[0])
        avail_kb = float(meminfo["MemAvailable"].split()[0])
        used_kb = total_kb - avail_kb

        mem_total_gb = round(total_kb / (1024 * 1024), 1)
        mem_used_gb = round(used_kb / (1024 * 1024), 1)
        system_mem_pct = round((used_kb / total_kb) * 100, 1)
        return {
            "mem_usage": system_mem_pct,
            "mem_total_gb": mem_total_gb,
            "mem_used_gb": mem_used_gb,
        }
    except Exception:
        return {"mem_usage": 0.0, "mem_total_gb": 0.0, "mem_used_gb": 0.0}


def get_system_tasks():
    try:
        with open("/proc/loadavg", "r") as f:
            return int(f.read().split()[3].split("/")[1])
    except Exception:
        return 0


def get_cpu_temp():
    try:
        hwmon_base = "/sys/class/hwmon"
        if os.path.exists(hwmon_base):
            for hwmon in os.listdir(hwmon_base):
                hwmon_path = os.path.join(hwmon_base, hwmon)
                name_path = os.path.join(hwmon_path, "name")
                if os.path.exists(name_path):
                    with open(name_path, "r") as f:
                        name = f.read().strip()
                    if name in [
                        "coretemp",
                        "k10temp",
                        "cpu_thermal",
                        "zenpower",
                        "Tctl",
                    ]:
                        for file in os.listdir(hwmon_path):
                            if file.startswith("temp") and file.endswith("_input"):
                                with open(os.path.join(hwmon_path, file), "r") as f:
                                    t = int(f.read().strip())
                                    if t > 0:
                                        return f"{t // 1000}°C"
    except Exception:
        pass

    try:
        thermal_base = "/sys/class/thermal"
        if os.path.exists(thermal_base):
            for zone in os.listdir(thermal_base):
                if zone.startswith("thermal_zone"):
                    zone_path = os.path.join(thermal_base, zone)
                    type_path = os.path.join(zone_path, "type")
                    if os.path.exists(type_path):
                        with open(type_path, "r") as f:
                            ztype = f.read().strip()
                        if ztype in ["x86_pkg_temp", "cpu_thermal", "acpitz"]:
                            temp_path = os.path.join(zone_path, "temp")
                            if os.path.exists(temp_path):
                                with open(temp_path, "r") as f:
                                    t = int(f.read().strip())
                                    if t > 0:
                                        return f"{t // 1000}°C"
    except Exception:
        pass

    temp_files = [
        "/sys/class/thermal/thermal_zone0/temp",
        "/sys/class/thermal/thermal_zone1/temp",
        "/sys/class/hwmon/hwmon0/temp1_input",
        "/sys/class/hwmon/hwmon1/temp1_input",
    ]
    for tf in temp_files:
        if os.path.exists(tf):
            try:
                with open(tf) as f:
                    t = int(f.read().strip())
                    return f"{t // 1000}°C"
            except Exception:
                pass
    return "55°C"


def get_uptime():
    try:
        with open("/proc/uptime") as f:
            uptime_seconds = float(f.read().split()[0])
        hours = int(uptime_seconds // 3600)
        minutes = int((uptime_seconds % 3600) // 60)
        if hours > 0:
            return f"{hours}h {minutes}m"
        else:
            return f"{minutes}m"
    except Exception:
        return "N/A"


def get_cpu_frequency():
    try:
        freq_list = []
        base_path = "/sys/devices/system/cpu"
        for dirname in os.listdir(base_path):
            if dirname.startswith("cpu") and dirname[3:].isdigit():
                freq_file = f"{base_path}/{dirname}/cpufreq/scaling_cur_freq"
                if os.path.exists(freq_file):
                    with open(freq_file, "r") as f:
                        freq_list.append(int(f.read().strip()))
        if freq_list:
            avg_khz = sum(freq_list) / len(freq_list)
            return f"{avg_khz / 1000000.0:.2f} GHz"
    except Exception:
        pass
    return "N/A"


def get_load_average():
    try:
        with open("/proc/loadavg", "r") as f:
            parts = f.read().split()
            return f"{parts[0]} {parts[1]} {parts[2]}"
    except Exception:
        return "0.00 0.00 0.00"


def get_cores_text():
    num_cores = os.cpu_count() or 1
    return f"{num_cores} Cores"


def _get_all_gpus_meta():
    """Detect all GPU devices via lspci -D. Sorted discrete-first. Cached."""
    global _gpus_meta_cache
    if _gpus_meta_cache is not None:
        return _gpus_meta_cache
    found = []
    try:
        res = subprocess.run(
            ["lspci", "-D"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        if res.returncode == 0:
            nv_idx = 0
            for line in res.stdout.splitlines():
                if not any(
                    x in line.lower()
                    for x in ["vga", "3d controller", "display controller"]
                ):
                    continue
                raw_name = None
                lower_line = line.lower()
                for keyword in [
                    "vga compatible controller:",
                    "3d controller:",
                    "display controller:",
                ]:
                    idx = lower_line.find(keyword)
                    if idx != -1:
                        raw_name = line[idx + len(keyword) :].strip()
                        break
                if not raw_name:
                    parts = line.split(":")
                    if len(parts) >= 3:
                        raw_name = ":".join(parts[2:]).strip()
                if not raw_name:
                    continue

                pci_slot = line.split()[0] if line.split() else ""
                vendor = ""
                if re.search(r"\bnvidia\b", raw_name.lower()):
                    vendor = "NVIDIA"
                elif re.search(r"\b(amd|ati)\b", raw_name.lower()):
                    vendor = "AMD"
                elif re.search(r"\bintel\b", raw_name.lower()):
                    vendor = "Intel"

                bracket_match = re.search(r"\[([^\]]+)\]", raw_name)
                if bracket_match:
                    model = bracket_match.group(1).strip()
                    if vendor and not model.lower().startswith(vendor.lower()):
                        name = f"{vendor} {model}"
                    else:
                        name = model
                else:
                    name = raw_name
                    name = re.sub(r"\(rev\s+[0-9a-fA-F]+\)", "", name)
                    name = (
                        name.replace("Corporation", "")
                        .replace("Technologies", "")
                        .replace("Inc.", "")
                        .strip()
                    )
                    name = " ".join(name.split())

                is_discrete = any(
                    k in name.lower()
                    for k in ["nvidia", "geforce", "rtx", "gtx", "amd", "radeon"]
                )
                current_nv_idx = None
                if vendor == "NVIDIA":
                    current_nv_idx = nv_idx
                    nv_idx += 1
                found.append(
                    {
                        "name": name,
                        "vendor": vendor,
                        "pci": pci_slot,
                        "is_discrete": is_discrete,
                        "nv_idx": current_nv_idx,
                    }
                )
    except Exception:
        pass
    # Sort: discrete GPUs first
    found.sort(key=lambda x: (1 if x["is_discrete"] else 0), reverse=True)
    _gpus_meta_cache = found
    return _gpus_meta_cache


def _get_intel_igpu_usage(pci_slot):
    """Estimate Intel iGPU usage from gt_act_freq_mhz / gt_RP0_freq_mhz sysfs ratio."""
    usage = 0
    drm_base = "/sys/class/drm"
    if not os.path.exists(drm_base):
        return usage
    try:
        for card in os.listdir(drm_base):
            if not (card.startswith("card") and "-" not in card):
                continue
            dev_path = os.path.realpath(f"{drm_base}/{card}/device")
            if pci_slot and pci_slot not in dev_path:
                continue
            act_f = f"{drm_base}/{card}/gt_act_freq_mhz"
            min_f = f"{drm_base}/{card}/gt_min_freq_mhz"
            max_f = f"{drm_base}/{card}/gt_RP0_freq_mhz"
            if os.path.exists(act_f) and os.path.exists(max_f):
                cur = int(open(act_f).read().strip())
                mn = int(open(min_f).read().strip()) if os.path.exists(min_f) else 350
                mx = int(open(max_f).read().strip())
                if mx > mn:
                    usage = max(0, min(100, int(round((cur - mn) / (mx - mn) * 100))))
            break
    except Exception:
        pass
    return usage


# Intel iGPU utilisation is sampled from the DRM client fdinfo interface
# (cumulative per-engine busy nanoseconds). btop reports the same metric, but
# reads it straight from the privileged i915 PMU (CAP_PERFMON); the fdinfo
# interface is readable without extra privileges.
_INTEL_ENGINES = (
    "drm-engine-render",
    "drm-engine-copy",
    "drm-engine-video",
    "drm-engine-video-enhance",
)
_intel_engine_state = {}  # pci_slot -> (monotonic_ts, {client_id: {engine: ns}})


def _read_intel_engine_clients(pci_slot):
    """Return {client_id: {engine: busy_ns}} for a GPU from /proc/*/fdinfo."""
    target = (pci_slot or "").lower()
    clients = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        fd_dir = f"/proc/{pid}/fd"
        try:
            fds = os.listdir(fd_dir)
        except OSError:
            continue
        for fd in fds:
            try:
                if not os.readlink(f"{fd_dir}/{fd}").startswith("/dev/dri/"):
                    continue
            except OSError:
                continue
            try:
                with open(f"/proc/{pid}/fdinfo/{fd}", "r") as f:
                    data = f.read()
            except OSError:
                continue
            if "drm-pdev:" not in data:
                continue
            client_id = None
            pdev = None
            counters = {}
            for line in data.splitlines():
                if line.startswith("drm-client-id:"):
                    client_id = line.split(":", 1)[1].strip()
                elif line.startswith("drm-pdev:"):
                    pdev = line.split(":", 1)[1].strip().lower()
                elif line.startswith("drm-engine-"):
                    key, _, value = line.partition(":")
                    key = key.strip()
                    if key in _INTEL_ENGINES:
                        try:
                            counters[key] = int(value.strip().split()[0])
                        except (ValueError, IndexError):
                            pass
            if not counters or pdev != target:
                continue
            if client_id is None:
                client_id = f"{pid}:{fd}"
            current = clients.setdefault(client_id, {})
            # Duplicated fds report the same client; keep the highest value
            for key, value in counters.items():
                if value > current.get(key, 0):
                    current[key] = value
    return clients


def _get_intel_igpu_usage_engine(pci_slot, min_window=0.15):
    """Real Intel iGPU busy% from per-client DRM engine counters.

    Returns None when no baseline is available yet, so the caller can fall
    back to the frequency heuristic. Like btop, the busiest engine wins.
    """
    snapshot = _read_intel_engine_clients(pci_slot)
    now = time.monotonic()
    prev = _intel_engine_state.get(pci_slot)
    # First sighting: take a short second sample so a value is ready immediately
    if prev is None and snapshot:
        time.sleep(min_window)
        previous_ts, previous_snapshot = now, snapshot
        snapshot = _read_intel_engine_clients(pci_slot)
        now = time.monotonic()
        prev = (previous_ts, previous_snapshot)
    _intel_engine_state[pci_slot] = (now, snapshot)
    if prev is None or not snapshot:
        return None
    prev_ts, prev_snapshot = prev
    elapsed = now - prev_ts
    if elapsed < min_window:
        return None
    best = 0.0
    for engine in _INTEL_ENGINES:
        busy_ns = 0
        for client_id, counters in snapshot.items():
            previous = prev_snapshot.get(client_id)
            if not previous:
                continue  # new client: skip until we have a baseline
            before = previous.get(engine)
            after = counters.get(engine)
            if before is None or after is None or after <= before:
                continue
            busy_ns += after - before
        best = max(best, busy_ns / 1e9 / elapsed * 100.0)
    return max(0, min(100, int(round(best))))


def _get_amd_drm_metrics(pci_slot):
    """Read AMD GPU busy%, VRAM and hwmon temp from sysfs."""
    usage, temp, vram = 0, "50°C", "GPU Active"
    drm_base = "/sys/class/drm"
    if not os.path.exists(drm_base):
        return usage, temp, vram
    try:
        for card in [
            c for c in os.listdir(drm_base) if c.startswith("card") and "-" not in c
        ]:
            dev_path = os.path.realpath(f"{drm_base}/{card}/device")
            if pci_slot and pci_slot not in dev_path:
                continue
            busy_f = f"{drm_base}/{card}/device/gpu_busy_percent"
            if os.path.exists(busy_f):
                usage = int(open(busy_f).read().strip())
            hwmon_dir = f"{drm_base}/{card}/device/hwmon"
            if os.path.exists(hwmon_dir):
                for hm in os.listdir(hwmon_dir):
                    tf = f"{hwmon_dir}/{hm}/temp1_input"
                    if os.path.exists(tf):
                        temp = f"{int(open(tf).read().strip()) // 1000}°C"
                        break
            used_f = f"{drm_base}/{card}/device/mem_info_vram_used"
            total_f = f"{drm_base}/{card}/device/mem_info_vram_total"
            if os.path.exists(used_f) and os.path.exists(total_f):
                vu = round(int(open(used_f).read().strip()) / (1024**3), 1)
                vt = round(int(open(total_f).read().strip()) / (1024**3), 1)
                vram = f"{vu} / {vt} GB"
            break
    except Exception:
        pass
    return usage, temp, vram


def get_gpus_info():
    """Return a list of GPU info dicts, one per detected GPU."""
    gpus_meta = _get_all_gpus_meta()
    if not gpus_meta:
        return []

    # Batch-query all NVIDIA GPUs in one nvidia-smi call
    nv_data = {}
    if any(g["vendor"] == "NVIDIA" for g in gpus_meta):
        try:
            res = subprocess.run(
                [
                    "nvidia-smi",
                    "--query-gpu=index,temperature.gpu,utilization.gpu,memory.used,memory.total",
                    "--format=csv,noheader,nounits",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=0.5,
            )
            if res.returncode == 0:
                for row in res.stdout.strip().splitlines():
                    parts = [p.strip() for p in row.split(",")]
                    if len(parts) >= 5:
                        idx = int(parts[0])
                        used_gb = round(int(parts[3]) / 1024.0, 1)
                        tot_gb = round(int(parts[4]) / 1024.0, 1)
                        nv_data[idx] = {
                            "temp": f"{parts[1]}°C",
                            "usage": int(parts[2]),
                            "vram": f"{used_gb} / {tot_gb} GB",
                        }
        except Exception:
            pass

    result = []
    for g in gpus_meta:
        temp = "50°C"
        usage = 0
        vram = "GPU Active"
        vendor = g["vendor"]

        if vendor == "NVIDIA" and g.get("nv_idx") in nv_data:
            d = nv_data[g["nv_idx"]]
            temp, usage, vram = d["temp"], d["usage"], d["vram"]
        elif vendor == "AMD":
            usage, temp, vram = _get_amd_drm_metrics(g["pci"])
        elif vendor == "Intel":
            vram = "Shared"
            usage = _get_intel_igpu_usage_engine(g["pci"])
            if usage is None:
                usage = _get_intel_igpu_usage(g["pci"])

        result.append(
            {
                "has_gpu": True,
                "name": g["name"],
                "temp": temp,
                "usage": usage,
                "vram": vram,
            }
        )
    return result


def get_storage_info():
    """Return a list of storage entries: root first, then Nautilus-mounted drives."""
    SKIP_FS = {
        "tmpfs",
        "sysfs",
        "proc",
        "devtmpfs",
        "cgroup",
        "cgroup2",
        "pstore",
        "efivarfs",
        "bpf",
        "tracefs",
        "autofs",
        "hugetlbfs",
        "mqueue",
        "debugfs",
        "securityfs",
        "configfs",
        "fusectl",
        "binfmt_misc",
        "overlay",
        "squashfs",
        "devpts",
        "fuse.gvfsd-fuse",
        "fuse.portal",
        "nsfs",
        "ramfs",
    }
    SKIP_MOUNTS = {"/boot", "/boot/efi", "/dev", "/dev/pts"}
    results = []

    try:
        with open("/proc/mounts", "r") as f:
            mounts = f.readlines()
    except Exception:
        mounts = []

    seen_devices = set()
    entries = []

    for line in mounts:
        parts = line.split()
        if len(parts) < 3:
            continue
        src, mount, fstype = parts[0], parts[1], parts[2]
        if fstype in SKIP_FS:
            continue
        if mount in SKIP_MOUNTS:
            continue
        if not src.startswith("/dev/"):
            continue
        # Skip /boot* partitions
        if mount.startswith("/boot"):
            continue
        # Deduplicate by device
        if src in seen_devices:
            continue
        seen_devices.add(src)
        entries.append((src, mount))

    # Sort: root first, then alphabetically by mount
    entries.sort(key=lambda x: (0 if x[1] == "/" else 1, x[1]))

    for src, mount in entries:
        try:
            st = os.statvfs(mount)
            total_bytes = st.f_blocks * st.f_frsize
            free_bytes = st.f_bfree * st.f_frsize
            used_bytes = total_bytes - free_bytes
            if total_bytes == 0:
                continue
            total_gib = round(total_bytes / (1024.0**3), 1)
            used_gib = round(used_bytes / (1024.0**3), 1)
            usage_pct = int(round(100.0 * used_bytes / total_bytes))
            # Human-friendly name: use the last path component or device basename
            if mount == "/":
                label = os.path.basename(src) or "root"
            else:
                label = os.path.basename(mount) or os.path.basename(src)
            results.append(
                {
                    "device": label,
                    "mount": mount,
                    "total_gib": total_gib,
                    "used_gib": used_gib,
                    "usage": usage_pct,
                }
            )
        except Exception:
            continue

    if not results:
        results = [
            {"device": "/", "mount": "/", "total_gib": 0.0, "used_gib": 0.0, "usage": 0}
        ]

    return results


_music_players_cache = None


def check_music_players():
    global _music_players_cache
    if _music_players_cache is not None:
        return _music_players_cache
    try:
        _music_players_cache = {
            "has_youtube_music": shutil.which("youtube-music") is not None,
            "has_spotify": shutil.which("spotify") is not None,
            "has_kew": shutil.which("kew") is not None,
        }
        return _music_players_cache
    except Exception:
        return {"has_youtube_music": False, "has_spotify": False, "has_kew": False}


def collect_and_output(
    prev_sys_ticks, prev_proc_ticks, sort_by, limit=25, no_processes=False
):
    curr_sys_ticks = get_system_cpu_ticks()
    curr_proc_ticks = {} if no_processes else get_all_processes_ticks()

    sys_cpu_pct = 0.0
    sys_total_diff = curr_sys_ticks["total"] - prev_sys_ticks["total"]
    sys_idle_diff = curr_sys_ticks["idle"] - prev_sys_ticks["idle"]
    if sys_total_diff > 0:
        sys_cpu_pct = round(
            100.0 * (sys_total_diff - sys_idle_diff) / sys_total_diff, 1
        )
        sys_cpu_pct = max(0.0, min(100.0, sys_cpu_pct))

    mem_info = get_system_mem()
    total_mem_bytes = mem_info.get("mem_total_gb", 0) * 1024 * 1024 * 1024
    if total_mem_bytes == 0:
        try:
            with open("/proc/meminfo") as f:
                for line in f:
                    if line.startswith("MemTotal:"):
                        total_mem_bytes = int(line.split()[1]) * 1024
                        break
        except Exception:
            pass

    processes = []
    if not no_processes:
        for pid, curr_p in curr_proc_ticks.items():
            if curr_p["comm"] in ["top", "ps", "get_processes.py", "python3"]:
                continue

            proc_cpu = 0.0
            if pid in prev_proc_ticks:
                prev_p = prev_proc_ticks[pid]
                proc_ticks_diff = (curr_p["utime"] + curr_p["stime"]) - (
                    prev_p["utime"] + prev_p["stime"]
                )
                if sys_total_diff > 0:
                    proc_cpu = round(100.0 * proc_ticks_diff / sys_total_diff, 1)
                    proc_cpu = max(0.0, proc_cpu)

            mem_pct = (
                round(100.0 * curr_p["rss_bytes"] / total_mem_bytes, 1)
                if total_mem_bytes > 0
                else 0.0
            )
            mem_formatted = format_memory(curr_p["rss_bytes"])

            processes.append(
                {
                    "pid": pid,
                    "name": curr_p["comm"],
                    "cpu": proc_cpu,
                    "mem": mem_pct,
                    "mem_str": mem_formatted,
                    "user": get_user_by_uid(curr_p["uid"]),
                    "cmdline": curr_p["cmdline"],
                }
            )

        if sort_by == "cpu":
            processes.sort(key=lambda x: x["cpu"], reverse=True)
        elif sort_by == "mem":
            processes.sort(key=lambda x: x["mem"], reverse=True)
        else:
            processes.sort(key=lambda x: x["cpu"], reverse=True)

    output_data = {
        "system": {
            "cpu_usage": sys_cpu_pct,
            "mem_usage": mem_info["mem_usage"],
            "mem_total_gb": mem_info["mem_total_gb"],
            "mem_used_gb": mem_info["mem_used_gb"],
            "tasks_total": get_system_tasks(),
            "cpu_temp": get_cpu_temp(),
            "uptime": get_uptime(),
            "cpu_freq": get_cpu_frequency(),
            "load_avg": get_load_average(),
            "cpu_cores": get_cores_text(),
        },
        "gpus": get_gpus_info(),
        "storage": get_storage_info(),
        "players": check_music_players(),
        "processes": processes[:limit],
    }

    print(json.dumps(output_data), flush=True)
    return curr_sys_ticks, curr_proc_ticks


if __name__ == "__main__":
    sort_by = "cpu"
    interval = 4.0
    is_daemon = False
    no_processes = False

    for arg in sys.argv[1:]:
        if arg == "--daemon":
            is_daemon = True
        elif arg == "--no-processes":
            no_processes = True
        elif arg in ["cpu", "mem"]:
            sort_by = arg
        else:
            try:
                interval = float(arg) / 1000.0
            except ValueError:
                pass

    if is_daemon:
        prev_sys = get_system_cpu_ticks()
        prev_proc = {} if no_processes else get_all_processes_ticks()
        time.sleep(0.2)
        prev_sys, prev_proc = collect_and_output(
            prev_sys, prev_proc, sort_by, no_processes=no_processes
        )
        while True:
            time.sleep(interval)
            prev_sys, prev_proc = collect_and_output(
                prev_sys, prev_proc, sort_by, no_processes=no_processes
            )
    else:
        prev_sys = get_system_cpu_ticks()
        prev_proc = {} if no_processes else get_all_processes_ticks()
        time.sleep(0.5)
        collect_and_output(prev_sys, prev_proc, sort_by, no_processes=no_processes)
