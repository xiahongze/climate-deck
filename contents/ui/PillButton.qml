import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// A compact text button. `filled` uses the tone as background.
Rectangle {
    id: pill
    property string text: ""
    property color ink: "white"
    property color tone: ink
    property bool filled: false
    property bool interactive: true
    signal clicked()

    implicitWidth: label.implicitWidth + Kirigami.Units.gridUnit * 1.1
    implicitHeight: label.implicitHeight + Kirigami.Units.smallSpacing * 2.2
    radius: height / 2
    opacity: interactive ? 1 : 0.4
    color: filled ? (tap.pressed ? Qt.darker(tone, 1.15) : hover.hovered && interactive ? Qt.lighter(tone, 1.1) : tone)
         : tap.pressed && interactive ? Qt.alpha(tone, 0.25) : hover.hovered && interactive ? Qt.alpha(tone, 0.14) : Qt.alpha(ink, 0.06)
    border.color: filled ? "transparent" : Qt.alpha(tone, hover.hovered && interactive ? 0.45 : 0.18)
    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

    Controls.Label {
        id: label
        anchors.centerIn: parent
        text: pill.text
        color: pill.filled ? "white" : pill.tone
        font.pixelSize: Kirigami.Units.gridUnit * 0.58
        font.weight: Font.DemiBold
        font.letterSpacing: 0.4
    }
    HoverHandler { id: hover; enabled: pill.interactive; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; enabled: pill.interactive; onTapped: pill.clicked() }
}
