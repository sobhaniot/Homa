//class for timer counter with millis
#ifndef TimerCounter_h
#define TimerCounter_h
#include <Arduino.h>

class TimerCounter {

  public:
    TimerCounter();
    bool Wait(int WaitTime);
	void CountReset();
    unsigned long CountUntil(bool IF);
  private:
    unsigned long _previousTime;
    unsigned long _startCounting;
};

#endif

TimerCounter::TimerCounter() {
  _previousTime = millis();
  _startCounting = millis();
}

bool TimerCounter::Wait(int WaitTime) {                           // wait until you want with millisecond
  unsigned long diff = millis() - _previousTime;
  if (diff > WaitTime) {
    _previousTime = millis();
    return true;
  } else {
    return false;
  }
}
void TimerCounter::CountReset(){
	_startCounting = millis();
}
unsigned long TimerCounter::CountUntil(bool IF) {                // counting millisecond until IF will true
  if (IF) {
    unsigned long diff = millis() - _startCounting;
    return diff;
  }else{
	  return false;
  }
	  
}


