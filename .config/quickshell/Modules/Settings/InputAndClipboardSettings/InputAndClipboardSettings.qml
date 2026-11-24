import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: root

    readonly property var layoutDefinitions: [
        { code: "us", name: "English (US)" },
        { code: "gb", name: "English (UK)" },
        { code: "latam", name: "Spanish (LatAm)" },
        { code: "es", name: "Spanish (ES)" },
        { code: "ara", name: "Arabic" },
        { code: "fr", name: "French (AZERTY)" },
        { code: "ca", name: "French (Canada)" },
        { code: "de", name: "German (QWERTZ)" },
        { code: "it", name: "Italian" },
        { code: "pt", name: "Portuguese" },
        { code: "br", name: "Portuguese (Brazil)" },
        { code: "ru", name: "Russian" },
        { code: "ua", name: "Ukrainian" },
        { code: "tr", name: "Turkish" },
        { code: "se", name: "Swedish" },
        { code: "no", name: "Norwegian" },
        { code: "dk", name: "Danish" },
        { code: "fi", name: "Finnish" },
        { code: "cz", name: "Czech" },
        { code: "gr", name: "Greek" },
        { code: "il", name: "Hebrew" }
    ]

    readonly property var layoutNameMap: {
        let map = {};
        for (let i = 0; i < layoutDefinitions.length; i++) {
            map[layoutDefinitions[i].code] = layoutDefinitions[i].name;
        }
        return map;
    }

    AppGroup {
        title: "Keyboard Layouts"
        icon: "keyboard"
        showDividers: false
        // Each row draws its own divider, so the gap between rows matches the
        // gap around the divider instead of the default 24px rhythm.
        contentSpacing: Constants.sizeSm

        Repeater {
            model: SettingsService.enabledKbLayouts

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                SettingRowTemplate {
                    label: root.layoutNameMap[modelData] || modelData
                    description: index === 0 ? "Primary Layout" : ("Layout " + (index + 1))

                    SvgIconButton {
                        icon: "trash"
                        visible: SettingsService.enabledKbLayouts.length > 1
                        onClicked: {
                            let layouts = [...SettingsService.enabledKbLayouts];
                            let idx = layouts.indexOf(modelData);
                            if (idx !== -1) {
                                layouts.splice(idx, 1);
                                SettingsService.enabledKbLayouts = layouts;
                            }
                        }
                    }
                }

                Divider {
                    Layout.fillWidth: true
                    visible: true
                }
            }
        }

        ThemedSelect {
            label: "Add Layout"
            description: "Select a language to add"
            searchable: true
            comboWidth: 200
            model: ["None"].concat(root.layoutDefinitions.map(d => d.name))
            currentIndex: 0
            onActivated: (index) => {
                if (index === 0) return;

                let code = root.layoutDefinitions[index - 1].code;
                if (SettingsService.enabledKbLayouts.indexOf(code) === -1) {
                    let layouts = [...SettingsService.enabledKbLayouts];
                    layouts.push(code);
                    SettingsService.enabledKbLayouts = layouts;
                }

                currentIndex = Qt.binding(() => 0);
            }
        }
    }

    AppGroup {
        title: "Clipboard"
        icon: "clipboard"

        ThemedSelect {
            label: "Clipboard Max History Items"
            description: "Limit number of clipboard entries displayed"
            model: ["25 items", "50 items", "100 items", "200 items", "500 items"]
            currentIndex: {
                let items = SettingsService.clipboardMaxItems;
                if (items === 25)
                    return 0;

                if (items === 50)
                    return 1;

                if (items === 100)
                    return 2;

                if (items === 200)
                    return 3;

                if (items === 500)
                    return 4;

                return 1;
            }
            onActivated: (index) => {
                let vals = [25, 50, 100, 200, 500];
                SettingsService.clipboardMaxItems = vals[index];
            }
        }

    }

}
