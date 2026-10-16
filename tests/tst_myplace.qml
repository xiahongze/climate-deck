import QtQuick
import QtTest
import "../contents/ui/myplace.js" as MyPlace

TestCase {
    name: "MyPlace"

    function test_urls() {
        compare(MyPlace.baseUrl(""), "");
        compare(MyPlace.baseUrl(" 192.168.1.50 "), "http://192.168.1.50:2025");
        compare(MyPlace.baseUrl("http://tablet.lan:8080/"), "http://tablet.lan:8080");
        compare(MyPlace.systemDataUrl("10.0.0.2"), "http://10.0.0.2:2025/getSystemData");
        const url = MyPlace.setAirconUrl("10.0.0.2", "ac1", { info: { state: "on" } });
        compare(url, "http://10.0.0.2:2025/setAircon?json=" + encodeURIComponent('{"ac1":{"info":{"state":"on"}}}'));
        verify(url.indexOf('"') < 0 && url.indexOf(" ") < 0);
    }

    function test_parseSystem_rejects_non_data() {
        verify(!MyPlace.parseSystem("{}").ok);
        verify(!MyPlace.parseSystem("Advantage Air v15.1548").ok);
        verify(!MyPlace.parseSystem("<iZS10.3><request>No longer supported</request></iZS10.3>").ok);
        verify(MyPlace.parseSystem('{"aircons":{"ac1":{"info":{},"zones":{}}}}').ok);
    }

    function test_parseAck() {
        verify(MyPlace.parseAck('{"request":"setAircon","ack":true}').ok);
        const bad = MyPlace.parseAck('{"request":"setAircon","reason":"Valid JSON, but nothing useful there.","ack":false}');
        verify(!bad.ok);
        compare(bad.reason, "Valid JSON, but nothing useful there.");
        verify(!MyPlace.parseAck("Advantage Air v15.1548").ok);
    }

    function test_clamps() {
        compare(MyPlace.clampTemp(12), 16);
        compare(MyPlace.clampTemp(40), 32);
        compare(MyPlace.clampTemp(23.6), 24);
        compare(MyPlace.clampDamper(0), 5);
        compare(MyPlace.clampDamper(57), 55);
        compare(MyPlace.clampDamper(120), 100);
    }

    function test_target_follows_myzone() {
        const ac = { info: { myZone: 4, setTemp: 28 }, zones: { z04: { setTemp: 24 } } };
        compare(MyPlace.targetTemp(ac), 24);
        compare(JSON.stringify(MyPlace.targetPayload(ac, 25)), '{"zones":{"z04":{"setTemp":25}}}');
        compare(MyPlace.targetPath(ac), "zones.z04.setTemp");
        const plain = { info: { myZone: 0, setTemp: 22 }, zones: {} };
        compare(MyPlace.targetTemp(plain), 22);
        compare(JSON.stringify(MyPlace.targetPayload(plain, 40)), '{"info":{"setTemp":32}}');
    }

    function test_house_stats_skip_unsensed_zones() {
        const zones = MyPlace.sortedZones({ info: { myZone: 1 }, zones: {
            z02: { number: 2, name: "B", type: 1, error: 0, measuredTemp: 22, state: "open" },
            z01: { number: 1, name: "A", type: 1, error: 0, measuredTemp: 20, state: "close" },
            z03: { number: 3, name: "C", type: 0, error: 0, measuredTemp: 0, state: "open" },
            z04: { number: 4, name: "D", type: 1, error: 2, measuredTemp: 35, state: "open" }
        } });
        compare(zones.map(z => z.key).join(), "z01,z02,z03,z04");
        verify(zones[0].isMyZone);
        verify(!zones[2].hasSensor);
        const s = MyPlace.houseStats(zones);
        compare(s.count, 2);
        compare(s.average, 21);
        compare(s.min, 20);
        compare(s.max, 22);
    }

    function test_outdoor_needs_valid_flag() {
        verify(isNaN(MyPlace.outdoorTemp({ isValidSuburbTemp: false, suburbTemp: 6.5 })));
        compare(MyPlace.outdoorTemp({ isValidSuburbTemp: true, suburbTemp: 6.5 }), 6.5);
    }

    function test_fan_and_modes() {
        compare(MyPlace.autoFan({ aaAutoFanModeEnabled: true }), "autoAA");
        compare(MyPlace.autoFan({ aaAutoFanModeEnabled: false }), "auto");
        compare(MyPlace.modes({}).join(), "cool,heat,vent,dry");
        compare(MyPlace.modes({ myAutoModeEnabled: true }).join(), "cool,heat,vent,dry,myauto");
    }

    function test_paths() {
        compare(MyPlace.leafPaths({ info: { mode: "cool" }, zones: { z01: { state: "open", setTemp: 22 } } }, "").join(),
                "info.mode,zones.z01.state,zones.z01.setTemp");
        const o = {};
        MyPlace.setPath(o, "zones.z01.state", "open");
        compare(MyPlace.getPath(o, "zones.z01.state"), "open");
        compare(MyPlace.getPath(o, "zones.z09.state"), undefined);
    }
}
