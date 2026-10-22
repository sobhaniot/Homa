//////////////////////////////////////////////////////////////////////// Wifi Setup Function
void setupAPWifi(void) {
  WiFi.mode(WIFI_AP_STA);
  //Constant IP for APWiFi
  IPAddress ipAP(192, 168, 11, 22);
  IPAddress gatewayAP(192, 168, 11, 1);
  IPAddress subnetAP(255, 255, 255, 0);
  //Start AP WiFi
  //    Serial.print("Setting soft-AP configuration ... ");
  WiFi.softAPConfig(ipAP, gatewayAP, subnetAP);

  //    Serial.print("Setting soft-AP ... ");
  WiFi.softAP(mySSID, passwordAP);

  //    Serial.print("Soft-AP IP address = ");
  //    Serial.println(WiFi.softAPIP());

}

void setupWifi(void) {

  //Constant IP for Local WiFi
  //  IPAddress ipWiFi(192, 168, 1, 55);
  //  IPAddress gatewayWiFi(192, 168, 1, 249);
  //  IPAddress subnetWiFi(255, 255, 255, 0);

  //  WiFi.config(ipWiFi, gatewayWiFi, subnetWiFi);

  WiFi.begin(&_SSID[0], &_PASSWORD[0]);

  for (int m = 0; m < 20; m++) {
    delay(500);
    //    Serial.print(F("."));
    if (WiFi.status() == WL_CONNECTED) {
      //      Serial.println(F("WiFi connected"));
      //      Serial.println(WiFi.localIP());
      //      WiFi.setAutoConnect(true);   we can't use this method because the firebase class has the same method and do this for us
      break;
    }
  }

}
