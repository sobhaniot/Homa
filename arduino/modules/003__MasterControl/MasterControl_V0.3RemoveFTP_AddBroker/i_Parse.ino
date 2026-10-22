void checkMessage(String message) {                                                 //check message function
  if (message.indexOf("lamp") > -1) 
                                    {
                                      Serial.println(message);
                                      WhichLamp = parseArray(message);
                                  
                                      String msgString = "{\"data\":" + (String)WhichLamp + ",\"condition\":\"Lamp\"}";
                                  
                                      MQTTclient.publish(publishTopic, (char*)&msgString[0]);
                                      delay(5);
                                      MQTTclient.publish(subscribeTopic, "0", true);
                                  
                                  
                                    } 
  else if (message.indexOf("Sim") > -1) 
                                    {
                                      Serial.println("Simulation");
                                      String msgString = "";
                                  
                                      if (SimCondition) {
                                        SimCondition = false;
                                        webSocket.broadcastTXT("{\"data\":0,\"condition\":\"Simulation\"}");
                                        msgString = "{\"data\":0,\"condition\":\"Simulation\"}";
                                      } else {
                                        SimCondition = true;
                                        flagDoSim = false;
                                        SimArrayIndex = 0;
                                        webSocket.broadcastTXT("{\"data\":1,\"condition\":\"Simulation\"}");
                                        msgString = "{\"data\":1,\"condition\":\"Simulation\"}";
                                      }
                                  
                                      MQTTclient.publish(publishTopic, (char*)&msgString[0]);
                                      EEPROM.write(eepromSim, SimCondition);
                                      delay(5);
                                      EEPROM.commit();
                                      MQTTclient.publish(subscribeTopic, "0", true);
                                  
                                    }
  else if (message.indexOf("Info") > -1) 
                                    {
                                  
                                      if (WiFi.status() == WL_CONNECTED && MQTTclient.connected()) {
                                  
                                        String msgString = "{\"data\":" + (String)SimCondition + ",\"condition\":\"Simulation\"}";
                                        
                                        webSocket.broadcastTXT(msgString);

                                        MQTTclient.publish(publishTopic, (char*)&msgString[0]);
                                      }
                                      delay(5);
                                      MQTTclient.publish(subscribeTopic, "0", true);
                                  
                                    }
}


byte parseArray(String message) {                                                                 //Function for parsing string to array
  byte LampCondition = 0;
  String stringVal;
  byte i = 0;
  while (message[i] != ']' && message[i] != '\0') {
    i++;
    if (isDigit(message[i])) {
      while ((message[i] != ']') && message[i] != '\0')
      {
        stringVal += message[i];
        i++;
        delay(1);
      }
      LampCondition = stringVal.toInt();
      stringVal = "";
      Serial.println(LampCondition);
    }
  }
  return LampCondition;
}
