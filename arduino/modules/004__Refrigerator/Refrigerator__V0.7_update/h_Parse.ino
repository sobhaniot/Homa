void checkMessage(String message) {  //check message function
  //vaghti dar msg kalameye type nabashad nabayad edame dahad
  if(message.indexOf("type") == -1) return;
  
  deserializeJson(Json, message);
  const char* type = Json["type"];
  // for strcmp if equal two string return 0
  if (!strcmp(type, "Param"))                                                 //check message function
                                    {
                                          float Temp = Json["Temp"];
                                          float Hyster = Json["Hyster"];

                                          // Print values.
                                          Serial.println(Temp);
                                          Serial.println(Hyster);
                                      
                                          
                                          handleTemp(G_MinTemp , G_MaxTemp, Temp, Hyster);
                                      
                                          String msgString = "{\"type\":\"Success\"}";
                                      
                                          CF_MQTT_send_msg_to(msgString);
                                        }
  else if (!strcmp(type, "Info"))                                                        ////Information

                                        {
                                          sendInfo();
                                        }
                                        
}

void sendInfo(){
  String msgString = "{\"TempIn\":" ;
  msgString += G_TempIn;
  msgString += ",\"TempOut\":" ;
  msgString += G_TempOut;
  msgString += ",\"MinTemp\":" ;
  msgString += G_MinTemp;
  msgString += ",\"MaxTemp\":" ;
  msgString += G_MaxTemp;
  msgString += ",\"Temp\":" ;
  msgString += (G_MaxTemp + G_MinTemp)/2;
  msgString += ",\"Hyster\":" ;
  msgString += (G_MaxTemp - G_MinTemp);
  msgString += ",\"OnTime\":" ;
  msgString += G_OnTime;
  msgString += ",\"OffTime\":" ;
  msgString += G_OffTime;

  msgString += ",\"IP\":" ;
  msgString += "\"" + WiFi.localIP().toString() + "\"";

  msgString += ",\"type\":\"Info\"}";

  CF_MQTT_send_msg_to(msgString);
}

void handleTemp(float &MinTemp , float &MaxTemp, float temp, float hyster) {                              //handle temp input and hysteresis

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("SetTemp = ");
  lcd.print(temp);
  lcd.write(5);
  lcd.setCursor(0, 1);
  lcd.print("SetHyster = ");
  lcd.print(hyster);
  lcd.write(5);

  MinTemp = temp - (hyster / 2);
  MaxTemp = temp + (hyster / 2);

  SFPRINT("minTemp = ");
  Serial.println(MinTemp);
  SFPRINT("maxTemp = ");
  Serial.println(MaxTemp);

  CF_EEPROM_write(String(MinTemp), D_eepromMinTemp);
  CF_EEPROM_write(String(MaxTemp), D_eepromMaxTemp);
}
