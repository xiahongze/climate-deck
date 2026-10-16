pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A row of equal-width pills; `options` is [{value, label}].
Rectangle {
    id: seg
    property var options: []
    property string current: ""
    property color ink: "white"
    property color accent: "steelblue"
    property bool interactive: true
    signal picked(string value)

    implicitHeight: Kirigami.Units.gridUnit * 1.7
    radius: height / 2
    color: Qt.alpha(ink, 0.06)
    border.color: Qt.alpha(ink, 0.08)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 2
        Repeater {
            model: seg.options
            delegate: Rectangle {
                id: pill
                required property var modelData
                readonly property bool selected: modelData.value === seg.current
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: height / 2
                color: selected ? Qt.alpha(seg.accent, 0.9) : hover.hovered && seg.interactive ? Qt.alpha(seg.ink, 0.08) : "transparent"
                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                Controls.Label {
                    anchors.centerIn: parent
                    text: pill.modelData.label
                    color: pill.selected ? "white" : Qt.alpha(seg.ink, 0.75)
                    font.pixelSize: Kirigami.Units.gridUnit * 0.62
                    font.weight: pill.selected ? Font.DemiBold : Font.Normal
                    font.letterSpacing: 0.4
                }
                HoverHandler { id: hover; enabled: seg.interactive; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    enabled: seg.interactive
                    onTapped: if (!pill.selected) seg.picked(pill.modelData.value)
                }
            }
        }
    }
}
