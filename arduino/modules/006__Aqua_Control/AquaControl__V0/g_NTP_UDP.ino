WiFiUDP ntpUDP;                     // Create an instance of the WiFiUDP class to send and receive
NTPClient timeClient(ntpUDP, "pool.ntp.org");

int lastTime = 0;

void start_NTP_UDP() {
  // Initialize a NTPClient to get time
  timeClient.begin();
  // Set offset time in seconds to adjust for your timezone, for example:
  // GMT +1 = 3600
  // GMT +8 = 28800
  // GMT -1 = -3600
  // GMT 0 = 0
  timeClient.setTimeOffset(0);
}

int NTP_Handle() {
  if (TNTP.Wait(20000)) { // If a minute has passed since last NTP request
    Serial.println("\r\nSending NTP request ...");
    timeClient.update();

    int currentHour = timeClient.getHours();
    int currentMinute = timeClient.getMinutes();
    currentMinute += 30;
    if (currentMinute > 59) {
      currentMinute %= 60;
      currentHour += 4;
      currentHour > 23 ? currentHour %= 24 : currentHour;

    } else {
      currentHour += 3;
      currentHour > 23 ? currentHour %= 24 : currentHour;
    }



    Serial.print("Time = ");
    Serial.print(currentHour);
    Serial.print(" : ");
    Serial.println(currentMinute);

    lastTime = (currentHour * 100) + currentMinute;
  }

  return lastTime;
}
