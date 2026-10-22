///////////////////////////////////////////////////////////////////////EEPROM Read
void readEEPROM() {
  EEPROM.begin(64);
  delay(100);
  byte n = 0;
  ////////////////////////////////////////////////////////////EEPROM conditionPowerGone
//  SimCondition = EEPROM.read(eepromSim);
  delay(5);

  ////////////////////////////////////////////////////////////EEPROM conditionPowerGone

  while (EEPROM.read(eepromBroker + n) != 255)
  {
    
    mqtt_server += (char)EEPROM.read(eepromBroker + n);
    n++;
    delay(5);
  }
}
