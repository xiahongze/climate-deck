pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "myplace.js" as MyPlace

Item {
    id: root
    required property Client client
    property bool desktop: true
    property string themeMode: "system"
    property int desktopOpacity: 70
    property bool showSparklines: true
    // Tests freeze this so relative times are stable.
    property var clockSource: function() { return Date.now(); }
    property double now: clockSource()
    signal configureRequested()
    // 0 = climate, 1 = scenes.
    property int page: 0
    readonly property var dayNames: [i18n("Mon"), i18n("Tue"), i18n("Wed"), i18n("Thu"), i18n("Fri"), i18n("Sat"), i18n("Sun")]
    readonly property var dayLetters: [i18n("M"), i18n("T"), i18n("W"), i18n("T"), i18n("F"), i18n("S"), i18n("S")]
    readonly property var dayWords: ({ everyDay: i18n("Every day"), weekdays: i18n("Weekdays"), weekends: i18n("Weekends"), noDays: i18n("No days") })

    readonly property var ac: client.aircon
    readonly property var info: ac ? ac.info : ({})
    readonly property var system: client.view ? client.view.system : ({})
    readonly property var zones: ac ? MyPlace.sortedZones(ac) : []
    readonly property var house: MyPlace.houseStats(zones)
    readonly property real outdoor: MyPlace.outdoorTemp(system)
    readonly property bool unitOn: info.state === "on"
    readonly property bool canControl: client.online && ac !== null
    readonly property real target: ac ? MyPlace.targetTemp(ac) : NaN
    readonly property int openCount: zones.filter(z => z.open).length
    readonly property bool canChangeMyZone: canControl && MyPlace.canChangeMyZone(info)
    readonly property var myZoneChoices: MyPlace.myZoneCandidates(zones)

    readonly property bool forcedDark: themeMode === "dark"
    readonly property bool forcedLight: themeMode === "light"
    readonly property color themeBg: Kirigami.Theme.backgroundColor
    readonly property bool dark: forcedDark || (!forcedLight && (0.299 * themeBg.r + 0.587 * themeBg.g + 0.114 * themeBg.b) < 0.5)
    readonly property var modeAccents: dark
        ? { cool: "#5aaaf5", heat: "#f28c45", vent: "#45c0ad", dry: "#b892f2", myauto: "#7fcb6e", auto: "#7fcb6e" }
        : { cool: "#2a76c6", heat: "#c8611c", vent: "#1d8d7c", dry: "#7a52c7", myauto: "#3f8f31", auto: "#3f8f31" }
    readonly property color accent: unitOn ? (modeAccents[info.mode] || colors.neutral) : colors.neutral
    readonly property var colors: ({
        surface: forcedDark ? "#141922" : forcedLight ? "#ffffff" : Kirigami.Theme.backgroundColor,
        ink: forcedDark ? "#eef2f6" : forcedLight ? "#1f242b" : Kirigami.Theme.textColor,
        muted: forcedDark ? "#8f99a5" : forcedLight ? "#69737e" : Qt.alpha(Kirigami.Theme.textColor, 0.6),
        neutral: dark ? "#8a96a3" : "#6b7682",
        warn: dark ? "#f2b84b" : "#b7791f",
        bad: dark ? "#f2706a" : "#c43d36",
        good: dark ? "#6fcf8b" : "#2f9e57",
        tempColor: tempColor
    })

    // 16° icy blue → 22° calm green → 27° amber → 31° warm red.
    function tempColor(t) {
        const stops = dark
            ? [[16, "#5aaaf5"], [22, "#6fcfa0"], [27, "#f2b04b"], [31, "#f2706a"]]
            : [[16, "#2a76c6"], [22, "#2f9e6e"], [27, "#c98a1c"], [31, "#c43d36"]];
        if (!isFinite(t))
            return stops[1][1];
        if (t <= stops[0][0])
            return stops[0][1];
        for (let i = 1; i < stops.length; i++) {
            if (t <= stops[i][0]) {
                const f = (t - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0]);
                const a = Qt.color(stops[i - 1][1]), b = Qt.color(stops[i][1]);
                return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1);
            }
        }
        return stops[stops.length - 1][1];
    }

    function modeLabel(m) {
        return { cool: i18n("Cool"), heat: i18n("Heat"), vent: i18n("Fan"), dry: i18n("Dry"), myauto: i18n("MyAuto"), auto: i18n("Auto") }[m] || m;
    }

    function fanLabel(f) {
        return { low: i18n("Low"), medium: i18n("Medium"), high: i18n("High"), auto: i18n("Auto"), autoAA: i18n("Auto") }[f] || f;
    }

    function ago(ms) {
        if (!ms)
            return "";
        const s = Math.max(0, Math.round((now - ms) / 1000));
        if (s < 5)
            return i18n("just now");
        if (s < 60)
            return i18n("%1 s ago", s);
        if (s < 3600)
            return i18n("%1 min ago", Math.round(s / 60));
        return i18n("%1 h ago", Math.round(s / 3600));
    }

    function setTarget(direction) {
        const next = MyPlace.clampTemp(target + direction);
        if (next !== target)
            client.command(MyPlace.targetPayload(ac, next), client.debounceMs);
    }

    function stepZone(zone, direction) {
        const zones = {};
        if (zone.hasSensor)
            zones[zone.key] = { setTemp: MyPlace.clampTemp(zone.setTemp + direction) };
        else
            zones[zone.key] = { value: MyPlace.clampDamper(zone.value + direction * MyPlace.DAMPER_STEP) };
        client.command({ zones: zones }, client.debounceMs);
    }

    function setMyZone(zone) {
        if (zone.isMyZone || !canChangeMyZone)
            return;
        for (const cmd of MyPlace.myZoneCommands(ac, zone.number))
            client.command(cmd, 0, true);
    }

    // 85 -> "1 h 25 min"; compact: 30 -> "30m", 120 -> "2h".
    function duration(minutes, compact) {
        const h = Math.floor(minutes / 60), m = minutes % 60;
        if (compact)
            return h === 0 ? i18n("%1m", m) : m === 0 ? i18n("%1h", h) : i18n("%1h %2m", h, m);
        return h === 0 ? i18n("%1 min", m) : m === 0 ? i18n("%1 h", h) : i18n("%1 h %2 min", h, m);
    }

    // The buttons swap places when a timer starts or stops, so a fast second
    // click would land on a different one; ignore it.
    property double lastTimerTap: 0
    function setCountdown(minutes) {
        const now = Date.now();
        if (now - lastTimerTap < 600)
            return;
        lastTimerTap = now;
        client.command(MyPlace.countdownPayload(info, minutes), 0);
    }

    // A short message over the footer; errors show in red.
    function notify(message, isError) {
        toast.message = message;
        toast.isError = isError;
        toastTimer.restart();
    }

    function toggleZone(zone) {
        const zones = {};
        zones[zone.key] = { state: zone.open ? "close" : "open" };
        client.command({ zones: zones }, 0);
    }

    implicitWidth: Kirigami.Units.gridUnit * 27
    implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 4
    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: Kirigami.Units.gridUnit * 14
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight

    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.now = root.clockSource() }

    Rectangle {
        anchors.fill: parent
        visible: root.desktop
        radius: Kirigami.Units.cornerRadius * 3
        color: Qt.alpha(root.colors.surface, root.desktopOpacity / 100)
        border.color: Qt.alpha(root.colors.ink, 0.08)
    }
    // A soft glow in the current mode's colour while the unit runs.
    Rectangle {
        anchors.fill: parent
        visible: root.desktop && root.unitOn
        radius: Kirigami.Units.cornerRadius * 3
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(root.accent, 0.14) }
            GradientStop { position: 0.45; color: "transparent" }
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing * 2
        spacing: Kirigami.Units.largeSpacing

        // Header: system name, link status, outdoor temperature.
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Controls.Label {
                visible: root.ac === null
                text: (root.system.name || i18n("Climate")).toUpperCase()
                color: root.colors.muted
                font.pixelSize: Kirigami.Units.gridUnit * 0.6
                font.weight: Font.DemiBold
                font.letterSpacing: 1.4
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            // Page tabs.
            RowLayout {
                visible: root.ac !== null
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                Repeater {
                    model: [i18n("CLIMATE"), i18n("SCENES")]
                    delegate: Item {
                        id: tab
                        required property string modelData
                        required property int index
                        readonly property bool active: root.page === index
                        objectName: "tab" + index
                        implicitWidth: tabLabel.implicitWidth
                        implicitHeight: tabLabel.implicitHeight + 6
                        Controls.Label {
                            id: tabLabel
                            text: tab.modelData
                            color: tab.active ? root.colors.ink : tabHover.hovered ? Qt.alpha(root.colors.ink, 0.8) : root.colors.muted
                            font.pixelSize: Kirigami.Units.gridUnit * 0.6
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.4
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: tab.active ? parent.width : 0
                            height: 2
                            radius: 1
                            color: root.unitOn ? root.accent : root.colors.ink
                            opacity: 0.85
                            Behavior on width { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                        }
                        HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.page = tab.index }
                    }
                }
                Item { Layout.fillWidth: true }
            }
            Rectangle {
                id: statusPill
                readonly property color tone: !root.client.configured ? root.colors.neutral
                    : root.client.online ? (root.client.stale ? root.colors.warn : root.colors.good) : root.colors.bad
                implicitWidth: statusRow.implicitWidth + 12
                implicitHeight: statusRow.implicitHeight + 4
                radius: height / 2
                color: Qt.alpha(tone, 0.14)
                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 5
                    Rectangle { width: 6; height: 6; radius: 3; color: statusPill.tone }
                    Controls.Label {
                        text: !root.client.configured ? i18n("SETUP") : root.client.online ? (root.client.stale ? i18n("RETRYING") : i18n("LIVE")) : root.client.lastUpdated > 0 ? i18n("OFFLINE") : i18n("CONNECTING")
                        color: statusPill.tone
                        font.pixelSize: Kirigami.Units.gridUnit * 0.5
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                }
                Controls.ToolTip.visible: statusHover.hovered && root.client.lastError !== ""
                Controls.ToolTip.text: root.client.lastError
                HoverHandler { id: statusHover }
            }
            RowLayout {
                visible: isFinite(root.outdoor)
                spacing: 3
                Kirigami.Icon {
                    source: "weather-few-clouds"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    opacity: 0.8
                }
                Controls.Label {
                    text: MyPlace.formatTemp(root.outdoor, 1)
                    color: root.colors.ink
                    font.pixelSize: Kirigami.Units.gridUnit * 0.68
                    font.features: { "tnum": 1 }
                }
                Controls.ToolTip.visible: outdoorHover.hovered
                Controls.ToolTip.text: i18n("Outside, as reported by the tablet")
                HoverHandler { id: outdoorHover }
            }
        }

        // Setup prompt before a tablet address is configured.
        ColumnLayout {
            visible: !root.client.configured
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.gridUnit
            Layout.bottomMargin: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.largeSpacing
            Controls.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: i18n("Enter the IP address of your MyPlace wall tablet to start.")
                color: root.colors.ink
            }
            Controls.Button {
                Layout.alignment: Qt.AlignHCenter
                icon.name: "configure"
                text: i18n("Configure…")
                onClicked: root.configureRequested()
            }
        }

        Controls.Label {
            visible: root.client.configured && root.ac === null
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.gridUnit
            Layout.bottomMargin: Kirigami.Units.gridUnit
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: root.colors.muted
            text: root.client.lastUpdated > 0 ? i18n("Aircon \"%1\" was not found on this system.", root.client.acKey)
                : root.client.failures > 0 ? i18n("Can't reach the tablet at %1. %2", root.client.host, root.client.lastError)
                : i18n("Connecting to %1…", root.client.host)
        }

        // Everything below needs data; it dims rather than blanks when offline.
        StackLayout {
            visible: root.ac !== null
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.page
            opacity: root.client.online ? 1 : 0.55
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                // Hero: inside temperature and the unit target.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    ColumnLayout {
                        spacing: 0
                        Controls.Label {
                            text: MyPlace.formatTemp(root.house.average, 1)
                            color: root.colors.ink
                            font.pixelSize: Kirigami.Units.gridUnit * 3
                            font.weight: Font.Light
                            font.features: { "tnum": 1 }
                        }
                        Controls.Label {
                            text: root.house.count > 1
                                ? i18n("INSIDE  %1 – %2", MyPlace.formatTemp(root.house.min, 1), MyPlace.formatTemp(root.house.max, 1))
                                : i18n("INSIDE")
                            color: root.colors.muted
                            font.pixelSize: Kirigami.Units.gridUnit * 0.52
                            font.letterSpacing: 1.2
                        }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter
                        Stepper {
                            Layout.alignment: Qt.AlignRight
                            text: MyPlace.formatTemp(root.target, 0)
                            ink: root.colors.ink
                            accent: root.accent
                            textSize: Kirigami.Units.gridUnit * 1.5
                            interactive: root.canControl
                            canDecrease: root.target > MyPlace.MIN_TEMP
                            canIncrease: root.target < MyPlace.MAX_TEMP
                            onDecrease: root.setTarget(-1)
                            onIncrease: root.setTarget(1)
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: 2
                            Controls.Label {
                                text: root.unitOn ? i18n("%1 TO", root.modeLabel(root.info.mode).toUpperCase()) : i18n("TARGET")
                                color: root.unitOn ? root.accent : root.colors.muted
                                font.pixelSize: Kirigami.Units.gridUnit * 0.52
                                font.letterSpacing: 1.2
                            }
                            // MyZone picker: which zone's sensor the unit works to.
                            Rectangle {
                                id: myZoneChip
                                objectName: "myZoneChip"
                                readonly property var myZone: root.zones.find(z => z.isMyZone)
                                readonly property bool live: root.canChangeMyZone
                                visible: myZone !== undefined
                                implicitWidth: myZoneText.implicitWidth + 10
                                implicitHeight: myZoneText.implicitHeight + 4
                                radius: height / 2
                                color: chipHover.hovered && live ? Qt.alpha(root.colors.ink, 0.12) : "transparent"
                                Controls.Label {
                                    id: myZoneText
                                    anchors.centerIn: parent
                                    text: myZoneChip.myZone ? myZoneChip.myZone.name.toUpperCase() + (myZoneChip.live ? "  ▾" : "") : ""
                                    color: root.unitOn ? root.accent : root.colors.muted
                                    font.pixelSize: Kirigami.Units.gridUnit * 0.52
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.2
                                }
                                HoverHandler { id: chipHover; cursorShape: myZoneChip.live ? Qt.PointingHandCursor : Qt.ArrowCursor }
                                TapHandler { enabled: myZoneChip.live; onTapped: myZoneMenu.popup(myZoneChip, 0, myZoneChip.height) }
                                Controls.ToolTip.visible: chipHover.hovered
                                Controls.ToolTip.text: root.info.quietNightModeIsRunning
                                    ? i18n("MyZone can't be changed while Quiet Night mode runs")
                                    : i18n("MyZone: the zone whose sensor the aircon works to. Click to change.")
                                Controls.Menu {
                                    id: myZoneMenu
                                    Instantiator {
                                        model: root.myZoneChoices
                                        delegate: Controls.MenuItem {
                                            required property var modelData
                                            text: modelData.name + "  ·  " + MyPlace.formatTemp(modelData.measuredTemp, 1) + (modelData.open ? "" : "  " + i18n("(opens it)"))
                                            checkable: true
                                            checked: modelData.isMyZone
                                            onTriggered: root.setMyZone(modelData)
                                        }
                                        onObjectAdded: (index, object) => myZoneMenu.insertItem(index, object)
                                        onObjectRemoved: (index, object) => myZoneMenu.removeItem(object)
                                    }
                                }
                            }
                        }
                    }
                }

                Sparkline {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.6
                    visible: root.showSparklines && (root.client.history.house || []).length > 1
                    points: root.client.history.house || []
                    windowMs: root.client.historyWindowMs
                    gapMs: root.client.historyGapMs
                    color: root.tempColor(root.house.average)
                    opacity: 0.8
                }

                // Power beside the stacked mode and fan selectors.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    Rectangle {
                        id: power
                        objectName: "powerButton"
                        readonly property color glyph: root.unitOn ? "white" : root.colors.ink
                        implicitWidth: selectors.implicitHeight
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: root.unitOn ? root.accent : Qt.alpha(root.colors.ink, powerHover.hovered && root.canControl ? 0.14 : 0.07)
                        border.color: root.unitOn ? Qt.lighter(root.accent, 1.25) : Qt.alpha(root.colors.ink, 0.12)
                        opacity: root.canControl ? 1 : 0.6
                        scale: powerTap.pressed ? 0.94 : 1
                        Behavior on color { ColorAnimation { duration: Kirigami.Units.longDuration } }
                        Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                        // The IEC power symbol, drawn so it never depends on the icon theme.
                        Canvas {
                            id: powerGlyph
                            anchors.centerIn: parent
                            width: parent.width * 0.4
                            height: width
                            property color tint: power.glyph
                            onTintChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const r = width / 2 - 2;
                                ctx.lineWidth = Math.max(2, width / 11);
                                ctx.lineCap = "round";
                                ctx.strokeStyle = tint;
                                ctx.beginPath();
                                ctx.arc(width / 2, height / 2 + 1, r, -Math.PI / 2 + 0.75, 1.5 * Math.PI - 0.75);
                                ctx.stroke();
                                ctx.beginPath();
                                ctx.moveTo(width / 2, 1);
                                ctx.lineTo(width / 2, height / 2);
                                ctx.stroke();
                            }
                        }
                        HoverHandler { id: powerHover; cursorShape: root.canControl ? Qt.PointingHandCursor : Qt.ArrowCursor }
                        TapHandler {
                            id: powerTap
                            enabled: root.canControl
                            onTapped: root.client.command({ info: { state: root.unitOn ? "off" : "on" } }, 0)
                        }
                        Controls.ToolTip.visible: powerHover.hovered
                        Controls.ToolTip.text: root.unitOn ? i18n("Turn the aircon off") : i18n("Turn the aircon on")
                    }

                    ColumnLayout {
                        id: selectors
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing * 1.5
                        Segmented {
                            Layout.fillWidth: true
                            options: MyPlace.modes(root.info).map(m => ({ value: m, label: root.modeLabel(m) }))
                            current: root.info.mode || ""
                            ink: root.colors.ink
                            accent: root.unitOn ? root.accent : root.colors.neutral
                            interactive: root.canControl
                            onPicked: value => root.client.command({ info: { mode: value } }, 0)
                        }
                        Segmented {
                            Layout.fillWidth: true
                            options: ["low", "medium", "high", MyPlace.autoFan(root.info)].map(f => ({ value: f, label: root.fanLabel(f) }))
                            current: MyPlace.isAutoFan(root.info.fan) ? MyPlace.autoFan(root.info) : root.info.fan || ""
                            ink: root.colors.ink
                            accent: root.unitOn ? root.accent : root.colors.neutral
                            interactive: root.canControl
                            onPicked: value => root.client.command({ info: { fan: value } }, 0)
                        }
                    }
                }

                // Quick timer: the unit's own countdown to off (while on) or on.
                RowLayout {
                    id: timerRow
                    objectName: "timerRow"
                    readonly property int remaining: MyPlace.countdownMinutes(root.info)
                    readonly property color tone: root.unitOn ? root.accent : root.modeAccents[root.info.mode] || root.colors.neutral
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Controls.Label {
                        text: timerRow.remaining > 0
                            ? (root.unitOn ? i18n("OFF IN") : i18n("ON IN"))
                            : (root.unitOn ? i18n("TURN OFF IN") : i18n("TURN ON IN"))
                        color: timerRow.remaining > 0 ? timerRow.tone : root.colors.muted
                        font.pixelSize: Kirigami.Units.gridUnit * 0.55
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.4
                    }
                    Controls.Label {
                        visible: timerRow.remaining > 0
                        text: root.duration(timerRow.remaining)
                        color: root.colors.ink
                        font.pixelSize: Kirigami.Units.gridUnit * 0.75
                        font.features: { "tnum": 1 }
                    }
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: timerRow.remaining > 0 ? [] : [30, 60, 120, 240]
                        delegate: PillButton {
                            required property int modelData
                            objectName: "timer" + modelData
                            text: root.duration(modelData, true)
                            ink: root.colors.ink
                            tone: timerRow.tone
                            interactive: root.canControl
                            onClicked: root.setCountdown(modelData)
                        }
                    }
                    PillButton {
                        visible: timerRow.remaining > 0
                        text: i18n("+30m")
                        ink: root.colors.ink
                        tone: timerRow.tone
                        interactive: root.canControl && timerRow.remaining < MyPlace.MAX_COUNTDOWN
                        onClicked: root.setCountdown(timerRow.remaining + 30)
                    }
                    PillButton {
                        objectName: "timerCancel"
                        visible: timerRow.remaining > 0
                        text: i18n("Cancel")
                        ink: root.colors.ink
                        tone: root.colors.ink
                        interactive: root.canControl
                        onClicked: root.setCountdown(0)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Controls.Label {
                        text: i18n("ZONES")
                        color: root.colors.muted
                        font.pixelSize: Kirigami.Units.gridUnit * 0.55
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.4
                    }
                    Item { Layout.fillWidth: true }
                    Controls.Label {
                        text: i18n("%1 of %2 open", root.openCount, root.zones.length)
                        color: root.colors.muted
                        font.pixelSize: Kirigami.Units.gridUnit * 0.55
                    }
                }

                GridLayout {
                    id: grid
                    Layout.fillWidth: true
                    columns: Math.max(2, Math.min(4, Math.floor(width / (Kirigami.Units.gridUnit * 8))))
                    columnSpacing: Kirigami.Units.smallSpacing * 1.5
                    rowSpacing: Kirigami.Units.smallSpacing * 1.5
                    Repeater {
                        model: root.zones
                        delegate: ZoneCard {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            zone: modelData
                            series: root.client.history[modelData.key] || []
                            colors: root.colors
                            accent: root.unitOn ? root.accent : root.colors.neutral
                            unitOn: root.unitOn
                            interactive: root.canControl
                            showSparkline: root.showSparklines
                            windowMs: root.client.historyWindowMs
                            gapMs: root.client.historyGapMs
                            onToggled: root.toggleZone(modelData)
                            onStepped: direction => root.stepZone(modelData, direction)
                        }
                    }
                }

                // Footer: freshness and unit alerts.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing
                    Controls.Label {
                        text: i18n("Updated %1", root.ago(root.client.lastUpdated))
                        color: root.colors.muted
                        font.pixelSize: Kirigami.Units.gridUnit * 0.52
                    }
                    Item { Layout.fillWidth: true }
                    Controls.Label {
                        visible: root.info.filterCleanStatus > 0
                        text: i18n("Clean filter")
                        color: root.colors.warn
                        font.pixelSize: Kirigami.Units.gridUnit * 0.52
                        font.weight: Font.DemiBold
                    }
                    Controls.Label {
                        visible: (root.info.airconErrorCode || "") !== ""
                        text: i18n("Unit error %1", root.info.airconErrorCode)
                        color: root.colors.bad
                        font.pixelSize: Kirigami.Units.gridUnit * 0.52
                        font.weight: Font.DemiBold
                    }
                }
                Item { Layout.fillHeight: true }
            }

            ScenesPage {
                deck: root
            }
        }

        Item { Layout.fillHeight: true; visible: root.ac === null }
    }

    // A failed command shows briefly over the footer.
    Rectangle {
        id: toast
        property string message: ""
        property bool isError: true
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Kirigami.Units.largeSpacing
        width: Math.min(parent.width - Kirigami.Units.gridUnit * 2, toastLabel.implicitWidth + Kirigami.Units.gridUnit)
        height: toastLabel.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: height / 2
        color: isError ? Qt.alpha(root.colors.bad, 0.92) : Qt.alpha(root.dark ? "#2a3240" : "#39424e", 0.94)
        opacity: message !== "" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
        Controls.Label {
            id: toastLabel
            anchors.centerIn: parent
            width: Math.min(implicitWidth, toast.parent.width - Kirigami.Units.gridUnit * 3)
            elide: Text.ElideRight
            text: toast.message
            color: "white"
            font.pixelSize: Kirigami.Units.gridUnit * 0.6
        }
        Timer { id: toastTimer; interval: 5000; onTriggered: toast.message = "" }
    }
    Connections {
        target: root.client
        function onCommandFailed(reason) {
            root.notify(i18n("Command failed: %1", reason), true);
        }
    }
}
