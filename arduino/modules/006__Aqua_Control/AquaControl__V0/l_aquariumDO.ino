void AquariumDO(const uint16_t last_time) {
  checkTime(G_BubbleStart, G_BubbleEnd, last_time, D_PIN_BUBBLE);
  checkTime(G_FilterStart, G_FilterEnd, last_time, D_PIN_FILTER);
}

void checkTime(uint16_t startTime, uint16_t endTime, uint16_t last_time, uint8_t pinNumber) {
  // if in 24 hours each outlet cant low reset micro
  if (TError.CountUntil(true) > (24*60*60*1000)){
    ESP.reset();
  }
  if (endTime - startTime < 0) {
    if ((startTime <= last_time && last_time < 2400) || (0 <= last_time && last_time < endTime)) {
      digitalWrite(pinNumber, HIGH);
    } else {
      digitalWrite(pinNumber, LOW);
      TError.CountReset();
    }
  } else {
    if (startTime <= last_time && last_time < endTime) {
      digitalWrite(pinNumber, HIGH);
    } else {
      digitalWrite(pinNumber, LOW);
      TError.CountReset();
    }
  }
}
/********************************************************************************/
