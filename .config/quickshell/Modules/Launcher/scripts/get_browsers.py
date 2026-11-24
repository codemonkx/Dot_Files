#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import configparser
import json
import os
from pathlib import Path


def get_browsers():
    browsers = []
    seen_names = set()

    # Same XDG locations used by get_apps.py, flatpak exports included.
    xdg_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
    paths = [Path(p) / "applications" for p in xdg_dirs]
    paths.append(Path.home() / ".local" / "share" / "applications")
    paths.append(
        Path.home()
        / ".local"
        / "share"
        / "flatpak"
        / "exports"
        / "share"
        / "applications"
    )
    paths.append(Path("/var/lib/flatpak/exports/share/applications"))

    for d in paths:
        if not d.is_dir():
            continue
        for f in sorted(d.glob("*.desktop")):
            try:
                config = configparser.ConfigParser(interpolation=None)
                config.read(f, encoding="utf-8")
                if "Desktop Entry" not in config:
                    continue

                entry = config["Desktop Entry"]
                if (
                    entry.get("NoDisplay", "false").lower() == "true"
                    or entry.get("Hidden", "false").lower() == "true"
                ):
                    continue

                categories = entry.get("Categories", "")
                mime_types = entry.get("MimeType", "")
                is_browser = (
                    "WebBrowser" in categories
                    or "x-scheme-handler/https" in mime_types
                    or "x-scheme-handler/http" in mime_types
                )
                if not is_browser:
                    continue

                name = entry.get("Name", "").strip()
                raw_exec = entry.get("Exec", "").strip()
                if not name or not raw_exec or name in seen_names:
                    continue

                browsers.append(
                    {
                        "id": f.stem,
                        "name": name,
                        "exec": raw_exec,
                        "icon": entry.get("Icon", "").strip(),
                    }
                )
                seen_names.add(name)
            except Exception:
                continue

    return sorted(browsers, key=lambda b: b["name"].lower())


if __name__ == "__main__":
    print(json.dumps(get_browsers()))
