#include <LiquidCrystal_PCF8574.h>
#include <Wire.h>

LiquidCrystal_PCF8574 lcd(0x27); // set the LCD address to 0x27 for a 16 chars and 2 line display

#define D_SET_BRIGHTNESS      120
//************************************************// PINS

#define D_PIN_SDA             13          // 13=sda, 12=scl
#define D_PIN_SCL             12

/********************************************************************/
//Creat Character
byte sotoon1[8] = {
  B10000,
  B10000,
  B10000,
  B10000,
  B10000,
  B10000,
  B10000,
  B10000
};
byte sotoon2[8] = {
  B11000,
  B11000,
  B11000,
  B11000,
  B11000,
  B11000,
  B11000,
  B11000
};
byte sotoon3[8] = {
  B11100,
  B11100,
  B11100,
  B11100,
  B11100,
  B11100,
  B11100,
  B11100
};
byte sotoon4[8] = {
  B11110,
  B11110,
  B11110,
  B11110,
  B11110,
  B11110,
  B11110,
  B11110
};
byte sotoon5[8] = {
  B11111,
  B11111,
  B11111,
  B11111,
  B11111,
  B11111,
  B11111,
  B11111
};
byte daraje[8] = {
  B01100,
  B10010,
  B10010,
  B01100,
  B00000,
  B00000,
  B00000,
  B00000
};
/********************************************************************/

void setUpLCD() {
  Wire.pins(D_PIN_SDA, D_PIN_SCL);// yes, see text
  Wire.begin(D_PIN_SDA, D_PIN_SCL); // 13=sda, 12=scl

  Wire.beginTransmission(0x27);
  Wire.endTransmission();

  /********************************************************************/
  lcd.begin(16, 2); // initialize the lcd

  lcd.setBacklight(D_SET_BRIGHTNESS);
  lcd.noBlink();
  lcd.noCursor();
}
/********************************************************************/
void SetCharLCD() {
  //set number to charector
  lcd.createChar(0, sotoon1);
  lcd.createChar(1, sotoon2);
  lcd.createChar(2, sotoon3);
  lcd.createChar(3, sotoon4);
  lcd.createChar(4, sotoon5);
  lcd.createChar(5, daraje);
  delay(100);
}

/**************************************************************************/
void WellComing() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("--refrigerator--");
  lcd.setCursor(0, 1);
  lcd.print("produceby Sobhan");
  SFPRINTLN("WellComing");
  delay(10000);
}

void WaitCounting() {

  if (!G_Waitting_Count) {
    G_Flag_First_PlugIn = 1;
    SetCharLCD();

  }
  lcd.setCursor(0, 1);
  lcd.print("      ");
  lcd.print(G_Waitting_Count--); lcd.print(" S         ");
  Serial.println(G_Waitting_Count);

}

void RemoveWellComing() {
  
  lcd.setCursor((G_Waitting_Count / 5) % 16, G_Waitting_Count / 80);
  lcd.write(G_Waitting_Count % 5);

  G_Waitting_Count++;

  if (G_Waitting_Count == 160) {
    G_Flag_First_PlugIn = 3;
  }

}

/**********************************************************************************************************/
bool        Flag_Second_Row_LCD     = true;

void showOnLCD(const float &Temp_In, const float &Temp_Out, const int &On_Time, const int &Off_Time) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Temp In = ");
  lcd.print(Temp_In);
  lcd.write(5);

  if (Flag_Second_Row_LCD) {
    lcd.setCursor(0, 1);
    lcd.print("Temp Out= ");
    lcd.print(Temp_Out);
    lcd.write(5);
    Flag_Second_Row_LCD = false;
  } else {
    lcd.setCursor(0, 1);
    lcd.print("TOn:");
    lcd.print(On_Time);
    lcd.write(4);
    lcd.print("TOff:");
    lcd.print(Off_Time);
    Flag_Second_Row_LCD = true;
  }

}
