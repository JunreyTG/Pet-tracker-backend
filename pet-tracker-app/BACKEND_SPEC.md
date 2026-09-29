# Pet Tracker Backend — Functionality & Specs for Flutter App (`pet-tracker-app`)

> Backend: `pet-tracker-backend/` — FastAPI + Firebase Admin SDK + Firestore
> Local base URL: `http://127.0.0.1:8000`
> API prefix: `/api/v1` (except `GET /health`)
> Docs: `GET /docs`, `/redoc`, `/openapi.json`
> This document is the contract for building `pet-tracker-app`.

---

## 1. System Overview

```
ESP32 GPS tracker --(device_secret)--> POST /api/v1/device/telemetry --> Firestore
Flutter app --(Firebase ID Token)--> /api/v1/pets|devices|geofences|alerts|notifications --> Firestore
Firebase Cloud Messaging <-- backend sends on alert events
```

Two separate auth schemes:
- **Flutter / mobile:** `Authorization: Bearer <Firebase ID Token>` for all `/api/v1/*` except telemetry.
- **ESP32:** `{device_id, device_secret}` in POST body for `POST /api/v1/device/telemetry` only. Flutter never uses this (except for dev simulation).

No WebSockets, MQTT, scheduler/worker, SMS/email. Flutter must poll with GET.

---

## 2. Run / Config

Backend run:
```powershell
cd pet-tracker-backend
.\.venv\Scripts\Activate.ps1
python -m app.firebase.verify
uvicorn app.main:app --reload
```

Env (`.env`, see `.env.example`):
```
APP_NAME="Pet Tracker Backend"
APP_VERSION="0.1.0"
DEBUG=false
FIREBASE_CREDENTIALS_PATH=".credentials/firebase-service-account.json"
FIREBASE_PROJECT_ID=""  # optional, falls back to JSON project_id
DEVICE_OFFLINE_THRESHOLD_SECONDS=300  # >0, strict > comparison
LOW_BATTERY_THRESHOLD_PERCENT=20      # 0..100, inclusive <=
```

CORS default: `["http://localhost:5000","http://127.0.0.1:5000"]`. Add Flutter web port if needed.

Health:
```
GET /health -> 200 {"status":"ok","message":"Pet tracker backend API is running"}
```

---

## 3. Auth Flow (Flutter)

1. Use `firebase_auth`: sign-in (email/Google/etc.).
2. Get token: `String token = await FirebaseAuth.instance.currentUser!.getIdToken();`
3. Send on every call:
```dart
headers: {
  'Authorization': 'Bearer $token',
  'Content-Type': 'application/json',
}
```
4. On `401`, refresh: `await user.getIdToken(true)` and retry once.
5. Rules:
   - Format must be `Bearer <token>`, no whitespace inside token, else `401 {"detail":"Invalid or missing Firebase authentication token."}` + `WWW-Authenticate: Bearer`.
   - Token verified with `check_revoked=True`. Admin SDK down -> `503 {"detail":"Authentication service is not available."}`.
   - `owner_id` is always server-derived from UID. Never send `owner_id`.
   - Pydantic `extra="forbid"` -> unknown fields = `422`. Send only documented fields.
   - Cross-owner access returns `404` (not `403`).
   - Never send/log device secrets or raw FCM tokens in query strings/logs.

Sync user profile after login:
```
GET /api/v1/auth/me -> 200 {"uid":"...","email":"...","display_name":"..."}
```
Creates/merges `users/{uid}`.

---

## 4. Data Models (Firestore)

