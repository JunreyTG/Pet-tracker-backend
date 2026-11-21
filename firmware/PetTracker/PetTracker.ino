#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <TinyGPSPlus.h>
#include <WebServer.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <esp_random.h>
#include <time.h>

#include "Dashboard.h"
#include "TrustRoots.h"

constexpr char CloudOrigin[] = "https://pet-tracker-backend-gamma.vercel.app";
constexpr char NtfyTopic[] = ""; // Optional: leave blank for app notifications only.
constexpr char FirmwareVersion[] = "1.0.0";
constexpr char Protocol[] = "pet-tracker-c3-v1";
constexpr char AccessHeader[] = "X-Tracker-Key";
constexpr uint8_t GpsRx = 4, GpsTx = 5, Led = 8, Boot = 9;
constexpr uint32_t FixMaxAge = 5000, WifiTimeout = 20000;
constexpr size_t TrailSize = 120;

struct Point { double lat, lng; };
struct Home { double lat, lng, radius; };
HardwareSerial gpsSerial(1);
TinyGPSPlus gps;
Preferences prefs;
WebServer server(80);
String deviceId, apName, apKey, ssid, wifiPassword, deviceSecret, setupNonce;
Home home{0, 0, 50};
Point trail[TrailSize];
size_t trailHead = 0, trailCount = 0;
uint32_t lastTrail = 0, wifiLostAt = 0, lastWifiRetry = 0, nextReport = 0, restartAt = 0;
bool homeSet = false, fenceKnown = false, outside = false, storageReady = false;
bool apActive = false, forceSetup = false, stationConnected = false;
int lastCloudCode = 0;

bool hasFix() {
  return gps.location.isValid() && gps.location.age() < FixMaxAge;
}

bool usableFix() {
  return hasFix() && gps.hdop.isValid() && gps.hdop.age() < FixMaxAge && gps.hdop.hdop() <= 5;
}

double distanceHome() {
  return homeSet && hasFix()
    ? TinyGPSPlus::distanceBetween(gps.location.lat(), gps.location.lng(), home.lat, home.lng) : -1;
}

bool hexNonce(const String& nonce) {
  if (nonce.length() != 32) return false;
  for (size_t i = 0; i < nonce.length(); ++i) {
    const char c = nonce[i];
    if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return false;
  }
  return true;
}

bool onSetupNetwork() {
  return apActive && server.client().localIP() == WiFi.softAPIP();
}

bool authorizedLocalEdit() {
  return !apKey.isEmpty() && server.header(AccessHeader) == apKey;
}

void sendText(int status, const String& text) {
  server.sendHeader("Cache-Control", "no-store");
  server.send(status, "text/plain; charset=utf-8", text);
}

void sendJson(JsonDocument& doc, int status = 200) {
  String body;
  serializeJson(doc, body);
  server.sendHeader("Cache-Control", "no-store");
  server.send(status, "application/json", body);
}

void loadSettings() {
  if (!storageReady) return;
  apKey = prefs.getString("ap_key", "");
  if (apKey.length() != 16) {
    char key[17];
    const auto first = (unsigned long)esp_random(), second = (unsigned long)esp_random();
    snprintf(key, sizeof(key), "%08lx%08lx", first, second);
    apKey = key;
    prefs.putString("ap_key", apKey);
  }
  JsonDocument doc;
  if (!deserializeJson(doc, prefs.getString("config", ""))) {
    ssid = doc["wifi_ssid"] | "";
    wifiPassword = doc["wifi_password"] | "";
    deviceSecret = doc["device_secret"] | "";
    setupNonce = doc["setup_nonce"] | "";
  }
  homeSet = prefs.getBytesLength("home") == sizeof(Home) &&
            prefs.getBytes("home", &home, sizeof(Home)) == sizeof(Home);
  if (!homeSet) home = {0, 0, 50};
}

