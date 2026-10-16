import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "myplace.js" as MyPlace

Rectangle {
    id: card
    property var zone: ({})
    property var series: []
    property var colors: ({})
    property color accent: "steelblue"
    property bool unitOn: false
    property bool interactive: true
    property bool showSparkline: true
    property double windowMs: 4 * 3600 * 1000
    property double gapMs: 5 * 60 * 1000
    signal toggled()
    signal stepped(int direction)

    readonly property bool open: Boolean(zone.open)
    readonly property bool hasSensor: Boolean(zone.hasSensor)
    readonly property color tempColor: colors.tempColor ? colors.tempColor(zone.measuredTemp) : accent

    implicitHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 2
    radius: Kirigami.Units.cornerRadius * 1.5
    color: open && unitOn ? Qt.alpha(accent, 0.10) : Qt.alpha(colors.ink, 0.045)
    border.color: open && unitOn ? Qt.alpha(accent, 0.35) : Qt.alpha(colors.ink, 0.08)
    Behavior on color { ColorAnimation { duration: Kirigami.Units.longDuration } }

    // Temperature tint along the leading edge.
    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height - Kirigami.Units.largeSpacing * 2
        radius: 1.5
        visible: card.hasSensor && !card.zone.sensorError
        color: card.tempColor
        opacity: 0.9
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        anchors.leftMargin: Kirigami.Units.largeSpacing + 2
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Controls.Label {
                Layout.fillWidth: true
                text: card.zone.name || ""
                elide: Text.ElideRight
                color: card.colors.ink
                font.pixelSize: Kirigami.Units.gridUnit * 0.68
                font.weight: Font.DemiBold
            }
            Rectangle {
                visible: Boolean(card.zone.isMyZone)
                implicitWidth: myZoneLabel.implicitWidth + 8
                implicitHeight: myZoneLabel.implicitHeight + 2
                radius: height / 2
                color: Qt.alpha(card.accent, 0.18)
                Controls.Label {
                    id: myZoneLabel
                    anchors.centerIn: parent
                    text: i18n("MyZone")
                    color: card.accent
                    font.pixelSize: Kirigami.Units.gridUnit * 0.48
                    font.weight: Font.DemiBold
                }
                Controls.ToolTip.visible: myZoneHover.hovered
                Controls.ToolTip.text: i18n("This zone's sensor drives the unit")
                HoverHandler { id: myZoneHover }
            }
            // Open/close switch.
            Rectangle {
                id: toggle
                implicitWidth: Kirigami.Units.gridUnit * 1.6
                implicitHeight: Kirigami.Units.gridUnit * 0.9
                radius: height / 2
                color: card.open ? card.accent : Qt.alpha(card.colors.ink, 0.18)
                opacity: card.interactive ? 1 : 0.5
                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                Rectangle {
                    width: parent.height - 4
                    height: width
                    radius: width / 2
                    y: 2
                    x: card.open ? parent.width - width - 2 : 2
                    color: "white"
                    Behavior on x { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                }
                HoverHandler { cursorShape: card.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler { enabled: card.interactive; onTapped: card.toggled() }
                Controls.ToolTip.visible: toggleHover.hovered
                Controls.ToolTip.text: card.open ? i18n("Close zone") : i18n("Open zone")
                HoverHandler { id: toggleHover }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Controls.Label {
                text: card.hasSensor ? MyPlace.formatTemp(card.zone.measuredTemp, 1) : i18n("No sensor")
                color: card.zone.sensorError ? card.colors.warn : card.colors.ink
                font.pixelSize: card.hasSensor ? Kirigami.Units.gridUnit * 1.55 : Kirigami.Units.gridUnit * 0.7
                font.weight: Font.Light
                font.features: { "tnum": 1 }
                Layout.alignment: Qt.AlignBaseline
            }
            Kirigami.Icon {
                visible: Boolean(card.zone.sensorError) || (card.hasSensor && card.zone.rssi > 0 && card.zone.rssi < 15)
                source: "dialog-warning"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
                Controls.ToolTip.visible: warnHover.hovered
                Controls.ToolTip.text: card.zone.sensorError ? i18n("Sensor error") : i18n("Weak sensor signal")
                HoverHandler { id: warnHover }
            }
            Item { Layout.fillWidth: true }
        }

        // Target or damper, depending on whether the zone has a sensor. Like
        // the app, a closed zone's setting can still be changed.
        RowLayout {
            Layout.fillWidth: true
            Stepper {
                id: stepper
                opacity: card.open ? 1 : 0.7
                ink: card.colors.ink
                accent: card.accent
                textSize: Kirigami.Units.gridUnit * 0.72
                interactive: card.interactive
                text: card.hasSensor ? MyPlace.formatTemp(card.zone.setTemp, 0) : card.zone.value + "%"
                canDecrease: card.hasSensor ? card.zone.setTemp > MyPlace.MIN_TEMP : card.zone.value > MyPlace.DAMPER_STEP
                canIncrease: card.hasSensor ? card.zone.setTemp < MyPlace.MAX_TEMP : card.zone.value < 100
                onDecrease: card.stepped(-1)
                onIncrease: card.stepped(1)
            }
            Item { Layout.fillWidth: true }
            Controls.Label {
                visible: !card.open
                text: i18n("Closed")
                color: card.colors.muted
                font.pixelSize: Kirigami.Units.gridUnit * 0.6
                font.letterSpacing: 0.6
            }
        }

        Sparkline {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.1
            visible: card.showSparkline && card.hasSensor
            points: card.series
            windowMs: card.windowMs
            gapMs: card.gapMs
            color: card.tempColor
            opacity: 0.85
        }
    }
}
