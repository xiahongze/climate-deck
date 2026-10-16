import QtQuick

// A small temperature trace. `points` is an array of numbers (oldest first);
// the line is scaled to its own min/max, with a floor so a flat reading still
// draws as a calm line instead of noise.
Canvas {
    id: spark
    property var points: []
    property color color: "white"
    property real lineWidth: 1.5
    property real minSpan: 1.0

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
        let lo = Math.min.apply(null, pts), hi = Math.max.apply(null, pts);
        if (hi - lo < minSpan) {
            const mid = (hi + lo) / 2;
            lo = mid - minSpan / 2;
            hi = mid + minSpan / 2;
        }
        const pad = lineWidth;
        const x = i => pad + (width - 2 * pad) * i / (pts.length - 1);
        const y = v => height - pad - (height - 2 * pad) * (v - lo) / (hi - lo);

        ctx.beginPath();
        ctx.moveTo(x(0), y(pts[0]));
        for (let i = 1; i < pts.length; i++)
            ctx.lineTo(x(i), y(pts[i]));
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.strokeStyle = color;
        ctx.stroke();

        ctx.lineTo(x(pts.length - 1), height);
        ctx.lineTo(x(0), height);
        ctx.closePath();
        const grad = ctx.createLinearGradient(0, 0, 0, height);
        grad.addColorStop(0, Qt.alpha(color, 0.28));
        grad.addColorStop(1, Qt.alpha(color, 0));
        ctx.fillStyle = grad;
        ctx.fill();
    }
}
