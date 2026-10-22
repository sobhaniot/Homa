void startServer() { // Start a HTTP server with a file read handler and an upload handler
  server.onNotFound([]() {                              // If the client requests any URI
    if (!handleFileRead(server.uri()))                  // send it if it exists
      server.send(404, "text/plain", "404: Not Found"); // otherwise, respond with a 404 (Not Found) error
  });

  server.begin();                             // start the HTTP server
  Serial.println("HTTP server started.");
}


bool handleFileRead(String path) { // send the right file to the client (if it exists)
  Serial.println("handleFileRead: " + path);

  //if we send temp and gas high and low alarm red line
  if (server.hasArg("TempH") && server.hasArg("TempL") && server.arg("TempH") != "" && server.arg("TempL") != "") {
    G_TempH = server.arg(F("TempH")).toInt();
    G_TempL = server.arg(F("TempL")).toInt();
    G_GasH = server.arg(F("GasH")).toInt();
    G_GasL = server.arg(F("GasL")).toInt();
    writeEEPROM(String(G_TempH), D_eepromTempH);
    writeEEPROM(String(G_TempL), D_eepromTempL);
    writeEEPROM(String(G_GasH), D_eepromGasH);
    writeEEPROM(String(G_GasL), D_eepromGasL);
  }
  if (server.hasArg("SSIDName") && server.hasArg("Password") && server.arg("SSIDName") != "" && server.arg("Password") != "") {                      //if we send username and password
    handleLogin();
  }
  if (server.hasArg("Broker") && server.arg("Broker") != "") {                      //if we send mqtt broker adress
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
