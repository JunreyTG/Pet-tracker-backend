import time
import httpx

device_id = "ESP32_1790575298381"
device_secret = "_8SRMsGxR9fliLgSGMHdEkj5qMYt4U1_Pshw6Fx_hSo"
base_url = "http://192.168.0.47:8000/api/v1/device/telemetry"

points = [
    {
        "step": 1,
        "name": "Point 1: Inside Zone (10.0m N from center)",
        "lat": 5.0160520,
        "lon": 119.7699004,
        "battery": 95,
        "distance": "10.0m",
        "zone_status": "INSIDE",
        "event": "Establish Initial INSIDE state (no false alarm)"
    },
    {
        "step": 2,
        "name": "Point 2: Inside Zone (31.2m NE from center)",
        "lat": 5.0162000,
        "lon": 119.7700500,
        "battery": 94,
        "distance": "31.2m",
        "zone_status": "INSIDE",
        "event": "Moving inside safe zone (INSIDE -> INSIDE)"
    },
    {
        "step": 3,
        "name": "Point 3: Outside Zone (88.4m NE - BREACH!)",
        "lat": 5.0166500,
        "lon": 119.7703000,
        "battery": 93,
        "distance": "88.4m",
        "zone_status": "OUTSIDE",
        "event": "BREACH! Geofence Exit Alert + Push Notification"
    },
    {
        "step": 4,
        "name": "Point 4: Farther Outside (170.0m NE from center)",
        "lat": 5.0172000,
        "lon": 119.7708000,
        "battery": 92,
        "distance": "170.0m",
        "zone_status": "OUTSIDE",
        "event": "Roaming outside (OUTSIDE -> OUTSIDE)"
    },
    {
        "step": 5,
        "name": "Point 5: Returned Inside Zone (3.0m NE from center)",
        "lat": 5.0159800,
        "lon": 119.7699200,
        "battery": 90,
        "distance": "3.0m",
        "zone_status": "INSIDE",
        "event": "RETURNED! Geofence Enter Alert + Push Notification"
    }
]

print("=== Starting Simandagit GPS Simulation (5 Waypoints) ===")
print("Geofence Center: 5.0159618, 119.7699004 | Radius: 50.0m\n")

for pt in points:
    print(f"--> Step {pt['step']}: {pt['name']}")
    print(f"    Coords: ({pt['lat']}, {pt['lon']}) | Distance: {pt['distance']} | Status: {pt['zone_status']}")
    
    payload = {
        "device_id": device_id,
        "device_secret": device_secret,
        "latitude": pt["lat"],
        "longitude": pt["lon"],
        "battery_level": pt["battery"]
    }
    
    try:
        response = httpx.post(base_url, json=payload, timeout=15)
        print(f"    Backend Response: HTTP {response.status_code} - {response.json().get('message', response.text)}")
        print(f"    Action Triggered: {pt['event']}\n")
    except Exception as exc:
        print(f"    Error sending telemetry: {exc}\n")
    
    if pt["step"] < len(points):
        time.sleep(3)

print("=== Simulation Completed Successfully! ===")
