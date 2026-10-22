/////////////////////////////////////////////////////////////////////MQTT Section
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
