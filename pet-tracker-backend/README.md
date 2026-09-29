# Pet Tracker Backend

FastAPI backend foundation for an ESP32 GPS pet tracking system.

This project currently includes the backend API foundation, Firebase Admin SDK initialization, Firebase Authentication verification, Firestore repositories, pet/device management, device telemetry ingestion, heartbeat/offline detection, geofencing, alert records, and Firebase Cloud Messaging delivery services. Mobile application features are intentionally not implemented yet.

## Tech Stack

- Python
- FastAPI
- Uvicorn
- Pydantic Settings
- Firebase Admin SDK

## Project Structure

```text
app/
├── main.py
├── api/
├── core/
├── models/
├── schemas/
├── services/
├── firebase/
└── utils/

tests/
```

## Setup

Create and activate a virtual environment:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Install dependencies:

```powershell
pip install -r requirements.txt
```

Create a local environment file if needed:

```powershell
Copy-Item .env.example .env
```

## Firebase Setup

Firebase is initialized from a local service-account JSON file. Do not commit this file and do not paste its contents into `.env` or source code.

1. In the Firebase Console, create or download a service-account private key JSON for the backend project.
2. Create a local credentials directory:

```powershell
New-Item -ItemType Directory -Path .credentials
```

3. Place the downloaded file here:

```text
.credentials/firebase-service-account.json
```

4. Configure `.env`:

```text
FIREBASE_CREDENTIALS_PATH=".credentials/firebase-service-account.json"
FIREBASE_PROJECT_ID="your-firebase-project-id"
DEVICE_OFFLINE_THRESHOLD_SECONDS=300
DEVICE_HEARTBEAT_CHECK_INTERVAL_SECONDS=60
LOW_BATTERY_THRESHOLD_PERCENT=20
```

`FIREBASE_PROJECT_ID` is optional if the service-account JSON contains the correct `project_id`, but setting it makes the local configuration explicit.

The `.credentials/` and `credentials/` directories and JSON credential files are excluded from Git. Do not commit service-account JSON files.

## Heartbeat / Offline Detection

Successful ESP32 telemetry updates `devices/{device_id}.last_seen`. The backend heartbeat service uses that timestamp to determine whether a tracker has stopped communicating.

The default offline threshold is 300 seconds, or 5 minutes. Configure it with:

```text
DEVICE_OFFLINE_THRESHOLD_SECONDS=300
```

The boundary is strict: a device is marked offline only when `current UTC time - last_seen` is greater than the threshold. With the default threshold, a device last seen exactly 5 minutes ago is still considered online; it becomes offline after more than 5 minutes.

Devices with `last_seen = null`, `unregistered` devices, and `disabled` devices are skipped. Heartbeat checking does not update `last_seen`; only successful device communication such as telemetry updates it.

Offline detection can create persistent alerts and FCM notifications. It does not run geofence checks.

The FastAPI app starts a best-effort in-process heartbeat loop on startup and stops it during shutdown. This is suitable for local development and simple single-worker deployments. For multi-worker production deployments, use a single external scheduler/worker to avoid duplicate checks.

## Location History

Telemetry writes are available to authenticated pet owners through:

```text
GET /api/v1/pets/{pet_id}/location-history?limit=100&start_time=2026-09-25T00:00:00Z&end_time=2026-09-25T23:59:59Z
```

The endpoint verifies pet ownership from the Firebase UID, never trusts client-supplied ownership, returns records chronologically, and caps `limit` at 500.

## Geofencing / Safe Zones

A geofence, or safe zone, defines a circular area for a pet using a GPS center point and a radius in meters:

```json
{
  "pet_id": "PET_ID",
  "name": "Home",
  "center": {
    "latitude": 14.5995,
    "longitude": 120.9842
  },
  "radius_meters": 100,
  "enabled": true
}
```

Geofence endpoints are owner-protected with Firebase Authentication:

```text
POST   /api/v1/geofences
GET    /api/v1/geofences
GET    /api/v1/geofences/{geofence_id}
PATCH  /api/v1/geofences/{geofence_id}
DELETE /api/v1/geofences/{geofence_id}
```

The backend derives `owner_id` from the authenticated Firebase UID. Clients cannot set or override geofence ownership.

Distance is calculated with the Haversine formula. Boundary behavior is inclusive: `distance <= radius_meters` is inside, and `distance > radius_meters` is outside.

Geofence state is stored on each geofence document:

```text
last_state
last_state_changed_at
last_checked_at
```

`last_state` starts as `null` until valid GPS telemetry is received for the assigned pet. The first GPS-based state is classified as `initial`, not as an enter or exit movement.

State transitions are classified as:

```text
UNKNOWN -> INSIDE   = initial
UNKNOWN -> OUTSIDE  = initial
INSIDE  -> OUTSIDE  = exit
OUTSIDE -> INSIDE   = enter
INSIDE  -> INSIDE   = none
OUTSIDE -> OUTSIDE  = none
```

