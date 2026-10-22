///////////////////////////////////////////////////////////////////////EEPROM Read
void readEEPROM() {
  EEPROM.begin(560);
  delay(100);
  byte n = 0;
  ////////////////////////////////////////////////////////////EEPROM last simulation's condition
  SimCondition = EEPROM.read(eepromSim);
  delay(5);

  ////////////////////////////////////////////////////////////EEPROM SSID
  G_SSID = reedEEprom(D_eepromSSID);
  Serial.print("\nSSID = ");  Serial.println(G_SSID);
  ////////////////////////////////////////////////////////////EEPROM PASSWORD
  G_PASSWORD = reedEEprom(D_eepromPASSWORD);
  Serial.print("PAEEWORD = ");  Serial.println(G_PASSWORD);
  ////////////////////////////////////////////////////////////EEPROM broker url
  G_mqtt_server = reedEEprom(D_eepromBroker);
  Serial.print("MQTT Broker = ");  Serial.println(G_mqtt_server);
}

String reedEEprom(int address) {
  byte n = 0;
  String value;
  while (EEPROM.read(address + n) != 255) {
    value += (char)EEPROM.read(address + n);
    n++;
    delay(5);
  }
  return value;
}

void writeEEPROM(const String value, int address) {
  byte L = 0;
  String existValue = reedEEprom(address);
  delay(5);
  if (value != existValue) {
    for (; L < value.length(); L++) {
      EEPROM.write((address + L), value[L]);
      delay(5);
    }
    EEPROM.write((address + L), 255);
    delay(5);
    Serial.println("EEPROM Saved");
    EEPROM.commit();
  }

}
