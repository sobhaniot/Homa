void GasTempDO(uint16_t last_time) {

  checkHighLow(last_time, G_TempH, G_TempL, readTemp(), "Temp", G_tooHighLowTempFlag);
  EEPROM.write(D_eepromHighLowTempFlag, G_tooHighLowTempFlag);
  delay(5);
  EEPROM.commit();

  checkHighLow(last_time, G_GasH, G_GasL, (float)readGas(), "Gas", G_tooHighLowGasFlag);
  EEPROM.write(D_eepromHighLowGasFlag, G_tooHighLowGasFlag);
  delay(5);
  EEPROM.commit();
}


void checkHighLow(uint16_t last_time, int High, int Low, float value, String text, bool &flag) {

  float CastHigh = (float)High;
  float CastLow = (float)Low;
  Serial.print(text + " : ");
  Serial.println(value);

  if (value < CastLow && !flag) {

    String resLow = "Time :" ;
    resLow += (last_time / 100);
    resLow += ":" ;
    resLow += (last_time % 100);
    resLow += " " ;
    resLow += text + " is too Low : ";
    resLow += value;
    Serial.println(resLow);
    TempGasReport((char *)&resLow[0]);
//    SendToBot((char *)&resLow[0]);
    flag = true;

  } else if (value > CastHigh && !flag) {

    String resHigh = "Time :" ;
    resHigh += (last_time / 100);
    resHigh += ":" ;
    resHigh += (last_time % 100);
    resHigh += " " ;
    resHigh += text + " is too High : ";
    resHigh += value;
    Serial.println(resHigh);
    TempGasReport((char *)&resHigh[0]);
//    SendToBot((char *)&resHigh[0]);
    flag = true;

  } else if (value > CastLow && value < CastHigh && flag) {

    flag = false;

  }
}
/********************************************************************************/

int readGas() {
  int gas = analogRead(D_PIN_Gas);
  return gas;
}

void recordDailyGasTemp(uint16_t last_time) {
  if (last_time > 0 && last_time < 5) {

    G_daily_temp_high         = 0;
    G_daily_temp_low          = 100;
    G_daily_gas_high          = 0;
    G_daily_gas_low           = 1024;

  } else {
    float temp =  readTemp();
    int gas = readGas();
    if (temp > G_daily_temp_high) G_daily_temp_high = temp;
    if (temp < G_daily_temp_low) G_daily_temp_low = temp;
    if (gas > G_daily_gas_high) G_daily_gas_high = gas;
    if (gas < G_daily_gas_low) G_daily_gas_low = gas;
  }

  writeEEPROM(String(G_daily_temp_high), D_eepromDailyTempHigh);
  writeEEPROM(String(G_daily_temp_low), D_eepromDailyTempLow);
  writeEEPROM(String(G_daily_gas_high), D_eepromDailyGasHigh);
  writeEEPROM(String(G_daily_gas_low), D_eepromDailyGasLow);
  Serial.println("Daily Report");
  Serial.print("Temp High : ");
  Serial.println(G_daily_temp_high);
  Serial.print("Temp Low : ");
  Serial.println(G_daily_temp_low);
  Serial.print("Gas High : ");
  Serial.println(G_daily_gas_high);
  Serial.print("Gas Low : ");
  Serial.println(G_daily_gas_low);
  Serial.println("================");
}


void handleDailyReport(uint16_t last_time) {
  Serial.print("last time in daily : ");
  Serial.print(last_time);
  Serial.print(" =>  ");
  Serial.println(G_dailyReportFlag);
  if (last_time > 2350) {
    if (!G_dailyReportFlag) {

      String msgDailyReport = "Time :" ;
      msgDailyReport += (last_time / 100);
      msgDailyReport += ":" ;
      msgDailyReport += (last_time % 100);
      msgDailyReport += " TempH :" ;
      msgDailyReport += G_daily_temp_high;
      msgDailyReport += " TempL :" ;
      msgDailyReport += G_daily_temp_low;
      msgDailyReport += " GasH :" ;
      msgDailyReport += G_daily_gas_high;
      msgDailyReport += " GasL :" ;
      msgDailyReport += G_daily_gas_low;

      TempGasReport((char *)&msgDailyReport[0]);
//      SendToBot((char *)&msgDailyReport[0]);
      G_dailyReportFlag = true;
    }
  } else if (G_dailyReportFlag) {
    G_dailyReportFlag = false;
  }
}
