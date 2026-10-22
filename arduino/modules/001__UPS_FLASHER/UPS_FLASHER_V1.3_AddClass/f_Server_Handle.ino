void startServer() { // Start a HTTP server with a file read handler and an upload handler
  server.onNotFound([]() {                              // If the client requests any URI
    if (!handleFileRead(server.uri()))                  // send it if it exists
      server.send(404, "text/plain", "404: Not Found"); // otherwise, respond with a 404 (Not Found) error
  });

  server.begin();                             // start the HTTP server
  //  Serial.println("HTTP server started.");
}


bool handleFileRead(String path) { // send the right file to the client (if it exists)
  //    Serial.println("handleFileRead: " + path);

  if (server.hasArg("SSIDName") && server.hasArg("Password")) {                      //if we send username and password
    handleLogin();
  }
  if (server.hasArg("Broker")) {                      //if we send mqtt broker adress
    handleBroker();
  }
  if (path.endsWith("/")) {                           // if path == /
    server.send(200, "text/html", index_html);   // Send HTTP status 200 (Ok) and send some text to the browser/client
    return true;
  }
  //    Serial.println("\tFile Not Found");
  return false;                                         // If the file doesn't exist, return false
}
/////////////////////////////////////////////////////////////////////////Get SSID and Password Function
void handleLogin() {                         // If a POST request is made to URI /login
  //    Serial.println("SSID: " + server.arg("SSIDName"));
  //    Serial.println("Password: " + server.arg("Password"));

  _SSID = server.arg(F("SSIDName"));
  _PASSWORD = server.arg(F("Password"));

  delay(5);
  setupWifi();
}


void handleBroker() {
  mqtt_server = server.arg(F("Broker"));

  byte L = 0;
  for (; L < mqtt_server.length(); L++) {
    EEPROM.write((eepromBroker + L), mqtt_server[L]);
    delay(5);
  }
  for (; L < 49; L++) {
    EEPROM.write((eepromBroker + L), 255);
    delay(5);
  }
  
  EEPROM.commit();
  
  mqttSetup();

}
