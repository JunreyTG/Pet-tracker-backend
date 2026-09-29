# Pet Tracker Backend — Technical & API Documentation

> **Backend Service:** `pet-tracker-backend`  
> **Framework:** FastAPI (Python 3.12+)  
> **Database:** Google Cloud Firestore (via Firebase Admin SDK)  
> **Authentication:** Dual Scheme (Firebase ID Tokens for App, Salted PBKDF2 for Trackers)  
> **Default API Base URL:** `http://127.0.0.1:8000`  
> **API Version Prefix:** `/api/v1` (except `GET /health`)

---

## 1. System Overview & Architecture

The `pet-tracker-backend` service acts as the central cloud coordinator in the Pet Tracker ecosystem. It handles:
- **Device Telemetry Ingestion:** Receives high-frequency GPS fixes and battery levels from ESP32 tracker collars.
- **Geofence Boundary Monitoring:** Analyzes pet movements against circular safe zones in real time using the Haversine formula.
- **Heartbeat & Offline Detection:** Runs an asynchronous background monitor to detect unresponsive or disconnected trackers.
- **Alert Dispatching & Push Notifications:** Generates persistent alert records and delivers push notifications to pet owners via Firebase Cloud Messaging (FCM).
- **Pet & Tracker Management:** Enforces 1:1 pairings between pets and physical hardware collars.
- **Geocoding & Administrative Address Search:** Integrates with the Philippine Standard Geographic Code (PSGC) API and OpenStreetMap Nominatim for address hierarchy lookup down to the barangay level.

### Layered Architecture

```text
app/
├── api/                   # HTTP endpoints and route handlers (FastAPI APIRouter)
│   ├── alerts.py          # Alert queries and acknowledgment
│   ├── auth.py            # User profile synchronization
│   ├── devices.py         # Device registration, provisioning, and assignment
│   ├── geofences.py       # Safe zone CRUD
│   ├── health.py          # Service health check
│   ├── notifications.py   # FCM push token registration
│   ├── pets.py            # Pet profiles and location history
│   ├── places.py          # PSGC administrative address search
│   └── telemetry.py       # ESP32 GPS data ingestion (device-authenticated)
├── core/
│   └── config.py          # Environment settings (Pydantic BaseSettings)
├── firebase/
│   ├── admin.py           # Firebase Admin SDK initialization
│   ├── firestore.py       # Cloud Firestore client factory
│   └── verify.py          # CLI connectivity verification script
├── models/
│   ├── auth.py            # AuthenticatedUser principal entity
│   └── entities.py        # Domain entities (Pet, Device, Alert, Geofence, etc.)
├── schemas/               # Request/Response DTOs (Pydantic v2 with extra="forbid")
│   ├── alerts.py
│   ├── devices.py
│   ├── geofences.py
│   ├── location_history.py
│   ├── notifications.py
│   ├── pets.py
│   ├── places.py
│   └── telemetry.py
├── services/              # Pure business logic and database interactions
│   ├── alert_service.py
│   ├── auth_service.py
│   ├── device_credentials.py
│   ├── device_service.py
│   ├── firestore_repositories.py
│   ├── geofence_service.py
│   ├── heartbeat_service.py
│   ├── location_history_service.py
│   ├── notification_service.py
│   ├── pet_service.py
│   ├── place_service.py
│   └── telemetry_service.py
└── main.py                # Application entrypoint, CORS, and heartbeat lifespan
```

---

## 2. Setup, Configuration & Running

### 2.1 Prerequisites
- Python 3.12+ (or 3.14)
- Google Cloud / Firebase project with Cloud Firestore and Cloud Messaging enabled
- Firebase Service Account private key JSON file

### 2.2 Installation

```powershell
# Navigate to backend directory
cd pet-tracker-backend

# Create and activate virtual environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

### 2.3 Environment Configuration (`.env`)

Create a `.env` file based on `.env.example`:

```ini
APP_NAME="Pet Tracker Backend"
APP_VERSION="0.1.0"
DEBUG=false

# Firebase Credentials
FIREBASE_CREDENTIALS_PATH=".credentials/firebase-service-account.json"
FIREBASE_PROJECT_ID="your-firebase-project-id"  # Optional if specified in JSON

