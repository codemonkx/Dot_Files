import json
import os
import shutil
import sys

from color_utils import sanitize_color

try:
    from theme_extractors.image_utils import prepare_image
except ImportError:
    theme_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if theme_root not in sys.path:
        sys.path.insert(0, theme_root)
    from theme_extractors.image_utils import prepare_image


def _argb(rgb, alpha):
    """Build a QML #AARRGGBB color from an #RRGGBB color and an opacity (0-1).

    SDDM's QML theme composites its surfaces over the blurred wallpaper, so the
    derived overlays must keep their alpha instead of being flattened onto the
    background (which is what apply_theme.py does for text-only appliers).
    """
    s = str(rgb).lstrip("#")
    if len(s) == 8:  # Qt ARGB format: keep only the RGB part
        s = s[-6:]
    elif len(s) == 3:
        s = "".join(ch * 2 for ch in s)
    s = s[-6:]
    a = max(0, min(255, int(round(alpha * 255))))
    return f"#{a:02x}{s}"


def apply(home, colors):
    sddm_dir = "/var/tmp/sddm-theme"
    try:
        os.makedirs(sddm_dir, mode=0o777, exist_ok=True)
        try:
            os.chmod(sddm_dir, 0o777)
        except OSError:
            pass

        # Read font family from quickshell preferences if available
        font_family = "Geist"
        prefs_file = os.path.join(home, ".cache", "quickshell", "settings_prefs.json")
        if os.path.exists(prefs_file):
            try:
                with open(prefs_file, "r") as pf:
                    prefs_data = json.load(pf)
                    if prefs_data.get("fontFamily"):
                        font_family = prefs_data["fontFamily"]
            except Exception:
                pass

        is_dark = bool(colors.get("is_dark", True))
        fg = sanitize_color(colors.get("fg", "#f1f0f4"))
        accent = sanitize_color(colors.get("accent", "#8265cc"))
        accent_complementary = sanitize_color(
            colors.get("accentComplementary", "#cc64c8")
        )
        overlay_base = sanitize_color(colors.get("overlayBase", "#a38fd8"))

        # Prepare color map. Opaque colors are sanitized; surfaces that float
        # over the wallpaper keep their alpha so they stay translucent.
        theme_data = {
            "font": font_family,
            "name": "Dynamic Tokyo Night",
            "bg": sanitize_color(colors.get("bg", "#09080b")),
            "opaqueBg": sanitize_color(colors.get("opaqueBg", "#09080b")),
            "fg": fg,
            "muted": _argb(fg, 0.40),
            "border": _argb(fg, 0.10 if is_dark else 0.20),
            "accent": accent,
            "accentComplementary": accent_complementary,
            "overlayBase": overlay_base,
            "bgSecondary": _argb(overlay_base, 0.06 if is_dark else 0.10),
            "bgTertiary": _argb(overlay_base, 0.02 if is_dark else 0.04),
            "bgAccent": _argb(accent, 0.15 if is_dark else 0.30),
            "bgAccentComplementary": _argb(
                accent_complementary, 0.15 if is_dark else 0.30
            ),
            "shadow": _argb("#000000", 0.75 if is_dark else 0.45),
            "isDark": is_dark,
        }

        colors_file = os.path.join(sddm_dir, "colorscheme.json")
        with open(colors_file, "w") as f:
            json.dump(theme_data, f, indent=2)
        try:
            os.chmod(colors_file, 0o666)
        except OSError:
            pass

        # Sync wallpaper
        qs_wall_file = os.path.join(home, ".cache", "quickshell", "current_wallpaper")
        if os.path.exists(qs_wall_file):
            with open(qs_wall_file, "r") as f:
                wall_name = f.read().strip()

            if wall_name:
                if wall_name.startswith("/"):
                    src_wall = wall_name
                else:
                    src_wall = os.path.join(home, "Pictures", "Wallpapers", wall_name)

                if os.path.exists(src_wall):
                    dest_wall_png = os.path.join(sddm_dir, "wallpaper.png")
                    # Safely obtain static image via prepare_image (cached single-frame extraction, no memory spikes)
                    static_wall, _ = prepare_image(src_wall)
                    if os.path.exists(static_wall):
                        shutil.copyfile(static_wall, dest_wall_png)

                    if os.path.exists(dest_wall_png):
                        try:
                            os.chmod(dest_wall_png, 0o666)
                        except OSError:
                            pass

                    name_file = os.path.join(sddm_dir, "current_wallpaper")
                    with open(name_file, "w") as f:
                        f.write(wall_name)
                    try:
                        os.chmod(name_file, 0o666)
                    except OSError:
                        pass
    except Exception as e:
        print(f"Error applying SDDM theme colors: {e}")
