# MyPlace / MyAir local API

This documents the LAN API of the Advantage Air **MyPlace** (also sold as MyAir and e-zone) wall touch screen. It is what Climate Deck uses.

**How it was worked out.** The Android app `com.air.advantage.myair5` v15.1548 was decompiled with jadx, and the results were checked against a live MyPlace system (tablet app `aaServiceRev` 14.150, model `PIC8GS12`).

**Confidence markers.**
- **Verified** means the behaviour was observed on the live system.
- **Code** means it was read from the decompiled app but not exercised live.
- **Inferred** means it is an educated guess.

The same APK runs on the wall tablet and on phones. On the tablet it starts an embedded NanoHTTPD server (`com.air.advantage.webserver.WebServer`). On phones it acts as a client of that server when it is on the same Wi-Fi. When it isn't, it falls back to Firebase (Firestore plus Cloud Functions at `backendv1-*.run.app`).

The local API is the one described here. It is plain HTTP and needs no authentication.

## Transport

| | |
|---|---|
| Protocol | HTTP/1.1, `GET` only, no TLS. `POST` is used only for `setBackupDataToRestore`. **Code** |
| Port | `2025`. The app reads it from the `communication_endpoint` string resource. **Verified** |
| Auth | None. Anyone on the LAN can read and control the system. **Verified** |
| Response type | `text/plain` with a JSON body, plus `Access-Control-Allow-Origin: *`. The status is always `200`, even for errors. **Code** |
| Speed | Usually 200–300 ms. The tablet's Wi-Fi can be slow to wake, so use a timeout of 4–5 s. The app uses 4000 ms for both connect and read. **Verified/Code** |

### Finding the tablet

There is no mDNS or SSDP announcement. The app finds the tablet by scanning:
1. It takes the phone's own `/24`.
2. It tries `GET http://<a.b.c.N>:2025/getSystemData` for N = 1–254.
3. It skips the router and tries stored IPs first.

**Code** (`s3.java`)

The quickest manual check:

```sh
for i in $(seq 1 254); do (curl -s -m 3 -o /dev/null -w "%{http_code} 192.168.1.$i\n" http://192.168.1.$i:2025/getSystemData | grep ^200 &) ; done; wait
```

The response also reports the tablet's own address in `system.tspIp`. Give the tablet a DHCP reservation on your router.

### Headers

No headers are required. The app sends `User-Agent: MyAir5/15.1548 <Dalvik UA>`. **Code**

The User-Agent affects how the server behaves:

- **`MyAir5/8.244`** gets `<iZS10.3><request>No longer supported</request></iZS10.3>`. **Code**
- **A UA containing `Android` or `Darwin`.** After a successful set command, the tablet forwards a copy of it to its Firebase event log, tagged `NW` or `PW`. **Code**
- **Any other UA**, for example `ClimateDeck/0.1`, works the same (**Verified**) and isn't forwarded (**Code**).

## Read: `GET /getSystemData`

```sh
curl -s http://192.168.1.50:2025/getSystemData
```

This returns the tablet's whole cached state as one JSON object. **Verified.** There is no smaller read endpoint. `getZoneData` and others return the plain-text banner, and `getLights` returns "No longer supported". **Code**

> **⚠ Send no query parameters.** The phone app polls `getSystemData?uid=<28-char Firebase uid>&fcmToken=…&deviceName=…&notificationVersion=…`. When `uid` is present and `system.remoteAccessPairingEnabled` is true, the tablet **registers the caller as a paired remote and push-notification device** (`WebServer.U()` → `HandlerAircon.j()`). A monitoring client must send the bare path. **Code**

### Responses that aren't data

The client must tolerate all of these and keep its last good state. **Code**

| Body | When |
|---|---|
| `{}` | Web requests are blocked, for example during a tablet update. |
| `Advantage Air v15.1548` (plain text) | Unknown path, or the tablet has nothing cached yet. |
| `<iZS10.3>…</iZS10.3>` (XML) | Legacy service mode or the legacy user agent. |

### Shape

Top-level keys:

| Key | Contents |
|---|---|
| `aircons` | `{ "ac1": { "info": {…}, "zones": { "z01": {…}, … } }, … }`, with up to four aircons (`ac1`–`ac4`). |
| `system` | Site and tablet metadata (see below). |
| `myLights`, `myThings`, `mySensors`, `myMonitors`, `myScenes`, `myView`, `myAddOns`, `myGarageRFControllers`, `snapshots` | MyPlace add-ons (lights, blinds and garage, scenes, cameras and locks, Hue bridges). They are empty on an aircon-only system. |

