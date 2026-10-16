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

    function test_myzone_rules() {
        verify(MyPlace.canChangeMyZone({ myZone: 4 }));
        verify(!MyPlace.canChangeMyZone({ myZone: 0 }));
        verify(!MyPlace.canChangeMyZone({ myZone: 4, quietNightModeIsRunning: true }));
        const zones = [{ key: "z01", hasSensor: true, sensorError: false }, { key: "z02", hasSensor: false, sensorError: false },
                       { key: "z03", hasSensor: true, sensorError: true }];
        compare(MyPlace.myZoneCandidates(zones).map(z => z.key).join(), "z01");
        const ac = { info: { myZone: 4 }, zones: { z01: { state: "close" }, z05: { state: "open" } } };
        compare(JSON.stringify(MyPlace.myZoneCommands(ac, 1)), '[{"info":{"myZone":1}},{"zones":{"z01":{"state":"open"}}}]');
        compare(JSON.stringify(MyPlace.myZoneCommands(ac, 5)), '[{"info":{"myZone":5}}]');
    }

    function test_scene_helpers() {
        compare(MyPlace.formatMinutes(285), "04:45");
        compare(MyPlace.formatMinutes(1439), "23:59");
        compare(MyPlace.stepMinutes(285, 1, 15), 300);
        compare(MyPlace.stepMinutes(0, -1, 15), 1425);
        compare(MyPlace.stepMinutes(1430, 1, 15), 0);
        compare(MyPlace.stepMinutes(17, 1, 15), 30);
        compare(MyPlace.stepMinutes(17, -1, 15), 15);
        const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
        const words = { everyDay: "Every day", weekdays: "Weekdays", weekends: "Weekends", noDays: "No days" };
        compare(MyPlace.daysLabel(127, names, words), "Every day");
        compare(MyPlace.daysLabel(62, names, words), "Weekdays");
        compare(MyPlace.daysLabel(65, names, words), "Weekends");
        compare(MyPlace.daysLabel(2 | 8 | 1, names, words), "Mon, Wed, Sun");
        verify(MyPlace.validSceneName("Morning"));
        verify(!MyPlace.validSceneName("   "));
        verify(!MyPlace.validSceneName("Thirteen chrs"));
        compare(MyPlace.commandUrl("10.0.0.2", "runScene", { id: "s10001" }),
                "http://10.0.0.2:2025/runScene?json=" + encodeURIComponent('{"id":"s10001"}'));
    }

    function test_scene_ids_and_order() {
        const view = { myScenes: { scenesOrder: ["s10002", "s10001"], scenes: {
            s10001: { id: "s10001" }, s10002: { id: "s10002" }, s10004: { id: "s10004" } } } };
        compare(MyPlace.sceneList(view).map(s => s.id).join(), "s10002,s10001,s10004");
        compare(MyPlace.nextSceneId(view), "s10003");
        const full = { myScenes: { scenes: {} } };
        for (let n = 1; n <= 12; n++)
            full.myScenes.scenes["s1" + ("000" + n).slice(-4)] = {};
        compare(MyPlace.nextSceneId(full), "");
    }

    function test_scene_draft_and_payload() {
        const ac = { info: { uid: "u", name: "AC", state: "off", mode: "cool", fan: "low", setTemp: 28, myZone: 4, freshAirStatus: "none" },
                     zones: { z04: { number: 4, state: "open", value: 100, setTemp: 24, motionConfig: 1, measuredTemp: 20, rssi: 40 } } };
        const d = MyPlace.draftFromCurrent("s10004", "Weekend", ac, "ac1");
        compare(d.aircons.ac1.info.state, "on");
        compare(d.aircons.ac1.zones.z04.measuredTemp, undefined);
        const p = MyPlace.scenePayload(d, "ac1");
        compare(p.id, "s10004");
        compare(p.name, "Weekend");
        compare(p.timerEnabled, false);
        compare(p.aircons.ac1.info.uid, "u");
        compare(p.aircons.ac1.zones.z04.setTemp, 24);
        compare(p.lights, undefined); // only what we manage
    }

    function test_countdown() {
        compare(MyPlace.countdownField({ state: "on" }), "countDownToOff");
        compare(MyPlace.countdownField({ state: "off" }), "countDownToOn");
        compare(MyPlace.countdownMinutes({ state: "on", countDownToOff: 45, countDownToOn: 9 }), 45);
        compare(MyPlace.countdownMinutes({ state: "off", countDownToOn: 0 }), 0);
        compare(JSON.stringify(MyPlace.countdownPayload({ state: "off" }, 900)), '{"info":{"countDownToOn":720}}');
        compare(JSON.stringify(MyPlace.countdownPayload({ state: "on" }, 0)), '{"info":{"countDownToOff":0}}');
    }

    function test_mycomfort() {
        compare(MyPlace.temperatureControl({}), "myzone");
        compare(MyPlace.temperatureControl({ climateControlModeEnabled: true }), "mytemp");
        compare(MyPlace.temperatureControl({ myAutoModeEnabled: true }), "myauto");
        compare(JSON.stringify(MyPlace.temperatureControlFields("myauto")), '{"climateControlModeEnabled":false,"myAutoModeEnabled":true}');
        compare(JSON.stringify(MyPlace.temperatureControlFields("myzone")), '{"climateControlModeEnabled":false,"myAutoModeEnabled":false}');
        compare(JSON.stringify(MyPlace.myAutoRange({})), '{"heat":20,"cool":24}');
        compare(JSON.stringify(MyPlace.myAutoRange({ myAutoHeatTargetTemp: 18, myAutoCoolTargetTemp: 26 })), '{"heat":18,"cool":26}');
        verify(MyPlace.myAutoRangeValid(20, 24));
        verify(!MyPlace.myAutoRangeValid(21, 24)); // under 4 apart
        verify(!MyPlace.myAutoRangeValid(15, 24));
        verify(!MyPlace.myAutoRangeValid(20, 33));
    }
}
