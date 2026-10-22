#include <Ticker.h>

void CF_setupAPWifi(void) {
  WiFi.mode(WIFI_AP);
  //Constant IP for APWiFi
  IPAddress ipAP(192, 168, 11, 22);
  IPAddress gatewayAP(192, 168, 11, 1);
  IPAddress subnetAP(255, 255, 255, 0);
  //Start AP WiFi
  Serial.print("Setting soft-AP configuration ... ");
  WiFi.softAPConfig(ipAP, gatewayAP, subnetAP);

  Serial.print("Setting soft-AP ... ");
  WiFi.softAP(G_mySSID, G_passwordAP);

  Serial.print("Soft-AP IP address = ");
  Serial.println(WiFi.softAPIP());

}

Ticker TickerWifi;
int  CountTryToConnect = -1;
int  WaitForConnect    = 0;
bool WifiTickerAttachFlag  = false;

void  Wifi_Connecting(){
  Serial.print(F(".")); 
  WaitForConnect += 1;

  if(WaitForConnect > 10 ){
    WaitForConnect = 0;
    WiFi.mode(WIFI_AP);
    Serial.println(F("WiFi can not connect"));
    TickerWifi.detach();
    WifiTickerAttachFlag =false;
    }

  if (WiFi.status() == WL_CONNECTED){
    Serial.println(F("WiFi connected"));
    Serial.println(WiFi.localIP());
    CountTryToConnect = -1;
    TickerWifi.detach();
    WifiTickerAttachFlag =false;    
  }
}

void Wifi_Connect(){
  Serial.print("Try To Connecting");
  WiFi.mode(WIFI_AP_STA);
  //  WiFi.config(ipWiFi, gatewayWiFi, subnetWiFi);
  WiFi.begin(G_SSID.c_str(), G_PASSWORD.c_str());

  TickerWifi.attach(0.5, Wifi_Connecting);
}

void CF_WifiLoop(){
  if(WiFi.status() != WL_CONNECTED && !WifiTickerAttachFlag){
    WifiTickerAttachFlag = true;
    CountTryToConnect++;
    if(CountTryToConnect > 10) CountTryToConnect = 10;
    Serial.print(F("CountTryToConnect : "));
    Serial.println(CountTryToConnect);
    TickerWifi.attach((60*CountTryToConnect) + 1, Wifi_Connect);
  }
}