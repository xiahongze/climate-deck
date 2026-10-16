import QtQuick

// Stands in for the wall tablet: records every URL and answers from memory.
QtObject {
    id: tablet
    property var system: null
    property var log: []
    property string pollReply: ""
    property string commandReply: '{"request":"setAircon","ack":true}'
    property bool reachable: true
    property bool hold: false
    property var held: []

    function load(text) { system = JSON.parse(text); }

    function transport(url, timeout, done) {
        tablet.log = tablet.log.concat([url]);
        const reply = () => {
            if (!tablet.reachable)
                return done(false, 0, "");
            if (url.indexOf("/getSystemData") >= 0)
                return done(true, 200, tablet.pollReply || JSON.stringify(tablet.system));
            if (url.indexOf("/setScene?") >= 0 || url.indexOf("/runScene?") >= 0)
                return done(true, 200, tablet.scene(url));
            return done(true, 200, tablet.commandReply);
        };
        if (tablet.hold)
            tablet.held = tablet.held.concat([reply]);
        else
            reply();
    }

    // Mirrors the tablet: "" name deletes, missing fields are kept, maps are
    // replaced whole, and a save past the limit is silently dropped but acked.
    property int sceneLimit: 12
    function scene(url) {
        const cmd = url.indexOf("/runScene?") >= 0 ? "runScene" : "setScene";
        const body = JSON.parse(decodeURIComponent(url.split("json=")[1]));
        const store = system.myScenes;
        if (cmd === "runScene") {
            const sc = store.scenes[body.id];
            if (!sc)
                return '{"request":"runScene","reason":"unknown id","ack":false}';
            for (const k in sc.aircons) {
                Object.assign(system.aircons[k].info, sc.aircons[k].info);
                for (const z in sc.aircons[k].zones)
                    Object.assign(system.aircons[k].zones[z], sc.aircons[k].zones[z]);
            }
            return '{"request":"runScene","ack":true}';
        }
        if (body.name === "") {
            delete store.scenes[body.id];
            store.scenesOrder = store.scenesOrder.filter(id => id !== body.id);
        } else if (store.scenes[body.id]) {
            Object.assign(store.scenes[body.id], body);
        } else if (store.scenesOrder.length < sceneLimit) {
            store.scenes[body.id] = body;
            store.scenesOrder.push(body.id);
        }
        return '{"request":"setScene","ack":true}';
    }

    function release() {
        const pending = held;
        held = [];
        for (const r of pending)
            r();
    }

    function commands() {
        return log.filter(u => u.indexOf("/setAircon") >= 0).map(u => JSON.parse(decodeURIComponent(u.split("json=")[1])));
    }
}
