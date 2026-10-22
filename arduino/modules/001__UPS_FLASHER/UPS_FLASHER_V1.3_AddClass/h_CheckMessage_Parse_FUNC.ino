void checkMessage(String message) {  //check message function


  if (message.indexOf("ON") > -1)                                                                ////ON
  
                                {
                                  //    Serial.println("ON");
                              
                                  String msgString = "{\"data\":[1,1],\"condition\":\"ON\"}";
                              
                                  MQTTclient.publish(publishTopic, (char*)&msgString[0]);
                                  OnOff = 1;
                                  MQTTclient.publish(subscribeTopic, "0", true);
                                }

  else if (message.indexOf("OFF") > -1)                                                          ////OFF

                                {
                                  //    Serial.println("OFF");
                              
                                  String msgString = "{\"data\":[0,0],\"condition\":\"OFF\"}";
                              
                                  MQTTclient.publish(publishTopic, (char*)&msgString[0]);
                                  OnOff = 0;
                                  MQTTclient.publish(subscribeTopic, "0", true);
                                }

  else if (message.indexOf("Flasher") > -1)                                                       ////FLASHER

                                {
                                  //    Serial.println("Flasher");
                                  OnOff = 2;
                                  parseArray(message);
                              
                                  String msgString = "{\"data\":" + message.substring(7) + ",\"condition\":\"Flasher\"}";
                              
                                  MQTTclient.publish(publishTopic, (char*)&msgString[0] );
                                  MQTTclient.publish(subscribeTopic, "0", true);
                                }

  else if (message.indexOf("Fade") > -1)                                                          ////FADE

                                {
                                  //    Serial.println("Fade");
                                  OnOff = 3;
                              
                                  parseArray(message);
                              
                                  String msgString = "{\"data\":" + message.substring(4) + ",\"condition\":\"Fade\"}";
                              
                                  MQTTclient.publish(publishTopic, (char*)&msgString[0]);
                                  MQTTclient.publish(subscribeTopic, "0", true);
                                }

  else if (message.indexOf("Option") > -1)                                                        ////OPTION

                                {
                                  String Option;
                                  for (uint8_t j = 7 ; j < 10 ; j++) {
                                    Option += message[j];
                                  }
                                  conditionPowerGone = Option.toInt();
                              
                                  String msgString = "{\"OP\":" + Option + ",\"condition\":\"Option\"}";
                              
                                  MQTTclient.publish(publishTopic, (char*)&msgString[0]);
                              
                                  EEPROM.write(eepromOption, conditionPowerGone);
                                  delay(5);
                                  EEPROM.commit();
                              
                                  MQTTclient.publish(subscribeTopic, "0", true);
                                }
  else if (message.indexOf("Info") > -1)                                                        ////Information

                                {
                                  String msgString = "{\"OP\":" + String(conditionPowerGone) + ",\"condition\":\"Info\"}";
                              
                                  MQTTclient.publish(publishTopic, (char*)&msgString[0]);
                              
                                  MQTTclient.publish(subscribeTopic, "0", true);
                                }
  else if (message.indexOf("Token") > -1)                                                        //Get Token from app on mobile

                                {
                                  message.remove(0,6);
                                  message.remove(message.length()-1);
                                  
                                  MQTTclient.publish(publishTopic, (char*)&message[0]);
                              
                                  MQTTclient.publish(subscribeTopic, "0", true);
                                  
                                  if(message != FIREBASE_FCM_DEVICE_TOKEN_1 && message != FIREBASE_FCM_DEVICE_TOKEN_2){ // if token was new
                                      if(flagWhichTokenSave == 0){
                                          flagWhichTokenSave = 1;
                                          FIREBASE_FCM_DEVICE_TOKEN_1 = message;

                                          byte L = 0;
                                          for (; L < FIREBASE_FCM_DEVICE_TOKEN_1.length(); L++) {
                                              EEPROM.write((eepromFirstToken + L), FIREBASE_FCM_DEVICE_TOKEN_1[L]);
                                              delay(5);
                                          }
                                          for (; L < 200; L++) {
                                              EEPROM.write((eepromFirstToken + L), 255);
                                              delay(5);
                                          }
                                      EEPROM.commit();
                                      
                                      }else if(flagWhichTokenSave == 1){
                                          flagWhichTokenSave = 0;
                                          FIREBASE_FCM_DEVICE_TOKEN_2 = message;

                                          byte L = 0;
                                          for (; L < FIREBASE_FCM_DEVICE_TOKEN_2.length(); L++) {
                                              EEPROM.write((eepromSecondToken + L), FIREBASE_FCM_DEVICE_TOKEN_2[L]);
                                              delay(5);
                                          }
                                          for (; L < 200; L++) {
                                              EEPROM.write((eepromSecondToken + L), 255);
                                              delay(5);
                                          }
                                      EEPROM.commit();

                                    }

                                  EEPROM.write(eepromFlagToken, flagWhichTokenSave);
                                  delay(5);
                                  EEPROM.commit();
                                  }
                                }
}



void parseArray(String message) {                                                                 //Function for parsing string to array
  byte rythmIndex = 0;
  String stringVal;
  byte i = 0;
  while (message[i] != ']' && message[i] != '\0') {
    i++;
    if (isDigit(message[i])) {

      while ((message[i] != ',') && (message[i] != ']') && message[i] != '\0')

      {
        stringVal += message[i];
        i++;
        delay(1);
      }

      rythm[rythmIndex] = stringVal.toInt();
      stringVal = "";
      //      Serial.println(rythm[rythmIndex]);
      rythmIndex++;

    }
  }
  for (; rythmIndex < 50; rythmIndex++) {
    rythm[rythmIndex] = 0;
  }
  k = 0;         // cause in loop function after order k must be zero
}
