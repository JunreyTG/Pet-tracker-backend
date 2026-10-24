# Pet Tracker App

Flutter client for the Pet Tracker FastAPI backend. The app uses Firebase Authentication, Firebase Cloud Messaging, GetX routing/state, and REST calls to `pet-tracker-backend`.

## Backend

Start the API from the repository root:

```powershell
cd pet-tracker-backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload
```

Default backend URL: `https://pet-tracker-backend-gamma.vercel.app`. The app adds
`/api/v1` to this URL for API requests. Set `PET_TRACKER_API_URL` to the backend
origin (without `/api/v1`) only when using a different deployment or a local server.

## Run The App

Install dependencies:

```powershell
flutter pub get
```

Run on web or desktop against the local backend:

```powershell
flutter run -d chrome --dart-define=PET_TRACKER_API_URL=http://127.0.0.1:8000
```

For Android emulator, use the host loopback address:

```powershell
flutter run -d android --dart-define=PET_TRACKER_API_URL=http://10.0.2.2:8000
```

For a physical device, replace the URL with the computer's LAN IP.

## Checks

```powershell
flutter analyze
flutter test
```

Backend API details are documented in `BACKEND_SPEC.md`.