# Heartbeat & Offline Monitoring
DEVICE_OFFLINE_THRESHOLD_SECONDS=300            # Seconds before device marked offline (strict >)
DEVICE_HEARTBEAT_CHECK_INTERVAL_SECONDS=60       # Interval between background checks

# Alerting Thresholds
LOW_BATTERY_THRESHOLD_PERCENT=20                 # Low battery alert trigger (<= 20%)

# CORS Configuration
CORS_ORIGINS=["http://localhost:5000","http://127.0.0.1:5000"]
CORS_ORIGIN_REGEX="^https?://(localhost|127\\.0\\.0\\.1)(:\\d+)?$"
```

### 2.4 Firebase Verification

Verify that your credentials file is valid and Firestore is reachable:

```powershell
python -m app.firebase.verify
```
*Expected output:* `Firebase verification succeeded: Admin SDK initialized and Firestore responded.`

### 2.5 Running the Server

```powershell
# Development mode with hot-reload
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

- **Interactive API Docs (Swagger UI):** `http://127.0.0.1:8000/docs`
- **ReDoc Documentation:** `http://127.0.0.1:8000/redoc`
- **OpenAPI JSON:** `http://127.0.0.1:8000/openapi.json`

---

## 3. Security & Dual Authentication Architecture

The backend distinguishes strictly between human pet owners and automated IoT devices:

```
┌────────────────────────────────────────┐          ┌────────────────────────────────────────┐
│             Flutter Client             │          │             ESP32 Hardware             │
└───────────────────┬────────────────────┘          └───────────────────┬────────────────────┘
                    │                                                   │
  Authorization: Bearer <Firebase_ID_Token>           POST body: {device_id, device_secret}
                    │                                                   │
                    ▼                                                   ▼
┌────────────────────────────────────────┐          ┌────────────────────────────────────────┐
│     Firebase Auth Verification         │          │      PBKDF2-SHA256 Password Hash       │
│  - Verifies token signature            │          │  - Verifies 210,000 iteration salt/hash│
│  - Enforces check_revoked=True         │          │  - Resolves registered device doc      │
│  - Derives owner_id from token UID     │          │  - Rejects if device not assigned      │
└────────────────────────────────────────┘          └────────────────────────────────────────┘
```

1. **User Request Rules:**
   - Client sends `Authorization: Bearer <Firebase ID Token>`.
   - The backend validates the token using the Firebase Admin SDK with `check_revoked=True`.
   - `owner_id` is always extracted from the token's `uid` claim on the server. Clients cannot provide or override `owner_id`.
   - Accessing a resource belonging to another user returns `404 Not Found` (rather than `403 Forbidden`) to avoid leaking document IDs.
   - Pydantic models use `extra="forbid"`. Any unexpected payload attributes return `422 Unprocessable Entity`.

2. **IoT Device Request Rules:**
   - ESP32 hardware collars submit telemetry to `POST /api/v1/device/telemetry`.
   - No Firebase ID Token is required.
   - The request body contains `{device_id, device_secret, latitude, longitude, battery_level}`.
   - The secret is validated against the stored PBKDF2-SHA256 hash.
   - The device must be assigned to an active pet; otherwise, a `409 Conflict` is returned.

---

## 4. Firestore Database Collections & Schema

| Collection | Document ID | Description & Key Attributes |
|---|---|---|
| `users` | `{uid}` | Created upon user login. Fields: `display_name`, `email`, `created_at`, `updated_at`. |
| `pets` | Auto-ID | Pet profiles. Fields: `owner_id`, `name`, `species`, `breed`, `age`, `photo_url`, `device_id`, `created_at`, `updated_at`. |
| `devices` | `{device_id}` | Hardware trackers. Fields: `device_id`, `owner_id`, `pet_id`, `status` (`unregistered\|online\|offline\|disabled`), `battery_level`, `current_location: {latitude, longitude}`, `last_seen`, `last_location_update`, `device_secret_hash` (hidden from API), `low_battery_alert_active`. |
| `tracking_history` | Auto-ID | Append-only GPS breadcrumbs. Fields: `device_id`, `pet_id`, `owner_id`, `latitude`, `longitude`, `battery_level`, `recorded_at`. |
| `geofences` | Auto-ID | Circular safe zones. Fields: `owner_id`, `pet_id`, `name`, `center: {latitude, longitude}`, `radius_meters`, `enabled`, `last_state` (`null\|inside\|outside`), `last_state_changed_at`, `last_checked_at`. |
| `alerts` | Auto-ID | Safety events. Fields: `owner_id`, `pet_id`, `device_id`, `type` (`device_offline\|device_online\|geofence_exit\|geofence_enter\|low_battery`), `title`, `message`, `latitude`, `longitude`, `read` (bool), `created_at`. |
| `notification_tokens` | `sha256(raw_token)` | Registered mobile FCM tokens. Fields: `owner_id`, `token` (raw, hidden from list), `platform` (`android\|ios`), `device_name`, `active`, `created_at`, `updated_at`, `last_used_at`. |

