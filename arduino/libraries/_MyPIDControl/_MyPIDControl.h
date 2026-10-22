
#ifndef pidControl_h
#define pidControl_h
// 

template <class T>
class MyPIDControl{
  private:
    unsigned long currentTime, previousTime;
    double lastError;
    double _setPoint;
    double cumError, rateError;
    T _kPkIkD;

  public:

    void SetUp(T pid, float  setPoint){
      _kPkIkD = pid;
      cumError = 0;
      _setPoint = setPoint;
    }


    // T computePID(float inp){
    //   T out;     
    //   currentTime = millis();                //get current time
    //   float elapsedTime = (float)(currentTime - previousTime);        //compute time elapsed from previous computation
      
    //   if (elapsedTime > 30000){
    //   cumError = 0;
    //   elapsedTime = 10;
    //   lastError = 0;
    //   }

    //   float error = _setPoint - inp;                                // determine error
    //   cumError += error * elapsedTime;                              // compute integral
    //   rateError = (error - lastError)/elapsedTime;                  // compute derivative

    //   out.kP = _kPkIkD.kP * error;
    //   out.kI = _kPkIkD.kI * cumError;
    //   out.kD = _kPkIkD.kD * rateError;

    //   lastError = error;                                //remember current error
    //   previousTime = currentTime;                        //remember current time

    //   return out;                                        //have function return the PID output
    // }

    T computePID(float inp){
      T out;     
      currentTime = millis();                //get current time
      float elapsedTime = (float)(currentTime - previousTime);        //compute time elapsed from previous computation
      
      if (elapsedTime > 30000){
      cumError = 0;
      elapsedTime = 10;
      lastError = 0;
      }

      float error = _setPoint - inp;                                // determine error
      
      if(!cumError && _kPkIkD.ActI && (abs(error) >= _kPkIkD.ActI)){
        cumError = 0;
      }else{
        cumError += error * elapsedTime;                              // compute integral
      }

      rateError = (error - lastError)/elapsedTime;                  // compute derivative

      out.kP = _kPkIkD.kP * error;
      out.kI = _kPkIkD.kI * cumError;
      out.kD = _kPkIkD.kD * rateError;

      lastError = error;                                //remember current error
      previousTime = currentTime;                        //remember current time

      return out;                                        //have function return the PID output
    }
    
};
#endif





