void rfSetUp() {
  // Transmitter is connected to ESP8266 Pin #2
  mySwitch.enableTransmit(PinRF);
  //Optional set protocol (default is 1, will work for most outlets)
  mySwitch.setProtocol(5);
  //Optional set pulse length.
  mySwitch.setPulseLength(385);
  //Optional set number of transmission repetitions.
  mySwitch.setRepeatTransmit(8);

}