---

## 5. Core Business Logic & State Machines

### 5.1 Telemetry Pipeline
When `POST /api/v1/device/telemetry` is received:
1. Verify device credentials via PBKDF2 hash comparison.
2. Confirm the tracker has an assigned `pet_id`.
3. Update `devices/{device_id}`:
   - `status = "online"`
   - `battery_level = payload.battery_level`
   - `current_location = {latitude, longitude}`
   - `last_seen = SERVER_TIMESTAMP`
   - `last_location_update = SERVER_TIMESTAMP`
4. Append an entry to `tracking_history`.
5. **Online Recovery:** If the device's previous status was `offline`, generate a `device_online` alert and dispatch an FCM notification.
6. **Low Battery Latching:** If `battery_level <= LOW_BATTERY_THRESHOLD_PERCENT` (20%) and `low_battery_alert_active == False`:
   - Generate a `low_battery` alert and dispatch FCM.
   - Set `low_battery_alert_active = True`.
   - If battery level subsequently rises $> 20\%$, reset `low_battery_alert_active = False`.
7. **Geofence Check:** Evaluate all enabled geofences assigned to this pet.

### 5.2 Geofence Evaluation & Transitions
Distance is calculated using the spherical Haversine formula:
$$\text{distance} \le \text{radius\_meters} \implies \text{INSIDE}, \quad \text{distance} > \text{radius\_meters} \implies \text{OUTSIDE}$$

State transition matrix:
| Previous State | Current State | Transition Classification | Alert Fired? |
|---|---|---|---|
| `null` (Unknown) | `inside` | `initial` | **No** (prevents false alarm on initial fix) |
| `null` (Unknown) | `outside` | `initial` | **No** |
| `inside` | `outside` | `exit` | **Yes:** `geofence_exit` alert + FCM |
| `outside` | `inside` | `enter` | **Yes:** `geofence_enter` alert + FCM |
| `inside` | `inside` | `none` | **No** |
| `outside` | `outside` | `none` | **No** |

### 5.3 Heartbeat & Offline Detection
- An asynchronous loop (`_heartbeat_loop`) executes every `DEVICE_HEARTBEAT_CHECK_INTERVAL_SECONDS` (60s).
- Query finds devices where `status != "offline"`, `status != "unregistered"`, `status != "disabled"`, and `last_seen != null`.
- Comparison is strict: a device is marked offline only when:
  $$(\text{now\_utc} - \text{last\_seen}) > \text{DEVICE\_OFFLINE\_THRESHOLD\_SECONDS}$$
- When marked offline:
  - `device.status` flips to `"offline"`.
  - A `device_offline` alert is persisted.
  - An FCM notification is sent to the pet owner.

---

## 6. Complete API Reference

### 6.1 System Health
#### `GET /health`
- **Auth:** None
- **Response `200`:**
  ```json
  {
    "status": "ok",
    "message": "Pet tracker backend API is running"
  }
  ```

---

### 6.2 Authentication
#### `GET /api/v1/auth/me`
- **Auth:** Bearer `<Firebase ID Token>`
- **Description:** Syncs current Firebase user into the `users/{uid}` collection and returns profile info.
- **Response `200`:**
  ```json
  {
    "uid": "FIREBASE_UID_123",
    "email": "owner@example.com",
    "display_name": "Alex Smith"
  }
  ```

---

### 6.3 Pets Management
#### `POST /api/v1/pets`
- **Auth:** Bearer `<Firebase ID Token>`
- **Request Body:**
  ```json
  {
    "name": "Brownie",
    "species": "Dog",
    "breed": "Golden Retriever",
    "age": 3,
    "photo_url": "https://example.com/brownie.jpg"
  }
  ```
