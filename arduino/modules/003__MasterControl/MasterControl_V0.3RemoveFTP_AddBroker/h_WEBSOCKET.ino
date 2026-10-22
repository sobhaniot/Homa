////////////////////////////////////////////////////////////////////////WebSocket Handle
void webSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t lenght) { // When a WebSocket message is received
  switch (type) {
    case WStype_DISCONNECTED:             // if the websocket is disconnected
      Serial.printf("[%u] Disconnected!\n", num);
      break;
    case WStype_CONNECTED: {              // if a new websocket connection is established
        Serial.printf("WebSocket Connected");
      }
      break;
    case WStype_TEXT:                     // if new text data is received
      Serial.print(F("I received: "));
      Serial.println((char*)payload);
      String message = (char*)payload;
      checkMessage(message);
      break;
  }
}
