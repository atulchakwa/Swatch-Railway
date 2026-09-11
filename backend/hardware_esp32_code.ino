#define TINY_GSM_MODEM_A7670
#include <TinyGsmClient.h>
#include <ArduinoHttpClient.h>
#include <WiFi.h>
#include <esp_now.h>
#include <HardwareSerial.h>
#include <Wire.h>
#include <RTClib.h>

RTC_DS3231 rtc;
HardwareSerial gsm(1);

#define GSM_RX 18
#define GSM_TX 17

// ===== CONFIGURE ONCE: Device MAC address (from Firestore devices collection) =====
const char deviceMac[] = "AA:BB:CC:DD:EE:01";
// ==================================================================================

// --- Network & API Configuration (same for ALL devices) ---
const char apn[]      = "www";
const char gprsUser[] = "";
const char gprsPass[] = "";
const char server[]   = "swatch-railway-4.onrender.com";
const int  port       = 443;

TinyGsm modem(gsm);
TinyGsmClient client(modem);
HttpClient http(client, server, port);

// --- Track last requestId per cabin per type ---
String lastAttRequestId[5] = {"", "", "", "", ""};
String lastClnRequestId[5] = {"", "", "", "", ""};

//---------------- LED PINS ----------------
#define C1_ATT_LED 4
#define C1_CLN_LED 5
#define C2_ATT_LED 15
#define C2_CLN_LED 16
#define C3_ATT_LED 41
#define C3_CLN_LED 42
#define C4_ATT_LED 21
#define C4_CLN_LED 22

// --- Anti-abuse cooldown ---
unsigned long lastButtonTime[5][5] = {0};
const unsigned long COOLDOWN_MS = 30000;

bool isCooldownActive(int cabin, int btn) {
  unsigned long now = millis();
  if (now - lastButtonTime[cabin][btn] < COOLDOWN_MS) {
    Serial.print("Cooldown active for cabin ");
    Serial.print(cabin); Serial.print(" button "); Serial.println(btn);
    return true;
  }
  lastButtonTime[cabin][btn] = now;
  return false;
}

typedef struct {
  uint8_t cabinID;
  uint8_t buttonID;
} Message;

Message msg;

void controlLED(uint8_t cabin, uint8_t button) {
  switch(cabin) {
    case 1:
      if(button==1) digitalWrite(C1_ATT_LED, HIGH);
      else if(button==2) digitalWrite(C1_ATT_LED, LOW);
      else if(button==3) digitalWrite(C1_CLN_LED, HIGH);
      else if(button==4) digitalWrite(C1_CLN_LED, LOW);
      break;
    case 2:
      if(button==1) digitalWrite(C2_ATT_LED, HIGH);
      else if(button==2) digitalWrite(C2_ATT_LED, LOW);
      else if(button==3) digitalWrite(C2_CLN_LED, HIGH);
      else if(button==4) digitalWrite(C2_CLN_LED, LOW);
      break;
    case 3:
      if(button==1) digitalWrite(C3_ATT_LED, HIGH);
      else if(button==2) digitalWrite(C3_ATT_LED, LOW);
      else if(button==3) digitalWrite(C3_CLN_LED, HIGH);
      else if(button==4) digitalWrite(C3_CLN_LED, LOW);
      break;
    case 4:
      if(button==1) digitalWrite(C4_ATT_LED, HIGH);
      else if(button==2) digitalWrite(C4_ATT_LED, LOW);
      else if(button==3) digitalWrite(C4_CLN_LED, HIGH);
      else if(button==4) digitalWrite(C4_CLN_LED, LOW);
      break;
  }
}

// ---- API: Create a new passenger request (buttons 1 & 3) ----
String createPassengerRequest(int cabin, String requestType) {
  String payload = "{";
  payload += "\"requestType\":\"" + requestType + "\"";
  payload += "}";

  Serial.println("--- CREATE REQUEST ---");
  Serial.println(payload);

  http.beginRequest();
  http.post("/api/passenger-service-requests");
  http.sendHeader("Content-Type", "application/json");
  http.sendHeader("x-device-mac", deviceMac);
  http.sendHeader("Content-Length", payload.length());
  http.beginBody();
  http.print(payload);
  http.endRequest();

  int statusCode = http.responseStatusCode();
  String response = http.responseBody();
  Serial.print("Status: "); Serial.println(statusCode);
  Serial.print("Response: "); Serial.println(response);

  String requestId = "";
  int idStart = response.indexOf("\"requestId\":\"");
  if (idStart > 0) {
    idStart += 13;
    int idEnd = response.indexOf("\"", idStart);
    requestId = response.substring(idStart, idEnd);
  }

  if (statusCode == 201) {
    controlLED(cabin, requestType == "ATTENDANT" ? 1 : 3);
  } else {
    Serial.println("LED not turned on (duplicate or error)");
  }
  return requestId;
}