| Collection | Doc ID | Fields |
|---|---|---|
| `users` | `{uid}` | `{display_name, email, created_at, updated_at}` |
| `pets` | auto | `{owner_id, name, species, breed?, age?, photo_url?, device_id?, created_at, updated_at}` |
| `devices` | `{device_id}` | `{device_id, owner_id, pet_id?, status, battery_level?, current_location:{latitude,longitude}?, last_seen?, last_location_update?, device_secret_hash(hidden), low_battery_alert_active, created_at, updated_at}` |
| `tracking_history` | auto | `{device_id, pet_id, owner_id, latitude, longitude, battery_level?, recorded_at}` — write-only, no read API |
| `geofences` | auto | `{owner_id, pet_id, name, center:{latitude,longitude}, radius_meters, enabled, last_state:inside\|outside\|null, last_state_changed_at?, last_checked_at?, created_at, updated_at}` |
| `alerts` | auto | `{owner_id, pet_id?, device_id?, type, title, message, latitude?, longitude?, read=false, created_at}` |
| `notification_tokens` | `sha256(rawFCM)` | `{owner_id, token(raw, hidden from list), platform, device_name?, active, created_at, updated_at, last_used_at?}` |

Enums:
- `device.status`: `online|offline|unregistered|disabled`. New = `unregistered`, telemetry flips to `online`.
- `alert.type`: `device_offline|device_online|geofence_exit|geofence_enter|low_battery`.
- `geofence.last_state`: `null|inside|outside`.
- `platform`: `android|ios`.

Timestamps are server timestamps, serialized ISO8601.

---

## 5. API Reference

### 5.1 Pets — all require Firebase Bearer

```
POST   /api/v1/pets
GET    /api/v1/pets
GET    /api/v1/pets/{pet_id}
PATCH  /api/v1/pets/{pet_id}
DELETE /api/v1/pets/{pet_id}
```

Create:
```json
// POST /api/v1/pets
{"name":"Brownie","species":"dog","breed":"Aspin","age":3,"photo_url":null}
// -> 201
{"id":"autoId","owner_id":"UID","name":"Brownie","species":"dog","breed":"Aspin","age":3,"photo_url":null,"device_id":null,"created_at":"...Z","updated_at":"...Z"}
```
Constraints: `name` req min1, `species` req min1, `age >=0`. Server forces `owner_id=UID, device_id=null`.

Update (`PATCH`): partial, same fields (cannot set `owner_id/device_id` here). Empty body = no-op return.

Delete: `204` empty. Does NOT cascade unassign device `pet_id` — unassign first in Flutter.

Errors: `404 {"detail":"Pet was not found."}`, `503 {"detail":"Pet service is not available."}`.

### 5.2 Devices — all require Firebase Bearer

```
POST   /api/v1/devices
GET    /api/v1/devices
GET    /api/v1/devices/{device_id}
POST   /api/v1/devices/{device_id}/assign
DELETE /api/v1/devices/{device_id}/assignment
```

Register:
```json
// POST /api/v1/devices  Body: {"device_id":"ESP32_001"}  // 1..128 chars, Firestore doc ID
// -> 201
{"id":"ESP32_001","device_id":"ESP32_001","owner_id":"UID","pet_id":null,"status":"unregistered","battery_level":null,"current_location":null,"last_seen":null,"last_location_update":null,"low_battery_alert_active":false,"created_at":"...","updated_at":"...","device_secret":"<SHOW-ONCE-plain>"}
```
- `device_secret` shown once. `device_secret_hash` never returned. Stored as PBKDF2-SHA256 (210k iterations).
- Duplicate `device_id` (any owner) -> `409 {"detail":"Device is already registered."}`.

List/get return same minus `device_secret`.

Assign (1:1 enforcement):
```json
// POST /api/v1/devices/{device_id}/assign  Body: {"pet_id":"..."} -> 200 DeviceResponse
```
- Device must be owned, else `404`.
- If `device.pet_id != null && != pet_id` -> `409`.
- Pet must be owned, else `404`.
- If `pet.device_id != null && != device_id` -> `409 "Pet already has a device assigned."`.

Unassign: `DELETE .../assignment -> 200 DeviceResponse`. Idempotent if already `null`.

### 5.3 Telemetry (ESP32 only, device-secret auth)

