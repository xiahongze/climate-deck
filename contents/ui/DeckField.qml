import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

// A text field drawn in the deck's own colours, so it sits on the
// translucent card in any theme rather than as a solid system box.
Controls.TextField {
    id: field
    property color ink: Kirigami.Theme.textColor
    property color accent: Kirigami.Theme.highlightColor

    color: ink
    placeholderTextColor: Qt.alpha(ink, 0.4)
    selectionColor: Qt.alpha(accent, 0.5)
    selectedTextColor: ink
    font.pixelSize: Kirigami.Units.gridUnit * 0.66
    leftPadding: Kirigami.Units.smallSpacing * 2
    rightPadding: Kirigami.Units.smallSpacing * 2
    topPadding: Kirigami.Units.smallSpacing * 1.2
    bottomPadding: Kirigami.Units.smallSpacing * 1.2
    background: Rectangle {
        radius: Kirigami.Units.cornerRadius
        color: field.activeFocus ? Qt.alpha(field.ink, 0.09) : field.hovered ? Qt.alpha(field.ink, 0.07) : Qt.alpha(field.ink, 0.045)
        border.color: field.activeFocus ? Qt.alpha(field.accent, 0.8) : Qt.alpha(field.ink, 0.1)
        border.width: field.activeFocus ? 1.5 : 1
    }
}