void startHotspot() {
  if (apActive || apKey.isEmpty()) return;
  WiFi.mode(forceSetup || ssid.isEmpty() ? WIFI_AP : WIFI_AP_STA);
  apActive = WiFi.softAP(apName.c_str(), apKey.c_str(), 1, 0, 2);
  if (apActive) Serial.printf("Setup Wi-Fi: %s | password: %s | http://%s/\n",
      apName.c_str(), apKey.c_str(), WiFi.softAPIP().toString().c_str());
  else Serial.println("Could not start setup hotspot.");
}

void maintainWifi(uint32_t now) {
  static uint32_t bootHeldAt = 0;
  if (digitalRead(Boot) == HIGH) bootHeldAt = 0;
  else if (bootHeldAt == 0) bootHeldAt = now;
  else if (!forceSetup && now - bootHeldAt >= 4000 && restartAt == 0) {
    forceSetup = true;
    WiFi.mode(WIFI_AP);
    startHotspot();
  }
  if (forceSetup) {
    if (!apActive && now - lastWifiRetry >= 10000) {
      lastWifiRetry = now;
      startHotspot();
    }
    return;
  }
  if (WiFi.status() == WL_CONNECTED) {
    if (!stationConnected) {
      stationConnected = true;
      if (apActive) {
        WiFi.softAPdisconnect(true);
        apActive = false;
      }
      nextReport = now;
      lastCloudCode = 0;
      configTime(0, 0, "time.google.com", "pool.ntp.org");
      Serial.printf("Dashboard: http://%s/\n", WiFi.localIP().toString().c_str());
    }
    return;
  }
  if (stationConnected) {
    stationConnected = false;
    wifiLostAt = now;
  }
  if (!apActive && now - wifiLostAt >= WifiTimeout && now - lastWifiRetry >= 10000) {
    lastWifiRetry = now;
    startHotspot();
  }
  if (now - lastWifiRetry >= 60000) {
    lastWifiRetry = now;
    WiFi.reconnect();
  }
}

int postHttps(const String& url, const String& body, const char* contentType, const char* title = nullptr) {
  WiFiClientSecure client;
  client.setCACert(TrustRoots);
  client.setHandshakeTimeout(4);
  HTTPClient http;
  http.setConnectTimeout(4000);
  http.setTimeout(4000);
  http.setFollowRedirects(HTTPC_DISABLE_FOLLOW_REDIRECTS);
  if (!http.begin(client, url)) return -1;
  http.addHeader("Content-Type", contentType);
  if (title) http.addHeader("Title", title);
  const int code = http.POST(body);
  http.end();
  return code;
}

bool cloudNetworkReady() {
  return !forceSetup && WiFi.status() == WL_CONNECTED && time(nullptr) >= 1704067200;
}

void reportCloud(uint32_t now) {
  if (restartAt || deviceSecret.isEmpty() || !cloudNetworkReady() || int32_t(now - nextReport) < 0) return;
  const bool fix = usableFix();
  JsonDocument doc;
  doc["device_id"] = deviceId;
  doc["device_secret"] = deviceSecret;
  doc["setup_nonce"] = setupNonce;
  if (fix) {
    doc["latitude"] = gps.location.lat();
    doc["longitude"] = gps.location.lng();
  }
  String body;
  serializeJson(doc, body);
  lastCloudCode = postHttps(String(CloudOrigin) + (fix ? "/api/v1/device/telemetry" : "/api/v1/device/heartbeat"),
                            body, "application/json");
  const bool ok = lastCloudCode >= 200 && lastCloudCode < 300;
  nextReport = millis() + (ok ? (fix ? 20000 : 10000) : 30000);
  Serial.printf("Cloud %s: %d\n", fix ? "GPS" : "heartbeat", lastCloudCode);
}

