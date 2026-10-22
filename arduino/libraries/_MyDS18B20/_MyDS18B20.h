/********************************************************************/
#include <OneWire.h>
#include <DallasTemperature.h>
// Setup a oneWire instance to communicate with any OneWire devices
// (not just Maxim/Dallas temperature ICs)
OneWire oneWire(D_PIN_TEMPS);
// Pass our oneWire reference to Dallas Temperature.
DallasTemperature tempSensor(&oneWire);

void My_setUpDS18B20() {
  tempSensor.begin();
}

uint8_t address = 0;

float My_readTemp(uint8_t num = 0) {
  // finds an address at a given index on the bus
	// bool getAddress(uint8_t*, uint8_t);
  // Serial.println(address);

  if(address){
    // returns temperature in degrees C
	  // float getTempC(const uint8_t*);
    // 
    tempSensor.requestTemperaturesByAddress(&address); // Send the command to get temperature readings  
    return tempSensor.getTempC(&address);
    // return tempSensor.getTempCByIndex(num);
  } else{
    tempSensor.getAddress(&address,num);
    return 0;
  }
  

  

  

  
 
}