- **Response `201`:**
  ```json
  {
    "id": "pet_auto_id_1",
    "owner_id": "FIREBASE_UID_123",
    "name": "Brownie",
    "species": "Dog",
    "breed": "Golden Retriever",
    "age": 3,
    "photo_url": "https://example.com/brownie.jpg",
    "device_id": null,
    "created_at": "2026-09-28T05:00:00Z",
    "updated_at": "2026-09-28T05:00:00Z"
  }
  ```

#### `GET /api/v1/pets`
- **Auth:** Bearer `<Firebase ID Token>`
- **Response `200`:** List of `PetResponse` objects owned by the authenticated user.

#### `GET /api/v1/pets/{pet_id}`
- **Auth:** Bearer `<Firebase ID Token>`
- **Response `200`:** Single `PetResponse` object. Returns `404` if not found or owned by another user.

#### `PATCH /api/v1/pets/{pet_id}`
- **Auth:** Bearer `<Firebase ID Token>`
- **Request Body:** Partial update fields (`name`, `species`, `breed`, `age`, `photo_url`). Cannot alter `owner_id` or `device_id`.
- **Response `200`:** Updated `PetResponse`.

#### `DELETE /api/v1/pets/{pet_id}`
- **Auth:** Bearer `<Firebase ID Token>`
- **Response `204`:** No Content. *(Note: Unassign any linked tracker before deleting).*

#### `GET /api/v1/pets/{pet_id}/location-history`
- **Auth:** Bearer `<Firebase ID Token>`
- **Query Parameters:**
  - `limit` (integer, default: 100, min: 1, max: 500)
  - `start_time` (ISO8601 string, optional)
  - `end_time` (ISO8601 string, optional)
- **Response `200`:**
  ```json
  [
    {
      "id": "history_auto_id",
      "pet_id": "pet_auto_id_1",
      "device_id": "ESP32_001",
      "latitude": 14.599512,
      "longitude": 120.984222,
      "battery_level": 88,
      "recorded_at": "2026-09-28T05:10:00Z"
    }
  ]
  ```

---

### 6.4 Devices Management & Provisioning
#### `POST /api/v1/devices`
- **Auth:** Bearer `<Firebase ID Token>`
- **Request Body:**
  ```json
  {
    "device_id": "ESP32_TRACKER_01"
  }
  ```
- **Response `201`:** Returns device record with the plain `device_secret` displayed **once**:
  ```json
  {
    "id": "ESP32_TRACKER_01",
    "device_id": "ESP32_TRACKER_01",
    "owner_id": "FIREBASE_UID_123",
    "pet_id": null,
    "status": "unregistered",
    "battery_level": null,
    "current_location": null,
    "last_seen": null,
    "last_location_update": null,
    "low_battery_alert_active": false,
    "created_at": "2026-09-28T05:00:00Z",
    "updated_at": "2026-09-28T05:00:00Z",
    "device_secret": "sec_7a8f9c2d1e0b4a5f"
  }
  ```

#### `POST /api/v1/devices/setup`
- **Auth:** Bearer `<Firebase ID Token>`
- **Request Body:**
  ```json
  {
    "device_id": "ESP32_TRACKER_01",
    "backend_url": "http://192.168.1.100:8000"
  }
  ```
- **Response `201`:** Complete provisioning bundle including setup hotspot SSID (`PET_TRACKER_SETUP_<device_id>`) and full telemetry URL.

#### `GET /api/v1/devices` & `GET /api/v1/devices/{device_id}`
- **Auth:** Bearer `<Firebase ID Token>`
- **Response `200`:** Device objects (excludes `device_secret` and `device_secret_hash`).

#### `POST /api/v1/devices/{device_id}/assign`
- **Auth:** Bearer `<Firebase ID Token>`
- **Request Body:** `{"pet_id": "pet_auto_id_1"}`
- **Response `200`:** Updated device object. Enforces 1:1 relationship between pet and tracker. Returns `409` if either already has an assignment.

#### `DELETE /api/v1/devices/{device_id}/assignment`
- **Auth:** Bearer `<Firebase ID Token>`
- **Response `200`:** Removes assignment from both device and pet.

---