```
POST /api/v1/device/telemetry  // NO Firebase token
{"device_id":"ESP32_001","device_secret":"<plain>","latitude":14.5995,"longitude":120.9842,"battery_level":87}
// -> 200 {"message":"Telemetry received successfully"}
```
Constraints: `lat -90..90, lon -180..180, battery 0..100`, all required.

Errors: `401 Invalid device credentials.`, `409 Device is not assigned to a pet.`, `422` validation, `503 Telemetry service is not available.`

Side effects in order:
1. Verify secret.
2. Require `pet_id`.
3. Update `devices/{id}`: `status=online, battery_level, current_location, last_seen=SERVER_TIMESTAMP, last_location_update=SERVER_TIMESTAMP`.
4. Append `tracking_history/{autoId}`.
5. If prev `status==offline` -> `device_online` alert + FCM.
6. Low-battery eval.
7. Eval all enabled geofences for pet -> `enter/exit` alerts + FCM.

Flutter: do NOT call in production; use only for dev simulation.

### 5.4 Geofences — all require Firebase Bearer

```
POST   /api/v1/geofences
GET    /api/v1/geofences
GET    /api/v1/geofences/{geofence_id}
PATCH  /api/v1/geofences/{geofence_id}
DELETE /api/v1/geofences/{geofence_id}
```

Create:
```json
// POST /api/v1/geofences -> 201
{"pet_id":"PET_ID","name":"Home","center":{"latitude":14.5995,"longitude":120.9842},"radius_meters":100,"enabled":true}
```
Constraints: `radius_meters >0`, `center` required. Pet must be owned else `404`. Server sets `owner_id=UID, last_state=null`.

List returns all owned (no `?pet_id` query — filter client-side).

Patch: `{name?, center?, radius_meters?, enabled?}` only. Cannot change `pet_id/owner_id`.

Delete: `204`.

### 5.5 Alerts — read/ack only, no POST

```
GET    /api/v1/alerts?pet_id=str&type=geofence_exit|geofence_enter|low_battery|device_offline|device_online&read=bool
GET    /api/v1/alerts/{alert_id}
PATCH  /api/v1/alerts/{alert_id}
DELETE /api/v1/alerts/{alert_id}
```

Example:
```json
{"id":"autoId","owner_id":"UID","pet_id":"petId","device_id":"ESP32_001","type":"geofence_exit","title":"Safe Zone Exit","message":"Brownie has left Home.","latitude":14.6,"longitude":121.0,"read":false,"created_at":"..."}
```

Patch body only: `{"read":true}`. Only mutable field. New alerts `read=false`.

### 5.6 Notifications / FCM tokens — Firebase Bearer required

```
POST   /api/v1/notifications/tokens
GET    /api/v1/notifications/tokens
DELETE /api/v1/notifications/tokens/{token_id}
```

Register:
```json
// POST -> 201
{"token":"FCM_TOKEN","platform":"android","device_name":"My Phone"}
// -> {"message":"Notification token registered successfully","token_id":"sha256hex"}
```
- `token_id = SHA256(rawToken)`, used as doc ID.
- Re-register same token -> update `{platform,device_name,active:true,last_used_at}`.
- Token owned by different UID -> `404`.

List returns `[{token_id,platform,device_name,active,created_at,updated_at,last_used_at}]` (no raw `token`).

Delete = soft-deactivate `active=false`, `204`. Call on logout/uninstall; `POST` on login/token refresh.

FCM send: `title=alert.title, body=alert.message, data={alert_id,type,pet_id?,device_id?}` strings only. Invalid token -> `active=false`. No custom push endpoint.

---

## 6. Business Rules (must mirror in Flutter UI)