// ---- API: Send device complete event (buttons 2 & 4) ----
void sendDeviceComplete(int cabin, String requestId, String buttonType) {
  if (requestId.length() == 0) {
    Serial.println("ERROR: No requestId stored");
    return;
  }

  String url = String("/api/passenger-service-requests/") + requestId + "/device-event";
  String payload = "{";
  payload += "\"requestId\":\"" + requestId + "\",";
  payload += "\"buttonPressed\":\"" + buttonType + "\"";
  payload += "}";

  Serial.println("--- DEVICE COMPLETE ---");
  Serial.println(url);
  Serial.println(payload);

  http.beginRequest();
  http.post(url);
  http.sendHeader("Content-Type", "application/json");
  http.sendHeader("x-device-mac", deviceMac);
  http.sendHeader("Content-Length", payload.length());
  http.beginBody();
  http.print(payload);
  http.endRequest();

  int statusCode = http.responseStatusCode();
  String response = http.responseBody();
  Serial.print("Status: "); Serial.println(statusCode);
  Serial.print("Response: "); Serial.println(response);

  if (statusCode == 200) {
    controlLED(cabin, buttonType == "ATTENDANT_COMPLETE" ? 2 : 4);
  }
}

void OnDataRecv(const esp_now_recv_info_t *info,
                const uint8_t *incomingData, int len) {
  memcpy(&msg, incomingData, sizeof(msg));
  int cabin = msg.cabinID;
  int btn = msg.buttonID;

  Serial.println("=======================");
  Serial.print("Cabin : "); Serial.println(cabin);
  Serial.print("Button: "); Serial.println(btn);

  if (isCooldownActive(cabin, btn)) return;

  controlLED(cabin, btn);

  if (btn == 1) {
    String rid = createPassengerRequest(cabin, "ATTENDANT");
    if (rid.length() > 0) lastAttRequestId[cabin] = rid;
  }
  else if (btn == 2) {
    sendDeviceComplete(cabin, lastAttRequestId[cabin], "ATTENDANT_COMPLETE");
    lastAttRequestId[cabin] = "";
  }
  else if (btn == 3) {
    String rid = createPassengerRequest(cabin, "CLEANING");
    if (rid.length() > 0) lastClnRequestId[cabin] = rid;
  }
  else if (btn == 4) {
    sendDeviceComplete(cabin, lastClnRequestId[cabin], "CLEANER_COMPLETE");
    lastClnRequestId[cabin] = "";
  }
}

void setup() {
  Serial.begin(115200);
  Wire.begin(21, 20);

  if (!rtc.begin()) { Serial.println("RTC Not Found"); while (1); }
  if (rtc.lostPower()) { rtc.adjust(DateTime(F(__DATE__), F(__TIME__))); }

  WiFi.mode(WIFI_STA);

  gsm.begin(115200, SERIAL_8N1, GSM_RX, GSM_TX);
  delay(3000);

  Serial.println("Initializing GSM...");
  modem.restart();

  Serial.print("Connecting to APN: ");
  Serial.println(apn);
  if (!modem.gprsConnect(apn, gprsUser, gprsPass)) {
    Serial.println("APN Connection failed!");
  } else {
    Serial.println("GPRS Connected!");
  }

  pinMode(C1_ATT_LED, OUTPUT); pinMode(C1_CLN_LED, OUTPUT);
  pinMode(C2_ATT_LED, OUTPUT); pinMode(C2_CLN_LED, OUTPUT);
  pinMode(C3_ATT_LED, OUTPUT); pinMode(C3_CLN_LED, OUTPUT);
  pinMode(C4_ATT_LED, OUTPUT); pinMode(C4_CLN_LED, OUTPUT);

  for (int i = 1; i <= 4; i++) { controlLED(i, 2); controlLED(i, 4); }

  Serial.print("Receiver MAC : ");
  Serial.println(WiFi.macAddress());

  if (esp_now_init() != ESP_OK) { Serial.println("ESP NOW INIT FAILED"); return; }
  esp_now_register_recv_cb(OnDataRecv);
  Serial.println("Receiver Ready");
}

void loop() {}
