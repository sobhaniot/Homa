/////////////////////////////////////////////////////////////////////MQTT Section
void mqttSetup() {
  MQTTclient.setServer(&mqtt_server[0], PortMQTT);
  MQTTclient.setCallback(callback);
}

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print(F("Message arrived ["));
  Serial.print(topic);
  Serial.print(F("] "));
  Serial.print(F("  Lenght MSG : "));
  Serial.println(length);
  String receivedChar;
  for (int i = 0; i < length; i++) {
    receivedChar += (char)payload[i];
  }
  Serial.print(F("MQTT Message: "));
  Serial.println(receivedChar);
  checkMessage(receivedChar);
}

void mqttConnection() {
  if (WiFi.status() == WL_CONNECTED && !MQTTclient.connected() && millis() % 60000 == 0) {
    Serial.print("Attempting MQTT connection...");
    // Attempt to connect
    if (MQTTclient.connect("CarControl esp8266")) {
      Serial.println("connected");
      // Once connected, publish an announcement...
      delay(50);
      MQTTclient.publish(publishTopic, "{\"data\":0,\"condition\":\"HomeLamp connect to mqtt\"}");
      // ... and resubscribe
      MQTTclient.subscribe(subscribeTopic);
    } else {
      Serial.print("failed, rc=");
      Serial.println(MQTTclient.state());
    }
  }

  if (WiFi.status() == WL_CONNECTED && MQTTclient.connected()) {
    MQTTclient.loop();
  }
}