- **Offline:** `now - last_seen > threshold` (strict `>`, default 300s). Exactly 300s = still online. Skips `last_seen=null`, `unregistered|disabled|offline`. Sets `status=offline` + `device_offline` alert + FCM. No geofence eval. Note: `HeartbeatService.check_devices_for_offline_status()` has **no route / no background task** — must be invoked externally or offline status only changes on next telemetry.
- **Online recovery:** telemetry when stored `status==offline` -> `device_online` alert.
- **Geofence:** Haversine `R=6371000`, `distance <= radius -> inside`. `null -> initial` (no alert). Then `inside->outside=exit`, `outside->inside=enter`, same = `none`. Only fresh GPS telemetry triggers eval (enabled fences only); heartbeat never does.
- **Low battery:** `battery_level <= threshold` (default 20, inclusive) + `low_battery_alert_active==false` -> alert + set flag `true` (dedup). Recovery `> threshold` resets to `false`.
- **Alert texts:**
  - `Tracker Offline: "{pet}'s tracker has gone offline."`
  - `Tracker Back Online`
  - `Safe Zone Exit: "{pet} has left {zone}."`
  - `Safe Zone Entered: "{pet} has returned to {zone}."`
  - `Low Battery: "{pet}'s tracker battery is low ({n}%)."` (`pet="Your pet"` fallback)
- **Initial geofence:** `unknown->inside/outside = no alert`.
- **Duplicates:** `offline->offline, online->online, inside->inside, outside->outside, low-battery-still-low = no new alert`.

---

## 7. Flutter Integration Guide

Suggested packages: `firebase_auth`, `firebase_messaging`, `http` or `dio`, `flutter_map` or `google_maps_flutter`, `geolocator` (for phone location, optional).

**Base client:**
```dart
const baseUrl = 'http://127.0.0.1:8000'; // 10.0.2.2 on Android emulator
Future<Map<String,String>> authHeaders() async {
  final token = await FirebaseAuth.instance.currentUser!.getIdToken();
  return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
}
// GET http://127.0.0.1:8000/api/v1/pets with authHeaders()
```

**Screens mapping:**
1. Auth -> Firebase sign-in -> `GET /auth/me`.
2. Pets CRUD -> `POST/GET/PATCH/DELETE /pets`. Show `device_id` badge if assigned.
3. Devices -> `POST /devices` (show secret once + QR for ESP32 flashing), `GET /devices`, assign/unassign. Show `status, battery_level, current_location, last_seen`.
4. Map -> `device.current_location` + `GET /geofences` circles. Poll `GET /devices/{id}` every 15-30s (no websocket). No `tracking_history` API — cannot draw trail yet.
5. Geofences CRUD -> `POST/GET/PATCH/DELETE /geofences`. Show `last_state, last_checked_at`.
6. Alerts inbox -> `GET /alerts?read=false`, filter chips `pet_id/type/read`, swipe to `PATCH {read:true}` / `DELETE`. Badge unread count.
7. Notifications -> on `FirebaseMessaging.getToken()`, `POST /notifications/tokens`. On refresh/logout, re-POST / DELETE. Handle `message.data = {alert_id,type,pet_id,device_id}` -> deep-link to alert/pet.

**Polling (no realtime):**
- Devices: 15-30s. Alerts: 15-30s or on FCM foreground message. Geofences: on map open.

**Error handling:**
- `401` -> refresh ID token once, retry; else force login.
- `404` -> treat as not-found / not-owned (don't distinguish).
- `409` -> show duplicate/assign conflict message.
- `422` -> validation (check lat/lon/battery ranges, non-empty name).
- `503` -> backend/Firestore down, retry with backoff.

---

## 8. What Is NOT Available (do not plan Flutter features on these)

- No `tracking_history` read endpoint / map trail.
- No device update/delete/secret-rotation/disable endpoints.
- No user update/delete.
- No `POST /alerts` (server-only).
- No scheduler — offline detection not automatic via API.
- No WebSockets, no SMS/email, FCM server-side only.
- No pagination/sorting, no `?pet_id` on geofences (client filter).
- Mobile app features intentionally not implemented yet — this doc is the starting contract.
