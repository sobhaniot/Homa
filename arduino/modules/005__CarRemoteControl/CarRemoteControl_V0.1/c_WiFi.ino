//////////////////////////////////////////////////////////////////////// Wifi Setup Function
void setupAPWifi(void) {
  WiFi.mode(WIFI_AP_STA);
  //Constant IP for APWiFi
  IPAddress ipAP(192, 168, 11, 22);
  IPAddress gatewayAP(192, 168, 11, 1);
  IPAddress subnetAP(255, 255, 255, 0);
  //Start AP WiFi
  Serial.print(F("Setting soft-AP configuration ... "));
  //  WiFi.softAPConfig(ipAP, gatewayAP, subnetAP);
  Serial.println(WiFi.softAPConfig(ipAP, gatewayAP, subnetAP) ? "Ready" : "Failed!");

  Serial.print(F("Setting soft-AP ... "));
  //  WiFi.softAP(mySSID, passwordAP);
  Serial.println(WiFi.softAP(mySSID, passwordAP) ? "Ready" : "Failed!");

  Serial.print(F("Soft-AP IP address = "));
  Serial.println(WiFi.softAPIP());

}

void setupWifi(void) {

  //Constant IP for Local WiFi
  //  IPAddress ipWiFi(192, 168, 1, 66);
  //  IPAddress gatewayWiFi(192, 168, 1, 249);
  //  IPAddress subnetWiFi(255, 255, 255, 0);

  //  WiFi.config(ipWiFi, gatewayWiFi, subnetWiFi);
  WiFi.begin(&_SSID[0], &_PASSWORD[0]);
  
  for (int m = 0; m < 20; m++) {
    delay(500);
    Serial.print(F("."));
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println(F("WiFi connected"));
      Serial.println(WiFi.localIP());
      WiFi.setAutoConnect(true);
      break;
    }
  }

}
