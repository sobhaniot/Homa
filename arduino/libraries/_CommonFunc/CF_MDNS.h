#include <ESP8266mDNS.h>

void CF_mdnsSetup(){
  if (!MDNS.begin(G_mySSID)) {             // Start the mDNS responder for lamp.local
    Serial.println("Error setting up MDNS responder!");
  }else{
    Serial.println("mDNS responder started");
    MDNS.addService("http", "tcp", 80);
  }
}