#include <EEPROM.h>

String CF_EEPROM_reed_string(const int* address);

void CF_EEPROM_SetUp(int _size) {
  EEPROM.begin(_size);
  delay(100);
  ////////////////////////////////////////////////////////////EEPROM SSID
  G_SSID = CF_EEPROM_reed_string(D_eepromSSID);
  Serial.print("\nSSID = ");  Serial.println(G_SSID);
   ////////////////////////////////////////////////////////////EEPROM PASSWORD
  G_PASSWORD = CF_EEPROM_reed_string(D_eepromPASSWORD);
  Serial.print("PASSWORD = ");  Serial.println(G_PASSWORD);
   ////////////////////////////////////////////////////////////EEPROM broker url
  G_mqtt_server = CF_EEPROM_reed_string(D_eepromBroker);
  Serial.print("MQTT Broker = ");  Serial.println(G_mqtt_server);Serial.println("");
}

bool CF_EEPROM_reed_bool(const int* address){
  if(EEPROM.read(address[0]) == 1){
    return true;
  }else{
    return false;
  }
}

void CF_EEPROM_write(const bool value, const int* address) {
  byte L = 0;
  bool existValue = CF_EEPROM_reed_bool(address);
  if (value != existValue) {
    EEPROM.write(address[0], value);
    delay(5);
    EEPROM.commit();
  }
}

String CF_EEPROM_reed_string(const int* address) {
  byte n = 0;
  String value;
  while (EEPROM.read(address[0] + n) != 255){
    value += (char)EEPROM.read(address[0] + n);
    n++;
    delay(5);
  }
  return value;
}

void CF_EEPROM_write(const String value, const int* address) {
  if(value.length() <= address[1]){
    byte L = 0;
    String existValue = CF_EEPROM_reed_string(address);
    if (value != existValue) {
      for (; L < value.length(); L++) {
        EEPROM.write((address[0] + L), value[L]);
        delay(5);
      }
      EEPROM.write((address[0] + L), 255);
      delay(5);
      EEPROM.commit();
    }
  }
}
