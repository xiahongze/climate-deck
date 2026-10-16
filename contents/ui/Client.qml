import QtQuick
import "myplace.js" as MyPlace

// Talks to the MyPlace wall tablet. Polls and commands share one request
// lane because the tablet is slow and the app itself never runs requests in
// parallel. Edits show immediately through a pending overlay until a poll
// confirms them, so controls don't snap back while the unit catches up.
Item {
    id: client
    visible: false

    property string host: ""
    property string acKey: "ac1"
    property int pollSeconds: 10
    property int timeoutMs: 5000
    property bool active: true
    property int offlineAfter: 3
    property int pendingMs: 12000
    property int debounceMs: 600
    property int historySeconds: 60
    property int historyLength: 240
    // function(url, timeoutMs, done(ok, status, text)); tests replace it.
    property var transport: defaultTransport
    property var clock: function() { return Date.now(); }

    property var snapshot: null
    property var view: null
    readonly property var aircon: view && view.aircons ? view.aircons[acKey] || null : null
    property double lastUpdated: 0
    property int failures: 0
    readonly property bool configured: MyPlace.baseUrl(host) !== ""
    readonly property bool online: lastUpdated > 0 && failures < offlineAfter
    readonly property bool stale: lastUpdated > 0 && failures > 0
    property string lastError: ""
    // {series: [{t, v}]}; "house" is the inside average.
    property var history: ({})
    // Optional persistence: {load(scope, since), append(scope, t, values, before)}.
    property var store: null

    signal commandFailed(string reason)
    // After every poll that brought fresh data.
    signal refreshed()

    property var _pending: ({})
    property var _queue: []
    property var _staged: null
    property bool _busy: false
    property var _xhr: null
    property double _lastSample: 0

    function poll() {
        const url = MyPlace.systemDataUrl(host);
        if (!url || _busy)
            return;
        _busy = true;
        transport(url, timeoutMs, _onPoll);
    }

    // Applies `payload` (e.g. {info: {mode: "heat"}}) to the shown state now
    // and sends it, after `delay` ms if more edits may follow. An `alone`
    // command goes in its own request, in order, never merged with others.
    function command(payload, delay, alone) {
        const until = clock() + pendingMs;
        const pending = Object.assign({}, _pending);
        for (const path of MyPlace.leafPaths(payload, ""))
            pending[path] = { value: MyPlace.getPath(payload, path), expires: until };
        _pending = pending;
        _rebuild();
        if (delay > 0 && !alone) {
            _staged = MyPlace.deepMerge(_staged || {}, payload);
            debounce.interval = delay;
            debounce.restart();
        } else {
            _queue.push({ payload: payload, alone: Boolean(alone) });
            _pump();
        }
    }

    // Sends `command` (e.g. "setScene") with a json body through the same
    // queue, calls done(ok, reason), then re-reads the tablet.
    function request(command, obj, done) {
        _queue.push({ command: command, payload: obj, alone: true, done: done || null });
        _pump();
    }

    function pendingValue(path) {
        return _pending[path] ? _pending[path].value : undefined;
    }

    function _flushStaged() {
        if (!_staged)
            return;
        _queue.push({ payload: _staged, alone: false });
        _staged = null;
        _pump();
    }

    function _pump() {
        if (_busy || _queue.length === 0)
            return;
        // Queued edits target the same aircon, so consecutive ones can go as
        // one request; `alone` commands keep their own request and order.
        const first = _queue.shift();
        if (first.command) {
            const url = MyPlace.commandUrl(host, first.command, first.payload);
            if (!url)
                return;
            _busy = true;
            transport(url, timeoutMs, function(ok, status, text) {
                _busy = false;
                const ack = ok && status === 200 ? MyPlace.parseAck(text) : { ok: false, reason: i18n("No reply from the tablet") };
                if (!ack.ok)
                    lastError = ack.reason;
                if (first.done)
                    first.done(ack.ok, ack.reason);
                followUp.restart();
                _pump();
            });
            return;
        }
        const payload = MyPlace.clone(first.payload);
        while (!first.alone && _queue.length && !_queue[0].alone)
            MyPlace.deepMerge(payload, _queue.shift().payload);
        const url = MyPlace.setAirconUrl(host, acKey, payload);
        if (!url)
            return;
        _busy = true;
        transport(url, timeoutMs, function(ok, status, text) {
            _busy = false;
            const ack = ok && status === 200 ? MyPlace.parseAck(text) : { ok: false, reason: i18n("No reply from the tablet") };
            if (!ack.ok) {
                const pending = Object.assign({}, _pending);
                for (const path of MyPlace.leafPaths(payload, ""))
                    delete pending[path];
                _pending = pending;
                lastError = ack.reason;
                _rebuild();
                commandFailed(ack.reason);
            }
            followUp.restart();
            _pump();
        });
    }

    function _onPoll(ok, status, text) {
        _busy = false;
        const result = ok && status === 200 ? MyPlace.parseSystem(text) : { ok: false, reason: i18n("Tablet not reachable") };
        if (result.ok) {
            snapshot = result.data;
            lastUpdated = clock();
            failures = 0;
            lastError = "";
            _reconcile();
            _record();
            _rebuild();
            refreshed();
        } else {
            failures += 1;
            lastError = result.reason;
        }
        _pump();
    }

    function _reconcile() {
        const ac = snapshot.aircons[acKey];
        const now = clock();
        const pending = {};
        for (const path in _pending) {
            const p = _pending[path];
            const actual = ac ? MyPlace.getPath(ac, path) : undefined;
            if (now < p.expires && String(actual) !== String(p.value))
                pending[path] = p;
        }
        _pending = pending;
    }

    function _rebuild() {
        if (!snapshot) {
            view = null;
            return;
        }
        const v = MyPlace.clone(snapshot);
        const ac = v.aircons[acKey];
        if (ac) {
            for (const path in _pending)
                MyPlace.setPath(ac, path, _pending[path].value);
        }
        view = v;
    }

    readonly property double historyWindowMs: historySeconds * historyLength * 1000
    // A trace breaks where samples are further apart than this.
    readonly property double historyGapMs: Math.max(historySeconds, pollSeconds) * 3000
    readonly property string historyScope: MyPlace.baseUrl(host) + "/" + acKey

    // One sample per series every `historySeconds`, as {t, v}, kept for
    // `historyLength` intervals and mirrored to `store` when one is set.
    function _record() {
        const now = clock();
        if (_lastSample > 0 && now - _lastSample < historySeconds * 1000)
            return;
        const ac = snapshot.aircons[acKey];
        if (!ac)
            return;
        // Aligned to the interval so restarts and other widgets reuse the slot.
        const t = Math.floor(now / (historySeconds * 1000)) * historySeconds * 1000;
        _lastSample = now;
        const values = {};
        const zones = MyPlace.sortedZones(ac);
        for (const z of zones) {
            if (z.hasSensor && !z.sensorError)
                values[z.key] = z.measuredTemp;
        }
        const house = MyPlace.houseStats(zones);
        if (house.count > 0)
            values.house = Math.round(house.average * 100) / 100;
        const cutoff = t - historyWindowMs;
        const next = {};
        for (const key in history) {
            const kept = history[key].filter(p => p.t > cutoff && p.t !== t);
            if (kept.length)
                next[key] = kept;
        }
        for (const key in values)
            next[key] = (next[key] || []).concat([{ t: t, v: values[key] }]);
        history = next;
        if (store)
            store.append(historyScope, t, values, cutoff);
    }

    function _loadHistory() {
        history = {};
        _lastSample = 0;
        if (!store || !configured)
            return;
        const loaded = store.load(historyScope, clock() - historyWindowMs);
        let last = 0;
        for (const key in loaded)
            last = Math.max(last, loaded[key][loaded[key].length - 1].t);
        history = loaded;
        _lastSample = last;
    }

    function defaultTransport(url, timeout, done) {
        const xhr = new XMLHttpRequest();
        let finished = false;
        const finish = (ok, status, text) => {
            if (finished)
                return;
            finished = true;
            watchdog.stop();
            _xhr = null;
            done(ok, status, text);
        };
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                finish(xhr.status > 0, xhr.status, xhr.responseText);
        };
        xhr.open("GET", url);
        // Without "Android" or "Darwin" here the tablet doesn't copy each
        // command to its cloud event log.
        xhr.setRequestHeader("User-Agent", "ClimateDeck/0.1 (KDE Plasma)");
        _xhr = { request: xhr, finish: finish };
        // Qt's XMLHttpRequest ignores .timeout, so a timer aborts instead.
        watchdog.interval = timeout;
        watchdog.restart();
        xhr.send();
    }

    Timer {
        id: watchdog
        repeat: false
        onTriggered: {
            const pending = client._xhr;
            if (!pending)
                return;
            pending.request.abort();
            pending.finish(false, 0, "");
        }
    }
    Timer {
        id: pollTimer
        interval: Math.max(3, client.pollSeconds) * 1000
        repeat: true
        running: client.active && client.configured
        triggeredOnStart: true
        onTriggered: client.poll()
    }
    Timer {
        id: debounce
        repeat: false
        onTriggered: client._flushStaged()
    }
    // Re-read soon after a command so the confirmed state shows quickly.
    Timer {
        id: followUp
        interval: 1500
        repeat: false
        onTriggered: client.poll()
    }

    onHostChanged: {
        snapshot = null;
        view = null;
        lastUpdated = 0;
        failures = 0;
        _pending = {};
        _loadHistory();
        if (configured && active)
            pollTimer.restart();
    }
    onAcKeyChanged: {
        _loadHistory();
        _rebuild();
    }
    onStoreChanged: _loadHistory()
}
