void doSimulation(bool SimCond) {

  if (SimCond) {
    if (!flagDoSim) {
      previousTime = millis();
      flagDoSim = true;
      WhichLamp = SimArrayLamp[SimArrayIndex];
      SimArrayIndex += 1;
    }

    unsigned long diff = millis() - previousTime;

    if(diff > 2000000 ) {
      diff = 0;
      previousTime = millis();
    }

    if (diff > OnOffDelay) {
      WhichLamp = SimArrayLamp[SimArrayIndex];
      SimArrayIndex += 1;
      if (SimArrayIndex > 7) SimArrayIndex = 0;
      Serial.print("Sim Index : ");
      Serial.println(SimArrayIndex);
      
      previousTime += diff;

      (OnOffDelay == OffDelayVal) ? OnOffDelay = OnDelayVal : OnOffDelay = OffDelayVal ;
    }
  }
}