### 6.5 Telemetry Ingestion (ESP32)
#### `POST /api/v1/device/telemetry`
- **Auth:** Device Secret (`device_id` + `device_secret` in body)
- **Request Body:**
  ```json
  {
    "device_id": "ESP32_TRACKER_01",
    "device_secret": "sec_7a8f9c2d1e0b4a5f",
    "latitude": 14.599512,
    "longitude": 120.984222,
    "battery_level": 85
  }
  ```
- **Responses:**
  - `200 OK`: `{"message": "Telemetry received successfully"}`
  - `401 Unauthorized`: Invalid device credentials
  - `409 Conflict`: Device is not assigned to a pet
  - `422 Unprocessable Entity`: Coordinates or battery out of range

---

### 6.6 Geofences (Safe Zones)
#### `POST /api/v1/geofences`
- **Auth:** Bearer `<Firebase ID Token>`
- **Request Body:**
  ```json
  {
    "pet_id": "pet_auto_id_1",
    "name": "Home Backyard",
    "center": {
      "latitude": 14.599512,
      "longitude": 120.984222
    },
    "radius_meters": 75.0,
    "enabled": true
  }
  ```
- **Response `201`:** Created geofence object with initial `last_state = null`.

#### `GET /api/v1/geofences` & `GET /api/v1/geofences/{geofence_id}`
- **Auth:** Bearer `<Firebase ID Token>`
- **Response `200`:** Returns user's geofences.

#### `PATCH /api/v1/geofences/{geofence_id}`
- **Auth:** Bearer `<Firebase ID Token>`
- **Request Body:** Modifiable fields: `name`, `center`, `radius_meters`, `enabled`.
- **Response `200`:** Updated geofence object.

#### `DELETE /api/v1/geofences/{geofence_id}`
- **Auth:** Bearer `<Firebase ID Token>`
- **Response `204`:** No Content.

---

### 6.7 Alerts Inbox
#### `GET /api/v1/alerts`
- **Auth:** Bearer `<Firebase ID Token>`
- **Query Parameters:**
  - `pet_id` (string, optional)
  - `type` (enum, optional: `device_offline`, `device_online`, `geofence_exit`, `geofence_enter`, `low_battery`)
  - `read` (boolean, optional)
- **Response `200`:** List of alert records.

#### `PATCH /api/v1/alerts/{alert_id}`
- **Auth:** Bearer `<Firebase ID Token>`
- **Request Body:** `{"read": true}`
- **Response `200`:** Acknowledged alert object.

#### `DELETE /api/v1/alerts/{alert_id}`
- **Auth:** Bearer `<Firebase ID Token>`
- **Response `204`:** No Content.

---

### 6.8 Notifications (FCM Tokens)
#### `POST /api/v1/notifications/tokens`
- **Auth:** Bearer `<Firebase ID Token>`
- **Request Body:**
  ```json
  {
    "token": "eXamPle_Fcm_ToKen_StRiNg",
    "platform": "android",
    "device_name": "Pixel 8 Pro"
  }
  ```
- **Response `201`:**
  ```json
  {
    "message": "Notification token registered successfully",
    "token_id": "sha256_hash_of_fcm_token"
  }
  ```

#### `DELETE /api/v1/notifications/tokens/{token_id}`
- **Auth:** Bearer `<Firebase ID Token>`
- **Response `204`:** Deactivates token (soft-delete, `active=false`).

---

### 6.9 Places & Administrative Geocoding
#### `GET /api/v1/places/countries`
- Returns: `[{"code": "PH", "name": "Philippines"}]`.

#### `GET /api/v1/places/provinces?country_code=PH`
- Returns Philippine provinces and NCR from the PSGC API.

#### `GET /api/v1/places/cities?province_code=130000000`
- Returns cities and municipalities under the given province code.

#### `GET /api/v1/places/barangays?city_code=133900000`
- Returns barangays under the given city/municipality code.

#### `GET /api/v1/places/search?country=Philippines&province=Metro+Manila&city=Manila&barangay=Barangay+659&limit=1`
- Resolves administrative address to GPS coordinates using OpenStreetMap Nominatim with memory caching.

---

## 7. Testing & Quality Assurance

The backend includes a comprehensive Pytest test suite covering repositories, authentication guards, geofence transitions, heartbeat timers, and telemetry ingestion.

Run the test suite:
```powershell
pytest -v
```
