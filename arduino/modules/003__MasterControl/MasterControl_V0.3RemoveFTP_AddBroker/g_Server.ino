bool handleFileRead(String path) { // send the right file to the client (if it exists)
  Serial.println("handleFileRead: " + path);

  if (server.hasArg("SSIDName") && server.hasArg("Password")) {
    handleLogin();
  }
  if (server.hasArg("Broker")) {                      //if we send mqtt broker adress
    handleBroker();
  }
  if (path.endsWith("/")) {                           // if path == /
    server.send(200, "text/html", index_html);   // Send HTTP status 200 (Ok) and send some text to the browser/client
    return true;
  }
  Serial.println("\tFile Not Found");
  return false;                                         // If the file doesn't exist, return false
}
/////////////////////////////////////////////////////////////////////////Get SSID and Password Function
void handleLogin() {                         // If a POST request is made to URI /login
  Serial.println("SSID: " + server.arg("SSIDName"));
  Serial.println("Password: " + server.arg("Password"));

  G_SSID = server.arg(F("SSIDName"));
  G_PASSWORD = server.arg(F("Password"));

  writeEEPROM(G_SSID, D_eepromSSID);
  writeEEPROM(G_PASSWORD, D_eepromPASSWORD);

  delay(5);
  setupWifi();
}
void handleBroker() {
  G_mqtt_server = server.arg(F("Broker"));

  Serial.println("MQTT Broker : " + G_mqtt_server);

  writeEEPROM(G_mqtt_server, D_eepromBroker);

  mqttSetup();
}
