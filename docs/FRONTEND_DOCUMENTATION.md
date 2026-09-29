# Pet Tracker App — Technical & UI Documentation

> **Client Application:** `pet-tracker-app`  
> **Framework:** Flutter (Dart SDK `^3.12.2`)  
> **State Management & Routing:** GetX (`get: ^4.7.3`)  
> **Target Platforms:** Android, iOS, Web, Windows, macOS, Linux  
> **Map Engine:** `flutter_map` (OpenStreetMap) + OSRM Road Snapping  
> **Authentication:** `firebase_auth` (`6.7.0`)  
> **Push Notifications:** `firebase_messaging` (`16.7.0`)

---

## 1. System Overview & Architecture

The `pet-tracker-app` is a cross-platform Flutter application providing pet owners with real-time GPS tracking, safe zone perimeter controls, instant safety alerts, and hardware onboarding for ESP32 tracking collars.

### Core Capabilities
- **Live Location Tracking:** Displays current pet coordinates on an interactive OpenStreetMap view with an automatic 15-second polling loop.
- **Historical Trail & Road Snapping:** Fetches up to 24 hours of GPS telemetry points and converts raw coordinates into smooth, road-snapped polylines using the OSRM (Open Source Routing Machine) routing engine.
- **Geofence Safe Zones:** Create and manage circular safe zones with interactive radius sliders (in meters) and visual map overlays.
- **Safety Alerts Inbox:** Real-time push notifications and an in-app inbox for safety events (`device_offline`, `device_online`, `geofence_exit`, `geofence_enter`, `low_battery`).
- **Hardware Wi-Fi Provisioning:** Guides owners through connecting their phone or computer to the ESP32 setup hotspot (`PET_TRACKER_SETUP_<id>`) and submitting Wi-Fi and backend server credentials to `http://192.168.4.1/config`.
- **Philippine Administrative Address Selector:** Hierarchical location picker (Country $\rightarrow$ Province $\rightarrow$ City $\rightarrow$ Barangay) utilizing the PSGC API to quickly jump and lock the map focus to specific neighborhoods.

---

## 2. Project Structure & Code Organization

```text
lib/
├── app/
│   ├── bindings/
│   │   └── initial_binding.dart    # GetX dependency injection (Repositories, Controllers)
│   ├── routes/
│   │   ├── app_pages.dart          # Page routing definitions (GetPage)
│   │   └── app_routes.dart         # Static route name constants
│   └── theme/
│       └── app_theme.dart          # Custom Material 3 Light and Dark themes
├── core/
│   ├── api/
│   │   ├── api_client.dart         # HTTP client with Bearer token & 401 retry
│   │   └── api_exception.dart      # Strongly-typed API error representation
│   ├── constants/
│   │   └── app_config.dart         # Backend URL resolver and environment configuration
│   ├── services/
│   │   └── notification_service.dart # Firebase Cloud Messaging listener and dispatcher
│   ├── utils/
│   │   └── navigation_args.dart    # Helper types for cross-screen arguments
│   └── widgets/
│       └── app_scaffold.dart       # Responsive shell with floating bottom navigation
├── data/
│   ├── models/
│   │   └── models.dart             # Typed data models and resilient JSON parsers
│   └── repositories/
│       └── repositories.dart       # API repository layer communicating with FastAPI
├── features/
│   ├── alerts/
│   │   └── views/alerts_screen.dart # Inbox with filtering by unread, type, and pet
│   ├── auth/
│   │   ├── controllers/auth_controller.dart # Firebase auth state and login/register logic
│   │   └── views/
│   │       ├── login_screen.dart   # Email/password login form
│   │       └── register_screen.dart # User registration form
│   ├── devices/
│   │   └── views/
│   │       ├── devices_screen.dart         # Tracker list and assignment controls
│   │       ├── device_details_screen.dart  # Secret display and tracker status
│   │       └── device_wifi_setup_screen.dart # ESP32 hotspot Wi-Fi provisioning wizard
│   ├── geofences/
│   │   └── views/geofences_screen.dart     # Safe zone management modal and radius slider
│   ├── home/
│   │   ├── controllers/app_data_controller.dart # Shared reactive data cache and refresh
│   │   └── views/home_screen.dart          # Central dashboard with pet hero card & stats
│   ├── pets/
│   │   └── views/
│   │       ├── pets_screen.dart        # Pet card grid with status badges
│   │       ├── pet_details_screen.dart # Detailed profile, battery level, device links
│   │       └── pet_form_screen.dart    # Create and edit pet form
│   ├── profile/
│   │   └── views/profile_screen.dart   # User account information and sign-out
│   └── tracking/
│       ├── controllers/tracking_controller.dart # Map controller, live poll, OSRM router
│       └── views/tracking_screen.dart           # Interactive OpenStreetMap & controls
├── firebase_options.dart           # Platform-specific Firebase credentials
└── main.dart                       # App entrypoint and AuthGate initialization
```

