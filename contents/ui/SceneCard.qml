import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "myplace.js" as MyPlace

Rectangle {
    id: card
    property var scene: ({})
    property var deck
    property bool timerOn: Boolean(scene.timerEnabled)
    property bool interactive: true
    property bool confirmingDelete: false
    signal run()
    signal edit()
    signal remove()
    signal timerToggled(bool on)

    readonly property var colors: deck.colors
    readonly property var sceneAc: MyPlace.sceneAircon(scene, deck.client.acKey)
    readonly property var sceneInfo: sceneAc ? sceneAc.info || {} : {}
    readonly property bool acOn: sceneInfo.state === "on"
    readonly property color tone: acOn ? (deck.modeAccents[sceneInfo.mode] || colors.neutral) : colors.neutral
    readonly property var openZones: MyPlace.sceneOpenZones(sceneAc, deck.ac)

    function scheduleText() {
        const days = MyPlace.daysLabel(scene.activeDays, deck.dayNames, deck.dayWords);
        let t = days + "  ·  " + MyPlace.formatMinutes(scene.startTime);
        if (scene.airconStopTimeEnabled)
            t += " → " + MyPlace.formatMinutes(scene.airconStopTime);
        return t;
    }

    function airconText() {
        if (!sceneAc)
            return i18n("No aircon settings");
        if (!acOn)
            return i18n("Aircon off");
        const target = MyPlace.targetTemp(sceneAc);
        return deck.modeLabel(sceneInfo.mode) + " " + MyPlace.formatTemp(target, 0) + "  ·  " + i18n("%1 fan", deck.fanLabel(sceneInfo.fan).toLowerCase());
    }

    implicitHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 2
    radius: Kirigami.Units.cornerRadius * 1.5
    color: Qt.alpha(colors.ink, 0.045)
    border.color: card.timerOn ? Qt.alpha(tone, 0.4) : Qt.alpha(colors.ink, 0.08)

    // Mode colour along the leading edge.
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height - Kirigami.Units.largeSpacing * 2
        radius: 1.5
        color: card.tone
        opacity: card.acOn ? 0.9 : 0.4
    }

    Timer { id: confirmTimer; interval: 4000; onTriggered: card.confirmingDelete = false }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        anchors.leftMargin: Kirigami.Units.largeSpacing + 4
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Controls.Label {
                Layout.fillWidth: true
                text: card.scene.name || card.scene.id
                elide: Text.ElideRight
                color: card.colors.ink
                font.pixelSize: Kirigami.Units.gridUnit * 0.78
                font.weight: Font.DemiBold
            }
            Controls.Label {
                text: card.timerOn ? i18n("AUTO") : i18n("MANUAL")
                color: card.timerOn ? card.tone : card.colors.muted
                font.pixelSize: Kirigami.Units.gridUnit * 0.48
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }
            // Auto-run switch (the scene's timer).
            Rectangle {
                objectName: "timerSwitch"
                implicitWidth: Kirigami.Units.gridUnit * 1.6
                implicitHeight: Kirigami.Units.gridUnit * 0.9
                radius: height / 2
                color: card.timerOn ? card.tone : Qt.alpha(card.colors.ink, 0.18)
                opacity: card.interactive ? 1 : 0.5
                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                Rectangle {
                    width: parent.height - 4
                    height: width
                    radius: width / 2
                    y: 2
                    x: card.timerOn ? parent.width - width - 2 : 2
                    color: "white"
                    Behavior on x { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                }
                HoverHandler { id: timerHover; cursorShape: card.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler { enabled: card.interactive; onTapped: card.timerToggled(!card.timerOn) }
                Controls.ToolTip.visible: timerHover.hovered
                Controls.ToolTip.text: card.timerOn ? i18n("Runs automatically on its days. Click to stop.") : i18n("Click to run automatically on its days")
            }
        }

        Controls.Label {
            Layout.fillWidth: true
            text: card.scheduleText()
            color: card.timerOn ? card.colors.ink : card.colors.muted
            elide: Text.ElideRight
            font.pixelSize: Kirigami.Units.gridUnit * 0.6
            font.features: { "tnum": 1 }
        }
        Controls.Label {
            Layout.fillWidth: true
            text: card.airconText() + (card.acOn && card.openZones.length ? "\n" + card.openZones.map(z => z.isMyZone ? z.name + " ★" : z.name).join(", ") : "")
            color: card.colors.muted
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            font.pixelSize: Kirigami.Units.gridUnit * 0.58
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: Kirigami.Units.smallSpacing
            PillButton {
                objectName: "runButton"
                text: i18n("Run now")
                ink: card.colors.ink
                tone: card.tone
                filled: card.acOn
                interactive: card.interactive
                onClicked: card.run()
            }
            PillButton {
                objectName: "editButton"
                text: i18n("Edit")
                ink: card.colors.ink
                tone: card.colors.ink
                interactive: card.interactive
                onClicked: card.edit()
            }
            Item { Layout.fillWidth: true }
            PillButton {
                objectName: "deleteButton"
                text: card.confirmingDelete ? i18n("Delete?") : i18n("Delete")
                ink: card.colors.ink
                tone: card.colors.bad
                filled: card.confirmingDelete
                interactive: card.interactive
                onClicked: {
                    if (card.confirmingDelete) {
                        card.confirmingDelete = false;
                        card.remove();
                    } else {
                        card.confirmingDelete = true;
                        confirmTimer.restart();
                    }
                }
            }
        }
    }
}
