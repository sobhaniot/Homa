void refrigeratorDO() {
  Serial.println(G_TempIn);

  static bool motorOnce = true;

  if (DoorCondition == D_DoorClose)
  {
    motorOnce = true;
  }
  else
  {
    if(motorOnce)
    {
      TickerMotor.once(40, [](){digitalWrite (D_PIN_MOTOR, LOW);});
      motorOnce = false;
    }
    return;
  }

  if (G_TempIn < G_MinTemp && digitalRead(D_PIN_MOTOR)) 
  {
    G_OnTime = T.CountUntil(true) / 60000;
    SFPRINT("OnTime = "); 
    Serial.println(G_OnTime);
    digitalWrite (D_PIN_MOTOR, LOW);
    T.CountReset();
  }

  
  if (G_TempIn > G_MaxTemp && !digitalRead(D_PIN_MOTOR))
  {
    G_OffTime = T.CountUntil(true) / 60000;
    SFPRINT("OffTime = ");
    Serial.println(G_OffTime);
    if (G_OffTime >= D_delayBeforeOn ) 
    {
      digitalWrite (D_PIN_MOTOR, HIGH);
      T.CountReset();
    }
  }
  
}
// /********************************************************************************/



void CheckTempHigh()
{
  static bool G_TooHighReportFlag = false;

  if (G_TempIn > D_tooHighTemp) {
    if (!G_TooHighReportFlag) {

    String msg = "Refrigerator's Temp Is Too High";

    if (CF_MQTT_send_notif_to(msg)) G_TooHighReportFlag = true;
    lcd.setCursor(0, 1);
    lcd.print("Temp Is Too High");
    }
  }else{
    G_TooHighReportFlag = false;
  }
}