void updateLocalTracking(uint32_t now) {
  if (!usableFix()) return;
  const Point p{gps.location.lat(), gps.location.lng()};
  if (trailCount == 0 || now - lastTrail >= 10000) {
    const auto& prev = trail[(trailHead + TrailSize - 1) % TrailSize];
    if (trailCount == 0 || TinyGPSPlus::distanceBetween(p.lat, p.lng, prev.lat, prev.lng) >= 5) {
      trail[trailHead] = p;
      trailHead = (trailHead + 1) % TrailSize;
      if (trailCount < TrailSize) ++trailCount;
      lastTrail = now;
    }
  }
  if (!homeSet) return;
  const double distance = distanceHome();
  const bool nextOutside = outside ? distance >= home.radius * 0.8 : distance > home.radius;
  const bool moved = fenceKnown && outside != nextOutside;
  outside = nextOutside;
  fenceKnown = true;
  if (moved) {
    Serial.println(outside ? "Left local Home zone" : "Returned to local Home zone");
    if (NtfyTopic[0] && cloudNetworkReady()) {
      const int code = postHttps(String("https://ntfy.sh/") + NtfyTopic,
          String(int(distance)) + " m from local Home", "text/plain",
          outside ? "Pet left safe zone" : "Pet returned to safe zone");
      Serial.printf("ntfy: %d\n", code);
    }
  }
}

void handleStatus() {
  JsonDocument doc;
  const bool fix = hasFix();
  doc["protocol"] = Protocol;
  doc["firmware_version"] = FirmwareVersion;
  doc["device_id"] = deviceId;
  doc["setup_mode"] = onSetupNetwork() && restartAt == 0;
  doc["fix"] = fix;
  doc["usable_fix"] = usableFix();
  if (fix) {
    doc["lat"] = gps.location.lat();
    doc["lng"] = gps.location.lng();
    if (gps.speed.isValid() && gps.speed.age() < FixMaxAge) doc["speed"] = gps.speed.kmph();
  }
  doc["chars"] = gps.charsProcessed();
  doc["sats"] = gps.satellites.isValid() ? gps.satellites.value() : 0;
  if (gps.hdop.isValid() && gps.hdop.age() < FixMaxAge) doc["hdop"] = gps.hdop.hdop();
  doc["homeSet"] = homeSet;
  if (homeSet) {
    doc["homeLat"] = home.lat;
    doc["homeLng"] = home.lng;
  }
  doc["radius"] = home.radius;
  doc["dist"] = distanceHome();
  doc["outside"] = outside;
  doc["fence_known"] = fenceKnown;
  doc["cloud_code"] = lastCloudCode;
  sendJson(doc);
}

void handleTrail() {
  String body = "[";
  body.reserve(TrailSize * 32 + 2);
  const size_t start = (trailHead + TrailSize - trailCount) % TrailSize;
  for (size_t i = 0; i < trailCount; i++) {
    const Point& p = trail[(start + i) % TrailSize];
    if (i) body += ',';
    body += '[' + String(p.lat, 6) + ',' + String(p.lng, 6) + ']';
  }
  body += ']';
  server.sendHeader("Cache-Control", "no-store");
  server.send(200, "application/json", body);
}

void handleConfig() {
  if (!onSetupNetwork() || !authorizedLocalEdit()) {
    sendText(403, "Join the setup hotspot and supply its setup password.");
    return;
  }
  if (restartAt) { sendText(409, "Tracker restarting."); return; }
  const String body = server.arg("plain");
  JsonDocument doc;
  if (body.length() > 1536 || deserializeJson(doc, body)) {
    sendText(400, "Invalid configuration JSON."); return;
  }
  const String suppliedId = doc["device_id"] | "", suppliedOrigin = doc["backend_url"] | "";
  const String name = doc["wifi_ssid"] | "", password = doc["wifi_password"] | "";
  const String secret = doc["device_secret"] | "", nonce = doc["setup_nonce"] | "";
  if (suppliedId != deviceId || suppliedOrigin != CloudOrigin || name.isEmpty() || name.length() > 32 ||
      !doc["wifi_password"].is<const char*>() || (!password.isEmpty() && (password.length() < 8 || password.length() > 63)) ||
      secret.isEmpty() || secret.length() > 256 || !hexNonce(nonce)) {
    sendText(422, "Check tracker code, backend origin and 2.4 GHz Wi-Fi credentials."); return;
  }
  JsonDocument saved;
  saved["wifi_ssid"] = name;
  saved["wifi_password"] = password;
  saved["device_secret"] = secret;
  saved["setup_nonce"] = nonce;
  String record;
  serializeJson(saved, record);
  if (!storageReady || prefs.putString("config", record) != record.length()) {
    sendText(500, "Could not save settings."); return;
  }
  JsonDocument reply;
  reply["accepted"] = true;
  reply["device_id"] = deviceId;
  sendJson(reply, 202);
  restartAt = millis() + 800;
}

