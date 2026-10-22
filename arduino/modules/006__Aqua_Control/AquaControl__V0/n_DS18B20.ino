/********************************************************************/
// Setup a oneWire instance to communicate with any OneWire devices
// (not just Maxim/Dallas temperature ICs)
OneWire oneWire(D_PIN_TEMPS);
// Pass our oneWire reference to Dallas Temperature.
DallasTemperature tempSensor(&oneWire);

void setUpDS18B20() {
  tempSensor.begin();
}


void readTemp() {
  tempSensor.requestTemperatures(); // Send the command to get temperature readings
  
  G_TempAquarium = tempSensor.getTempCByIndex(0);
  Serial.print("Temp = ");
  Serial.println(G_TempAquarium);
}
