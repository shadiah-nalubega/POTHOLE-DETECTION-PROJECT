#include <Wire.h>
#include <MPU6050.h>
#include <HardwareSerial.h>
#include <TinyGPSPlus.h>
#include <WiFiManager.h>
#include <WiFi.h>
#include <HTTPClient.h>


// === Sensor Setup ===
MPU6050 mpu;
TinyGPSPlus gps;
HardwareSerial GPS_Serial(2);
#define GPS_RX 16
#define GPS_TX 17
#define SAMPLE_SIZE 10

int16_t z_history[SAMPLE_SIZE];
int zIndex = 0;

// === ThingSpeak Setup ===
const char* thingspeakServer = "https://api.thingspeak.com/update";
String apiKey = "UOPAYZP2P3Q5BDD0";


// === URL Encode Function ===
String urlEncode(const String &str) {
  String encoded = "";
  char c;
  char code0, code1;
  for (int i = 0; i < str.length(); i++) {
    c = str.charAt(i);
    if (isalnum(c)) {
      encoded += c;
    } else {
      code1 = (c & 0xf) + '0';
      if ((c & 0xf) > 9) code1 = (c & 0xf) - 10 + 'A';
      code0 = ((c >> 4) & 0xf) + '0';
      if (((c >> 4) & 0xf) > 9) code0 = ((c >> 4) & 0xf) - 10 + 'A';
      encoded += '%';
      encoded += code0;
      encoded += code1;
    }
  }
  return encoded;
}

// === Shape Detection Logic ===
bool detectPotholeShape() {
  return z_history[(zIndex + SAMPLE_SIZE - 2) % SAMPLE_SIZE] < 14000 &&
         z_history[zIndex] > 16000;
}

// === Send Data to ThingSpeak ===
void sendToThingSpeak(float lat, float lon, int az, float speed, String label, String locationName) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String url = String(thingspeakServer) +
      "?api_key=" + apiKey +
      "&field1=" + String(lat, 6) +
      "&field2=" + String(lon, 6) +
      "&field3=" + String(az) +
      "&field4=" + urlEncode(locationName) +
      "&field5=" + String(speed, 2);
// Sends an HTTP GET request to ThingSpeak and logs the response or error to Serial
    http.begin(url);
    int responseCode = http.GET();
    if (responseCode > 0) {
      String response = http.getString();
      Serial.printf("ThingSpeak responded: %d\nResponse: %s\n", responseCode, response.c_str());
    } else {
      Serial.printf("ThingSpeak send error: %d\n", responseCode);
    }
    http.end();
  }
}
// Sets up Serial, I2C (pins 21, 22), and GPS serial for IoT device
void setup() {
  Serial.begin(9600);
  delay(1000);
  Wire.begin(21, 22);
  GPS_Serial.begin(9600, SERIAL_8N1, GPS_RX, GPS_TX);

  mpu.initialize();
  if (mpu.testConnection()) {
    Serial.println("MPU6050 connected");
  } else {
    Serial.println("MPU6050 connection failed");
    while (true);
  }

  // === WiFiManager Setup ===
  WiFiManager wm;
  bool res = wm.autoConnect("ESP32-Road-Setup");

  if (!res) {
    Serial.println("Failed to connect. Opening config portal...");
    wm.startConfigPortal("ESP32-Road-Setup");
  }

  Serial.println("WiFi connected!");
}
// === read accelerometer values ===
void loop() {
  int16_t ax, ay, az;
  mpu.getAcceleration(&ax, &ay, &az);
  z_history[zIndex] = az;
  zIndex = (zIndex + 1) % SAMPLE_SIZE;
  Serial.printf("Accel → X: %d | Y: %d | Z: %d\n", ax, ay, az);

  while (GPS_Serial.available()) {
    gps.encode(GPS_Serial.read());
  }

  if (!gps.location.isValid()) {
    Serial.println("Waiting for GPS fix");
    delay(100);
    return;
  }

  float lat = gps.location.lat();
  float lon = gps.location.lng();
  float speed = gps.speed.kmph();

  if (detectPotholeShape()) {
    Serial.println("Bump/Pothole Detected!");
    Serial.printf("Location: Lat %.6f, Lon %.6f\n", lat, lon);

    String locationName = "Unknown";
    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient geoClient;
      String geoURL = "https://nominatim.openstreetmap.org/reverse?format=json&lat=" + String(lat, 6) + "&lon=" + String(lon, 6);
      geoClient.begin(geoURL);
      geoClient.addHeader("User-Agent", "ESP32-Road-Mapper/1.0");
      int geoCode = geoClient.GET();
      if (geoCode == 200) {
        String payload = geoClient.getString();
        int start = payload.indexOf("\"display_name\":\"") + 17;
        int end = payload.indexOf("\"", start);
        if (start > 16 && end > start) {
          locationName = payload.substring(start, end);
        }
        Serial.println("Location: " + locationName);
      } else {
        Serial.printf("Geocode failed: %d\n", geoCode);
      }
      geoClient.end();
    }

    if (speed > 20) {
      sendToThingSpeak(lat, lon, az, speed, "Hard pothole", locationName);
    } else {
      sendToThingSpeak(lat, lon, az, speed, "Soft pothole", locationName);
    }

    delay(15000); // Prevent spamming
  }

  delay(50);
}
