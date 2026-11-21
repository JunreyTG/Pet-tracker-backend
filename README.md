# Pet Tracker System

An end-to-end IoT pet tracking and safety ecosystem. This project enables pet owners to monitor their pets in real time using wearable ESP32 GPS hardware collars, a high-performance Python FastAPI cloud backend with Cloud Firestore, and a modern cross-platform Flutter application.

---

## 📁 Repository Structure

```text
Pet_tracker_system/
├── docs/                             # Comprehensive system documentation
│   ├── BACKEND_DOCUMENTATION.md      # FastAPI backend architecture, API reference, & setup
│   └── FRONTEND_DOCUMENTATION.md     # Flutter app architecture, state management, & UI workflows
├── firmware/PetTracker/               # ESP32-C3 + NEO-6M Arduino firmware
├── pet-tracker-backend/              # Python FastAPI + Firebase Admin + Firestore backend
│   ├── app/                          # Routers, schemas, models, and business logic services
│   ├── tests/                        # Pytest automated test suites
│   ├── requirements.txt              # Python dependencies
│   └── README.md                     # Backend quick start
└── pet-tracker-app/                  # Flutter cross-platform mobile/web application
    ├── lib/                          # GetX state management, OpenStreetMap, & feature screens
    ├── test/                         # Widget and unit tests
    ├── pubspec.yaml                  # Flutter package dependencies
    └── README.md                     # Frontend quick start
```

---

## 📖 Detailed Documentation

- **[Backend Technical & API Documentation](docs/BACKEND_DOCUMENTATION.md):** Complete guide to FastAPI endpoints, dual-scheme authentication (Firebase ID Token + PBKDF2 device secrets), Cloud Firestore schemas, Haversine geofencing, heartbeat/offline monitoring, and Firebase Cloud Messaging (FCM).
- **[Frontend Technical & UI Documentation](docs/FRONTEND_DOCUMENTATION.md):** Guide to Flutter app architecture, GetX state management, OpenStreetMap, GPS trails, and ESP32 Wi-Fi provisioning.
- **[Tracker Firmware & Pairing Guide](firmware/README.md):** Wiring, Arduino build, tracker hotspot, cloud setup, and local dashboard.

---

## 🚀 Quick Start

### 1. Start the Backend API

```powershell
cd pet-tracker-backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Verify Firebase credentials
python -m app.firebase.verify

# Run the server
uvicorn app.main:app --reload
```
API Documentation will be available at `http://127.0.0.1:8000/docs`.

### 2. Start the Flutter App

```powershell
cd pet-tracker-app
flutter pub get

# Run on Chrome/Desktop
flutter run -d chrome --dart-define=PET_TRACKER_API_URL=http://127.0.0.1:8000

# Run on Android Emulator
flutter run -d android --dart-define=PET_TRACKER_API_URL=http://10.0.2.2:8000
```
