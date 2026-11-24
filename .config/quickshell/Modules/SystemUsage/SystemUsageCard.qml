import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

Card {
    id: root

    property string icon: ""
    property string title: ""
    property int usage: 0
    property color accentColor: Theme.accent
    // Usage (%) from which the ring starts blending towards the complementary accent
    property real hotUsageThreshold: 60
    // Slot to replace the title text with custom content (e.g. a selector)
    property alias titleSlot: titleContainer.data
    default property alias content: detailsContainer.data

    function mixColors(from, to, t) {
        let f = Math.max(0, Math.min(1, t));
        return Qt.rgba(from.r + (to.r - from.r) * f, from.g + (to.g - from.g) * f, from.b + (to.b - from.b) * f, from.a + (to.a - from.a) * f);
    }

    backgroundColor: Theme.bgTertiary
    cardRadius: Constants.sizeLg
    contentPadding: Constants.sizeSm
    useBorder: true
    implicitWidth: Math.max(220, mainRow.implicitWidth)
    clip: true

    RowLayout {
        id: mainRow

        anchors.fill: parent
        spacing: Constants.sizeMd

        // Left side: icon, title and metrics
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Constants.sizeSm

            // Icon + title row
            RowLayout {
                spacing: Constants.sizeXs
                Layout.fillWidth: true

                Rectangle {
                    width: Constants.size2Xl
                    height: width
                    radius: Constants.sizeXs
                    color: Theme.bgAccent
                    Layout.alignment: Qt.AlignVCenter

                    SvgIcon {
                        anchors.centerIn: parent
                        icon: root.icon
                        iconColor: root.accentColor
                        iconSize: Constants.sizeMd
                        flat: true
                    }

                }

                // Either custom titleSlot content or default text
                Item {
                    id: titleContainer

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: childrenRect.height
                    implicitWidth: childrenRect.width

                    // Default title text — visible only when titleSlot is empty
                    ThemedText {
                        width: parent.width
                        text: root.title
                        customSize: Constants.sizeSm
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        color: Theme.fg
                        visible: titleContainer.children.length <= 1
                    }

                }

            }

            // Metrics / extra content
            ColumnLayout {
                id: detailsContainer

                Layout.fillWidth: true
                spacing: Constants.sizeXs
            }

            // Absorbs the remaining height so the title and metrics stay
            // anchored to the top instead of being centered vertically
            Item {
                Layout.fillHeight: true
            }

        }

        // Right side: radial segmented indicator
        Item {
            id: radialIndicator

            readonly property int size: 90
            readonly property int segmentCount: 24
            readonly property int activeSegments: Math.round((Math.max(0, Math.min(100, root.usage)) / 100) * segmentCount)
            readonly property real innerRadius: size * 0.27
            readonly property real outerRadius: size * 0.5
            readonly property real segmentWidth: 3.5
            readonly property real startAngle: -225
            readonly property real sweepAngle: 270
            // Delay between consecutive segments so they light up one after another
            readonly property int segmentStagger: Math.round(Constants.animUltraFast / 8)
            // 0 = cool (accent), 1 = hot (complementary accent) as usage grows
            readonly property real heat: {
                let u = Math.max(0, Math.min(100, root.usage));
                let span = Math.max(1, 100 - root.hotUsageThreshold);
                return Math.max(0, Math.min(1, (u - root.hotUsageThreshold) / span));
            }

            width: size
            height: size
            Layout.preferredWidth: size
            Layout.preferredHeight: size
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

            Repeater {
                model: radialIndicator.segmentCount

                Rectangle {
                    id: seg

                    readonly property real fraction: index / (radialIndicator.segmentCount - 1)
                    readonly property real angleDeg: radialIndicator.startAngle + fraction * radialIndicator.sweepAngle
                    readonly property real angleRad: angleDeg * Math.PI / 180
                    readonly property real midRadius: (radialIndicator.innerRadius + radialIndicator.outerRadius) / 2
                    readonly property real segLen: radialIndicator.outerRadius - radialIndicator.innerRadius - 2
                    readonly property bool active: index < radialIndicator.activeSegments
                    // Delay is index-ordered when filling and reversed when draining
                    readonly property int staggerDelay: (active ? index : radialIndicator.segmentCount - 1 - index) * radialIndicator.segmentStagger
                    // 0 = inactive, 1 = active; driven only by the animation below
                    property real lit: 0
                    // Position along the ring, used to build the accent → complementary gradient
                    readonly property real gradientPos: radialIndicator.segmentCount > 1 ? index / (radialIndicator.segmentCount - 1) : 0
                    // Ring colour for this segment: closer to the complementary accent the
                    // further along the ring it sits and the higher the overall usage
                    property color segmentColor: root.mixColors(root.accentColor, Theme.accentComplementary, radialIndicator.heat * gradientPos)

                    function blendedColor(t) {
                        return root.mixColors(Theme.bgSecondary, segmentColor, t);
                    }

                    // When animations are disabled (Game Mode / power-saver) the
                    // durations are 0, and restarting the sequential animation no
                    // longer applies the target value, leaving segments stuck on
                    // stale states. Jump straight to the target in that case so the
                    // ring always matches the displayed percentage.
                    function syncLit() {
                        if (Constants.durationFactor === 0) {
                            lit = active ? 1 : 0;
                            return ;
                        }
                        litAnimation.restart();
                    }

                    width: radialIndicator.segmentWidth
                    height: segLen
                    radius: radialIndicator.segmentWidth / 2
                    x: radialIndicator.size / 2 + midRadius * Math.cos(angleRad) - width / 2
                    y: radialIndicator.size / 2 + midRadius * Math.sin(angleRad) - height / 2
                    rotation: angleDeg + 90
                    color: blendedColor(lit)
                    onActiveChanged: syncLit()
                    // Animate the initial state on load so the ring sweeps in
                    Component.onCompleted: syncLit()

                    SequentialAnimation {
                        id: litAnimation

                        PauseAnimation {
                            duration: seg.staggerDelay
                        }

                        NumberAnimation {
                            target: seg
                            property: "lit"
                            to: seg.active ? 1 : 0
                            duration: Constants.animFast
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on segmentColor {
                        ColorAnimation {
                            duration: Constants.animNormal
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

            // Percentage text in center
            ThemedText {
                anchors.centerIn: parent
                text: root.usage + "%"
                customSize: Constants.sizeSm - 1
                font.bold: true
                color: root.accentColor
                horizontalAlignment: Text.AlignHCenter
            }

        }

    }

}
