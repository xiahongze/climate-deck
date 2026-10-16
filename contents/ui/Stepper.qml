import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// "−  24°  +" with round hit targets. The owner decides what a step means.
RowLayout {
    id: stepper
    property string text: ""
    property color ink: "white"
    property color accent: "steelblue"
    property real textSize: Kirigami.Units.gridUnit
    property bool canDecrease: true
    property bool canIncrease: true
    property bool interactive: true
    signal decrease()
    signal increase()

    spacing: Kirigami.Units.smallSpacing

    component StepButton: Rectangle {
        id: button
        property string glyph
        property bool allowed: true
        signal activated()
        readonly property bool live: allowed && stepper.interactive
        implicitWidth: stepper.textSize * 1.25
        implicitHeight: implicitWidth
        radius: width / 2
        color: tap.pressed && live ? Qt.alpha(stepper.accent, 0.35)
             : hover.hovered && live ? Qt.alpha(stepper.ink, 0.12) : Qt.alpha(stepper.ink, 0.06)
        opacity: live ? 1 : 0.35
        Controls.Label {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            text: button.glyph
            color: stepper.ink
            font.pixelSize: stepper.textSize * 0.8
        }
        HoverHandler { id: hover; cursorShape: button.live ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { id: tap; enabled: button.live; onTapped: button.activated() }
    }

    StepButton { glyph: "−"; allowed: stepper.canDecrease; onActivated: stepper.decrease() }
    Controls.Label {
        Layout.minimumWidth: stepper.textSize * 2.4
        horizontalAlignment: Text.AlignHCenter
        text: stepper.text
        color: stepper.ink
        font.pixelSize: stepper.textSize
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
    }
    StepButton { glyph: "+"; allowed: stepper.canIncrease; onActivated: stepper.increase() }
}
