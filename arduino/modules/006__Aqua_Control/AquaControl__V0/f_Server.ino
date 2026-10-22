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

  if (server.hasArg("BubbleStartH") && server.hasArg("BubbleEndH") && server.arg("BubbleStartH") != "" && server.arg("BubbleEndH") != "") {                      //if we send bubble time
    uint16_t BubbleStartH = server.arg(F("BubbleStartH")).toInt();
    uint16_t BubbleStartM = server.arg(F("BubbleStartM")).toInt();
    uint16_t BubbleEndH = server.arg(F("BubbleEndH")).toInt();
    uint16_t BubbleEndM = server.arg(F("BubbleEndM")).toInt();

    handleTime(G_BubbleStart, G_BubbleEnd, BubbleStartH, BubbleStartM, BubbleEndH, BubbleEndM);
    writeEEPROM(String(G_BubbleStart), D_eepromBubbleStart);
    writeEEPROM(String(G_BubbleEnd), D_eepromBubbleEnd);
  }
  if (server.hasArg("FilterStartH") && server.hasArg("FilterEndH") && server.arg("FilterStartH") != "" && server.arg("FilterEndH") != "") {                      //if we send filter time
    uint16_t FilterStartH = server.arg(F("FilterStartH")).toInt();
    uint16_t FilterStartM = server.arg(F("FilterStartM")).toInt();
    uint16_t FilterEndH = server.arg(F("FilterEndH")).toInt();
    uint16_t FilterEndM = server.arg(F("FilterEndM")).toInt();

    handleTime(G_FilterStart, G_FilterEnd, FilterStartH, FilterStartM, FilterEndH, FilterEndM);
    writeEEPROM(String(G_FilterStart), D_eepromFilterStart);
    writeEEPROM(String(G_FilterEnd), D_eepromFilterEnd);
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
void handleTime(uint16_t &StartTime, uint16_t &EndTime, uint16_t StartH, uint16_t StartM, uint16_t EndH, uint16_t EndM) { //handle start and end time

  StartTime = (StartH * 100) + StartM;
  EndTime = (EndH * 100) + EndM;
  Serial.print("StartTime = ");
  Serial.println(StartTime);
  Serial.print("EndTime = ");
  Serial.println(EndTime);
}

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
