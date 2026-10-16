.pragma library

// Pure helpers for the Advantage Air MyPlace / MyAir local API.
// The wall tablet serves HTTP on port 2025; see docs/API.md.

var PORT = 2025;
var MIN_TEMP = 16;
var MAX_TEMP = 32;
var DAMPER_STEP = 5;

function baseUrl(host) {
    var h = String(host || "").trim().replace(/^https?:\/\//, "").replace(/\/+$/, "");
    if (h.length === 0)
        return "";
    return "http://" + (h.indexOf(":") >= 0 ? h : h + ":" + PORT);
}

// Always a bare request: query parameters (uid, fcmToken, deviceName) make the
// tablet register the caller as a paired remote device.
function systemDataUrl(host) {
    var b = baseUrl(host);
    return b ? b + "/getSystemData" : "";
}

// One aircon per request: the tablet only reads the first key.
function setAirconUrl(host, acKey, payload) {
    var b = baseUrl(host);
    if (!b)
        return "";
    var body = {};
    body[acKey] = payload;
    return b + "/setAircon?json=" + encodeURIComponent(JSON.stringify(body));
}

// Returns {ok: true, data} for a usable snapshot, otherwise {ok: false, reason}.
// The tablet may answer with "{}", a plain-text banner or legacy XML when it
// has nothing to report; none of those should replace the last good state.
function parseSystem(text) {
    var data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return { ok: false, reason: "unexpected reply" };
    }
    if (!data || typeof data !== "object" || !data.aircons || Object.keys(data.aircons).length === 0)
        return { ok: false, reason: "no aircon data" };
    return { ok: true, data: data };
}

function parseAck(text) {
    try {
        var r = JSON.parse(text);
        if (r && r.ack === true)
            return { ok: true, reason: "" };
        return { ok: false, reason: (r && r.reason) || "command rejected" };
    } catch (e) {
        return { ok: false, reason: "unexpected reply" };
    }
}

function clampTemp(t) {
    return Math.max(MIN_TEMP, Math.min(MAX_TEMP, Math.round(Number(t))));
}

// Below the first step the app closes the zone instead of going to 0%.
function clampDamper(v) {
    var s = Math.round(Number(v) / DAMPER_STEP) * DAMPER_STEP;
    return Math.max(DAMPER_STEP, Math.min(100, s));
}

function zoneKey(n) {
    return "z" + (n < 10 ? "0" : "") + n;
}

function hasSensor(zone) {
    return Number(zone.type) !== 0;
}

function validMyZone(info) {
    var z = Number(info && info.myZone);
    return z >= 1 && z <= 10 ? z : 0;
}

// The unit target lives on the MyZone zone when one is set, as in the app.
function targetTemp(ac) {
    var mz = validMyZone(ac.info);
    if (mz) {
        var z = ac.zones && ac.zones[zoneKey(mz)];
        if (z && z.setTemp !== undefined)
            return Number(z.setTemp);
    }
    return Number(ac.info.setTemp);
}

function targetPayload(ac, temp) {
    var t = clampTemp(temp);
    var mz = validMyZone(ac.info);
    if (mz) {
        var zones = {};
        zones[zoneKey(mz)] = { setTemp: t };
        return { zones: zones };
    }
    return { info: { setTemp: t } };
}

// The dotted path of the field a payload edits, used for pending overlays.
function targetPath(ac) {
    var mz = validMyZone(ac.info);
    return mz ? "zones." + zoneKey(mz) + ".setTemp" : "info.setTemp";
}

// The app only offers a MyZone change while one is already set (1-10), and
// not during Quiet Night mode.
function canChangeMyZone(info) {
    return validMyZone(info) > 0 && !(info && info.quietNightModeIsRunning);
}

// MyZone runs off the zone's sensor, so only zones with a working one qualify.
function myZoneCandidates(zones) {
    return zones.filter(function (z) { return z.hasSensor && !z.sensorError; });
}

