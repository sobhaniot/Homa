const int DS1307 = 0x68; // Address of DS1307 see data sheets

const char* days[] =
{"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"};
byte second = 0;
byte minute = 0;
byte hour = 0;
byte weekday = 0;
byte monthday = 0;
byte month = 0;
byte year = 0;

/////////////////////////////////////////////////////////////////////////Time rtc 1307 Section
byte decToBcd(byte val) {
  return ((val / 10 * 16) + (val % 10));
}
byte bcdToDec(byte val) {
  return ((val / 16 * 10) + (val % 16));
}
// This set of codes is allows input of data
void setTime(String yearS, String monthS, String monthdayS, String weekdayS, String hourS, String minuteS) {
  year = yearS.toInt();
  month = monthS.toInt();
  monthday = monthdayS.toInt();
  weekday = weekdayS.toInt();
  hour = hourS.toInt();
  minute = minuteS.toInt();
  second = 0;
//  Serial.println("The data has been entered.");

  // The following codes transmits the data to the RTC
  Wire.beginTransmission(DS1307);
  Wire.write(byte(0));
  Wire.write(decToBcd(second));
  Wire.write(decToBcd(minute));
  Wire.write(decToBcd(hour));
  Wire.write(decToBcd(weekday));
  Wire.write(decToBcd(monthday));
  Wire.write(decToBcd(month));
  Wire.write(decToBcd(year));
  Wire.write(byte(0));
  Wire.endTransmission();
  // Ends transmission of data
}

void printTime(char* powerStatus) {
  readTime();

  fs::File f = SPIFFS.open("/info.txt", "a");                 // Open it
  f.print(String(days[weekday - 1]) + " (" + "20" + String(year) + " " + String(month) + " " + String(monthday) +  ") Clock:: " + String(hour) + ":" + String(minute) + " ===>>> " + powerStatus + "\n");
  delay(5);
  f.close();                                       // Then close the file again
}


void readTime() {
  Wire.beginTransmission(DS1307);
  Wire.write(byte(0));
  Wire.endTransmission();
  Wire.requestFrom(DS1307, 7);
  second = bcdToDec(Wire.read());
  minute = bcdToDec(Wire.read());
  hour = bcdToDec(Wire.read());
  weekday = bcdToDec(Wire.read());
  monthday = bcdToDec(Wire.read());
  month = bcdToDec(Wire.read());
  year = bcdToDec(Wire.read());
}