The example below is trimmed and redacted from the live system:

```json
{
  "aircons": {
    "ac1": {
      "info": {
        "aaAutoFanModeEnabled": true,
        "activationCodeStatus": "noCode",
        "airconErrorCode": "",
        "cbFWRevMajor": 10, "cbFWRevMinor": 30, "cbType": 1,
        "climateControlModeEnabled": false, "climateControlModeIsRunning": false,
        "constant1": 1, "constant2": 0, "constant3": 0, "noOfConstants": 1,
        "countDownToOff": 0, "countDownToOn": 0,
        "dbFWRevMajor": 17, "dbFWRevMinor": 28,
        "fan": "low",
        "filterCleanStatus": 0,
        "freshAirStatus": "none",
        "mode": "cool",
        "myAutoModeCurrentSetMode": "cool", "myAutoModeEnabled": false, "myAutoModeIsRunning": false,
        "myZone": 4,
        "name": "AC",
        "noOfZones": 6,
        "quietNightModeEnabled": false, "quietNightModeIsRunning": false,
        "rfFWRevMajor": 4, "rfSysID": 0,
        "setTemp": 28.0,
        "state": "off",
        "uid": "00000",
        "unitType": 17
      },
      "zones": {
        "z04": {
          "error": 0, "followers": [], "following": 0,
          "maxDamper": 100, "minDamper": 0,
          "measuredTemp": 20.0,
          "motion": 0, "motionConfig": 1,
          "name": "Bed 1", "number": 4,
          "rssi": 43, "SensorUid": "000000",
          "setTemp": 24.0,
          "state": "open",
          "tempSensorClash": false,
          "type": 1,
          "value": 100
        }
      }
    }
  },
  "system": {
    "aaServiceRev": "14.150", "myAppRev": "15.1548",
    "name": "MyPlace", "sysType": "MyAir5", "tspModel": "PIC8GS12", "tspIp": "192.168.1.50",
    "hasAircons": true, "noOfAircons": 1, "hasLights": false, "hasThings": false, "hasSensors": false,
    "suburbTemp": 6.5, "isValidSuburbTemp": false,
    "showMeasuredTemp": true,
    "remoteAccessPairingEnabled": true,
    "needsUpdate": false, "tspErrorCode": "noError"
  }
}
```

> **Privacy.** `system` also contains the site's latitude, longitude and postcode, the tablet's `logoPIN`, `rid`/`backupId`/`mid`, and `deviceIds`/`deviceIdsV2`/`deviceNames`, which are the paired phones' Firebase uids and **FCM push tokens**. Don't log or publish raw `getSystemData` output.

### `aircons.acN.info`