// Commands to make zone `n` the MyZone, in order. Like the app, a closed zone
// is opened in a second request once the switch is made.
function myZoneCommands(ac, n) {
    var commands = [{ info: { myZone: n } }];
    var z = ac.zones && ac.zones[zoneKey(n)];
    if (z && z.state !== "open") {
        var zones = {};
        zones[zoneKey(n)] = { state: "open" };
        commands.push({ zones: zones });
    }
    return commands;
}

function sortedZones(ac) {
    var zones = ac.zones || {};
    return Object.keys(zones).sort().map(function (k) {
        var z = zones[k];
        return {
            key: k,
            number: Number(z.number),
            name: String(z.name || k),
            measuredTemp: Number(z.measuredTemp),
            setTemp: Number(z.setTemp),
            open: z.state === "open",
            value: Number(z.value),
            hasSensor: hasSensor(z),
            sensorError: Number(z.error) !== 0,
            rssi: Number(z.rssi),
            isMyZone: Number(z.number) === validMyZone(ac.info)
        };
    });
}

// Zones without a working sensor are left out of the house figures.
function houseStats(zones) {
    var temps = zones.filter(function (z) {
        return z.hasSensor && !z.sensorError && z.measuredTemp > 0;
    }).map(function (z) { return z.measuredTemp; });
    if (temps.length === 0)
        return { average: NaN, min: NaN, max: NaN, count: 0 };
    var sum = temps.reduce(function (a, b) { return a + b; }, 0);
    return {
        average: sum / temps.length,
        min: Math.min.apply(null, temps),
        max: Math.max.apply(null, temps),
        count: temps.length
    };
}

function outdoorTemp(system) {
    if (!system || !system.isValidSuburbTemp)
        return NaN;
    var t = Number(system.suburbTemp);
    return isFinite(t) ? t : NaN;
}

// Fan "auto" maps to MyFan (autoAA) when the system has it switched on.
function autoFan(info) {
    return info && info.aaAutoFanModeEnabled ? "autoAA" : "auto";
}

function isAutoFan(fan) {
    return fan === "auto" || fan === "autoAA";
}

function modes(info) {
    var list = ["cool", "heat", "vent", "dry"];
    if (info && info.myAutoModeEnabled)
        list.push("myauto");
    return list;
}

// Dotted-path helpers so pending edits can overlay a polled snapshot.
function getPath(obj, path) {
    var parts = path.split(".");
    for (var i = 0; i < parts.length; i++) {
        if (obj === undefined || obj === null)
            return undefined;
        obj = obj[parts[i]];
    }
    return obj;
}

function setPath(obj, path, value) {
    var parts = path.split(".");
    for (var i = 0; i < parts.length - 1; i++) {
        if (typeof obj[parts[i]] !== "object" || obj[parts[i]] === null)
            obj[parts[i]] = {};
        obj = obj[parts[i]];
    }
    obj[parts[parts.length - 1]] = value;
}

// Leaf paths of a payload, e.g. {info: {mode: "cool"}} -> ["info.mode"].
function leafPaths(obj, prefix) {
    var out = [];
    Object.keys(obj).forEach(function (k) {
        var p = prefix ? prefix + "." + k : k;
        if (obj[k] !== null && typeof obj[k] === "object")
            out = out.concat(leafPaths(obj[k], p));
        else
            out.push(p);
    });
    return out;
}

function deepMerge(target, src) {
    Object.keys(src).forEach(function (k) {
        if (src[k] !== null && typeof src[k] === "object") {
            if (typeof target[k] !== "object" || target[k] === null)
                target[k] = {};
            deepMerge(target[k], src[k]);
        } else {
            target[k] = src[k];
        }
    });
    return target;
}

function clone(obj) {
    return JSON.parse(JSON.stringify(obj));
}

function formatTemp(t, digits) {
    if (!isFinite(t))
        return "–";
    return Number(t).toFixed(digits === undefined ? 1 : digits) + "°";
}
