#include <ESPAsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <AsyncElegantOTA.h>



AsyncWebServer server(80);    // Create a webserver object that listens for HTTP request on port 80

bool handleFileRead(AsyncWebServerRequest *request);
void handleLogin(AsyncWebServerRequest *request);
void handleBroker(AsyncWebServerRequest *request);


void CF_startServer() { // Start a HTTP server with a file read handler and an upload handler
  server.onNotFound([](AsyncWebServerRequest *request) {                              // If the client requests any URI
    if (!handleFileRead(request))                  // send it if it exists
      request->send(404, "text/plain", "404: Not Found"); // otherwise, respond with a 404 (Not Found) error
  });

  AsyncElegantOTA.begin(&server);    // Start AsyncElegantOTA
  server.begin();                             // start the HTTP server
  Serial.println("HTTP server started.");
}


bool handleFileRead(AsyncWebServerRequest *request) { // send the right file to the client (if it exists)
  String path = request->url();
  Serial.println("handleFileRead: " + path);

  if (request->hasParam("SSIDName",true) && request->hasParam("Password",true)){
    handleLogin(request);
  }

  if (request->hasParam("Broker",true)) {                      //if we send mqtt broker adress
    handleBroker(request);
  }
  if (path.endsWith("/")) {                           // if path == /
    request->send(200, "text/html", index_html);   // Send HTTP status 200 (Ok) and send some text to the browser/client
    return true;
  }
  Serial.println("\tFile Not Found");
  return false;                                         // If the file doesn't exist, return false
}

void handleLogin(AsyncWebServerRequest *request) {                         // If a POST request is made to URI /login
  G_SSID = request->getParam("SSIDName",true)->value(); // because we use post method set true for input
  G_PASSWORD = request->getParam("Password",true)->value(); // because we use post method set true for input

  Serial.println("SSID: " + G_SSID);
  Serial.println("Password: " + G_PASSWORD);

  CF_EEPROM_write(G_SSID, D_eepromSSID);
  CF_EEPROM_write(G_PASSWORD, D_eepromPASSWORD);

  delay(5);
}


void handleBroker(AsyncWebServerRequest *request) {
  G_mqtt_server = request->getParam("Broker",true)->value(); // because we use post method set true for input

  Serial.println("MQTT Broker : " + G_mqtt_server);

  CF_EEPROM_write(G_mqtt_server, D_eepromBroker);

}