| Field | Type | Meaning |
|---|---|---|
| `state` | `on` \| `off` | Unit power. |
| `mode` | `cool` \| `heat` \| `vent` \| `dry` \| `auto` \| `myauto` | Operating mode. `vent` is fan only. `myauto` is Advantage Air's own auto, and while it runs, `myAutoModeCurrentSetMode` says whether it is currently cooling or heating. |
| `fan` | `low` \| `medium` \| `high` \| `auto` \| `autoAA` | Fan speed. `autoAA` is "MyFan" (Advantage Air's auto) and is only accepted when `aaAutoFanModeEnabled` is true. Otherwise the tablet turns it into `auto`, or `high` if the unit has no auto fan. **Code** |
| `setTemp` | number, °C | Unit set point. When `myZone` is set, the MyZone zone's `setTemp` is the effective target, and the phone app shows and edits that instead (see Writes). **Verified**: `setTemp` was 28 while MyZone `z04.setTemp` was 24. |
| `myZone` | 0–10 | The zone whose sensor drives the unit. 0 means none, and the unit then uses its return-air sensor. |
| `noOfZones` | int | Number of zones present. |
| `constant1..3`, `noOfConstants` | int | Constant (never-closed) zones, set by the installer. |
| `countDownToOn`, `countDownToOff` | int, minutes | Timers. 0 means not set. |
| `filterCleanStatus` | int | Non-zero means the filter needs cleaning. **Inferred polarity** |
| `airconErrorCode` | string | Empty when OK. For example, `AA4` means no temperature sensors. |
| `freshAirStatus` | `none` \| `off` \| `on` | Fresh-air damper. `none` means it isn't fitted. |
| `myAutoModeEnabled`, `myAutoCoolTargetTemp`, `myAutoHeatTargetTemp` | | MyAuto feature settings. |
| `quietNightModeEnabled` / `…IsRunning`, `climateControlModeEnabled` / `…IsRunning`, `aaAutoFanModeEnabled` | bool | Feature flags. |
| `activationCodeStatus` | `noCode` \| `codeEnabled` \| `expired` \| `sending` | Dealer lock. When it is `expired`, every set command fails with `Please check Touch screen`. |
| `unitType`, `cbType`, `*FWRev*`, `rfSysID`, `uid` | | Hardware identification. |

### `aircons.acN.zones.zNN`

Zone keys are `z01`–`z10`.

| Field | Type | Meaning |
|---|---|---|
| `name` | string | Zone name, 12 characters max. |
| `number` | int | 1–10. |
| `state` | `open` \| `close` | Zone damper open or closed. |
| `type` | int | Sensor type: `0` no sensor (percentage control), `1` RF sensor, `2` wired, `3` RF2CAN booster, `4` RF-X. **Non-zero means temperature control.** **Code** |
| `measuredTemp` | number, °C | Zone sensor reading. Ignore it when `type` is 0 or `error` is non-zero. |
| `setTemp` | number, °C | Zone target (temperature-controlled zones). |
| `value` | 0–100 | Damper opening %. For a temperature-controlled zone the controller sets it. For `type` 0 it is the user setting. |
| `minDamper`, `maxDamper` | 0–100 | Installer limits. |
| `error` | int | Non-zero means a sensor fault. **Inferred** |
| `rssi` | int | Wireless sensor signal. **Inferred** |
| `motion`, `motionConfig` | int | Motion-sensor state and setting. `motionConfig` is writable. |
| `following`, `followers` | int, [int] | Zone grouping, where a follower mirrors its master. |
| `tempSensorClash` | bool | Probably a duplicate sensor assignment. **Inferred** |
| `SensorUid` | string | Sensor hardware id. |

### `system` (useful fields)

| Field | Meaning |
|---|---|
| `name` | Site name shown in the app. |
| `suburbTemp`, `isValidSuburbTemp` | Outdoor temperature from the cloud weather lookup. **Only use it when `isValidSuburbTemp` is true.** It can be stale otherwise; it read 6.5 °C and invalid on the test system. |
| `noOfAircons`, `hasAircons`, `hasLights`, `hasThings`, `hasSensors` | Which features are present. |
| `tspIp`, `tspModel`, `myAppRev`, `aaServiceRev`, `needsUpdate`, `tspErrorCode` | Tablet info. |

## Write: `GET /setAircon?json=<payload>`

```sh
# Turn on, cooling, fan low
curl -s 'http://192.168.1.50:2025/setAircon?json=%7B%22ac1%22%3A%7B%22info%22%3A%7B%22state%22%3A%22on%22%2C%22mode%22%3A%22cool%22%2C%22fan%22%3A%22low%22%7D%7D%7D'
# → {"ack":true,"request":"setAircon"}
```

Payload (URL-encode it; NanoHTTPD decodes the parameter):

```json
{ "ac1": { "info": { "<field>": <value> }, "zones": { "zNN": { "<field>": <value> } } } }
```

### Rules

- **Partial updates.** Send only the fields you're changing. The tablet diffs them against its state and only sends changed frames to the unit. This is what the app does. **Code/Verified**
- **One aircon per request.** Only the first top-level key is processed, so send separate requests for `ac2`. The key can be `ac1`–`ac4` or the aircon's `uid`. **Code**
- **No backslashes.** Every `\` is stripped before parsing, so escaped characters in names break. **Code**
- **Numeric strings are accepted**, for example `"setTemp":"24"`. **Code**
- **Don't send `following` or `followers`** unless you mean to regroup zones. **Code**

### Writable fields

**Code** (`HandlerAircon`)

`info`:

| Field | Values and limits |
|---|---|
| `state` | `on`, `off` |
| `mode` | `cool`, `heat`, `vent`, `dry`, `auto`, `myauto` |
| `fan` | `low`, `medium`, `high`, `auto`, `autoAA` |
| `setTemp` | The protocol carries 0.5 °C steps (`setTemp*2` in the unit frame), but the tablet **doesn't range-check it**. The app uses whole degrees from **16 to 32**, and clients should clamp to that. |
| `myZone` | 0–10 |
| `countDownToOn`, `countDownToOff` | Minutes, 0–720. 0 cancels. The tablet counts them down itself, and `721` is rejected with `Aircon countDownToOn cannot be greater than 720 minutes`. **Verified** |
| `freshAirStatus` | `on`, `off`. Ignored if fresh air isn't fitted. |
| `myAutoModeEnabled`, `myAutoCoolTargetTemp` (20–32), `myAutoHeatTargetTemp` (16–28, at least 4 below cool), `quietNightModeEnabled`, `climateControlModeEnabled`, `aaAutoFanModeEnabled` | Feature settings. |
| `name` | 12 characters max. |

`zones.zNN`:

| Field | Values and limits |
|---|---|
| `state` | `open`, `close` |
| `setTemp` | 16–32, whole degrees. For temperature-controlled zones (`type` ≠ 0). |
| `value` | Damper %, 5–100 in steps of 5. For `type` 0 zones. The app closes the zone instead of going below 5. |
| `motionConfig` | Motion-sensor setting. |
| `name` | 12 characters max. |

Read-only, because the tablet nulls these before applying a LAN command:
- `info`: `airconErrorCode`, `filterCleanStatus`, `constant1-3`, `noOfConstants`, `noOfZones`, `uid`, `unitType`, firmware fields, activation fields.
- Zones: `measuredTemp`, `minDamper`, `maxDamper`, `type`, `error`, `rssi`, `motion`, `number`, `SensorUid`.

Filter reset and installer settings aren't available over the LAN.

### Changing the target temperature

Do what the app does:

```
myZone in 1..10  →  {"ac1":{"zones":{"z0<myZone>":{"setTemp":T}}}}
otherwise        →  {"ac1":{"info":{"setTemp":T}}}
```

Show the same value as the target: the MyZone zone's `setTemp`, or else `info.setTemp`. When `info.setTemp` is sent while a MyZone is set, the tablet also copies it into that zone, but that part of the decompiled code is garbled. **Code/Inferred**

### Changing MyZone

MyZone is the zone whose sensor the unit works to. The app does this (**Code**, `aircon/r.java`, `jsondata/c.java` `setAirconMyZoneZoneNumber`):

1. It sends `{"ac1":{"info":{"myZone":N}}}` on its own.
2. If zone N is closed, it then sends `{"ac1":{"zones":{"zNN":{"state":"open"}}}}` as a second request.

The app only offers the change when:
- the system is already in MyZone mode (`info.myZone` is 1–10). It never sets `myZone` back to 0 from the zone screen.
- Quiet Night mode isn't running. If it is, the app first asks to exit it.

The tablet doesn't validate `myZone` against the zones, so a client should only pick zones with a working sensor (`type` ≠ 0, `error` 0). After the switch, the target temperature is the new MyZone zone's `setTemp`.

Zone `setTemp` and `value` can be changed while a zone is closed. The app allows it, and the value applies when the zone opens.

### Replies

**Verified**

```json
{"ack":true,"request":"setAircon"}
{"ack":false,"reason":"Valid JSON, but nothing useful there.","request":"setAircon"}
```

`ack:true` only means the command was accepted (it is also true when nothing changed). Re-read `getSystemData` about a second later to see the applied state.

Error reasons (**Code**):
- `Failed to parse message`
- `Valid JSON, but nothing useful there.`
- `No aircon found with name X use ac1-4, uid or check the number of aircons`
- `Zone zNN is not found - check the noOfZones for this aircon and use z01-z10`
- `Aircon name is too long - maximum length is 12`
- `Zone name for zone zNN is too long - maximum length is 12`
- `Aircon countDownToOn cannot be less than 0` and `… cannot be greater than 720 minutes`, plus the same two for `countDownToOff`
- `Please check Touch screen`

An unknown or empty aircon key with nothing usable in it gives `Valid JSON, but nothing useful there.` **Verified**

## Scenes

Scenes live on the tablet under `myScenes` in `getSystemData`: `{"scenes": {"s10001": {...}}, "scenesOrder": ["s10001", ...]}`. Each one is an aircon snapshot that the tablet can apply on demand or on a timer. The tablet also runs the timers itself, so nothing needs to be awake on your side. **Verified**

### Scene fields

| Field | Meaning |
|---|---|
| `id` | `s` + 5 hex digits. User scenes are `s10001`–`s10012`, and the **client picks the id**: the app uses the first free one. **Verified** |
| `name` | 12 characters max. |
| `activeDays` | Day bitmask: **Sunday = 1, Monday = 2, Tuesday = 4 … Saturday = 64**. 127 is every day, 62 is Mon–Fri, 65 is the weekend. **Verified** (62 is summarised as Monday–Friday) |
| `startTime` | Minutes after midnight, 0–1439. For example, 285 = 04:45. |
| `timerEnabled` | Start automatically at `startTime` on `activeDays`. |
| `airconStopTime`, `airconStopTimeEnabled` | Turn the aircon off at this time, in minutes after midnight. If it is at or before the start, it means the next day. |
| `myTimeEnabled` | MyTime option. **Inferred** |
| `aircons` | `{"ac1": {"info": {uid, name, state, mode, fan, setTemp, myZone, freshAirStatus}, "zones": {"z01": {number, state, value, setTemp, motionConfig}, …}}}`. As on the live system, the scene's target is the MyZone zone's `setTemp`; the tablet's own summary shows it. **Verified** |
| `lights`, `things`, `monitors`, `sonos` | Other MyPlace devices. |
| `summary` | Human-readable text generated by the tablet. Read-only. |
| `runNow` | Write-only flag: run the scene right after saving it. **Code** |

Built-in scenes use ids `s0`–`s4` (MyUndo, MyWelcome, MyGoodbye, MyEco, MySunset). They aren't listed in `getSystemData` on an aircon-only system. **Code/Verified**

### Commands

All of these take a single `json=` parameter and reply `{"request", "ack", "reason"}`. **Verified**

```
GET /setScene?json={"id":"s10004","name":"Weekend","timerEnabled":true,"activeDays":65,"startTime":540,
                    "airconStopTimeEnabled":false,"airconStopTime":600,"myTimeEnabled":false,
                    "aircons":{"ac1":{"info":{...},"zones":{...}}}}      create (new id) or replace
GET /setScene?json={"id":"s10002","startTime":300}                       edit: missing fields are kept
GET /setScene?json={"id":"s10002","name":""}                             delete
GET /runScene?json={"id":"s10001"}                                       apply now
```

- **Create and edit** use the same command. A new id is added to the end of `scenesOrder`. There is no reorder command.
- **Partial edits keep the fields you leave out. Maps you send (`aircons`, `lights`, `things`) replace the stored ones whole.** Send the full aircon snapshot, including `uid`. **Verified**
- **An empty `name` deletes the scene.** **Verified**
- **`runScene`** applies the first aircon in the scene, both info and zones. **Verified**: a scene that changed one closed zone's target applied it.
- **`ack:true` doesn't prove a save worked.** The tablet acks saves it drops, for example past 12 scenes. Re-read `getSystemData`. **Code**
- **Every `setScene` and `runScene` first saves the current state into MyUndo (`s0`).** **Code**
- **Android phones hide scene create/edit; the tablet itself doesn't block it.** The Android app only shows the full scene editor when it is running on the wall tablet (it checks for the tablet's `aaservice` package), and gives phones a timer-only screen. The tablet accepts the full commands from any LAN client. **Code**

## Other commands

The server dispatches these paths the same way: `GET /<command>?<params>`, replying `{"request","ack","reason"}`. They weren't needed for Climate Deck and are listed from code only:

- `setZoneData`, `setZoneTimer`, `setScheduleData`, `setSystemData`, `setClock`, `changeName`
- `setLight`, `setLightName`, `setLightGroup`, `setLightGroupName`, `setLightToGroup`, `setLightScene`, `runLightScene`
- `setThing`, `setGroupThing`, `setGroupThingName`, `setNewGroupThingName`, `setThingToGroupThing`, `setThingToNewGroupThing`
- `setSnapShot` ("Aircon plans", aircon-only schedules `p1`–`p10` with a stop time), `setMySystem`, `setSensor`, `setMonitor`
- `setBackupDataToRestore` (POST)

`setLight` and `setThing` use the same `json=` style for lights, blinds and garage doors.

## Client guidance

These rules come from the app's behaviour:

- **Polling.** The app polls about once a second while open. A monitor is fine at 5–15 s.
- **Serialise requests.** The app sends one request at a time through a queue and drops duplicates. The tablet is a small Android device.
- **Debounce stepper input** so a burst of taps becomes one command.
- **Expect lag and stale reads.** A poll right after a write can return the old state. Keep the new value shown until a poll confirms it or a few seconds pass.
- **Timeouts.** If you use Qt/QML `XMLHttpRequest`, note that its `timeout` property is ignored. Abort from a timer instead. **Verified** on Qt 6.12.

## Cloud path, briefly

Away from home, the app signs in to Firebase Auth. It exchanges a token at `https://backendv1-6dwj2vpyhq-uc.a.run.app/generateCustomToken` and syncs the system through Firestore and FCM. The tablet mirrors its state there, keyed by `system.rid`. None of this is needed on the LAN.
