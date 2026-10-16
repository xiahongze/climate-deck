import QtQuick
import QtTest
import "../contents/ui" as Deck

TestCase {
    id: suite
    name: "DeckView"
    width: 560
    height: 640
    visible: true
    when: windowShown
    property string fixture: ""

    function i18n(text) {
        for (let i = 1; i < arguments.length; i++)
            text = text.replace("%" + i, arguments[i]);
        return text;
    }

    FakeTablet { id: tablet }
    Deck.Client {
        id: client
        active: false
        host: "192.168.1.50"
        transport: tablet.transport
    }
    Deck.DeckView { id: deck; anchors.fill: parent; client: client; themeMode: "dark" }

    function initTestCase() {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() { if (xhr.readyState === XMLHttpRequest.DONE) suite.fixture = xhr.responseText; };
        xhr.open("GET", Qt.resolvedUrl("fixtures/system.json"));
        xhr.send();
        tryVerify(() => fixture.length > 0);
    }

    function init() {
        tablet.load(fixture);
        tablet.reachable = true;
        client.host = "";
        client.host = "192.168.1.50";
        client.poll();
    }

    function test_summary() {
        compare(deck.zones.length, 6);
        compare(deck.house.count, 6);
        compare(deck.target, 24); // MyZone (Bed 1) target, not info.setTemp
        verify(isFinite(deck.outdoor));
        compare(deck.openCount, 3);
    }

    function test_power_tap_sends_command() {
        tablet.log = [];
        const power = findChild(deck, "powerButton");
        verify(power !== null);
        mouseClick(power);
        compare(JSON.stringify(tablet.commands()), '[{"ac1":{"info":{"state":"on"}}}]');
        verify(deck.unitOn);
    }

    function test_offline_dims_and_disables() {
        tablet.reachable = false;
        client.poll(); client.poll(); client.poll();
        verify(!deck.canControl);
        verify(deck.ac !== null);
        tablet.reachable = true;
        client.poll();
        verify(deck.canControl);
    }

    function test_set_myzone_opens_closed_zone() {
        tablet.log = [];
        const living = deck.zones.find(z => z.key === "z01");
        verify(!living.open);
        verify(deck.canChangeMyZone);
        compare(deck.myZoneChoices.length, 6);
        deck.setMyZone(living);
        compare(JSON.stringify(tablet.commands()), '[{"ac1":{"info":{"myZone":1}}},{"ac1":{"zones":{"z01":{"state":"open"}}}}]');
        // Target now follows the new MyZone.
        compare(deck.target, 25);
        verify(deck.zones.find(z => z.key === "z01").isMyZone);
        verify(findChild(deck, "myZoneChip").visible);
    }

    function test_quick_timer() {
        tablet.log = [];
        // Unit is off in the fixture, so presets set the turn-on countdown.
        const preset = findChild(deck, "timer60");
        verify(preset !== null && preset.visible);
        mouseClick(preset);
        compare(JSON.stringify(tablet.commands()), '[{"ac1":{"info":{"countDownToOn":60}}}]');
        compare(deck.duration(60), "1 h");
        compare(deck.duration(85), "1 h 25 min");
        compare(deck.duration(90, true), "1h 30m");
        // The tablet reports it counting down; Cancel sends 0.
        tablet.system.aircons.ac1.info.countDownToOn = 59;
        client.poll();
        const cancel = findChild(deck, "timerCancel");
        tryVerify(() => cancel.visible);
        waitForRendering(deck);
        deck.lastTimerTap = 0;
        tablet.log = [];
        mouseClick(cancel);
        compare(JSON.stringify(tablet.commands()), '[{"ac1":{"info":{"countDownToOn":0}}}]');
        // An immediate second click on whatever replaced Cancel is ignored.
        waitForRendering(deck);
        mouseClick(findChild(deck, "timer240"));
        compare(tablet.commands().length, 1);
    }
}
