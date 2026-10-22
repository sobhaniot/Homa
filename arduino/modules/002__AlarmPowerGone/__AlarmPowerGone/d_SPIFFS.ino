////////////////////////////////////////////////////////////////////////SPIFFS Function
String getContentType(String filename) { // convert the file extension to the MIME type
  if (filename.endsWith(".html")) return "text/html";
  else if (filename.endsWith(".css")) return "text/css";
  else if (filename.endsWith(".js")) return "application/javascript";
  else if (filename.endsWith(".ico")) return "image/x-icon";
  else if (filename.endsWith(".txt")) return "text/plain";
  return "text/plain";
}
bool handleFileRead(String path) { // send the right file to the client (if it exists)
//  Serial.println("handleFileRead: " + path);

  if (server.hasArg("SSIDName") && server.hasArg("Password")) {
    handleLogin();
  }
  if (server.hasArg("yearSet") && server.hasArg("monthSet")) {
    handleSetTime();
  }
  if (path.endsWith("/")) path += "index.html";         // If a folder is requested, send the index file
  String contentType = getContentType(path);            // Get the MIME type
  if (SPIFFS.exists(path)) {                            // If the file exists
    fs::File file = SPIFFS.open(path, "r");                 // Open it
    size_t sent = server.streamFile(file, contentType); // And send it to the client
    file.close();                                       // Then close the file again
    return true;
  }
//  Serial.println("\tFile Not Found");
  return false;                                         // If the file doesn't exist, return false
}
/////////////////////////////////////////////////////////////////////////Get SSID and Password Function
void handleLogin() {                         // If a POST request is made to URI /login
//  Serial.println("SSID: " + server.arg("SSIDName"));
//  Serial.println("Password: " + server.arg("Password"));

  _SSID = server.arg("SSIDName");
  _PASSWORD = server.arg("Password");
  ssid = &_SSID[0];
  password = &_PASSWORD[0];

  byte l;
  for (l = 0; l < 40; l++) {
    EEPROM.write((eepromSSID + l), _SSID[l]);
    delay(5);
  }
  for (l = 0; l < 40; l++) {
    EEPROM.write((eepromPass + l), _PASSWORD[l]);
    delay(5);
  }
  EEPROM.commit();
  setupWifi();
}

void  handleSetTime(){
//  Serial.println("Year: " + server.arg("yearSet"));
//  Serial.println("Month: " + server.arg("monthSet"));
//  Serial.println("Day: " + server.arg("daySet"));
//  Serial.println("Day: " + server.arg("weekdaySet"));
//  Serial.println("Hour: " + server.arg("hourSet"));
//  Serial.println("Minute: " + server.arg("minSet"));  
  setTime(server.arg("yearSet"),server.arg("monthSet") ,server.arg("daySet") ,server.arg("weekdaySet"), server.arg("hourSet") ,server.arg("minSet") ) ;
}
