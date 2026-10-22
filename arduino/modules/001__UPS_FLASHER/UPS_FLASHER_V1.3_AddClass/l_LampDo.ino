void LampDo() {
  unsigned long diff = millis() - previousTime;

  if (diff > 200000 ) {
    diff = 0;
    previousTime = millis();
  }

  switch (OnOffSwitch) {
    case OFF: {                                            //condition for led off
        digitalWrite(PinLED, HIGH);
        digitalWrite(relayModemPin, HIGH);
        digitalWrite(relayCameraPin, HIGH);
      } break;
    case ON: {                                            //condition for led on
        digitalWrite(PinLED, LOW);
      } break;
    case FLASHER: {                                            //condition for led flasher mode
        if (diff > rythm[k]) {
          ((k % 2) != 0) ? Condition = false : Condition = true;
          if (rythm[k] > 5) digitalWrite(PinLED, Condition);  // Change the state of the LED when rythm > 5 millisecond
          previousTime += diff;
          k++;
          if (k > (sizeof(rythm) / sizeof(rythm[0]) - 1)) k = 0; // when finish array start from first of
        }
      } break;
    case FADE: {
        int fadeNum;
        if (rythm[k] > 5) {
          switch (k % 4) {
            case 0: {
                fadeNum = (1024 - (((float)500 / (float)rythm[k]) * diff));
              } break;
            case 1: {
                fadeNum = 0;
              } break;
            case 2: {
                fadeNum = (524 + (((float)500 / (float)rythm[k]) * diff));
              } break;
            case 3: {
                fadeNum = 1024;
              } break;
          }
          analogWrite(PinLED, fadeNum );
        }

        if (diff > rythm[k]) {
          previousTime += diff;
          k++;
        }
        if (k > (sizeof(rythm) / sizeof(rythm[0]) - 1)) k = 0;
      } break;

    case POWERGONE: {                                            //condition when power gone

        ((conditionPowerGone / 100) == 2) ? digitalWrite(relayCameraPin, LOW) : digitalWrite(relayCameraPin, HIGH);
        (((conditionPowerGone % 100) / 10) == 2) ? digitalWrite(relayModemPin, LOW) : digitalWrite(relayModemPin, HIGH);
        ((conditionPowerGone % 10) == 2) ? digitalWrite(PinLED, LOW) : digitalWrite(PinLED, HIGH);
        OnOff = OFF;
      } break;
  }
}
