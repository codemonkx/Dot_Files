import QtQuick

// Launcher quick commands: applications shipped with Minflair that are opened
// through AppState instead of their .desktop entry. They are rendered as plain
// text rows (no icon) and matched by name and keywords.
QtObject {
    id: root

    readonly property var items: [{
        "name": "Settings",
        "subtitle": "Minflair",
        "widgetId": "minflair_settings",
        "keywords": ["config", "configuration", "settings", "ajustes", "configuracion", "preferences"]
    }, {
        "name": "Keybinds",
        "subtitle": "Minflair",
        "widgetId": "minflair_keybinds",
        "keywords": ["keybinds", "keybindings", "shortcuts", "atajos", "teclas"]
    }, {
        "name": "Package Manager",
        "subtitle": "Minflair",
        "widgetId": "packagemanager",
        "keywords": ["package", "packages", "paquetes", "pacman", "yay", "install", "instalar"]
    }, {
        "name": "Pomodoro",
        "subtitle": "Minflair",
        "widgetId": "pomodoro",
        "keywords": ["pomodoro", "timer", "temporizador", "focus", "enfoque"]
    }]
}
