pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "myplace.js" as MyPlace

// Names and MyComfort options. Aircon settings go through setAircon (with the
// client's pending overlay); the system option goes through setMySystem.
Item {
    id: page
    objectName: "setupPage"
    property var deck
    readonly property var client: deck.client
    readonly property var colors: deck.colors
    readonly property var info: deck.info
    readonly property color tone: deck.unitOn ? deck.accent : deck.modeAccents.cool
    readonly property string control: MyPlace.temperatureControl(info)
    readonly property var range: MyPlace.myAutoRange(info)
    // Optimistic value for the system option until a poll agrees.
    property var showMeasuredOverride: undefined
    readonly property bool showMeasured: showMeasuredOverride !== undefined ? showMeasuredOverride
        : Boolean(deck.system.showMeasuredTemp)

    implicitHeight: 0

    function setInfo(fields) {
        client.command({ info: fields }, 0);
    }

    function rename(zoneKey, name) {
        const zones = {};
        zones[zoneKey] = { name: name };
        client.command({ zones: zones }, 0);
    }

    function setShowMeasured(on) {
        showMeasuredOverride = on;
        client.request("setMySystem", { showMeasuredTemp: on }, function(ok, reason) {
            if (!ok) {
                page.showMeasuredOverride = undefined;
                page.deck.notify(i18n("Couldn't change the setting: %1", reason), true);
            }
        });
    }

    Connections {
        target: page.client
        function onRefreshed() {
            if (page.showMeasuredOverride !== undefined && Boolean(page.deck.system.showMeasuredTemp) === page.showMeasuredOverride)
                page.showMeasuredOverride = undefined;
        }
    }

    component SectionLabel: Controls.Label {
        color: page.colors.muted
        font.pixelSize: Kirigami.Units.gridUnit * 0.55
        font.weight: Font.DemiBold
        font.letterSpacing: 1.4
        Layout.topMargin: Kirigami.Units.smallSpacing
    }
    // A titled row with a muted explanation underneath and a control on the right.
    component OptionRow: RowLayout {
        id: row
        property string title
        property string detail
        default property alias control: slot.data
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Controls.Label {
                Layout.fillWidth: true
                text: row.title
                color: page.colors.ink
                font.pixelSize: Kirigami.Units.gridUnit * 0.66
                font.weight: Font.Medium
            }
            Controls.Label {
                Layout.fillWidth: true
                visible: row.detail !== ""
                text: row.detail
                color: page.colors.muted
                wrapMode: Text.Wrap
                font.pixelSize: Kirigami.Units.gridUnit * 0.55
            }
        }
        Item {
            id: slot
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
    // Commits on Enter or when focus leaves, only when the name actually changed.
    component NameField: DeckField {
        id: field
        property string current
        ink: page.colors.ink
        accent: page.tone
        signal committed(string name)
        Layout.fillWidth: true
        maximumLength: 12
        text: current
        placeholderText: i18n("Up to 12 characters")
        onEditingFinished: {
            const name = text.trim();
            if (name === current)
                return;
            if (!MyPlace.validSceneName(name)) {
                text = Qt.binding(() => field.current);
                return;
            }
            committed(name);
        }
    }

    Controls.ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: scroll.availableWidth
            spacing: Kirigami.Units.largeSpacing

            SectionLabel { text: i18n("NAMES") }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing
                Controls.Label {
                    text: i18n("Aircon")
                    color: page.colors.muted
                    font.pixelSize: Kirigami.Units.gridUnit * 0.6
                }
                NameField {
                    objectName: "airconName"
                    current: page.info.name || ""
                    enabled: page.deck.canControl
                    onCommitted: name => page.setInfo({ name: name })
                }
                Repeater {
                    model: page.deck.zones
                    delegate: Controls.Label {
                        required property var modelData
                        text: i18n("Zone %1", modelData.number)
                        color: page.colors.muted
                        font.pixelSize: Kirigami.Units.gridUnit * 0.6
                        font.features: { "tnum": 1 }
                        Layout.row: modelData.number
                        Layout.column: 0
                    }
                }
                Repeater {
                    model: page.deck.zones
                    delegate: NameField {
                        required property var modelData
                        objectName: "zoneName_" + modelData.key
                        Layout.row: modelData.number
                        Layout.column: 1
                        current: modelData.name
                        enabled: page.deck.canControl
                        onCommitted: name => page.rename(modelData.key, name)
                    }
                }
            }

            SectionLabel { text: i18n("MYCOMFORT") }
            OptionRow {
                title: i18n("MySleep$aver")
                detail: i18n("Advantage Air's overnight energy saver")
                Toggle {
                    objectName: "quietNightToggle"
                    on: Boolean(page.info.quietNightModeEnabled)
                    tone: page.tone
                    ink: page.colors.ink
                    interactive: page.deck.canControl
                    onToggled: on => page.setInfo({ quietNightModeEnabled: on })
                }
            }
            OptionRow {
                visible: page.info.aaAutoFanModeEnabled !== undefined
                title: i18n("MyFan speed")
                detail: i18n("Auto fan speed uses MyFan")
                Toggle {
                    objectName: "myFanToggle"
                    on: Boolean(page.info.aaAutoFanModeEnabled)
                    tone: page.tone
                    ink: page.colors.ink
                    interactive: page.deck.canControl
                    onToggled: on => page.setInfo({ aaAutoFanModeEnabled: on })
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Controls.Label {
                    text: i18n("Temperature control")
                    color: page.colors.ink
                    font.pixelSize: Kirigami.Units.gridUnit * 0.66
                    font.weight: Font.Medium
                }
                Segmented {
                    objectName: "temperatureControl"
                    Layout.fillWidth: true
                    options: [{ value: "myzone", label: i18n("MyZone") }, { value: "mytemp", label: i18n("MyTemp") }, { value: "myauto", label: i18n("MyAuto") }]
                    current: page.control
                    ink: page.colors.ink
                    accent: page.tone
                    interactive: page.deck.canControl
                    onPicked: value => page.setInfo(MyPlace.temperatureControlFields(value))
                }
                Controls.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: page.colors.muted
                    font.pixelSize: Kirigami.Units.gridUnit * 0.55
                    text: page.control === "mytemp" ? i18n("MyTemp acts as an automated MyZone: the system picks the zone to follow.")
                        : page.control === "myauto" ? i18n("MyAuto heats or cools by itself to stay within the range below. Choose MyAuto as the mode on the climate page.")
                        : i18n("The unit follows the MyZone you pick on the climate page.")
                }
            }
            OptionRow {
                opacity: page.control === "myauto" ? 1 : 0.45
                title: i18n("MyAuto range")
                detail: i18n("Heats below the first, cools above the second, at least 4° apart")
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Stepper {
                        objectName: "myAutoHeat"
                        text: MyPlace.formatTemp(page.range.heat, 0)
                        ink: page.deck.modeAccents.heat
                        accent: page.deck.modeAccents.heat
                        textSize: Kirigami.Units.gridUnit * 0.75
                        interactive: page.deck.canControl
                        canDecrease: MyPlace.myAutoRangeValid(page.range.heat - 1, page.range.cool)
                        canIncrease: MyPlace.myAutoRangeValid(page.range.heat + 1, page.range.cool)
                        onDecrease: page.setInfo({ myAutoHeatTargetTemp: page.range.heat - 1, myAutoCoolTargetTemp: page.range.cool })
                        onIncrease: page.setInfo({ myAutoHeatTargetTemp: page.range.heat + 1, myAutoCoolTargetTemp: page.range.cool })
                    }
                    Controls.Label { text: i18n("to"); color: page.colors.muted; font.pixelSize: Kirigami.Units.gridUnit * 0.6 }
                    Stepper {
                        objectName: "myAutoCool"
                        text: MyPlace.formatTemp(page.range.cool, 0)
                        ink: page.deck.modeAccents.cool
                        accent: page.deck.modeAccents.cool
                        textSize: Kirigami.Units.gridUnit * 0.75
                        interactive: page.deck.canControl
                        canDecrease: MyPlace.myAutoRangeValid(page.range.heat, page.range.cool - 1)
                        canIncrease: MyPlace.myAutoRangeValid(page.range.heat, page.range.cool + 1)
                        onDecrease: page.setInfo({ myAutoHeatTargetTemp: page.range.heat, myAutoCoolTargetTemp: page.range.cool - 1 })
                        onIncrease: page.setInfo({ myAutoHeatTargetTemp: page.range.heat, myAutoCoolTargetTemp: page.range.cool + 1 })
                    }
                }
            }

            SectionLabel { text: i18n("SYSTEM") }
            OptionRow {
                title: i18n("Show actual temperature")
                detail: i18n("Show measured zone temperatures on the wall tablet and in the apps")
                Toggle {
                    objectName: "showMeasuredToggle"
                    on: page.showMeasured
                    tone: page.tone
                    ink: page.colors.ink
                    interactive: page.deck.canControl
                    onToggled: on => page.setShowMeasured(on)
                }
            }
            Item { implicitHeight: Kirigami.Units.smallSpacing }
        }
    }
}
