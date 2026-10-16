import QtQuick
import QtTest
import "../contents/ui" as Deck

TestCase {
    id: suite
    name: "History"
    property string fixture: ""
    property double fakeNow: Date.UTC(2026, 9, 16, 8, 0)

    function i18n(text) { return text; }

    FakeTablet { id: tablet }
    Deck.HistoryStore { id: store; databaseName: "climatedeck-test" }
    Component {
        id: clientComponent
        Deck.Client {
            active: false
            host: "192.168.1.50"
            transport: tablet.transport
            clock: function() { return suite.fakeNow; }
        }
    }

    function initTestCase() {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() { if (xhr.readyState === XMLHttpRequest.DONE) suite.fixture = xhr.responseText; };
        xhr.open("GET", Qt.resolvedUrl("fixtures/system.json"));
        xhr.send();
        tryVerify(() => fixture.length > 0);
        tablet.load(fixture);
    }

    function test_store_roundtrip() {
        store.append("a", 1000, { z01: 20.5, house: 21 }, 0);
        store.append("a", 1000, { z01: 20.7 }, 0); // same slot replaces
        store.append("a", 2000, { z01: 21 }, 0);
        store.append("b", 2000, { z01: 99 }, 0);
        const loaded = store.load("a", 0);
        compare(JSON.stringify(loaded.z01), '[{"t":1000,"v":20.7},{"t":2000,"v":21}]');
        compare(loaded.house.length, 1);
        compare(store.load("a", 1500).z01.length, 1);
        store.append("a", 3000, { z01: 22 }, 2500); // prunes everything before 2500
        compare(store.load("a", 0).z01.length, 1);
        compare(store.load("b", 0).z01, undefined);
    }

    function test_history_survives_restart() {
        const first = createTemporaryObject(clientComponent, suite, { store: store });
        for (let i = 0; i < 5; i++) {
            first.poll();
            fakeNow += 60000;
        }
        compare(first.history.z01.length, 5);
        first.destroy();

        fakeNow += 10 * 60000; // Plasma restarted ten minutes later
        const second = createTemporaryObject(clientComponent, suite, { store: store });
        compare(second.history.z01.length, 5);
        compare(second.history.house.length, 5);
        second.poll();
        compare(second.history.z01.length, 6);
        // The pause shows as a gap, not a bridged line.
        const pts = second.history.z01;
        verify(pts[5].t - pts[4].t > second.historyGapMs);
    }

    function test_old_samples_expire() {
        const c = createTemporaryObject(clientComponent, suite, { store: store });
        c.poll();
        verify(c.history.z01.length > 0);
        fakeNow += c.historyWindowMs + 60000;
        const later = createTemporaryObject(clientComponent, suite, { store: store });
        compare(later.history.z01, undefined);
        later.poll();
        compare(later.history.z01.length, 1);
    }
}
