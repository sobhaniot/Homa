void remoteDo() {
  if (mySwitch.available()) {
    byte code = mySwitch.getReceivedValue() % 100;

    shodAllCode();      //show all posible on remote control

    if (code == OpenCode && !flagOpen && !flagClose) {
      digitalWrite(PinOpen, HIGH);
      flagOpen = true;
      previousCOTime = millis();
    }

    if (code == CloseCode && !flagOpen && !flagClose) {
      digitalWrite(PinClose, HIGH);
      flagClose = true;
      previousCOTime = millis();
    }

    if (code == TrunkCode && !flagTrunk) {
      digitalWrite(PinTrunk, HIGH);
      flagTrunk = true;
      previousTrunkTime = millis();
    }

    mySwitch.resetAvailable();
  }

  unsigned int diffCO = millis() - previousCOTime;

  if (diffCO > 200000 ) {
    diffCO = 0;
    previousCOTime = millis();
  }

  
  if (flagOpen && diffCO > 3000) {
    digitalWrite(PinOpen, LOW);
    flagOpen = false;
  }

  if (flagClose && diffCO > 3000) {
    digitalWrite(PinClose, LOW);
    flagClose = false;
  }
  
  unsigned int diffTrunk = millis() - previousTrunkTime;

  if (diffTrunk > 200000 ) {
    diffTrunk = 0;
    previousTrunkTime = millis();
  }
  
  if (flagTrunk && diffTrunk > 300) {
    digitalWrite(PinTrunk, LOW);
    flagTrunk = false;
  }

}
