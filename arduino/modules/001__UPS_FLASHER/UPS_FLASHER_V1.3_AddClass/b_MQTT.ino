/////////////////////////////////////////////////////////////////////MQTT Section
void mqttSetup() {
  MQTTclient.setServer(&mqtt_server[0], PortMQTT);
  MQTTclient.setCallback(callback);
}



void callback(char* topic, byte* payload, unsigned int length) {
//  Serial.print("Message arrived [");
//  Serial.print(topic);
//  Serial.print("] ");
//  Serial.print(length);
  String receivedChar;
  for (int i = 0; i < length; i++) {
    receivedChar += (char)payload[i];
  }
//  Serial.print("MQTT Message: ");
//  Serial.println(receivedChar);
  checkMessage(receivedChar);
}



void MQTTConnecting(){
  if (WiFi.status() == WL_CONNECTED && !MQTTclient.connected() && millis() % 60000 == 0) {
    //    Serial.print("Attempting MQTT connection...");
    // Attempt to connect
    if (MQTTclient.connect("Flasher esp8266")) {
      //      Serial.println("connected");
      // Once connected, publish an announcement...
      delay(50);
      MQTTclient.publish(publishTopic, "{\"condition\":\"Flasher connect to mqtt\"}");
      // ... and resubscribe
      MQTTclient.subscribe(subscribeTopic);

    } else {
      //      Serial.print("failed, rc=");
      //      Serial.println(MQTTclient.state());
    }
  }
  if (WiFi.status() == WL_CONNECTED && MQTTclient.connected()) {
    MQTTclient.loop();
  }
}
  
