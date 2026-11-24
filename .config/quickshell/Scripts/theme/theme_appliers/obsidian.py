import json
import os

from color_utils import blend_hex, force_hsl, rgb_to_hsl, sanitize_color

SNIPPET_NAME = "minflair"
SNIPPET_FILE = f"{SNIPPET_NAME}.css"

CONFIG_CANDIDATES = (
    os.path.join(".config", "obsidian"),
    os.path.join(".var", "app", "md.obsidian.Obsidian", ".config", "obsidian"),
    os.path.join("snap", "obsidian", "current", ".config", "obsidian"),
)

# Hues used for the semantic colors, harmonized with the active accent
HUES = {
    "red": 0,
    "orange": 28,
    "yellow": 48,
    "green": 142,
    "cyan": 188,
    "blue": 214,
    "purple": 270,
    "pink": 330,
}


def hex_to_rgb(value):
    s = sanitize_color(value).lstrip("#")
    if len(s) == 3:
        s = "".join(c * 2 for c in s)
    if len(s) != 6:
        return (0, 0, 0)
    try:
        return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))
    except ValueError:
        return (0, 0, 0)


def rgb_triple(value):
    r, g, b = hex_to_rgb(value)
    return f"{r}, {g}, {b}"


def tone(base_hex, hue, light, min_sat=0.45):
    r, g, b = hex_to_rgb(base_hex)
    _, s, _ = rgb_to_hsl(r, g, b)
    return force_hsl(hue, s, light, min_sat, light)


def find_vaults(home):
    vaults = []
    for candidate in CONFIG_CANDIDATES:
        config_json = os.path.join(home, candidate, "obsidian.json")
        if not os.path.exists(config_json):
            continue
        try:
            with open(config_json, "r") as f:
                data = json.load(f)
        except Exception:
            continue
        for vault in (data.get("vaults") or {}).values():
            path = vault.get("path") if isinstance(vault, dict) else None
            if not path:
                continue
            if not os.path.isdir(os.path.join(path, ".obsidian")):
                continue
            real = os.path.realpath(path)
            if real not in vaults:
                vaults.append(real)
    return vaults


