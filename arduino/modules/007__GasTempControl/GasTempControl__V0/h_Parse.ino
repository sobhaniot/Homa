void checkMessage(String message) {  //check message function

  if (message.indexOf("Option") > -1)                                                        ////OPTION

                                        {
                                          const char* condition;
                                          
                                          parseJson(message, condition, G_TempH, G_TempL, G_GasH, G_GasL);

                                          writeEEPROM(String(G_TempH), D_eepromTempH);
                                          writeEEPROM(String(G_TempL), D_eepromTempL);
                                          
                                          writeEEPROM(String(G_GasH), D_eepromGasH);
                                          writeEEPROM(String(G_GasL), D_eepromGasL);
                                          
                                          String msgString = "{\"condition\":\"Success\"}";
                                      
                                          MQTTclient.publish(G_publishTopic, (char*)&msgString[0]);
                                      
                                          MQTTclient.publish(G_subscribeTopic, "0", true); // in bakhsh baraye in ast ke dar servere mqtt chizi baghi namanad
                                        }
  else if (message.indexOf("Info") > -1)                                                        ////Information

                                        {
                                          float Temp = readTemp();
                                          int Gas = readGas();
                                          String msgString = "{\"TempH\":" ;
                                          msgString += G_TempH;
                                          msgString += ",\"TempL\":" ;
                                          msgString += G_TempL;
                                          msgString += ",\"GasH\":" ;
                                          msgString += G_GasH;
                                          msgString += ",\"GasL\":" ;
                                          msgString += G_GasL;
                                          msgString += ",\"Temp\":" ;
                                          msgString += Temp;
                                          msgString += ",\"Gas\":" ;
                                          msgString += Gas;
                                          msgString += ",\"DTempH\":" ;
                                          msgString += G_daily_temp_high;
                                          msgString += ",\"DTempL\":" ;
                                          msgString += G_daily_temp_low;
                                          msgString += ",\"DGasH\":" ;
                                          msgString += G_daily_gas_high;
                                          msgString += ",\"DGasL\":" ;
                                          msgString += G_daily_gas_low;
                                          msgString += ",\"condition\":\"Info\"}";

                                          MQTTclient.publish(G_publishTopic, (char*)&msgString[0]);
                                      
                                          MQTTclient.publish(G_subscribeTopic, "0", true);
                                        }
  else if (message.indexOf("Token") > -1)                                                        //Get Token from app on mobile

                                        {
                                          message.remove(0, 6);
                                          message.remove(message.length() - 1);
                                      
                                          MQTTclient.publish(G_publishTopic, (char*)&message[0]);
                                      
                                          MQTTclient.publish(G_subscribeTopic, "0", true);
                                      
                                          if (message != G_FIREBASE_FCM_DEVICE_TOKEN_1 && message != G_FIREBASE_FCM_DEVICE_TOKEN_2) { // if token was new
                                            if (G_flagWhichTokenSave == 0) {
                                              G_flagWhichTokenSave = 1;
                                              G_FIREBASE_FCM_DEVICE_TOKEN_1 = message;
                                      
                                              writeEEPROM(G_FIREBASE_FCM_DEVICE_TOKEN_1, D_eepromFirstToken);      //this function declare in eeprom tab
                                      
                                            } else if (G_flagWhichTokenSave == 1) {
                                              G_flagWhichTokenSave = 0;
                                              G_FIREBASE_FCM_DEVICE_TOKEN_2 = message;
                                      
                                              writeEEPROM(G_FIREBASE_FCM_DEVICE_TOKEN_2, D_eepromSecondToken);     //this function declare in eeprom tab
                                      
                                            }
                                      
                                            EEPROM.write(D_eepromFlagToken, G_flagWhichTokenSave);
                                            delay(5);
                                            EEPROM.commit();
                                          }
                                        }
}



void parseJson(String message, const char* condition, int &TempHigh, int &TempLow, int &GasHigh, int &GasLow) {  //convert json to variable
  // Deserialize the JSON document
  DeserializationError error = deserializeJson(Json, message);

  // Test if parsing succeeds.
  if (error) {
    Serial.print(F("deserializeJson() failed: "));
    Serial.println(error.f_str());
    return;
  }

  // Fetch values.
  //
  // Most of the time, you can rely on the implicit casts.
  // In other case, you can do doc["time"].as<long>();
  condition = Json["condition"];
  TempHigh = Json["TempH"];
  TempLow = Json["TempL"];
  GasHigh = Json["GasH"];
  GasLow = Json["GasL"];
  
  // Print values.
  Serial.println(condition);
  Serial.println(TempHigh);
  Serial.println(TempLow);
  Serial.println(GasHigh);
  Serial.println(GasLow);
}
