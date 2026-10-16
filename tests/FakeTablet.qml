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
            return done(true, 200, tablet.commandReply);
        };
        if (tablet.hold)
            tablet.held = tablet.held.concat([reply]);
        else
            reply();
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
