# ESP32-C3 Pet Tracker

This firmware runs on the **ESP32-C3 Super Mini** with a **NEO-6M** GPS. It serves a local dashboard and reports to the same cloud API as the Flutter app.

## Wiring and build

| GPS module | ESP32-C3 |
| --- | --- |
| VCC | 3.3 V (for the module in this setup; check your breakout's voltage requirements) |
| GND | GND |
| TX | GPIO 4 (RX) |
| RX | GPIO 5 (TX) |

- Arduino IDE: open `PetTracker/PetTracker.ino`. Select **ESP32C3 Dev Module**, enable **USB CDC On Boot**, and install **TinyGPSPlus** by Mikal Hart and **ArduinoJson** 7. The sketch was compiled with Arduino ESP32 core 3.3.11, TinyGPSPlus 1.0.3, and ArduinoJson 7.4.3.
- Upload and open Serial Monitor at **115200 baud**. Reset the board if you missed its boot output. Keep the `PT-…` tracker code and setup hotspot password available; the password is generated on the tracker and saved in flash.
- The firmware's `CloudOrigin` and the app's `PET_TRACKER_API_URL` must agree. A different HTTPS deployment may require updating `TrustRoots.h`. The tracker uses NTP before making verified TLS requests. There are no home Wi-Fi or cloud credentials in the source.

## Pair a collar

1. Deploy the updated FastAPI backend and install a build of the updated Flutter app. Visit `/ready` on the backend to make sure Firestore is reachable before pairing. Older app or backend builds do not support this pairing protocol.
2. On the phone's normal internet connection, sign in, add a pet, and open **Collars → Add Device**. Name the device, then enter the `PT-` ID from Serial Monitor and tap **Connect Device**. Select the pet if prompted. If the app issues a new tracker recovery key, save it privately for future reconfiguration.
3. Join the `PetTracker-…` hotspot using the password printed by the board. If the tracker is already configured and online, hold **BOOT for four seconds after it starts** to reopen the hotspot. Holding BOOT during power-on can enter the ESP32 download mode instead.
4. Return to the app. It checks the connection automatically and shows the Wi-Fi form after verifying the tracker ID and setup mode with `GET /api/status`. Enter the hotspot password and the tracker’s **2.4 GHz** Wi-Fi details. The app sends `POST /config` locally. The tracker saves the settings and restarts.
5. Return the phone to normal Wi-Fi or mobile data. **Online, waiting for GPS** means the backend received a heartbeat matching this setup. Move the tracker outdoors with a clear view of the sky. **GPS reporting** means it sent a usable fix. If the router cannot be reached, the tracker opens its setup hotspot again after about 20 seconds.

The hosted Flutter web app provides a guide. Use the native app for pairing, so the hosted page does not need access to the tracker’s local HTTP interface.

## Use the local dashboard

On the tracker hotspot, open `http://192.168.4.1/`. On home Wi-Fi, use the LAN address printed by the tracker. The dashboard shows GPS diagnostics, the last cloud response, and a 120-point in-memory trail. Leaflet and OpenStreetMap tiles require internet; the local trail and GPS status work without them. GPS points are available to devices that can reach the dashboard, so keep it on trusted networks and don't expose it to the internet.

Enter the setup hotspot password to set the local **Home** zone or change its radius (10–5,000 m). The Home zone survives a restart. It is separate from safe zones created in the app. To opt into additional local Home alerts, set a private topic in `NtfyTopic` and recompile. Leave it blank for app notifications only. The default ntfy message contains the transition and distance, without GPS coordinates.

## Verify on hardware

- Pair once with an incorrect Wi-Fi password. Verify the `PetTracker-…` hotspot returns and setup can be retried.
- Pair on working Wi-Fi before GPS lock. Verify a heartbeat in the app and no new History point. Take the collar outside, obtain a fix, and verify the Live Map and History update. Restart and verify the saved Wi-Fi and Home zone still work.
- If `chars` stays at zero, check power, ground, and TX/RX wiring. For cloud failures, check the dashboard or Serial Monitor: `401` points to the tracker recovery key, `409` to pet assignment, and a connection failure to Wi-Fi, NTP, or TLS. A `404` on heartbeat usually indicates an old backend deployment.
