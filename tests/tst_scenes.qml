import QtQuick
import QtTest
import "../contents/ui" as Deck

TestCase {
    id: suite
    name: "Scenes"
    width: 560
    height: 700
    visible: true
    when: windowShown
    property string fixture: ""
    property var scenes: null

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
        tablet.sceneLimit = 12;
        client.host = "";
        client.host = "192.168.1.50";
        client.poll();
        tablet.log = [];
        deck.page = 1;
        scenes = findChild(deck, "scenesPage");
        scenes.closeEditor();
        scenes.timerOverride = {};
        wait(50);
    }

    function sent() {
        return tablet.log.filter(u => u.indexOf("Scene?") >= 0).map(u => ({
            command: u.split("/").pop().split("?")[0],
            body: JSON.parse(decodeURIComponent(u.split("json=")[1]))
        }));
    }

    function test_lists_scenes_in_order() {
        compare(scenes.scenes.map(s => s.name).join(), "Sleep,Morning,Evening");
        verify(scenes.canAdd);
    }

    function test_run_scene() {
        scenes.run(scenes.scenes[1]);
        compare(JSON.stringify(sent()), '[{"command":"runScene","body":{"id":"s10002"}}]');
        client.poll();
        compare(client.aircon.info.state, "on");
        compare(client.aircon.info.mode, "heat");
    }

    function test_delete_needs_confirmation() {
        const card = findChild(deck, "deleteButton");
        verify(card !== null);
        mouseClick(card);
        compare(sent().length, 0);
        mouseClick(card);
        compare(JSON.stringify(sent()[0]), '{"command":"setScene","body":{"id":"s10001","name":""}}');
        client.poll();
        compare(scenes.scenes.map(s => s.name).join(), "Morning,Evening");
    }

    function test_timer_toggle_is_optimistic_and_partial() {
        const s = scenes.scenes[0];
        verify(!s.timerEnabled);
        scenes.setTimer(s, true);
        compare(scenes.timerOverride[s.id], true);
        compare(JSON.stringify(sent()[0].body), '{"id":"s10001","timerEnabled":true}');
        client.poll();
        verify(scenes.scenes[0].timerEnabled);
        compare(scenes.timerOverride[s.id], undefined);
        compare(scenes.scenes[0].name, "Sleep"); // other fields kept
    }

    function test_create_scene_confirms_from_poll() {
        scenes.startNew();
        verify(scenes.draft !== null);
        compare(scenes.draft.id, "s10004");
        const d = JSON.parse(JSON.stringify(scenes.draft));
        d.name = "Weekend";
        d.activeDays = 65;
        d.timerEnabled = true;
        d.startTime = 540;
        scenes.draft = d;
        scenes.save(scenes.draft);
        verify(scenes.saving);
        const body = sent()[0].body;
        compare(body.id, "s10004");
        compare(body.activeDays, 65);
        compare(body.aircons.ac1.info.state, "on");
        compare(Object.keys(body.aircons.ac1.zones).length, 6);
        client.poll();
        compare(scenes.draft, null);
        compare(scenes.scenes.map(s => s.name).join(), "Sleep,Morning,Evening,Weekend");
    }

    function test_edit_keeps_identity() {
        scenes.startEdit(scenes.scenes[1]);
        const d = JSON.parse(JSON.stringify(scenes.draft));
        d.startTime = 300;
        d.aircons.ac1.zones.z04.setTemp = 19;
        scenes.draft = d;
        scenes.save(scenes.draft);
        client.poll();
        compare(scenes.draft, null);
        const m = scenes.scenes[1];
        compare(m.id, "s10002");
        compare(m.name, "Morning");
        compare(m.startTime, 300);
        compare(m.aircons.ac1.zones.z04.setTemp, 19);
    }

    function test_limit_is_reported() {
        tablet.sceneLimit = 3;
        scenes.startNew();
        const d = JSON.parse(JSON.stringify(scenes.draft));
        d.name = "Extra";
        scenes.draft = d;
        scenes.save(scenes.draft);
        client.poll();
        verify(scenes.saving);
        client.poll();
        verify(!scenes.saving);
        verify(scenes.editorError.indexOf("12") >= 0);
        verify(scenes.draft !== null);
    }
}
