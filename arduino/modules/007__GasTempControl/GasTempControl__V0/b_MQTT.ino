/////////////////////////////////////////////////////////////////////MQTT Section
void mqttSetup() {
  MQTTclient.setServer(&G_mqtt_server[0], D_PortMQTT);
  MQTTclient.setCallback(callback);
}

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  Serial.print(length);
  String receivedChar;
  for (int i = 0; i < length; i++) {
    receivedChar += (char)payload[i];
  }
  Serial.print("MQTT Message: ");
  Serial.println(receivedChar);
  checkMessage(receivedChar); // this function declare in h_Parse tab
}

void MQTTConnecting() {

  if (WiFi.status() == WL_CONNECTED) {
    if (!MQTTclient.connected() && TMQTT.Wait(60000)) {
      Serial.print("Attempting MQTT connection...");
      // Attempt to connect
      #if DEBUG
            bool MQTTConnect = MQTTclient.connect("GasTemp esp8266Test");
      #else
            bool MQTTConnect = MQTTclient.connect("GasTemp esp8266");
      
      #endif
      
      if (MQTTConnect) {
        Serial.println("connected");
        // Once connected, publish an announcement...
        delay(50);
        MQTTclient.publish(G_publishTopic, "{\"condition\":\"GasTemp connect to mqtt\"}");
        // ... and resubscribe
        MQTTclient.subscribe(G_subscribeTopic);

      } else {
        Serial.print("failed, rc="); Serial.println(MQTTclient.state());
      }
    }
    if (MQTTclient.connected()) {
      MQTTclient.loop();
    }
  }
}
