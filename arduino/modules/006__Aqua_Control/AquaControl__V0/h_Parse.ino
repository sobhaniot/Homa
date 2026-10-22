void checkMessage(String message) {  //check message function

  if (message.indexOf("Option") > -1)                                                        ////OPTION

                                        {
                                          const char* condition;
                                          
                                          parseJson(message, condition, G_FilterStart, G_FilterEnd, G_BubbleStart, G_BubbleEnd);

                                          writeEEPROM(String(G_BubbleStart), D_eepromBubbleStart);
                                          writeEEPROM(String(G_BubbleEnd), D_eepromBubbleEnd);
                                          
                                          writeEEPROM(String(G_FilterStart), D_eepromFilterStart);
                                          writeEEPROM(String(G_FilterEnd), D_eepromFilterEnd);

                                          String msgString = "{\"condition\":\"Success\"}";
                                                                                
                                          MQTTclient.publish(G_publishTopic, (char*)&msgString[0]);
                                      
                                          MQTTclient.publish(G_subscribeTopic, "0", true); // in bakhsh baraye in ast ke dar servere mqtt chizi baghi namanad
                                        }
  else if (message.indexOf("Info") > -1)                                                        ////Information

                                        {
                                          String msgString = "{\"BubbleStart\":" ;
                                          msgString += G_BubbleStart;
                                          msgString += ",\"BubbleEnd\":" ;
                                          msgString += G_BubbleEnd;
                                          msgString += ",\"FilterStart\":" ;
                                          msgString += G_FilterStart;
                                          msgString += ",\"FilterEnd\":" ;
                                          msgString += G_FilterEnd;
                                          msgString += ",\"Temp\":" ;
                                          msgString += G_TempAquarium;
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



void parseJson(String message, const char* condition, uint16_t &FilterOn, uint16_t &FilterOff, uint16_t &BubbleOn, uint16_t &BubbleOff) {  //convert json to variable
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
  FilterOn = Json["FilterOn"];
  FilterOff = Json["FilterOff"];
  BubbleOn = Json["BubbleOn"];
  BubbleOff = Json["BubbleOff"];
  
  // Print values.
  Serial.println(condition);
  Serial.println(FilterOn);
  Serial.println(FilterOff);
  Serial.println(BubbleOn);
  Serial.println(BubbleOff);
}
