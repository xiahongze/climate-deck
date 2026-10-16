import QtQuick
import QtTest
import "../contents/ui" as Deck

TestCase {
    id: suite
    name: "Client"
    property string fixture: ""
    property double fakeNow: 1000000

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
        debounceMs: 200
        transport: tablet.transport
        clock: function() { return suite.fakeNow; }
    }
    SignalSpy { id: failed; target: client; signalName: "commandFailed" }

    function initTestCase() {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() { if (xhr.readyState === XMLHttpRequest.DONE) suite.fixture = xhr.responseText; };
        xhr.open("GET", Qt.resolvedUrl("fixtures/system.json"));
        xhr.send();
        tryVerify(() => fixture.length > 0);
    }

    function init() {
        tablet.load(fixture);
        tablet.log = [];
        tablet.pollReply = "";
        tablet.reachable = true;
        tablet.hold = false;
        tablet.commandReply = '{"request":"setAircon","ack":true}';
        failed.clear();
        fakeNow += 3600000;
        client.host = "";
        client.host = "192.168.1.50";
        client.poll();
        verify(client.online);
        tablet.log = [];
    }

    function test_poll_is_bare_request() {
        client.poll();
        compare(tablet.log[0], "http://192.168.1.50:2025/getSystemData");
        compare(client.aircon.info.mode, "cool");
        compare(Object.keys(client.aircon.zones).length, 6);
    }

    function test_bad_replies_keep_last_state() {
        for (const reply of ["{}", "Advantage Air v15.1548", "<iZS10.3></iZS10.3>"]) {
            tablet.pollReply = reply;
            client.poll();
            verify(client.view !== null);
            compare(client.aircon.info.name, "AC");
        }
        compare(client.failures, 3);
        verify(!client.online);
        tablet.pollReply = "";
        client.poll();
        verify(client.online);
        compare(client.failures, 0);
    }

    function test_offline_after_three_failures() {
        tablet.reachable = false;
        client.poll();
        client.poll();
        verify(client.online);
        verify(client.stale);
        client.poll();
        verify(!client.online);
    }

    function test_command_shows_immediately_and_sends() {
        client.command({ info: { state: "on" } }, 0);
        compare(client.aircon.info.state, "on");
        compare(JSON.stringify(tablet.commands()), '[{"ac1":{"info":{"state":"on"}}}]');
    }

    function test_pending_survives_stale_poll() {
        client.command({ info: { mode: "heat" } }, 0);
        client.poll(); // tablet hasn't applied it yet
        compare(client.aircon.info.mode, "heat");
        tablet.system.aircons.ac1.info.mode = "heat";
        client.poll();
        compare(client.pendingValue("info.mode"), undefined);
        fakeNow += 60000;
        tablet.system.aircons.ac1.info.mode = "cool";
        client.poll();
        compare(client.aircon.info.mode, "cool");
    }

    function test_pending_expires() {
        client.command({ info: { fan: "high" } }, 0);
        fakeNow += client.pendingMs + 1;
        client.poll();
        compare(client.aircon.info.fan, "low");
    }

    function test_debounce_merges_steps() {
        client.command({ zones: { z04: { setTemp: 25 } } }, 200);
        client.command({ zones: { z04: { setTemp: 26 } } }, 200);
        client.command({ zones: { z05: { state: "close" } } }, 200);
        compare(client.aircon.zones.z04.setTemp, 26);
        compare(tablet.commands().length, 0);
        tryVerify(() => tablet.commands().length === 1, 2000);
        compare(JSON.stringify(tablet.commands()[0]), '{"ac1":{"zones":{"z04":{"setTemp":26},"z05":{"state":"close"}}}}');
    }

    function test_one_request_at_a_time() {
        tablet.hold = true;
        client.command({ info: { state: "on" } }, 0);
        client.command({ info: { fan: "high" } }, 0);
        client.poll();
        compare(tablet.log.length, 1);
        tablet.release();
        compare(tablet.commands().length, 2);
        compare(JSON.stringify(tablet.commands()[1]), '{"ac1":{"info":{"fan":"high"}}}');
        tablet.release();
    }

    function test_rejected_command_rolls_back() {
        tablet.commandReply = '{"request":"setAircon","reason":"Please check Touch screen","ack":false}';
        client.command({ info: { state: "on" } }, 0);
        compare(client.aircon.info.state, "off");
        compare(failed.count, 1);
        compare(failed.signalArguments[0][0], "Please check Touch screen");
    }

    function test_history_samples_per_interval() {
        client.history = {};
        client._lastSample = 0;
        client.poll();
        client.poll();
        compare(client.history.z01.length, 1);
        fakeNow += client.historySeconds * 1000;
        client.poll();
        compare(client.history.z01.length, 2);
        compare(client.history.house.length, 2);
    }
}
