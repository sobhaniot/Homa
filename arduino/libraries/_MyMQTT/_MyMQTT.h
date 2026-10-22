#include <Ticker.h>
#include <PubSubClient.h>


WiFiClient espClient;
PubSubClient MQTTclient(espClient);

void checkMessage(String message);
void callback(char* topic, byte* payload, unsigned int length);


void CF_MQTTSetup(int _size=256) {
  MQTTclient.setServer(G_mqtt_server.c_str(), D_PortMQTT);
  MQTTclient.setCallback(callback);
  MQTTclient.setBufferSize(_size);
  Serial.print("MQTT Buffer Size : ");
  Serial.println(MQTTclient.getBufferSize());
}

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  Serial.print(length);
  String receivedChar;
  for (int i = 0; i < length; i++) {
    receivedChar += (char)payload[i];
  }
  Serial.print("MQTT Message: ");
  Serial.println(receivedChar);
  checkMessage(receivedChar); // this function declare in h_Parse tab
}

Ticker TickerMQTT;
int  CountTryMQTT = 0;
bool MQTTTickerAttachFlag  = false;
bool MQTTTryConnectFlag  = false;

void MQTTConnecting(){

  if (MQTTTryConnectFlag){
    MQTTTryConnectFlag = false;
    
    Serial.print("Attempting MQTT connection...");
    // Attempt to connect
    String msg = (String)G_mySSID + "esp8266";

    if (MQTTclient.connect(msg.c_str())) {
      Serial.println("connected");
      // Once connected, publish an announcement...
      msg = "{\"type\":\"" + (String)G_mySSID + " connect to mqtt\"}";
      MQTTclient.publish(G_publishTopic, msg.c_str());
      // ... and resubscribe
      MQTTclient.subscribe(G_subscribeTopic);
      CountTryMQTT=0;
      
    } else {

      Serial.print("failed, rc="); 
      Serial.println(MQTTclient.state());

    }

    TickerMQTT.detach();
    MQTTTickerAttachFlag =false;
  }
}

void CF_MQTTLoop(){
  if (MQTTclient.connected()){

    MQTTclient.loop();

  } else if (WiFi.status() == WL_CONNECTED && !MQTTTickerAttachFlag){

    MQTTTickerAttachFlag = true;
    CountTryMQTT++;
    if(CountTryMQTT > 10) CountTryMQTT = 10;
    Serial.print(F("CountTryMQTT : "));
    Serial.println(CountTryMQTT);
    TickerMQTT.attach(60*CountTryMQTT, [](){MQTTTryConnectFlag = true;});

  }else{

    MQTTConnecting();

  }
}

void CF_MQTT_send_msg_to(String msg){
  Serial.println(msg);

  webSocket.broadcastTXT(msg);
  delay(10);

  MQTTclient.publish(G_publishTopic, msg.c_str());
  // in bakhsh baraye in ast ke dar servere mqtt chizi baghi namanad
  MQTTclient.publish(G_subscribeTopic, "0", true);
}

bool CF_MQTT_send_notif_to(String msg){

  if (MQTTclient.connected()){

    String msgString = "{\"content\":\"" ;

    msgString += msg;
    msgString += "\",\"type\":\"notif\"}";

    CF_MQTT_send_msg_to(msgString);

    return true;

  }else{

    return false;

  }
}
  