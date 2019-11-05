#include <ESP8266WiFi.h>
/* 依赖 PubSubClient 2.4.0 */
#include <PubSubClient.h>
/* 依赖 ArduinoJson 5.13.4 */
#include <ArduinoJson.h>

#define SENSOR_PIN    13    //传感器引脚
#define LED_PIN       12
/* 连接您的WIFI SSID和密码 */
#define WIFI_SSID         "stupid"
#define WIFI_PASSWD       "qazxswedc"


/* 设备证书信息*/
#define PRODUCT_KEY       "a1276PgIJdj"
#define DEVICE_NAME       "Fang_light"
#define DEVICE_SECRET     "O8kDrgI3JGIvGurkCRoo1ONlRXNyx3oE"
#define REGION_ID         "cn-shanghai"

/* 线上环境域名和端口号，不需要改 */
#define MQTT_SERVER       PRODUCT_KEY ".iot-as-mqtt." REGION_ID ".aliyuncs.com"
#define MQTT_PORT         1883
#define MQTT_USRNAME      DEVICE_NAME "&" PRODUCT_KEY

#define CLIENT_ID         "esp8266|securemode=3,timestamp=1234567890,signmethod=hmacsha1|"
// MQTT连接报文参数,请参见MQTT-TCP连接通信文档，文档地址：https://help.aliyun.com/document_detail/73742.html
// 加密明文是参数和对应的值（clientIdesp8266deviceName${deviceName}productKey${productKey}timestamp1234567890）按字典顺序拼接
// 密钥是设备的DeviceSecret
#define MQTT_PASSWD       "A7D8E56403F0F9D96939BA67CDF68DDF2B873D41"
//上传心跳包格式
#define ALINK_BODY_FORMAT         "{\"id\":\"123\",\"version\":\"1.0\",\"method\":\"thing.event.property.post\",\"params\":%s}"
#define ALINK_TOPIC_PROP_POST     "/sys/" PRODUCT_KEY "/" DEVICE_NAME "/thing/event/property/post"

//led灯的状态
int ledState = HIGH; // the current state of the output pin
int previous = LOW; // the previous reading from the input pin  记录开关的上一次状态


unsigned long lastMs = 0;
WiFiClient espClient;
PubSubClient  client(espClient);

//返回数据
void callback(char *topic, byte *payload, unsigned int length)
{
    Serial.print("Message arrived [");
    Serial.print(topic);
    Serial.print("] ");
    payload[length] = '\0';
    Serial.println((char *)payload);
    
    DynamicJsonDocument doc(100);
    DeserializationError error = deserializeJson(doc, payload);
    if (error)
    {
      Serial.println("parse json failed");
      return;
    }
     //          将字符串payload转换为json格式的对象
    // {"method":"thing.service.property.set","id":"282860794","params":{"LightSwitch":1},"version":"1.0.0"}
    JsonObject setAlinkMsgObj = doc.as<JsonObject>();
    // LightSwitch
    int desiredLedState = setAlinkMsgObj["params"]["LightSwitch"];

    if (desiredLedState == HIGH || desiredLedState == LOW) {
      ledState = desiredLedState;   //     修改灯的状态，但是这里没有digitalWrite
      if(desiredLedState == HIGH)
       digitalWrite(LED_PIN,HIGH);
       else
        digitalWrite(LED_PIN,LOW);
      const char* cmdStr = desiredLedState == HIGH ? "on" : "off";
     
      Serial.print("网络命令: Turn ");
      Serial.print(cmdStr);
      Serial.println(" 这个灯.");
    }
}


void wifiInit()
{
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWD);
    while (WiFi.status() != WL_CONNECTED)
    {
        delay(1000);
        Serial.println("WiFi not Connect");
    }

    Serial.println("Connected to AP");
    Serial.println("IP address: ");
    Serial.println(WiFi.localIP());


    Serial.print("espClient [");


    client.setServer(MQTT_SERVER, MQTT_PORT);   /* 连接WiFi之后，连接MQTT服务器 */
    client.setCallback(callback);
}


void mqttCheckConnect()
{
    while (!client.connected())
    {
        Serial.println("Connecting to MQTT Server ...");
        if (client.connect(CLIENT_ID, MQTT_USRNAME, MQTT_PASSWD))
        {
            Serial.println("MQTT Connected!");
        }
        else
        {
            Serial.print("MQTT Connect err:");
            Serial.println(client.state());
            delay(5000);
        }
    }
}


void mqttIntervalPost()
{
    char param[32];
    char jsonBuf[128];

    sprintf(param, "{\"LightSwitch\":%d}", digitalRead(SENSOR_PIN));
    sprintf(jsonBuf, ALINK_BODY_FORMAT, param);
    Serial.println(jsonBuf);
    boolean d = client.publish(ALINK_TOPIC_PROP_POST, jsonBuf);
    Serial.print("publish:0 失败;1成功");
    Serial.println(d);

    
    sprintf(param, "{\"LightMode\":%d}", digitalRead(14));
    sprintf(jsonBuf, ALINK_BODY_FORMAT, param);
    Serial.println(jsonBuf);
    boolean F = client.publish(ALINK_TOPIC_PROP_POST, jsonBuf);
    Serial.print("publish:0 失败;1成功");
    Serial.println(F);
}



void setup() 
{

    pinMode(SENSOR_PIN,  INPUT);
    /* initialize serial for debugging */
    Serial.begin(115200);
    Serial.println("Demo Start");

    wifiInit();
}


// the loop function runs over and over again forever
void loop()
{
    if (millis() - lastMs >= 5000)
    {
        lastMs = millis();
        mqttCheckConnect(); 

        /* 上报消息心跳周期 */
        mqttIntervalPost();
    }

    client.loop();
    if (digitalRead(SENSOR_PIN) == HIGH){
  Serial.println("Motion detected!");
    delay(1000);
     }
    else {
    Serial.println("Motion absent!");
    delay(1000);
 }

}
