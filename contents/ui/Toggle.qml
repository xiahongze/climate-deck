import QtQuick
import org.kde.kirigami as Kirigami

// A small on/off switch matching the zone cards.
Rectangle {
    id: toggle
    property bool on: false
    property color tone: "steelblue"
    property color ink: "white"
    property bool interactive: true
    signal toggled(bool on)

    implicitWidth: Kirigami.Units.gridUnit * 1.6
    implicitHeight: Kirigami.Units.gridUnit * 0.9
    radius: height / 2
    color: on ? tone : Qt.alpha(ink, 0.18)
    opacity: interactive ? 1 : 0.5
    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
    Rectangle {
        width: parent.height - 4
        height: width
        radius: width / 2
        y: 2
        x: toggle.on ? parent.width - width - 2 : 2
        color: "white"
        Behavior on x { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
    }
    HoverHandler { cursorShape: toggle.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler { enabled: toggle.interactive; onTapped: toggle.toggled(!toggle.on) }
}