Valid device telemetry triggers geofence checks for all enabled geofences assigned to the telemetry device's pet. Disabled geofences are skipped. Offline detection does not trigger geofence transitions because only fresh GPS telemetry can establish movement.

Alerts and FCM delivery are handled by later alert/notification services; geofence evaluation itself only returns transition results.

## Alerts

The backend creates persistent alert records in Firestore under `alerts/{alertId}` for important tracker state changes. Firebase Cloud Messaging is used as a delivery mechanism after alerts are stored.

Supported alert types:

```text
device_offline
device_online
geofence_exit
geofence_enter
low_battery
```

Alerts are generated by backend logic only. Mobile clients cannot create arbitrary alert documents, cannot set `owner_id`, and cannot modify server-controlled alert fields.

Alert endpoints are owner-protected with Firebase Authentication:

```text
GET    /api/v1/alerts
GET    /api/v1/alerts/{alert_id}
PATCH  /api/v1/alerts/{alert_id}
DELETE /api/v1/alerts/{alert_id}
```

The list endpoint supports optional filters:

```text
pet_id
type
read
```

New alerts are created with `read = false`. The mobile app can later mark alerts read or unread with:

```json
{
  "read": true
}
```

Alert generation rules:

```text
online  -> offline = device_offline
offline -> online  = device_online
inside  -> outside = geofence_exit
outside -> inside  = geofence_enter
battery_level <= LOW_BATTERY_THRESHOLD_PERCENT = low_battery
```

Initial geofence states do not create enter or exit alerts:

```text
unknown -> inside  = no alert
unknown -> outside = no alert
```

Duplicate prevention:

```text
offline -> offline = no duplicate alert
online  -> online  = no duplicate alert
inside  -> inside  = no duplicate alert
outside -> outside = no duplicate alert
low battery remaining below threshold = no duplicate alert
```

Low-battery threshold defaults to 20 percent and is configurable:

```text
LOW_BATTERY_THRESHOLD_PERCENT=20
```

Devices store `low_battery_alert_active` to prevent low-battery alert spam. When battery recovers above the threshold, the flag is reset so a later drop below the threshold can create a new alert.

Offline detection can create offline alerts, but it does not run geofence checks. Only fresh GPS telemetry can generate geofence enter/exit alerts.

## Firebase Cloud Messaging

Notification tokens are stored in a dedicated collection, one document per mobile device token:

```text
notification_tokens/{tokenId}
```

Token documents contain:

```json
{
  "owner_id": "FIREBASE_UID",
  "token": "FCM_DEVICE_TOKEN",
  "platform": "android",
  "device_name": "Owner Phone",
  "active": true,
  "created_at": "timestamp",
  "updated_at": "timestamp",
  "last_used_at": "timestamp"
}
```

`tokenId` is a SHA-256 hash of the raw FCM token. The raw token is stored only inside the token document because Firebase Cloud Messaging requires it for delivery. Raw FCM tokens are not returned by list endpoints and must not be logged.

Notification token endpoints are owner-protected with Firebase Authentication:

```text
POST   /api/v1/notifications/tokens
GET    /api/v1/notifications/tokens
DELETE /api/v1/notifications/tokens/{token_id}
```

Registration request:

```json
{
  "token": "FCM_TOKEN",
  "platform": "android",
  "device_name": "My Phone"
}
```

Supported platforms are `android` and `ios`. The backend derives `owner_id` from the authenticated Firebase UID. Clients cannot set token ownership.

Alert to FCM flow:

```text
event occurs
alert is created in Firestore
active notification tokens for alert.owner_id are loaded
FCM notification is sent to each active token
```

FCM payload uses existing alert content:

```text
title = alert.title
body  = alert.message
```

FCM data includes string values for `alert_id`, `type`, `pet_id`, and `device_id` when available. Device secrets, Firebase ID tokens, passwords, and credentials are never included in FCM payloads.

If Firebase reports an FCM token as invalid or unregistered, the backend marks that token inactive and continues processing. If FCM delivery fails, the alert remains stored and the original event processing continues.

Push notification delivery is implemented only through Firebase Admin SDK server-side FCM. No Flutter mobile code, WebSockets, SMS, email, scheduler, or background worker is implemented.

## Firebase Verification

After placing the service-account file and configuring `.env`, verify Firebase Admin SDK initialization and Firestore connectivity:

```powershell
python -m app.firebase.verify
```

Expected successful output:

```text
Firebase verification succeeded: Admin SDK initialized and Firestore responded.
```

This verification does not create application-specific collections or documents.

## Run

Start the API with Uvicorn:

```powershell
uvicorn app.main:app --reload
```

Health check:

```text
GET /health
```

Expected response:

```json
{
  "status": "ok",
  "message": "Pet tracker backend API is running"
}
```

## Tests

```powershell
pytest
```