---

## 3. Setup, Configuration & Running

### 3.1 Prerequisites
- Flutter SDK 3.x with Dart SDK `^3.12.2`
- Android SDK (for Android), Xcode (for iOS/macOS), or Chrome (for Web)
- Running instance of `pet-tracker-backend`

### 3.2 Installation

```powershell
# Navigate to app directory
cd pet-tracker-app

# Install Dart/Flutter packages
flutter pub get
```

### 3.3 Target Environment Configuration (`--dart-define`)

The app dynamically resolves the backend URL via the `PET_TRACKER_API_URL` compile-time environment variable defined in [`lib/core/constants/app_config.dart`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/core/constants/app_config.dart).

```powershell
# 1. Web or Desktop against local backend
flutter run -d chrome --dart-define=PET_TRACKER_API_URL=http://127.0.0.1:8000

# 2. Android Emulator (uses Android host loopback 10.0.2.2)
flutter run -d android --dart-define=PET_TRACKER_API_URL=http://10.0.2.2:8000

# 3. Physical Mobile Device (use your computer's local Wi-Fi IP)
flutter run -d <device_id> --dart-define=PET_TRACKER_API_URL=http://192.168.1.100:8000
```

### 3.4 Static Analysis & Tests

```powershell
flutter analyze
flutter test
```

---

## 4. Core Architecture & Services

### 4.1 Networking & Authentication Layer ([`ApiClient`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/core/api/api_client.dart))
The custom `ApiClient` wraps Dart's `http` package and handles:
- **Bearer Token Injection:** Retrieves the current Firebase user token via `FirebaseAuth.instance.currentUser?.getIdToken()` and sets the `Authorization: Bearer <token>` header on every outgoing request.
- **Automatic 401 Retry:** If a request returns `401 Unauthorized`, `ApiClient` forces a token refresh via `user.getIdToken(true)` and transparently replays the request once before reporting an error.
- **Typed Exception Handling:** Converts raw HTTP error codes and FastAPI error bodies into clean, human-readable `ApiException` instances.

