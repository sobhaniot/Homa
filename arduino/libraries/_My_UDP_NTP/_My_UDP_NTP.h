#include <NTPClient.h>
#include <WiFiUdp.h>

WiFiUDP ntpUDP;                     // Create an instance of the WiFiUDP class to send and receive
NTPClient timeClient(ntpUDP, "pool.ntp.org");

struct S_DaysTime{
  uint16_t    Days;
  uint32_t    Time;             
};

void My_start_NTP_UDP() {
  // Initialize a NTPClient to get time
  timeClient.begin();
  // Set offset time in seconds to adjust for your timezone, for example:
  // GMT +1 = 3600
  // GMT +8 = 28800
  // GMT -1 = -3600
  // GMT 0 = 0
  timeClient.setTimeOffset(0);
}

S_DaysTime My_getDaysTime() {

    Serial.println("\r\nSending NTP request ...");
    timeClient.update();

    unsigned long epoch         = timeClient.getEpochTime() + 12600;
    uint16_t days               = epoch/86400L;
    uint8_t  currentHour        = ((epoch % 86400L) / 3600);
    uint8_t  currentMinute      = ((epoch % 3600) / 60);
    uint8_t  currentSecond      = epoch % 60;

    S_DaysTime result = {days,(currentHour * 10000) + (currentMinute * 100) + currentSecond};
  return result;
}

String My_get_time_in_string_format(){
    S_DaysTime time_ = My_getDaysTime();
    String timeString = "Days = ";
    timeString += time_.Days;
    timeString += " Time = ";
    timeString += time_.Time / 10000;
    timeString += " : ";
    // agar koochecktar az 10 bood baraye ghashangie namayesh yek sefr be ghablesh ezafe mikonad
    timeString += ((time_.Time % 10000) / 100) < 10 ? "0" : "";
    timeString += (time_.Time % 10000) / 100;
    timeString += " : ";
    // agar koochecktar az 10 bood baraye ghashangie namayesh yek sefr be ghablesh ezafe mikonad
    timeString += (time_.Time % 100) < 10 ? "0" : "";
    timeString += time_.Time % 100;

    return timeString;
}

String My_convert_int_time_to_string_format(const uint32_t time_){
    String timeString = " Time = ";
    timeString += time_ / 10000;
    timeString += " : ";
    // agar koochecktar az 10 bood baraye ghashangie namayesh yek sefr be ghablesh ezafe mikonad
    timeString += ((time_ % 10000) / 100) < 10 ? "0" : "";
    timeString += (time_ % 10000) / 100;
    timeString += " : ";
    // agar koochecktar az 10 bood baraye ghashangie namayesh yek sefr be ghablesh ezafe mikonad
    timeString += (time_ % 100) < 10 ? "0" : "";
    timeString += time_ % 100;

    return timeString;
}

S_DaysTime My_timePlus(S_DaysTime DHMS,uint32_t P){ // P saat va daghighe va sanie ra chasbide be ham migirad, masalan 3:30:50 mishavad 33050
  uint8_t H = DHMS.Time / 10000;
  uint8_t M = (DHMS.Time % 10000) / 100;
  uint8_t S = DHMS.Time % 100;

  S += (P % 100);
  if(S>59){
    M += 1;
    S %= 60;
  }

  M += (P % 10000) / 100;
  if(M>59){
    H += 1;
    M %= 60;
  }
  H += (P / 10000);
  if(H>23){
    DHMS.Days += 1;
    H %= 24;
  }

  DHMS.Time = (H * 10000) + (M * 100) + S;

  return DHMS;
}

bool My_first_bigger(S_DaysTime f_time, S_DaysTime s_time){
  return f_time.Days > s_time.Days || (f_time.Days == s_time.Days && f_time.Time > s_time.Time);
}