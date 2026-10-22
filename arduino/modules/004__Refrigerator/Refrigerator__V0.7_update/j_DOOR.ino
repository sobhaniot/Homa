// ////////////////////////////////////////////////////////////////////////DOOR Function

void checkCloseAfterFiveMin(){
    DoorCondition = D_FiveMinOpen;
    SFPRINTLN("Door Is Open More Than Five Minutes");
}

void checkCloseAfterOneMin(){
    DoorCondition = D_OneMinOpen;
    SFPRINTLN("Door Is Open More Than One Minute");
    TickerDoor.once(240, checkCloseAfterFiveMin);
}


void CheckDoor() {
  static bool last_door_state = true;

  bool door_state = digitalRead(D_PIN_CHECKDOOR);

  if (last_door_state != door_state){
      T_Debounce.CountReset();
      last_door_state = door_state;
    }

  if (T_Debounce.CountUntil(true) > 10){

    if (digitalRead(D_PIN_CHECKDOOR)){

      if(!checkDoorFlag){
        // in khat ham ticker ra az kar miandazad ham inke motor be mahz baste shodan dar roshan nemishavad
        DoorCondition = D_AlarmOff;
        TickerDoor.once(60,[](){DoorCondition = D_DoorClose;});
        checkDoorFlag = true;
        SFPRINTLN("Door Close Again");
      }

    }else{

      if(checkDoorFlag) {
        DoorCondition = D_DoorOpen;
        checkDoorFlag = false;
        TickerDoor.once(60, checkCloseAfterOneMin);
      }

    }
  }
}


int8_t  M = -1;
int16_t N = 0;
bool G_FiveMinuteReportFlag = false;
void checkAlarm() {                                           //Alarm

  if (DoorCondition == D_OneMinOpen || DoorCondition == D_FiveMinOpen){
    
    if (M == -1) {
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print(" Close The Door");
      lcd.setCursor(0, 1);
      lcd.print("Open More 1 Min");
      SFPRINTLN("Write in LCD");

      M = 0;
    }

    if (M == 0) {
      analogWrite(D_PIN_LEDIN, N++);
      lcd.setBacklight(0);
    }
    if (M == 1) {
      analogWrite(D_PIN_LEDIN, N--);
      lcd.setBacklight(D_SET_BRIGHTNESS);
    }
    if (N > 1000) M = 1;
    if (N < 0) M = 0;

    if (DoorCondition == D_FiveMinOpen) {
      if (!G_FiveMinuteReportFlag) {

        String msg = "Refrigerator's Door Is Open More Than Five Minutes";

        if (CF_MQTT_send_notif_to(msg)) G_FiveMinuteReportFlag = true;
        lcd.setCursor(0, 1);
        lcd.print("Open More 5 Min");
      }
      
    }
   
  }else{
    lcd.setBacklight(D_SET_BRIGHTNESS);
    M = -1;
    G_FiveMinuteReportFlag = false;
    digitalWrite(D_PIN_LEDIN, LOW);
  }
}
