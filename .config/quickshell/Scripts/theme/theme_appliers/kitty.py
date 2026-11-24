import os
import subprocess

from color_utils import sanitize_color, rgb_to_hsl, force_hsl

HUE_SPREAD = 0


def tone(accent_hex, hue_shift, light, min_sat=0.35):
    r, g, b = (int(accent_hex[i:i + 2], 16) for i in (1, 3, 5))
    h, s, _ = rgb_to_hsl(r, g, b)
    return force_hsl((h + hue_shift) % 360, s, light, min_sat, light)


def apply(home, colors):
    bg = sanitize_color(colors["bg"])
    fg = sanitize_color(colors["fg"])
    accent = sanitize_color(colors["accent"])
    comp = sanitize_color(colors["accentComplementary"])
    muted = sanitize_color(colors["muted"])
    border = sanitize_color(colors["border"])
    bgSecondary = sanitize_color(colors["bgSecondary"])

    sp = HUE_SPREAD
    ansi = {
        0: bgSecondary,            
        1: tone(accent, 0, 0.62),
        2: tone(accent, sp, 0.58),
        3: tone(accent, sp * 2, 0.68),
        4: tone(accent, -sp, 0.60),
        5: tone(accent, -sp * 2, 0.64),
        6: tone(accent, sp // 2, 0.70),
        7: fg,
        8: muted,
        9: tone(accent, 0, 0.74),
        10: tone(accent, sp, 0.70),
        11: tone(accent, sp * 2, 0.78),
        12: tone(accent, -sp, 0.72),
        13: tone(accent, -sp * 2, 0.76),
        14: tone(accent, sp // 2, 0.80),
        15: fg,
    }
    ansi_lines = "\n".join(f"color{i:<2} {c}" for i, c in ansi.items())

    kitty_theme = f"""foreground              {fg}
background              {bg}
selection_foreground    {bg}
selection_background    {accent}
cursor                  {fg}
cursor_text_color       {bg}
url_color               {accent}
active_border_color     {accent}
inactive_border_color   {border}
bell_border_color       {accent}
active_tab_foreground   {bg}
active_tab_background   {accent}
inactive_tab_foreground {muted}
inactive_tab_background {bgSecondary}
tab_bar_background      {bg}
{ansi_lines}
"""
    kitty_dir = os.path.join(home, ".config", "kitty")
    os.makedirs(kitty_dir, exist_ok=True)
    with open(os.path.join(kitty_dir, "theme.conf"), "w") as f2:
        f2.write(kitty_theme)
    subprocess.run("kill -SIGUSR1 $(pidof kitty) 2>/dev/null", shell=True)