void saveHome(const Home& next) {
  if (!storageReady || prefs.putBytes("home", &next, sizeof(next)) != sizeof(next)) {
    sendText(500, "Could not save Home zone."); return;
  }
  home = next;
  homeSet = true;
  fenceKnown = false;
  outside = false;
  sendText(200, "Home zone saved.");
}

void handleSetHome() {
  if (!authorizedLocalEdit()) { sendText(403, "Enter your tracker setup password."); return; }
  if (!usableFix()) { sendText(409, "Wait for a usable GPS fix before setting Home."); return; }
  saveHome({gps.location.lat(), gps.location.lng(), home.radius});
}

void handleRadius() {
  if (!authorizedLocalEdit()) { sendText(403, "Enter your tracker setup password."); return; }
  if (!homeSet) { sendText(409, "Set your Home position first."); return; }
  const String value = server.arg("m");
  char* end = nullptr;
  const double radius = strtod(value.c_str(), &end);
  if (end == value.c_str() || *end || !isfinite(radius) || radius < 10 || radius > 5000) {
    sendText(400, "Radius must be 10–5000 m."); return;
  }
  saveHome({home.lat, home.lng, radius});
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  pinMode(Led, OUTPUT);
  pinMode(Boot, INPUT_PULLUP);
  gpsSerial.setRxBufferSize(8192);
  gpsSerial.begin(9600, SERIAL_8N1, GpsRx, GpsTx);

  char id[16];
  snprintf(id, sizeof(id), "PT-%012llX", (unsigned long long)(ESP.getEfuseMac() & 0xFFFFFFFFFFFFULL));
  deviceId = id;
  apName = "PetTracker-" + deviceId.substring(deviceId.length() - 6);
  WiFi.persistent(false);
  WiFi.mode(WIFI_STA); // Enable the radio before generating the random hotspot key.
  Serial.printf("Tracker code: %s | firmware: %s\n", id, FirmwareVersion);
  storageReady = prefs.begin("pettracker", false);
  loadSettings();
  wifiLostAt = millis();
  if (ssid.isEmpty()) {
    forceSetup = true;
    startHotspot();
  } else {
    WiFi.setAutoReconnect(true);
    WiFi.begin(ssid.c_str(), wifiPassword.c_str());
  }

  const char* headers[] = {AccessHeader};
  server.collectHeaders(headers, 1);
  server.on("/", HTTP_GET, [] { server.send_P(200, "text/html; charset=utf-8", Dashboard); });
  server.on("/api/status", HTTP_GET, handleStatus);
  server.on("/api/trail", HTTP_GET, handleTrail);
  server.on("/config", HTTP_POST, handleConfig);
  server.on("/api/sethome", HTTP_POST, handleSetHome);
  server.on("/api/radius", HTTP_POST, handleRadius);
  server.begin();
}

void loop() {
  while (gpsSerial.available()) gps.encode(gpsSerial.read());
  const uint32_t now = millis();
  if (restartAt && int32_t(now - restartAt) >= 0) ESP.restart();
  maintainWifi(now);
  server.handleClient();
  updateLocalTracking(now);
  const bool blink = outside ? (now / 150) % 2 : hasFix() ? now % 2000 < 80 : (now / 1000) % 2;
  digitalWrite(Led, blink ? LOW : HIGH);
  reportCloud(now);
  delay(2);
}
