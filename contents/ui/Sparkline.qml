import QtQuick

// A small temperature trace. `points` is [{t, v}] oldest first, placed by time
// across `windowMs` ending at the newest point. Gaps longer than `gapMs` (the
// PC was off, or the tablet unreachable) break the line rather than bridging
// it. The scale follows the data's own min/max, with a floor so a flat
// reading draws as a calm line instead of noise.
Canvas {
    id: spark
    property var points: []
    property color color: "white"
    property real lineWidth: 1.5
    property real minSpan: 1.0
    property double windowMs: 4 * 3600 * 1000
    property double gapMs: 5 * 60 * 1000

    onPointsChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const pts = points || [];
        if (pts.length < 2 || width <= 0 || height <= 0)
            return;
        const values = pts.map(p => p.v);
        let lo = Math.min.apply(null, values), hi = Math.max.apply(null, values);
        if (hi - lo < minSpan) {
            const mid = (hi + lo) / 2;
            lo = mid - minSpan / 2;
            hi = mid + minSpan / 2;
        }
        const pad = lineWidth;
        const end = pts[pts.length - 1].t;
        const start = end - windowMs;
        const x = t => pad + (width - 2 * pad) * Math.max(0, t - start) / windowMs;
        const y = v => height - pad - (height - 2 * pad) * (v - lo) / (hi - lo);

        // Split into runs at gaps.
        const runs = [];
        let run = [];
        for (let i = 0; i < pts.length; i++) {
            if (run.length && pts[i].t - run[run.length - 1].t > gapMs) {
                runs.push(run);
                run = [];
            }
            run.push(pts[i]);
        }
        runs.push(run);

        const grad = ctx.createLinearGradient(0, 0, 0, height);
        grad.addColorStop(0, Qt.alpha(color, 0.28));
        grad.addColorStop(1, Qt.alpha(color, 0));
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.strokeStyle = color;
        ctx.fillStyle = grad;

        for (const r of runs) {
            if (r.length === 1) {
                ctx.beginPath();
                ctx.arc(x(r[0].t), y(r[0].v), lineWidth, 0, 2 * Math.PI);
                ctx.fillStyle = color;
                ctx.fill();
                ctx.fillStyle = grad;
                continue;
            }
            ctx.beginPath();
            ctx.moveTo(x(r[0].t), y(r[0].v));
            for (let i = 1; i < r.length; i++)
                ctx.lineTo(x(r[i].t), y(r[i].v));
            ctx.stroke();
            ctx.lineTo(x(r[r.length - 1].t), height);
            ctx.lineTo(x(r[0].t), height);
            ctx.closePath();
            ctx.fill();
        }
    }
}
