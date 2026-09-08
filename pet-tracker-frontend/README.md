# Pet Tracker Frontend

Flutter frontend prototype for the Pet Tracker system.

## Getting Started

Run commands from this folder, not from the repository root.

```powershell
flutter pub get
.\tool\run_web.ps1
```

The web helper uses `--no-web-resources-cdn` so Flutter serves CanvasKit and web fonts locally instead of loading them from `gstatic.com`. Use this when the browser shows `ERR_NAME_NOT_RESOLVED` for Google font or CanvasKit resources.

The frontend API layer defaults to `http://localhost:8000`. To use a different backend URL later:

```powershell
flutter run -d chrome --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:8000
```

Firebase Auth is configured through `--dart-define` values. Use your Firebase web app config:

```powershell
flutter run -d chrome --no-web-resources-cdn `
  --web-hostname localhost `
  --web-port 5000 `
  --dart-define=API_BASE_URL=http://localhost:8000 `
  --dart-define=FIREBASE_API_KEY=your-api-key `
  --dart-define=FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com `
  --dart-define=FIREBASE_PROJECT_ID=your-project-id `
  --dart-define=FIREBASE_STORAGE_BUCKET=your-project.appspot.com `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your-sender-id `
  --dart-define=FIREBASE_APP_ID=your-web-app-id
```

After signing in, click `Call /auth/me` on the dashboard to verify the backend accepts the Firebase ID token.

To build web output with local resources:

```powershell
.\tool\build_web.ps1
```

The frontend is not connected to the backend yet.