def enable_snippet(vault):
    appearance = os.path.join(vault, ".obsidian", "appearance.json")
    data = {}
    if os.path.exists(appearance):
        try:
            with open(appearance, "r") as f:
                data = json.load(f)
        except Exception:
            data = {}
    if not isinstance(data, dict):
        data = {}

    enabled = data.get("enabledCssSnippets")
    if not isinstance(enabled, list):
        enabled = []
    if SNIPPET_NAME in enabled:
        return

    enabled.append(SNIPPET_NAME)
    data["enabledCssSnippets"] = enabled
    try:
        with open(appearance, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
    except Exception:
        pass


def build_css(colors):
    bg = sanitize_color(colors["bg"])
    opaque_bg = sanitize_color(colors.get("opaqueBg", bg))
    fg = sanitize_color(colors["fg"])
    bg_secondary = sanitize_color(colors["bgSecondary"])
    bg_tertiary = sanitize_color(colors.get("bgTertiary", bg_secondary))
    bg_accent = sanitize_color(colors.get("bgAccent", colors["accent"]))
    bg_accent_comp = sanitize_color(
        colors.get("bgAccentComplementary", colors["accentComplementary"])
    )
    accent = sanitize_color(colors["accent"])
    accent_comp = sanitize_color(colors["accentComplementary"])
    muted = sanitize_color(colors["muted"])
    border = sanitize_color(colors.get("border", muted))
    shadow = sanitize_color(colors.get("shadow", bg))
    is_dark = bool(colors.get("is_dark", True))

    # Semantic colors follow the accent's saturation, so they stay in-palette
    light = 0.64 if is_dark else 0.44
    semantic = {name: tone(accent, hue, light) for name, hue in HUES.items()}

    # Neutral ramp from the background to the foreground
    ramp = {
        "00": bg,
        "05": blend_hex(fg, bg, 0.03),
        "10": bg_secondary,
        "20": blend_hex(fg, bg, 0.10),
        "25": blend_hex(fg, bg, 0.13),
        "30": blend_hex(fg, bg, 0.16),
        "40": blend_hex(fg, bg, 0.24),
        "50": blend_hex(fg, bg, 0.34),
        "60": blend_hex(fg, bg, 0.44),
        "70": blend_hex(fg, bg, 0.60),
        "80": blend_hex(fg, bg, 0.72),
        "90": blend_hex(fg, bg, 0.85),
        "100": fg,
    }

    ar, ag, ab = hex_to_rgb(accent)
    accent_h, accent_s, accent_l = rgb_to_hsl(ar, ag, ab)
    accent_hover = blend_hex(fg if is_dark else bg, accent, 0.18)
    accent_light = blend_hex(fg, accent, 0.20)
    accent_dark = blend_hex(bg, accent, 0.20)

    # Headings walk through the accent family
    headings = [
        accent,
        accent_comp,
        blend_hex(accent, accent_comp, 0.35),
        blend_hex(accent, accent_comp, 0.65),
        blend_hex(accent, bg, 0.80),
        blend_hex(accent_comp, bg, 0.80),
    ]

    vars = {}

    # --- Base neutral scale ---------------------------------------------
    for key, value in ramp.items():
        vars[f"--color-base-{key}"] = value
    vars["--mono-rgb-0"] = rgb_triple(bg)
    vars["--mono-rgb-100"] = rgb_triple(fg)

    # --- Semantic colors -------------------------------------------------
    for name, value in semantic.items():
        vars[f"--color-{name}"] = value
        vars[f"--color-{name}-rgb"] = rgb_triple(value)

    # --- Backgrounds -----------------------------------------------------
    vars["--background-primary"] = opaque_bg
    vars["--background-primary-alt"] = bg_secondary
    vars["--background-secondary"] = bg_secondary
    vars["--background-secondary-alt"] = bg_tertiary
    vars["--background-modifier-border"] = border
    vars["--background-modifier-border-hover"] = blend_hex(
        fg, bg, 0.22 if is_dark else 0.32
    )
    vars["--background-modifier-border-focus"] = accent
    vars["--background-modifier-hover"] = bg_secondary
    vars["--background-modifier-active-hover"] = bg_accent
    vars["--background-modifier-form-field"] = bg_tertiary
    vars["--background-modifier-box-shadow"] = shadow
    vars["--background-modifier-cover"] = shadow
    vars["--background-modifier-message"] = bg_secondary
    vars["--background-modifier-success"] = semantic["green"]
    vars["--background-modifier-success-rgb"] = rgb_triple(semantic["green"])
    vars["--background-modifier-error"] = semantic["red"]
    vars["--background-modifier-error-hover"] = blend_hex(fg, semantic["red"], 0.15)
    vars["--background-modifier-error-rgb"] = rgb_triple(semantic["red"])

    # --- Text ------------------------------------------------------------
    vars["--text-normal"] = fg
    vars["--text-muted"] = muted
    vars["--text-faint"] = blend_hex(fg, bg, 0.28)
    vars["--text-on-accent"] = opaque_bg
    vars["--text-on-accent-inverted"] = fg
    vars["--text-success"] = semantic["green"]
    vars["--text-warning"] = semantic["orange"]
    vars["--text-error"] = semantic["red"]
    vars["--text-accent"] = accent
    vars["--text-accent-hover"] = accent_comp
    vars["--text-selection"] = bg_accent
    vars["--text-highlight-bg"] = bg_accent
    vars["--text-highlight-bg-active"] = bg_accent_comp
    vars["--bold-color"] = accent
    vars["--italic-color"] = accent_comp

    # --- Accent & interactive -------------------------------------------
    vars["--accent-h"] = str(round(accent_h))
    vars["--accent-s"] = f"{round(accent_s * 100)}%"
    vars["--accent-l"] = f"{round(accent_l * 100)}%"
    vars["--color-accent-hsl"] = f"var(--accent-h), var(--accent-s), var(--accent-l)"
    vars["--color-accent"] = accent
    vars["--color-accent-1"] = accent_light
    vars["--color-accent-2"] = accent_dark
    vars["--color-accent-rgb"] = rgb_triple(accent)
    vars["--interactive-accent"] = accent
    vars["--interactive-accent-hover"] = accent_hover
    vars["--interactive-accent-rgb"] = rgb_triple(accent)
    vars["--interactive-normal"] = bg_secondary
    vars["--interactive-hover"] = bg_accent
    vars["--checkbox-color"] = accent
    vars["--checkbox-color-hover"] = accent_hover
    vars["--checkbox-border-color"] = border
    vars["--checkbox-border-color-hover"] = accent
    vars["--checkbox-marker-color"] = opaque_bg
    vars["--slider-thumb-bg"] = accent
    vars["--toggle-thumb-color"] = opaque_bg
    vars["--toggle-thumb-enabled-color"] = opaque_bg
    vars["--toggle-background-color-hover"] = bg_accent

    # --- Links -----------------------------------------------------------
    vars["--link-color"] = accent
    vars["--link-color-hover"] = accent_comp
    vars["--link-external-color"] = accent_comp
    vars["--link-external-color-hover"] = accent
    vars["--link-unresolved-color"] = muted
    vars["--link-unresolved-decoration-color"] = border

    # --- Markdown --------------------------------------------------------
    vars["--inline-title-color"] = accent
    for index, color in enumerate(headings, start=1):
        vars[f"--h{index}-color"] = color
    vars["--heading-formatting"] = muted
    vars["--blockquote-border-color"] = accent
    vars["--blockquote-color"] = muted
    vars["--blockquote-background-color"] = bg_tertiary
    vars["--hr-color"] = border
    vars["--tag-background"] = bg_accent
    vars["--tag-background-hover"] = bg_accent_comp
    vars["--tag-color"] = accent
    vars["--tag-color-hover"] = accent_comp
    vars["--tag-border-color"] = border

    # --- Code ------------------------------------------------------------
    vars["--code-background"] = bg_tertiary
    vars["--code-normal"] = fg
    vars["--code-comment"] = muted
    vars["--code-function"] = accent
    vars["--code-important"] = accent_comp
    vars["--code-keyword"] = accent_comp
    vars["--code-operator"] = muted
    vars["--code-property"] = semantic["orange"]
    vars["--code-punctuation"] = muted
    vars["--code-string"] = semantic["green"]
    vars["--code-tag"] = semantic["red"]
    vars["--code-value"] = semantic["yellow"]

    # --- Window chrome ---------------------------------------------------
    vars["--titlebar-background"] = opaque_bg
    vars["--titlebar-background-focused"] = bg_secondary
    vars["--titlebar-text-color"] = muted
    vars["--titlebar-text-color-focused"] = fg
    vars["--ribbon-background"] = opaque_bg
    vars["--ribbon-background-collapsed"] = bg_secondary
    vars["--status-bar-background"] = opaque_bg
    vars["--status-bar-border-color"] = border
    vars["--status-bar-text-color"] = muted
    vars["--tab-background-active"] = opaque_bg
    vars["--tab-text-color"] = muted
    vars["--tab-text-color-active"] = fg
    vars["--tab-text-color-focused"] = muted
    vars["--tab-text-color-focused-active"] = fg
    vars["--tab-text-color-focused-active-current"] = accent
    vars["--tab-outline-color"] = border
    vars["--divider-color"] = border
    vars["--scrollbar-bg"] = bg
    vars["--scrollbar-thumb-bg"] = border
    vars["--scrollbar-active-thumb-bg"] = accent
    vars["--nav-item-color"] = muted
    vars["--nav-item-color-hover"] = fg
    vars["--nav-item-color-active"] = accent
    vars["--nav-item-color-selected"] = fg
    vars["--nav-item-background-hover"] = bg_secondary
    vars["--nav-item-background-active"] = bg_accent
    vars["--nav-item-background-selected"] = bg_accent
    vars["--nav-collapse-icon-color"] = muted
    vars["--nav-collapse-icon-color-collapsed"] = muted
    vars["--nav-indentation-guide-color"] = border
    vars["--nav-heading-color"] = fg
    vars["--search-result-background"] = bg_accent

    # --- Graph -----------------------------------------------------------
    vars["--graph-node"] = accent
    vars["--graph-node-focused"] = accent_comp
    vars["--graph-node-tag"] = semantic["green"]
    vars["--graph-node-attachment"] = semantic["orange"]
    vars["--graph-node-unresolved"] = muted
    vars["--graph-line"] = border
    vars["--graph-text"] = fg

    # --- Canvas ----------------------------------------------------------
    vars["--canvas-background"] = bg
    vars["--canvas-dot-pattern"] = border

    lines = [
        "/* Generated by Minflair Theme Service - do not edit */",
        "body.theme-dark,",
        "body.theme-light {",
    ]
    for name, value in vars.items():
        lines.append(f"  {name}: {value};")
    lines.append("}")
    lines.append("")
    lines.append("body.theme-dark,")
    lines.append("body.theme-light {")
    lines.append("  background-color: var(--background-primary);")
    lines.append("  color: var(--text-normal);")
    lines.append("}")
    lines.append("")
    lines.append(".workspace,")
    lines.append(".workspace-split.mod-root,")
    lines.append(".workspace-leaf-content,")
    lines.append(".markdown-source-view.mod-cm6 .cm-scroller,")
    lines.append(".markdown-reading-view {")
    lines.append("  background-color: var(--background-primary);")
    lines.append("}")
    lines.append("")
    lines.append("::selection {")
    lines.append("  background-color: var(--text-selection);")
    lines.append("  color: var(--text-normal);")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def apply(home, colors):
    vaults = find_vaults(home)
    if not vaults:
        return

    css = build_css(colors)
    for vault in vaults:
        snippets_dir = os.path.join(vault, ".obsidian", "snippets")
        try:
            os.makedirs(snippets_dir, exist_ok=True)
            with open(os.path.join(snippets_dir, SNIPPET_FILE), "w") as f:
                f.write(css)
        except Exception:
            continue
        enable_snippet(vault)
