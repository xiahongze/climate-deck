import QtQuick
import QtTest
import "../contents/ui" as Deck

TestCase {
    id: suite
    name: "Setup"
    width: 560
    height: 760
    visible: true
    when: windowShown
    property string fixture: ""
    property var setup: null

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
        client.host = "";
        client.host = "192.168.1.50";
        client.poll();
        tablet.log = [];
        deck.page = 2;
        setup = findChild(deck, "setupPage");
        setup.showMeasuredOverride = undefined;
        waitForRendering(deck);
    }

    function test_rename_zone_only_when_changed() {
        const field = findChild(deck, "zoneName_z01");
        verify(field !== null);
        compare(field.text, "Living");
        field.editingFinished();
        compare(tablet.commands().length, 0);
        field.text = "  Kitchen ";
        field.editingFinished();
        compare(JSON.stringify(tablet.commands()), '[{"ac1":{"zones":{"z01":{"name":"Kitchen"}}}}]');
        compare(deck.zones[0].name, "Kitchen"); // pending overlay
    }

    function test_blank_name_reverts() {
        const field = findChild(deck, "zoneName_z02");
        field.text = "   ";
        field.editingFinished();
        compare(tablet.commands().length, 0);
        compare(field.text, "Lounge");
    }

    function test_rename_aircon() {
        const field = findChild(deck, "airconName");
        field.text = "Upstairs";
        field.editingFinished();
        compare(JSON.stringify(tablet.commands()), '[{"ac1":{"info":{"name":"Upstairs"}}}]');
    }

    function test_mycomfort_toggles() {
        mouseClick(findChild(deck, "quietNightToggle"));
        compare(JSON.stringify(tablet.commands()), '[{"ac1":{"info":{"quietNightModeEnabled":true}}}]');
        verify(deck.info.quietNightModeEnabled);
    }

    function test_temperature_control_sets_both_flags() {
        compare(setup.control, "myzone");
        findChild(deck, "temperatureControl").picked("myauto");
        compare(JSON.stringify(tablet.commands()), '[{"ac1":{"info":{"climateControlModeEnabled":false,"myAutoModeEnabled":true}}}]');
        compare(setup.control, "myauto");
        // MyAuto then appears as a mode on the climate page.
        verify(deck.info.myAutoModeEnabled);
    }

    function test_myauto_range_respects_gap() {
        compare(JSON.stringify(setup.range), '{"heat":20,"cool":24}');
        const heat = findChild(deck, "myAutoHeat");
        verify(!heat.canIncrease); // 21 to 24 is under 4 apart
        verify(heat.canDecrease);
        findChild(deck, "myAutoCool").increase();
        compare(JSON.stringify(tablet.commands()), '[{"ac1":{"info":{"myAutoHeatTargetTemp":20,"myAutoCoolTargetTemp":25}}}]');
    }

    function test_show_measured_uses_setMySystem() {
        verify(setup.showMeasured);
        mouseClick(findChild(deck, "showMeasuredToggle"));
        verify(!setup.showMeasured);
        const sent = tablet.log.filter(u => u.indexOf("/setMySystem?") >= 0);
        compare(sent.length, 1);
        compare(decodeURIComponent(sent[0].split("json=")[1]), '{"showMeasuredTemp":false}');
        client.poll();
        compare(setup.showMeasuredOverride, undefined);
        verify(!setup.showMeasured);
    }
}
