/////////////////////////////////////////////////////////////////////////EEPROM Read
void readEEPROM() {
  EEPROM.begin(512);
  delay(100);
  ////////////////////////////////////////////////////////////EEPROM Read Bubble Start and End Time
  String StartTime;
  String EndTime;
  reedEEprom(StartTime, D_eepromBubbleStart);
  G_BubbleStart = StartTime.toInt();
  reedEEprom(EndTime, D_eepromBubbleEnd);
  G_BubbleEnd = EndTime.toInt();
  ////////////////////////////////////////////////////////////EEPROM Read Filter Start and End Time
  String FStartTime;
  String FEndTime;
  reedEEprom(FStartTime, D_eepromFilterStart);
  G_FilterStart = FStartTime.toInt();
  reedEEprom(FEndTime, D_eepromFilterEnd);
  G_FilterEnd = FEndTime.toInt();
  /////////////////////////////////////////////////////////////////////////////////
  Serial.println("\n\n\n"); Serial.print("EE BubbleStart = "); Serial.println(G_BubbleStart); Serial.print("EE BubbleEnd = "); Serial.println(G_BubbleEnd);
  Serial.println("\n"); Serial.print("EE FilterStart = "); Serial.println(G_FilterStart); Serial.print("EE FilterEnd = "); Serial.println(G_FilterEnd);Serial.println("\n\n\n");
  ////////////////////////////////////////////////////////////EEPROM SSID
  reedEEprom(G_SSID, D_eepromSSID);
  Serial.print("SSID = ");  Serial.println(G_SSID);
   ////////////////////////////////////////////////////////////EEPROM PASSWORD
  reedEEprom(G_PASSWORD, D_eepromPASSWORD);
  Serial.print("PAEEWORD = ");  Serial.println(G_PASSWORD);
   ////////////////////////////////////////////////////////////EEPROM broker url
  reedEEprom(G_mqtt_server, D_eepromBroker);
  Serial.print("MQTT Broker = ");  Serial.println(G_mqtt_server);
  ////////////////////////////////////////////////////////////EEPROM first Token
  reedEEprom(G_FIREBASE_FCM_DEVICE_TOKEN_1, D_eepromFirstToken);
  Serial.print("First Token = ");  Serial.println(G_FIREBASE_FCM_DEVICE_TOKEN_1);
  ////////////////////////////////////////////////////////////EEPROM second Token
  reedEEprom(G_FIREBASE_FCM_DEVICE_TOKEN_2, D_eepromSecondToken);
  Serial.print("Second Token = ");  Serial.println(G_FIREBASE_FCM_DEVICE_TOKEN_2);
}

void reedEEprom(String &value, int address) {
  byte n = 0;
  while (EEPROM.read(address + n) != 255){
    value += (char)EEPROM.read(address + n);
    n++;
    delay(5);
  }
}

void writeEEPROM(const String value, int address) {
  byte L = 0;
  for (; L < value.length(); L++) {
    EEPROM.write((address + L), value[L]);
    delay(5);
  }
  EEPROM.write((address + L), 255);
  delay(5);

  EEPROM.commit();
}
