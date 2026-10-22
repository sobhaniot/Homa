//https://api.telegram.org/bot226195640:AAF1BAqvJKl9v_4Ch0-oEWyxdNDiFqCkOss/sendMessage?chat_id=86978452&text=""

void SendToBot(char* msg) {
  //  HTTPClient httpTelegram;  //Declare an object of class HTTPClient
  WiFiClientSecure httpsTelegram;
  HTTPClient http;
  httpsTelegram.setInsecure();

  String urlTelegram = "https://api.telegram.org/bot226195640:AAF1BAqvJKl9v_4Ch0-oEWyxdNDiFqCkOss/sendMessage?chat_id=86978452&text=\""; //make url for telegram
  urlTelegram += String(msg);
  urlTelegram += "\"";

  httpsTelegram.connect(urlTelegram, 443);

  Serial.println(urlTelegram);                     //Print the response payload

  http.begin(httpsTelegram, (char *)&urlTelegram[0]); //Specify request destination
  int httpCode = http.GET();                                                                  //Send the request

  Serial.println(httpCode);                     //Print the response payload

  if (httpCode > 0) { //Check the returning code
    String payload = http.getString();   //Get the request response payload
    Serial.println(payload);                     //Print the response payload
    Serial.println("msg Send to Bot");                     //Print the response payload
    Serial.flush();
  }
  http.end();   //Close connection
}
