HTTPClient http;
#define fatherURL "http://www.eleknow.com/wp-content/themes/eleknowV2/iot/power_report/fatherWrite.php"

///////////////////////////////////////////////////////////////////////
// in ghesmat baraye ferestadan etelaate ghatio vasli be server mibashad
// 
bool sendPowerLostData() {
  String message = "message=";

  fs::File h = SPIFFS.open("/info.txt", "r");                 // Open it

  int z;
  int q = 0;

  for (z = 0; z < h.size(); z++) //Read upto complete file size
  {
    //    Serial.print((char)h.read());
    delay(1);
    message += (char)h.read();

  }
  h.close();


  if (http.begin(fatherURL)) {

    http.addHeader("Content-Type", "application/x-www-form-urlencoded");
    int httpCode = http.POST(message);
    delay(100);
//    Serial.println(httpCode);
//    Serial.println(http.errorToString(httpCode).c_str());
    String payload = "";
    if (httpCode > 0) { //Check the returning code
      payload = http.getString();   //Get the request response payload
//      Serial.println(payload);                     //Print the response payload
//      Serial.flush();
    }

    delay(500);
    http.end();   //Close connection
    if (payload.indexOf("success") > -1) {
      return true;
    } else {
      return false;
    }
  }
}
