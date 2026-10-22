

///////////////////////////////////////////////////////////////////////EEPROM Read
void readEEPROM() {
  EEPROM.begin(512);
  delay(100);
  byte n = 0;
  /////////////////////////////////////////////////////////////EEPROM SSID
  while (EEPROM.read(eepromSSID + n) != 255)
  {
    _SSID += (char)EEPROM.read(eepromSSID + n);
    n++;
    delay(5);
  }
  ssid = &_SSID[0];
  Serial.println("");
  Serial.println(ssid);
  delay(1000);
  n = 0;
  ////////////////////////////////////////////////////////////EEPROM PASSWORD
  while (EEPROM.read(eepromPass + n) != 255)
  {
    _PASSWORD += (char)EEPROM.read(eepromPass + n);
    n++;
    delay(5);
  }
  password = &_PASSWORD[0];
  Serial.println(password);
  n = 0;

  //////////////////////////////////////////////////////////EEPROM Flags
  flagLastPowerStatus = EEPROM.read(eepromflagLastPowerStatus);
  flagSendDataToSite = EEPROM.read(eepromflagSendDataToSite);
  Serial.print("Flagz : ");
  Serial.print(flagLastPowerStatus);
  Serial.print("  ");
  Serial.println(flagSendDataToSite);
}
