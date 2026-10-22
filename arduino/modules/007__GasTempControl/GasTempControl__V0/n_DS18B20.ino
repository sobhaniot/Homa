/********************************************************************/
// Setup a oneWire instance to communicate with any OneWire devices
// (not just Maxim/Dallas temperature ICs)
OneWire oneWire(D_PIN_TEMP);
// Pass our oneWire reference to Dallas Temperature.
DallasTemperature tempSensor(&oneWire);

void setUpDS18B20() {
  tempSensor.begin();
}


float readTemp() {
  tempSensor.requestTemperatures(); // Send the command to get temperature readings
  return tempSensor.getTempCByIndex(0);
}
