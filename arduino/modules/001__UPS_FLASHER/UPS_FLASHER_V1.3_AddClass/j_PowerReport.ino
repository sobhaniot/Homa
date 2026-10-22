////////////////////////////////////////////////////////////////////////SetUp Function
void PowerConditionReport() {
  bool pinRead = digitalRead(CheckPin);

  (!pinRead) ? OnOffSwitch = POWERGONE : OnOffSwitch = OnOff;

  if (WiFi.status() == WL_CONNECTED && !pinRead && millis() % 60000 == 0 && !flagPowerGone) {

    MQTTclient.publish(publishTopic, "{\"condition\":\"Power Gone\"}");

    bool resultOne = sendDataToFirebase( &FIREBASE_FCM_DEVICE_TOKEN_1 , "Power Gone" );
    bool resultTwo = sendDataToFirebase( &FIREBASE_FCM_DEVICE_TOKEN_2 , "Power Gone" );
    if (resultOne || resultTwo) {
      flagPowerGone = true;
      //      Serial.println("Send Message Success");
    }

  }
  if (WiFi.status() == WL_CONNECTED && pinRead && millis() % 60000 == 0 && flagPowerGone) {

    MQTTclient.publish(publishTopic, "{\"condition\":\"Power is Back\"}");

    bool resultOne = sendDataToFirebase( &FIREBASE_FCM_DEVICE_TOKEN_1 , "Power is Back");
    bool resultTwo = sendDataToFirebase( &FIREBASE_FCM_DEVICE_TOKEN_2 , "Power is Back" );
    if (resultOne || resultTwo) {
      flagPowerGone = false;
      //      Serial.println("Send Message Success");
    }

  }

}
