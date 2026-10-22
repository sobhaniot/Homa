///////////////////////////////////////////////////////////////////////EEPROM Read
void readEEPROM() {
  EEPROM.begin(512);
  delay(100);
  ////////////////////////////////////////////////////////////EEPROM conditionPowerGone
  conditionPowerGone = EEPROM.read(eepromOption);
  if (conditionPowerGone == 255) conditionPowerGone = powerGoneML;
  delay(5);
  ////////////////////////////////////////////////////////////EEPROM Flag Token
  flagWhichTokenSave = EEPROM.read(eepromFlagToken);
  if (flagWhichTokenSave == 255) flagWhichTokenSave = 0;
  delay(5);
  ////////////////////////////////////////////////////////////EEPROM broker url
  reedEEprom(&mqtt_server, eepromBroker);
  ////////////////////////////////////////////////////////////EEPROM first Token
  reedEEprom(&FIREBASE_FCM_DEVICE_TOKEN_1, eepromFirstToken);
  ////////////////////////////////////////////////////////////EEPROM second Token
  reedEEprom(&FIREBASE_FCM_DEVICE_TOKEN_2, eepromSecondToken);
}

void reedEEprom(String* value, int address) {
  byte n = 0;
  while (EEPROM.read(address + n) != 255)
  {
    *value += (char)EEPROM.read(address + n);
    n++;
    delay(5);
  }
}
