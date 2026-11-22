/*
  Pet Tracker - ESP32-C3 Super Mini + NEO-6M GPS

  Features
   - Reads GPS with TinyGPSPlus
   - Web dashboard with a live map, trail and status (http://<ip>/)
   - "Home" safe zone (geofence) saved in flash
   - Phone push alert via ntfy.sh when the pet leaves / returns
   - Falls back to its own WiFi hotspot if home WiFi is not reachable

  Wiring (GY-GPS6MV2 -> ESP32-C3)
   VCC -> 3.3V
   GND -> GND
   TX  -> GPIO 4  (ESP32 RX)
   RX  -> GPIO 5  (ESP32 TX)

  Status LEDs (each: GPIO -> 220-330 ohm resistor -> LED anode, LED cathode -> GND)
   GPIO 6  GPS LED     blinking = searching satellites, solid = GPS fix
   GPIO 7  WiFi LED    blinking = connecting, solid = connected,
                       short flash every 2 s = hotspot mode (home WiFi failed)
   GPIO 10 Charge LED  blinking = charging, solid = fully charged, off = no USB power
   Onboard blue LED (GPIO 8) fast blinks while the pet is outside the safe zone.

  Charger status (TP4056 module)
   CHRG  pin -> GPIO 0   (LOW while charging)
   STDBY pin -> GPIO 1   (LOW when fully charged)
   Both pins are open-drain; the ESP32 internal pull-ups are used.

  Arduino IDE
   Board: "ESP32C3 Dev Module" (or "Nologo ESP32C3 Super Mini")
   USB CDC On Boot: Enabled   (otherwise Serial Monitor shows nothing)
   Library: TinyGPSPlus by Mikal Hart

  NOTE: this is a standalone, local-only sketch. It serves its own LAN
  dashboard and sends alerts directly to ntfy.sh, but it does NOT report
  to the pet-tracker-backend cloud API, so pets tracked with this firmware
  will not appear in the Pet Tracker app. Use firmware/PetTracker/PetTracker.ino
  instead for cloud-connected tracking.
*/

#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Preferences.h>
#include <TinyGPSPlus.h>

