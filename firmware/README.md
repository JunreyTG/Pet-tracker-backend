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
- Upload and open Serial Monitor at **115200 baud**. Reset the board if you missed its boot output. Verify that the reported `PT-…` ID matches the package label.
- The firmware's `CloudOrigin` and the app's `PET_TRACKER_API_URL` must agree. A different HTTPS deployment may require updating `TrustRoots.h`. The tracker uses NTP before making verified TLS requests. There are no home Wi-Fi or cloud credentials in the source.

## Prepare new hardware for cloud reporting

1. From `pet-tracker-backend/`, run `python -m app.make_tracker_identity` with the same private `TRACKER_FACTORY_KEY` as the cloud deployment. This generates a random package ID and private per-device reporting secret without creating a database record.
2. Copy `TrackerConfig.example.h` to the git-ignored `TrackerConfig.h`. Set `FactoryDeviceId`, `FactoryDeviceSecret`, `ConfiguredWifiSsid`, and `ConfiguredWifiPassword` before flashing. Print only the ID on the device package. The ESP32-C3 needs a known **2.4 GHz Wi-Fi** network with internet access to send reports; the app does not configure Wi-Fi.
3. For previously configured collars, leave the factory ID and secret blank to reuse the board's original ID and saved credential. Saved Wi-Fi will also be reused unless a new SSID is supplied in the private header. Do not erase flash if relying on saved settings.

## Link a collar in the app

After creating a pet, enter the `PT-…` ID from the package and tap **Connect Device**. You can link on mobile data or any Wi-Fi network, even before powering up the tracker. **Online · waiting for GPS** means the backend received a heartbeat. Move the collar outdoors to get a fix and see **Online · GPS reporting**.

## Use the local dashboard

On the same trusted Wi-Fi network, open the LAN address printed by the tracker. The dashboard shows GPS diagnostics, the last cloud response, and a 120-point in-memory trail. Leaflet and OpenStreetMap tiles require internet; the local trail and GPS status work without them. GPS points are available to devices that can reach the dashboard, so keep it on trusted networks and don't expose it to the internet.

Enter the local dashboard key from Serial Monitor to set the local **Home** zone or change its radius (10–5,000 m). The Home zone survives a restart. It is separate from safe zones created in the app. To opt into additional local Home alerts, set a private topic in `NtfyTopic` and recompile. Leave it blank for app notifications only. The default ntfy message contains the transition and distance, without GPS coordinates.

## Verify on hardware

- Link the package ID before powering up the collar. Verify that the app saves the tracker, even while it is waiting for a report.
- Start the tracker on working Wi-Fi before it has a GPS fix. Verify a heartbeat in the app and no new History point. Take the collar outside, obtain a fix, and verify the Live Map and History update. Restart and verify Wi-Fi and the Home zone still work.
- If `chars` stays at zero, check power, ground, and TX/RX wiring. For cloud failures, check the dashboard or Serial Monitor: `401` indicates the ID hasn't been linked or the reporting secret is invalid, `409` indicates a linked tracker has no pet assignment, and a connection failure points to Wi-Fi, NTP, or TLS.
