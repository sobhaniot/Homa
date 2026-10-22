///////////////////////////////////////////////////////////////////////FireBase Notification
//void FirebaseSetup() {
//  Firebase.begin("a", "b");               //this method just use for ignor error
//  Firebase.reconnectWiFi(true);
//  //  Set the size of WiFi rx/tx buffers in the case where we want to work with large data.
//  FBNotification.setBSSLBufferSize(1024, 1024);
//
//  //Set the size of HTTP response buffers in the case where we want to work with large data.
//  FBNotification.setResponseSize(1024);
//
//  FBNotification.fcm.begin(D_FIREBASE_FCM_SERVER_KEY);
//
//  //  FBNotification.fcm.addDeviceToken(FIREBASE_FCM_DEVICE_TOKEN_1);
//
//  //  FBNotification.fcm.addDeviceToken(FIREBASE_FCM_DEVICE_TOKEN_2);
//
//  FBNotification.fcm.setPriority("high");
//
//  FBNotification.fcm.setTimeToLive(1000);
//}
//
//
//bool sendDataToFirebase(String* Token, char* message) {
//  //  Serial.println("Send Firebase Cloud Messaging...");
//  FBNotification.fcm.clearDeviceToken();
//  FBNotification.fcm.addDeviceToken(*Token);
//
//  FBNotification.fcm.setNotifyMessage(F("Refrigerator"), message);
//  String msg = "{\"myData\":\"" + String(message) + "\"}";
//  FBNotification.fcm.setDataMessage((char*)&msg[0]);
//
//  //if (Firebase.broadcastMessage(FBNotification))
//  //if (Firebase.sendTopic(FBNotification))
//  if (Firebase.sendMessage(FBNotification, 0))//send message to recipient index 0
//  {
//
//    Serial.println("PASSED");
//    Serial.println(FBNotification.fcm.getSendResult());
//    Serial.println("------------------------------------");
//    Serial.println();
//    return true;
//  }
//  else
//  {
//    Serial.println("FAILED");
//    Serial.println("REASON: " + FBNotification.errorReason());
//    Serial.println("------------------------------------");
//    Serial.println();
//    return false;
//  }
//}
//
//void AquariumReport(char* message) {
//
//  if (WiFi.status() == WL_CONNECTED) {
//
//    String msg = "{\"condition\":\"" + String(message) + "\"}";
//
//    MQTTclient.publish(G_publishTopic, (char*)&msg[0]);
//
//    bool resultOne = sendDataToFirebase( &G_FIREBASE_FCM_DEVICE_TOKEN_1 , message );
//    bool resultTwo = sendDataToFirebase( &G_FIREBASE_FCM_DEVICE_TOKEN_2 , message );
//    
//    if (resultOne || resultTwo) {
//      Serial.println("Send Message Success");
//    }
//
//  }
//}