const char INDEX_HTML[] PROGMEM = R"rawliteral(
<!doctype html><html><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pet Tracker</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
 body{font-family:system-ui,sans-serif;margin:0;background:#f4f4f5;color:#18181b}
 header{padding:12px 16px;background:#18181b;color:#fff;font-weight:600}
 #map{height:55vh}
 .wrap{padding:12px 16px}
 .badge{display:inline-block;padding:4px 10px;border-radius:99px;font-weight:600}
 .ok{background:#dcfce7;color:#166534}.bad{background:#fee2e2;color:#991b1b}.wait{background:#fef9c3;color:#854d0e}
 table{border-collapse:collapse;margin:10px 0}td{padding:3px 12px 3px 0}
 button,input{font-size:15px;padding:6px 10px}
 a{color:#2563eb}
</style></head><body>
<header>🐾 Pet Tracker</header>
<div id="map"></div>
<div class="wrap">
 <span id="state" class="badge wait">Waiting for GPS…</span>
 <table>
  <tr><td>Position</td><td id="pos">-</td></tr>
  <tr><td>Satellites</td><td id="sats">-</td></tr>
  <tr><td>Accuracy (HDOP)</td><td id="hdop">-</td></tr>
  <tr><td>Speed</td><td id="spd">-</td></tr>
  <tr><td>Distance from home</td><td id="dist">-</td></tr>
  <tr><td>GPS data received</td><td id="chars">-</td></tr>
 </table>
 <p><a id="gmaps" href="#" target="_blank">Open in Google Maps</a></p>
 <p><button onclick="setHome()">Set home = current position</button></p>
 <p>Safe radius <input id="radius" type="number" min="10" max="5000" style="width:90px"> m
    <button onclick="setRadius()">Save</button></p>
</div>
<script>
const $=id=>document.getElementById(id);
let map,marker,circle,line,centered=false;
if(window.L){
 map=L.map('map').setView([0,0],2);
 L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'© OpenStreetMap'}).addTo(map);
 line=L.polyline([],{color:'#2563eb'}).addTo(map);
}else{$('map').style.display='none';}

async function refresh(){
 try{
  const s=await (await fetch('/api/status')).json();
  $('sats').textContent=s.sats; $('hdop').textContent=s.hdop.toFixed(1);
  $('chars').textContent=s.chars+' chars'+(s.chars==0?' (check wiring / baud!)':'');
  if(document.activeElement!==$('radius')) $('radius').value=s.radius;
  const st=$('state');
  if(!s.fix){st.className='badge wait';st.textContent='Waiting for GPS fix…';}
  else if(!s.homeSet){st.className='badge wait';st.textContent='Fix OK - set home';}
  else if(s.outside){st.className='badge bad';st.textContent='OUTSIDE safe zone!';}
  else{st.className='badge ok';st.textContent='Inside safe zone';}
  if(s.fix){
   $('pos').textContent=s.lat.toFixed(6)+', '+s.lng.toFixed(6);
   $('spd').textContent=s.speed.toFixed(1)+' km/h';
   $('gmaps').href='https://maps.google.com/?q='+s.lat+','+s.lng;
   $('dist').textContent=s.dist>=0?Math.round(s.dist)+' m':'-';
   if(map){
    const p=[s.lat,s.lng];
    if(!marker) marker=L.marker(p).addTo(map); else marker.setLatLng(p);
    if(!centered){map.setView(p,18);centered=true;}
   }
  }
  if(map&&s.homeSet){
   const h=[s.homeLat,s.homeLng];
   if(!circle) circle=L.circle(h,{radius:s.radius,color:'#16a34a'}).addTo(map);
   else{circle.setLatLng(h);circle.setRadius(s.radius);}
  }
  if(map){const t=await (await fetch('/api/trail')).json(); line.setLatLngs(t);}
 }catch(e){console.log(e);}
}
async function setHome(){
 const r=await fetch('/api/sethome',{method:'POST'}); alert(await r.text()); refresh();
}
async function setRadius(){
 const r=await fetch('/api/radius?m='+$('radius').value,{method:'POST'}); alert(await r.text()); refresh();
}
refresh(); setInterval(refresh,3000);
</script></body></html>
)rawliteral";

// ---------- user settings ----------
const char* WIFI_SSID  = "SIGIDAS 2.0";
const char* WIFI_PASS  = "Beben032894";
const char* AP_SSID    = "PetTracker";      // hotspot used when home WiFi fails
const char* AP_PASS    = "pettracker123";   // min 8 characters
const char* NTFY_TOPIC = "";                // e.g. "my-pet-tracker-8f3k2" ("" = alerts off)

#define GPS_RX_PIN 4     // ESP32 RX  <- GPS TX
#define GPS_TX_PIN 5     // ESP32 TX  -> GPS RX
#define GPS_BAUD   9600  // NEO-6M default
#define LED_PIN    8     // onboard blue LED (active LOW) - geofence alert
#define GPS_LED_PIN    6   // external LED, active HIGH
#define WIFI_LED_PIN   7   // external LED, active HIGH
#define CHARGE_LED_PIN 10  // external LED, active HIGH
#define CHRG_PIN       0   // TP4056 CHRG  (LOW = charging)
#define STDBY_PIN      1   // TP4056 STDBY (LOW = charge complete)

#define TRAIL_SIZE        120
#define TRAIL_INTERVAL_MS 10000  // store a trail point at most every 10 s
#define TRAIL_MIN_MOVE_M  5      // ...and only if moved this far
#define FIX_MAX_AGE_MS    5000
#define MAX_HDOP          5.0    // ignore poor fixes for the geofence
// -----------------------------------

HardwareSerial GPSSerial(1);
TinyGPSPlus gps;
WebServer server(80);
Preferences prefs;

struct Point { double lat, lng; };
Point trail[TRAIL_SIZE];
int trailCount = 0;
int trailHead = 0;
unsigned long lastTrailMs = 0;

bool   homeSet = false;
double homeLat = 0, homeLng = 0;
float  fenceRadius = 50;  // metres
bool   outside = false;
bool   apMode = false;

bool hasFix() {
  return gps.location.isValid() && gps.location.age() < FIX_MAX_AGE_MS;
}

double distanceHome() {
  if (!homeSet || !hasFix()) return -1;
  return TinyGPSPlus::distanceBetween(gps.location.lat(), gps.location.lng(), homeLat, homeLng);
}

// ---------- alerts ----------
void sendAlert(const String& title, const String& msg) {
  Serial.println("[ALERT] " + title + ": " + msg);
  if (apMode || strlen(NTFY_TOPIC) == 0 || WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  http.setTimeout(4000);
  if (http.begin(client, String("https://ntfy.sh/") + NTFY_TOPIC)) {
    http.addHeader("Title", title);
    http.addHeader("Priority", "high");
    http.addHeader("Tags", "dog");
    int code = http.POST(msg);
    Serial.printf("ntfy -> HTTP %d\n", code);
    http.end();
  }
}

String mapsLink() {
  return "https://maps.google.com/?q=" + String(gps.location.lat(), 6) + "," + String(gps.location.lng(), 6);
}

void checkGeofence() {
  if (!homeSet || !hasFix() || !gps.hdop.isValid() || gps.hdop.hdop() > MAX_HDOP) return;
  double d = distanceHome();

  // hysteresis so GPS jitter at the edge doesn't spam alerts
  if (!outside && d > fenceRadius) {
    outside = true;
    sendAlert("Pet left safe zone", String((int)d) + " m from home. " + mapsLink());
  } else if (outside && d < fenceRadius * 0.8) {
    outside = false;
    sendAlert("Pet is back home", String((int)d) + " m from home.");
  }
}

// ---------- trail ----------
void updateTrail() {
  if (!hasFix() || millis() - lastTrailMs < TRAIL_INTERVAL_MS) return;
  double lat = gps.location.lat(), lng = gps.location.lng();

  if (trailCount > 0) {
    Point& last = trail[(trailHead + TRAIL_SIZE - 1) % TRAIL_SIZE];
    if (TinyGPSPlus::distanceBetween(lat, lng, last.lat, last.lng) < TRAIL_MIN_MOVE_M) return;
  }
  trail[trailHead] = { lat, lng };
  trailHead = (trailHead + 1) % TRAIL_SIZE;
  if (trailCount < TRAIL_SIZE) trailCount++;
  lastTrailMs = millis();
}

// ---------- LEDs ----------
void updateLeds() {
  unsigned long t = millis();
  bool blink = (t / 500) % 2;  // 1 Hz blink shared by all "in progress" states

  // GPS: blinking while searching satellites, solid once fixed
  digitalWrite(GPS_LED_PIN, (hasFix() || blink) ? HIGH : LOW);

  // WiFi: blinking while connecting, solid when connected, short flash in hotspot mode
  bool wifiOn;
  if (apMode)                             wifiOn = (t % 2000) < 80;
  else if (WiFi.status() == WL_CONNECTED) wifiOn = true;
  else                                    wifiOn = blink;
  digitalWrite(WIFI_LED_PIN, wifiOn ? HIGH : LOW);

  // Charging: blinking while charging, solid when full, off without USB power
  bool charging = digitalRead(CHRG_PIN) == LOW;
  bool full     = digitalRead(STDBY_PIN) == LOW;
  digitalWrite(CHARGE_LED_PIN, (full || (charging && blink)) ? HIGH : LOW);

  // Onboard LED: fast blink while outside the safe zone
  bool alertOn = outside && (t / 150) % 2;
  digitalWrite(LED_PIN, alertOn ? LOW : HIGH);
}

// ---------- web ----------

void handleStatus() {
  bool fix = hasFix();
  char buf[420];
  snprintf(buf, sizeof(buf),
    "{\"fix\":%s,\"lat\":%.6f,\"lng\":%.6f,\"sats\":%u,\"hdop\":%.2f,\"speed\":%.2f,"
    "\"chars\":%lu,\"homeSet\":%s,\"homeLat\":%.6f,\"homeLng\":%.6f,\"radius\":%.0f,"
    "\"dist\":%.1f,\"outside\":%s}",
    fix ? "true" : "false",
    fix ? gps.location.lat() : 0.0, fix ? gps.location.lng() : 0.0,
    gps.satellites.isValid() ? (unsigned)gps.satellites.value() : 0u,
    gps.hdop.isValid() ? gps.hdop.hdop() : 99.0,
    gps.speed.isValid() ? gps.speed.kmph() : 0.0,
    (unsigned long)gps.charsProcessed(),
    homeSet ? "true" : "false", homeLat, homeLng, fenceRadius,
    distanceHome(), outside ? "true" : "false");
  server.send(200, "application/json", buf);
}

void handleTrail() {
  String json = "[";
  int start = (trailHead - trailCount + TRAIL_SIZE) % TRAIL_SIZE;
  for (int i = 0; i < trailCount; i++) {
    Point& p = trail[(start + i) % TRAIL_SIZE];
    if (i) json += ",";
    json += "[" + String(p.lat, 6) + "," + String(p.lng, 6) + "]";
  }
  json += "]";
  server.send(200, "application/json", json);
}

void handleSetHome() {
  if (!hasFix()) {
    server.send(400, "text/plain", "No GPS fix yet - cannot set home.");
    return;
  }
  homeLat = gps.location.lat();
  homeLng = gps.location.lng();
  homeSet = true;
  outside = false;
  prefs.putDouble("lat", homeLat);
  prefs.putDouble("lng", homeLng);
  prefs.putBool("set", true);
  server.send(200, "text/plain", "Home saved.");
}

void handleRadius() {
  float r = server.arg("m").toFloat();
  if (r < 10 || r > 5000) {
    server.send(400, "text/plain", "Radius must be 10-5000 m.");
    return;
  }
  fenceRadius = r;
  prefs.putFloat("radius", r);
  server.send(200, "text/plain", "Radius saved.");
}

void startWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  Serial.print("Connecting to WiFi");
  for (int i = 0; i < 30 && WiFi.status() != WL_CONNECTED; i++) {
    for (int j = 0; j < 10; j++) { updateLeds(); delay(50); }  // keep LEDs blinking
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Connected. Open http://");
    Serial.println(WiFi.localIP());
  } else {
    apMode = true;
    WiFi.mode(WIFI_AP);
    WiFi.softAP(AP_SSID, AP_PASS);
    Serial.printf("WiFi failed. Hotspot \"%s\" started. Open http://", AP_SSID);
    Serial.println(WiFi.softAPIP());
  }
}

void printStatus() {
  if (hasFix()) {
    Serial.printf("FIX  %.6f, %.6f  sats=%u hdop=%.1f  dist=%.0fm %s\n",
                  gps.location.lat(), gps.location.lng(), (unsigned)gps.satellites.value(),
                  gps.hdop.hdop(), distanceHome(), outside ? "OUTSIDE" : "");
  } else {
    Serial.printf("No fix yet  sats=%u  chars=%lu%s\n",
                  gps.satellites.isValid() ? (unsigned)gps.satellites.value() : 0u,
                  (unsigned long)gps.charsProcessed(),
                  gps.charsProcessed() < 10 ? "  <- no GPS data: check TX/RX wiring and baud" : "");
  }
}

void setup() {
  Serial.begin(115200);
  delay(1500);
  pinMode(LED_PIN, OUTPUT);
  pinMode(GPS_LED_PIN, OUTPUT);
  pinMode(WIFI_LED_PIN, OUTPUT);
  pinMode(CHARGE_LED_PIN, OUTPUT);
  pinMode(CHRG_PIN, INPUT_PULLUP);
  pinMode(STDBY_PIN, INPUT_PULLUP);

  GPSSerial.setRxBufferSize(1024);  // room for data while WiFi/HTTP is busy
  GPSSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

  prefs.begin("pettracker", false);
  homeSet     = prefs.getBool("set", false);
  homeLat     = prefs.getDouble("lat", 0);
  homeLng     = prefs.getDouble("lng", 0);
  fenceRadius = prefs.getFloat("radius", 50);

  startWifi();

  server.on("/", [] { server.send_P(200, "text/html", INDEX_HTML); });
  server.on("/api/status", handleStatus);
  server.on("/api/trail", handleTrail);
  server.on("/api/sethome", HTTP_POST, handleSetHome);
  server.on("/api/radius", HTTP_POST, handleRadius);
  server.begin();
}

void loop() {
  while (GPSSerial.available()) gps.encode(GPSSerial.read());

  server.handleClient();
  updateTrail();
  checkGeofence();
  updateLeds();

  static unsigned long lastPrint = 0;
  if (millis() - lastPrint > 5000) {
    lastPrint = millis();
    printStatus();
  }

  // reconnect if home WiFi drops
  static unsigned long lastWifiCheck = 0;
  if (!apMode && millis() - lastWifiCheck > 15000) {
    lastWifiCheck = millis();
    if (WiFi.status() != WL_CONNECTED) WiFi.reconnect();
  }
}