### 4.2 Reactive State Architecture ([GetX](https://pub.dev/packages/get))
- **`AuthController`:** Observes the `FirebaseAuth.instance.authStateChanges()` stream. It automatically routes the user between authentication screens and the dashboard via `AuthGate` in `main.dart`. Upon login, it invokes `GET /api/v1/auth/me` to sync the user profile.
- **`AppDataController`:** Serves as the central data store. It caches reactive lists of `pets`, `devices`, `geofences`, and `alerts`. When the user logs in, `ever(auth.backendUser, ...)` triggers a concurrent `Future.wait([petsRepo.list(), devicesRepo.list(), ...])` batch load. It also tracks the `unreadCount` badge for alerts.
- **Resilient Model Parsing:** Uses [`parseModelList`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/data/repositories/repositories.dart#L6-L23) across all repositories. If a single document in Firestore is malformed, it is safely skipped rather than crashing the UI with a parsing error.

### 4.3 Push Notifications ([`NotificationService`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/core/services/notification_service.dart))
- Obtains the FCM device registration token using `FirebaseMessaging.instance.getToken()`.
- Registers the token with the backend at `POST /api/v1/notifications/tokens`.
- Listens to incoming FCM foreground and background messages. When an alert arrives, it triggers an immediate refresh of `AppDataController` and navigates the user directly to the relevant alert or pet screen.

---

## 5. Feature Modules & UI Workflows

### 5.1 Home Dashboard ([`HomeScreen`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/features/home/views/home_screen.dart))
- **Pet Hero Card:** Highlights the selected pet, live tracker connectivity (`online`, `offline`, `unregistered`), current battery level with color-coded battery indicators, and a one-tap shortcut to open the live map.
- **Overview Metrics:** Displays total active pets and unread alert count chips.
- **Quick Action Grid:** Fast navigation to Pets, Geo-fencing, Alerts, and Devices.

### 5.2 Live Tracking & History ([`TrackingScreen`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/features/tracking/views/tracking_screen.dart))
Operated by [`TrackingController`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/features/tracking/controllers/tracking_controller.dart):
- **OpenStreetMap Canvas:** Powered by `flutter_map` without proprietary map API keys.
- **Live Tracking Mode:** Automatically polls the assigned tracker (`GET /api/v1/devices/{id}`) every 15 seconds. Renders a distinct custom marker at the pet's current coordinates.
- **History Mode:** Queries `GET /api/v1/pets/{id}/location-history` for the last 24 hours of recorded movement.
- **Road Snapping via OSRM:** Raw GPS points often cut through buildings. The controller feeds waypoints into `https://router.project-osrm.org/route/v1/driving/...` to render realistic street-following path lines.
- **Geofence Overlays:** Projects circular polygons on the map indicating safe zone boundaries.
- **Philippine Geographic Focus Picker:** An address selector allowing owners to filter by Country $\rightarrow$ Province $\rightarrow$ City $\rightarrow$ Barangay. The app resolves coordinates via `GET /api/v1/places/search` and persists the preferred map focus in local `SharedPreferences`.

### 5.3 Pet Management ([`PetsScreen`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/features/pets/views/pets_screen.dart))
- View all registered pets in card layouts with species icons, age, and assigned collar status.
- Add or edit pets using [`PetFormScreen`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/features/pets/views/pet_form_screen.dart) (`name`, `species`, `breed`, `age`, `photo_url`).
- Dedicated [`PetDetailsScreen`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/features/pets/views/pet_details_screen.dart) displaying telemetry details, last seen timestamp, and device unassignment actions.

### 5.4 Tracker Onboarding & Wi-Fi Provisioning ([`DeviceWifiSetupScreen`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/features/devices/views/device_wifi_setup_screen.dart))
The app provides an interactive hardware provisioning wizard for ESP32 collars:
1. **Step 1: Register Tracker:** Calls `POST /api/v1/devices` or `POST /api/v1/devices/setup`. Displays the generated `device_secret` once and renders a QR code.
2. **Step 2: Connect to ESP32 Hotspot:** The physical ESP32 tracker boots into Access Point (AP) mode broadcasting an SSID named `PET_TRACKER_SETUP_<device_id>`. The user connects their phone or PC to this Wi-Fi network.
3. **Step 3: Transfer Settings:** The user inputs the home Wi-Fi SSID, password, and the backend server IP. The app sends an HTTP POST request to the tracker's onboard web server at:
   ```text
   http://192.168.4.1/config
   ```
   Payload:
   ```json
   {
     "device_id": "ESP32_001",
     "device_secret": "sec_xxxx",
     "wifi_ssid": "Home_WiFi",
     "wifi_password": "secret_password",
     "backend_url": "http://192.168.1.100:8000"
   }
   ```
4. **Step 4: Verification:** The tracker connects to the home Wi-Fi, submits its first telemetry packet, and transitions to `online` status.

### 5.5 Safe Zone Geofencing ([`GeofencesScreen`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/features/geofences/views/geofences_screen.dart))
- Lists all active and inactive safe zones.
- Interactive creation modal: select the pet, name the zone, define center coordinates, and set the radius using a slider (50m to 1,000m).
- Toggle zones on/off instantly without deleting them.

### 5.6 Alerts Inbox ([`AlertsScreen`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/features/alerts/views/alerts_screen.dart))
- Filter chips: All, Unread Only, or filtered by event type (`geofence_exit`, `device_offline`, `low_battery`, etc.).
- Swipe or tap to mark as read (`PATCH /api/v1/alerts/{id}`).
- Delete dismissed alerts.

---

## 6. Design System & Theme ([`AppTheme`](file:///c:/Users/Admin/Desktop/Pet_tracker_system/pet-tracker-app/lib/app/theme/app_theme.dart))

The UI follows modern Material 3 guidelines:
- **Primary Color:** Forest Teal (`#00897B`)
- **Status Colors:**
  - Online / Active: Emerald Green (`#43A047`)
  - Alerts / Warnings: Vivid Amber / Orange (`#F57C00`)
  - Danger / Breaches: Crimson Red (`#E53935`)
- **Floating Navigation Bar:** Rounded capsule card with elevation shadows floating above screen content.
- **Card Styling:** Rounded corners (16px–24px) with subtle tinted borders for high contrast and readability outdoors.
