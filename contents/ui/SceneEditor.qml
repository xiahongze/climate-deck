pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "myplace.js" as MyPlace

// Edits a scene draft: name, days and times, and the aircon snapshot it applies.
Item {
    id: editor
    property var deck
    property var draft: ({})
    property bool isNew: true
    property bool saving: false
    property string error: ""
    signal save(var draft)
    // The page owns the draft; edits come back through this.
    signal edited(var draft)
    signal cancel()

    readonly property var colors: deck.colors
    readonly property string acKey: deck.client.acKey
    readonly property var sceneAc: MyPlace.sceneAircon(draft, acKey)
    readonly property var sceneInfo: sceneAc ? sceneAc.info || {} : {}
    readonly property bool acOn: sceneInfo.state === "on"
    readonly property color tone: acOn ? (deck.modeAccents[sceneInfo.mode] || colors.neutral) : colors.neutral
    readonly property real target: sceneAc ? MyPlace.targetTemp(sceneAc) : NaN
    readonly property int myZone: MyPlace.validMyZone(sceneInfo)
    readonly property bool valid: MyPlace.validSceneName(draft.name) && sceneAc !== null

    function mutate(fn) {
        const d = MyPlace.clone(draft);
        fn(d, MyPlace.sceneAircon(d, acKey));
        edited(d);
    }

    function zoneOf(ac, key) {
        if (!ac.zones)
            ac.zones = {};
        if (!ac.zones[key])
            ac.zones[key] = { number: Number(key.slice(1)) };
        return ac.zones[key];
    }

    function setTarget(t) {
        mutate((d, ac) => {
            if (editor.myZone)
                zoneOf(ac, MyPlace.zoneKey(editor.myZone)).setTemp = MyPlace.clampTemp(t);
            else
                ac.info.setTemp = MyPlace.clampTemp(t);
        });
    }

    component SectionLabel: Controls.Label {
        color: editor.colors.muted
        font.pixelSize: Kirigami.Units.gridUnit * 0.55
        font.weight: Font.DemiBold
        font.letterSpacing: 1.4
        Layout.topMargin: Kirigami.Units.smallSpacing
    }
    component FieldLabel: Controls.Label {
        color: editor.colors.ink
        font.pixelSize: Kirigami.Units.gridUnit * 0.62
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // Title bar.
        RowLayout {
            Layout.fillWidth: true
            PillButton {
                text: i18n("Cancel")
                ink: editor.colors.ink
                tone: editor.colors.ink
                onClicked: editor.cancel()
            }
            Controls.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: editor.isNew ? i18n("New scene") : i18n("Edit scene")
                color: editor.colors.ink
                font.pixelSize: Kirigami.Units.gridUnit * 0.72
                font.weight: Font.DemiBold
            }
            PillButton {
                objectName: "saveButton"
                text: editor.saving ? i18n("Saving…") : i18n("Save")
                ink: editor.colors.ink
                tone: editor.acOn ? editor.tone : editor.deck.modeAccents.cool
                filled: true
                interactive: editor.valid && !editor.saving && editor.deck.canControl
                onClicked: editor.save(editor.draft)
            }
        }
        Controls.Label {
            visible: editor.error !== ""
            Layout.fillWidth: true
            text: editor.error
            color: editor.colors.bad
            wrapMode: Text.Wrap
            font.pixelSize: Kirigami.Units.gridUnit * 0.6
        }

        Controls.ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: scroll.availableWidth
                spacing: Kirigami.Units.largeSpacing

                DeckField {
                    id: nameField
                    objectName: "nameField"
                    ink: editor.colors.ink
                    accent: editor.tone
                    Layout.fillWidth: true
                    placeholderText: i18n("Scene name (up to 12 characters)")
                    maximumLength: 12
                    text: editor.draft.name || ""
                    onTextEdited: editor.mutate(d => { d.name = text; })
                }

                SectionLabel { text: i18n("WHEN") }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: 7
                        delegate: Rectangle {
                            id: dayPill
                            required property int index
                            readonly property int bit: MyPlace.DAY_BITS[index]
                            readonly property bool on: (Number(editor.draft.activeDays) & bit) !== 0
                            Layout.fillWidth: true
                            implicitHeight: Kirigami.Units.gridUnit * 1.5
                            radius: height / 2
                            color: on ? Qt.alpha(editor.tone, 0.85) : dayHover.hovered ? Qt.alpha(editor.colors.ink, 0.1) : Qt.alpha(editor.colors.ink, 0.05)
                            border.color: on ? "transparent" : Qt.alpha(editor.colors.ink, 0.1)
                            Controls.Label {
                                anchors.centerIn: parent
                                text: editor.deck.dayLetters[dayPill.index]
                                color: dayPill.on ? "white" : editor.colors.muted
                                font.pixelSize: Kirigami.Units.gridUnit * 0.6
                                font.weight: Font.DemiBold
                            }
                            HoverHandler { id: dayHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: editor.mutate(d => { d.activeDays = Number(d.activeDays) ^ dayPill.bit; }) }
                            Controls.ToolTip.visible: dayHover.hovered
                            Controls.ToolTip.text: editor.deck.dayNames[dayPill.index]
                        }
                    }
                }
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: [{ text: editor.deck.dayWords.everyDay, mask: MyPlace.EVERY_DAY },
                                { text: editor.deck.dayWords.weekdays, mask: MyPlace.WEEKDAYS },
                                { text: editor.deck.dayWords.weekends, mask: MyPlace.WEEKENDS }]
                        delegate: PillButton {
                            required property var modelData
                            text: modelData.text
                            ink: editor.colors.ink
                            tone: Number(editor.draft.activeDays) === modelData.mask ? editor.tone : editor.colors.muted
                            onClicked: editor.mutate(d => { d.activeDays = modelData.mask; })
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    FieldLabel { text: i18n("Run automatically") }
                    Item { Layout.fillWidth: true }
                    Toggle {
                        objectName: "autoToggle"
                        on: Boolean(editor.draft.timerEnabled)
                        tone: editor.tone
                        ink: editor.colors.ink
                        onToggled: on => editor.mutate(d => { d.timerEnabled = on; })
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    FieldLabel { text: i18n("Starts at") }
                    Item { Layout.fillWidth: true }
                    Stepper {
                        text: MyPlace.formatMinutes(editor.draft.startTime)
                        ink: editor.colors.ink
                        accent: editor.tone
                        textSize: Kirigami.Units.gridUnit * 0.8
                        onDecrease: editor.mutate(d => { d.startTime = MyPlace.stepMinutes(d.startTime, -1, 15); })
                        onIncrease: editor.mutate(d => { d.startTime = MyPlace.stepMinutes(d.startTime, 1, 15); })
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    FieldLabel { text: i18n("Turn aircon off later") }
                    Item { Layout.fillWidth: true }
                    Toggle {
                        on: Boolean(editor.draft.airconStopTimeEnabled)
                        tone: editor.tone
                        ink: editor.colors.ink
                        onToggled: on => editor.mutate(d => { d.airconStopTimeEnabled = on; })
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    opacity: editor.draft.airconStopTimeEnabled ? 1 : 0.4
                    FieldLabel { text: i18n("Off at") }
                    Item { Layout.fillWidth: true }
                    Stepper {
                        interactive: Boolean(editor.draft.airconStopTimeEnabled)
                        text: MyPlace.formatMinutes(editor.draft.airconStopTime)
                        ink: editor.colors.ink
                        accent: editor.tone
                        textSize: Kirigami.Units.gridUnit * 0.8
                        onDecrease: editor.mutate(d => { d.airconStopTime = MyPlace.stepMinutes(d.airconStopTime, -1, 15); })
                        onIncrease: editor.mutate(d => { d.airconStopTime = MyPlace.stepMinutes(d.airconStopTime, 1, 15); })
                    }
                }

                SectionLabel { text: i18n("AIRCON") }
                Segmented {
                    Layout.fillWidth: true
                    options: [{ value: "on", label: i18n("On") }, { value: "off", label: i18n("Off") }]
                    current: editor.sceneInfo.state || "off"
                    ink: editor.colors.ink
                    accent: editor.acOn ? editor.tone : editor.colors.neutral
                    onPicked: value => editor.mutate((d, ac) => { ac.info.state = value; })
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing
                    opacity: editor.acOn ? 1 : 0.45
                    Segmented {
                        Layout.fillWidth: true
                        options: MyPlace.modes(editor.deck.info).map(m => ({ value: m, label: editor.deck.modeLabel(m) }))
                        current: editor.sceneInfo.mode || ""
                        ink: editor.colors.ink
                        accent: editor.tone
                        onPicked: value => editor.mutate((d, ac) => { ac.info.mode = value; })
                    }
                    Segmented {
                        Layout.fillWidth: true
                        options: ["low", "medium", "high", MyPlace.autoFan(editor.deck.info)].map(f => ({ value: f, label: editor.deck.fanLabel(f) }))
                        current: MyPlace.isAutoFan(editor.sceneInfo.fan) ? MyPlace.autoFan(editor.deck.info) : editor.sceneInfo.fan || ""
                        ink: editor.colors.ink
                        accent: editor.tone
                        onPicked: value => editor.mutate((d, ac) => { ac.info.fan = value; })
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        FieldLabel { text: editor.myZone ? i18n("Target, MyZone") : i18n("Target") }
                        Controls.ComboBox {
                            id: myZoneBox
                            objectName: "sceneMyZone"
                            visible: editor.myZone > 0
                            textRole: "text"
                            valueRole: "value"
                            model: editor.deck.myZoneChoices.map(z => ({ text: z.name, value: z.number }))
                            currentIndex: Math.max(0, indexOfValue(editor.myZone))
                            onActivated: {
                                const n = currentValue;
                                editor.mutate((d, ac) => {
                                    ac.info.myZone = n;
                                    editor.zoneOf(ac, MyPlace.zoneKey(n)).state = "open";
                                });
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Stepper {
                            text: MyPlace.formatTemp(editor.target, 0)
                            ink: editor.colors.ink
                            accent: editor.tone
                            textSize: Kirigami.Units.gridUnit * 0.95
                            canDecrease: editor.target > MyPlace.MIN_TEMP
                            canIncrease: editor.target < MyPlace.MAX_TEMP
                            onDecrease: editor.setTarget(editor.target - 1)
                            onIncrease: editor.setTarget(editor.target + 1)
                        }
                    }

                    SectionLabel { text: i18n("ZONES") }
                    Repeater {
                        model: editor.deck.zones
                        delegate: RowLayout {
                            id: zoneRow
                            required property var modelData
                            readonly property var sz: editor.sceneAc && editor.sceneAc.zones ? editor.sceneAc.zones[modelData.key] || {} : {}
                            readonly property bool open: sz.state === "open"
                            readonly property bool isMyZone: modelData.number === editor.myZone
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            Toggle {
                                on: zoneRow.open
                                tone: editor.tone
                                ink: editor.colors.ink
                                // The MyZone zone has to stay open.
                                interactive: !zoneRow.isMyZone
                                onToggled: on => editor.mutate((d, ac) => { editor.zoneOf(ac, zoneRow.modelData.key).state = on ? "open" : "close"; })
                            }
                            Controls.Label {
                                Layout.fillWidth: true
                                text: zoneRow.modelData.name + (zoneRow.isMyZone ? "  ★" : "")
                                color: zoneRow.open ? editor.colors.ink : editor.colors.muted
                                elide: Text.ElideRight
                                font.pixelSize: Kirigami.Units.gridUnit * 0.62
                            }
                            Stepper {
                                opacity: zoneRow.open ? 1 : 0.6
                                ink: editor.colors.ink
                                accent: editor.tone
                                textSize: Kirigami.Units.gridUnit * 0.68
                                readonly property bool sensor: zoneRow.modelData.hasSensor
                                readonly property real temp: Number(zoneRow.sz.setTemp)
                                readonly property real damper: Number(zoneRow.sz.value)
                                text: sensor ? MyPlace.formatTemp(temp, 0) : damper + "%"
                                canDecrease: sensor ? temp > MyPlace.MIN_TEMP : damper > MyPlace.DAMPER_STEP
                                canIncrease: sensor ? temp < MyPlace.MAX_TEMP : damper < 100
                                onDecrease: editor.mutate((d, ac) => {
                                    const z = editor.zoneOf(ac, zoneRow.modelData.key);
                                    if (sensor) z.setTemp = MyPlace.clampTemp(temp - 1); else z.value = MyPlace.clampDamper(damper - MyPlace.DAMPER_STEP);
                                })
                                onIncrease: editor.mutate((d, ac) => {
                                    const z = editor.zoneOf(ac, zoneRow.modelData.key);
                                    if (sensor) z.setTemp = MyPlace.clampTemp(temp + 1); else z.value = MyPlace.clampDamper(damper + MyPlace.DAMPER_STEP);
                                })
                            }
                        }
                    }
                }
                Item { implicitHeight: Kirigami.Units.smallSpacing }
            }
        }
    }
}
