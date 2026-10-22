////////////////////////////////////////////////////////////////////////SetUp Function
void startWebSocket() { // Start a WebSocket server
  webSocket.begin();                          // start the websocket server
  webSocket.onEvent(webSocketEvent);          // if there's an incomming websocket message, go to function 'webSocketEvent'
  Serial.println(F("WebSocket server started."));
}

void startServer() { // Start a HTTP server with a file read handler and an upload handler
  server.onNotFound([]() {                              // If the client requests any URI
    if (!handleFileRead(server.uri()))                  // send it if it exists
      server.send(404, "text/plain", "404: Not Found"); // otherwise, respond with a 404 (Not Found) error
  });

  server.begin();                             // start the HTTP server
  Serial.println(F("HTTP server started."));
}

void mqttSetup() {
  MQTTclient.setServer(&G_mqtt_server[0], PortMQTT);
  MQTTclient.setCallback(callback);
}
