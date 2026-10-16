import QtQuick
import QtQuick.LocalStorage

// Keeps temperature samples in Plasma's offline storage (SQLite) so history
// survives restarts. Rows are keyed by scope (tablet and aircon), series and
// minute, so two widgets on the same tablet don't double up.
QtObject {
    id: store
    property string databaseName: "io.github.xiahongze.climatedeck"
    property var _db: null

    function _open() {
        if (_db)
            return _db;
        try {
            _db = LocalStorage.openDatabaseSync(databaseName, "", "Climate Deck temperature history", 4000000);
            _db.transaction(tx => tx.executeSql(
                "CREATE TABLE IF NOT EXISTS samples (scope TEXT NOT NULL, series TEXT NOT NULL, t INTEGER NOT NULL, v REAL NOT NULL, PRIMARY KEY (scope, series, t))"));
        } catch (e) {
            console.warn("Climate Deck: history storage unavailable:", e);
            _db = null;
        }
        return _db;
    }

    // Returns {series: [{t, v}, ...]} for samples at or after `since`.
    function load(scope, since) {
        const out = {};
        const db = _open();
        if (!db)
            return out;
        try {
            db.readTransaction(tx => {
                const rs = tx.executeSql("SELECT series, t, v FROM samples WHERE scope = ? AND t >= ? ORDER BY t", [scope, since]);
                for (let i = 0; i < rs.rows.length; i++) {
                    const row = rs.rows.item(i);
                    (out[row.series] = out[row.series] || []).push({ t: row.t, v: row.v });
                }
            });
        } catch (e) {
            console.warn("Climate Deck: could not read history:", e);
        }
        return out;
    }

    // Stores one sample per series and drops anything older than `before`.
    function append(scope, t, values, before) {
        const db = _open();
        if (!db)
            return;
        try {
            db.transaction(tx => {
                for (const series in values)
                    tx.executeSql("INSERT OR REPLACE INTO samples (scope, series, t, v) VALUES (?, ?, ?, ?)", [scope, series, t, values[series]]);
                tx.executeSql("DELETE FROM samples WHERE t < ?", [before]);
            });
        } catch (e) {
            console.warn("Climate Deck: could not save history:", e);
        }
    }
}
