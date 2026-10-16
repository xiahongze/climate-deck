import QtQuick
import QtTest
import "../contents/ui" as Deck
import "../tests" as Fixtures

// `make screenshots`: renders the widget over a stand-in wallpaper so the
// translucent card is visible, from the redacted fixture.
TestCase {
    id: preview
    name: "Screenshots"
    width: 600
    height: 660
    visible: true
    when: windowShown
    property string fixture: ""
    property double fakeNow: Date.UTC(2026, 9, 16, 10, 0)

    function i18n(text) {
        for (let i = 1; i < arguments.length; i++)
            text = text.replace("%" + i, arguments[i]);
        return text;
    }

    Item {
        id: stage
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: wallpaper.dark ? "#1b2a4a" : "#9cc3e8" }
                GradientStop { position: 0.55; color: wallpaper.dark ? "#3b2f5c" : "#e9c7d9" }
                GradientStop { position: 1; color: wallpaper.dark ? "#0e3b3f" : "#f3e1b8" }
            }
            QtObject { id: wallpaper; property bool dark: deck.themeMode === "dark" }
        }
        Repeater {
            model: 3
            Rectangle {
                required property int index
                x: [-60, 380, 120][index]; y: [80, 380, 600][index]
                width: [300, 260, 220][index]; height: width; radius: width / 2
                color: wallpaper.dark ? ["#4f7cff", "#ff7b54", "#2fd3a8"][index] : ["#ffffff", "#ff9e7a", "#7fd6ff"][index]
                opacity: 0.35
            }
        }
        Deck.DeckView {
            id: deck
            anchors.fill: parent
            anchors.margins: 32
            client: client
            clockSource: function() { return preview.fakeNow + 12000; }
        }
    }

    Fixtures.FakeTablet { id: tablet }
    Deck.Client {
        id: client
        active: false
        host: "192.168.1.50"
        transport: tablet.transport
        clock: function() { return preview.fakeNow; }
    }

    function initTestCase() {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() { if (xhr.readyState === XMLHttpRequest.DONE) preview.fixture = xhr.responseText; };
        xhr.open("GET", Qt.resolvedUrl("../tests/fixtures/system.json"));
        xhr.send();
        tryVerify(() => fixture.length > 0);
        tablet.load(fixture);
        // A few hours of gently drifting readings for the sparklines.
        const base = {};
        for (const k in tablet.system.aircons.ac1.zones)
            base[k] = tablet.system.aircons.ac1.zones[k].measuredTemp;
        for (let i = 0; i < 90; i++) {
            preview.fakeNow += 120000;
            for (const k in base)
                tablet.system.aircons.ac1.zones[k].measuredTemp = Math.round((base[k] - 1.2 + 1.2 * i / 90 + 0.25 * Math.sin(i / 7 + base[k])) * 10) / 10;
            client.poll();
        }
    }

    function test_capture() {
        for (const theme of ["dark", "light"]) {
            deck.themeMode = theme;
            save("climate-deck-" + theme);
        }
        // Running in heat, as during a winter evening.
        const ac = tablet.system.aircons.ac1;
        ac.info.state = "on";
        ac.info.mode = "heat";
        ac.info.fan = "autoAA";
        ac.zones.z03.state = "open";
        ac.info.countDownToOff = 85;
        client.poll();
        deck.themeMode = "dark";
        save("climate-deck-heating");

        // Scenes page, with the morning warm-up on a timer.
        ac.info.state = "off";
        ac.info.countDownToOff = 0;
        tablet.system.myScenes.scenes.s10002.timerEnabled = true;
        client.poll();
        deck.page = 1;
        save("climate-deck-scenes");
        const scenes = findChild(deck, "scenesPage");
        scenes.startEdit(scenes.scenes[1]);
        save("climate-deck-scene-editor");
        scenes.closeEditor();
        deck.page = 2;
        save("climate-deck-setup");
        deck.page = 0;
    }

    function save(name) {
        wait(400);
        grabImage(stage).save(Qt.resolvedUrl("../docs/screenshots/" + name + ".png").toString().replace("file://", ""));
    }
}
