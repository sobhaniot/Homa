/////////////////////////////////////////////////////////////////////////EEPROM Read
void readEEPROM() {
  EEPROM.begin(560);
  delay(100);
  ////////////////////////////////////////////////////////////EEPROM Read Temp High and Low red line Alarm
  String tempHigh;
  String tempLow;
  tempHigh = reedEEprom(D_eepromTempH);
  G_TempH = tempHigh.toInt();
  tempLow = reedEEprom(D_eepromTempL);
  G_TempL = tempLow.toInt();
  ////////////////////////////////////////////////////////////EEPROM Read Gas High and Low red line Alarm
  String gasHigh;
  String gasLow;
  gasHigh = reedEEprom(D_eepromGasH);
  G_GasH = gasHigh.toInt();
  gasLow = reedEEprom(D_eepromGasL);
  G_GasL = gasLow.toInt();
  ////////////////////////////////////////////////////////////EEPROM Read Daily High Low Value
  String dailyTempHigh;
  String dailyTempLow;
  String dailyGasHigh;
  String dailyGasLow;
  
  dailyTempHigh = reedEEprom(D_eepromDailyTempHigh);
  G_daily_temp_high = dailyTempHigh.toFloat();
  dailyTempLow = reedEEprom(D_eepromDailyTempLow);
  G_daily_temp_low = dailyTempLow.toFloat();
  if (G_daily_temp_low == 0.0) G_daily_temp_low = 100;
  Serial.println("\n\n\n"); Serial.print("EE Daily Temp High : "); Serial.println(G_daily_temp_high); Serial.print("EE Daily Temp Low : "); Serial.println(G_daily_temp_low);
  
  dailyGasHigh = reedEEprom(D_eepromDailyGasHigh);
  G_daily_gas_high = dailyGasHigh.toInt();
  dailyGasLow = reedEEprom(D_eepromDailyGasLow);
  G_daily_gas_low = dailyGasLow.toInt();
  if (G_daily_gas_low == 0) G_daily_gas_low = 1024;
  Serial.println("\n\n\n"); Serial.print("EE Daily Gas High : "); Serial.println(G_daily_gas_high); Serial.print("EE Daily Gas Low : "); Serial.println(G_daily_gas_low);
  ////////////////////////////////////////////////////////////EEPROM Flag Temp Report
  G_tooHighLowTempFlag = EEPROM.read(D_eepromHighLowTempFlag);
  if (G_tooHighLowTempFlag == 255) G_tooHighLowTempFlag = 0;
  delay(5);
  Serial.println("\n\n\n"); Serial.print("EE Temp Report Flag : "); Serial.println(G_tooHighLowTempFlag);
  ////////////////////////////////////////////////////////////EEPROM Flag Gas Report
  G_tooHighLowGasFlag = EEPROM.read(D_eepromHighLowGasFlag);
  if (G_tooHighLowGasFlag == 255) G_tooHighLowGasFlag = 0;
  delay(5);
  Serial.println("\n\n\n"); Serial.print("EE Gas Report Flag : "); Serial.println(G_tooHighLowGasFlag);
  /////////////////////////////////////////////////////////////////////////////////
  Serial.println("\n\n\n"); Serial.print("EE TempHigh = "); Serial.println(G_TempH); Serial.print("EE TempLow = "); Serial.println(G_TempL);
  Serial.println("\n"); Serial.print("EE GasHigh = "); Serial.println(G_GasH); Serial.print("EE GasLow = "); Serial.println(G_GasL); Serial.println("\n\n\n");
  ////////////////////////////////////////////////////////////EEPROM SSID
  G_SSID = reedEEprom(D_eepromSSID);
  Serial.print("SSID = ");  Serial.println(G_SSID);
  ////////////////////////////////////////////////////////////EEPROM PASSWORD
  G_PASSWORD = reedEEprom(D_eepromPASSWORD);
  Serial.print("PAEEWORD = ");  Serial.println(G_PASSWORD);
  ////////////////////////////////////////////////////////////EEPROM broker url
  G_mqtt_server = reedEEprom(D_eepromBroker);
  Serial.print("MQTT Broker = ");  Serial.println(G_mqtt_server);
  ////////////////////////////////////////////////////////////EEPROM first Token
  G_FIREBASE_FCM_DEVICE_TOKEN_1 = reedEEprom(D_eepromFirstToken);
  Serial.print("First Token = ");  Serial.println(G_FIREBASE_FCM_DEVICE_TOKEN_1);
  ////////////////////////////////////////////////////////////EEPROM second Token
  G_FIREBASE_FCM_DEVICE_TOKEN_2 = reedEEprom(D_eepromSecondToken);
  Serial.print("Second Token = ");  Serial.println(G_FIREBASE_FCM_DEVICE_TOKEN_2);
  ////////////////////////////////////////////////////////////EEPROM Flag Token
  G_flagWhichTokenSave = EEPROM.read(D_eepromFlagToken);
  if (G_flagWhichTokenSave == 255) G_flagWhichTokenSave = 0;
  delay(5);
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
