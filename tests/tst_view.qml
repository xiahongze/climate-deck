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
        tablet.load(fixture);
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
}
