# Changelog

## 0.2.0 — 2026-10-16

- Scenes page: run, create, edit and delete scenes, and switch their timers, with days, start and stop times, and the aircon settings each applies.
- Saves are confirmed from the next poll, so a dropped save (for example past 12 scenes) shows an error.
- docs/API.md documents scenes, checked against a live system.

## 0.1.0 — 2026-10-16

- Desktop deck for Advantage Air MyPlace / MyAir over the local network (port 2025), with no cloud.
- Inside average and range, outdoor temperature, link status and four hours of temperature history.
- Power, mode, fan and target temperature; the target follows the MyZone zone like the app.
- Per-zone cards: temperature colour strip, open/close, zone target or damper %, MyZone badge, sensor warnings, sparkline.
- One request at a time, debounced steppers, pending overlay against stale polls, offline after three failed polls.
- System/Light/Dark themes and adjustable background opacity.
- Protocol reference in docs/API.md.
- Temperature history is saved to local storage and survives restarts; gaps show as breaks in the trace.
- MyZone picker under the target temperature; a closed zone is opened when chosen, as in the app.
- Zone targets and dampers can be changed while the zone is closed.
