#ifndef HIVE_H
#define HIVE_H

#define HIVE_NANO 

#include "FastLED.h"
#include <WebSocketsServer.h>
#include <ArduinoJson.h>

// Includes for BLE
#include <BLE2902.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLEDevice.h>
#include <BLEAdvertising.h>

#define FIRMWARE_VERSION "0.0.23"





#define BATTERY_SERVICE_UUID BLEUUID((uint16_t)0x180F)


#ifndef HIVE_NANO
#define FIRMWARE_DEVICE_TYPE "Hive"
#define TOTAL_LEDS  300
#define SLICE_LEDS  10
#define DATA_PIN    33
#else
#define FIRMWARE_DEVICE_TYPE "Hive_Nano"
#define TOTAL_LEDS  53
#define SLICE_LEDS  7
#define DATA_PIN    16
#endif

#define BATTERY_PIN 36
#define MAX_BATTERY_VOLTAGE 4.2
#define MIN_BATTERY_VOLTAGE 3.0
#define BATTERY_HW_SCALE_FACTOR 5.6 //7.075



#define DEFAULT_PSWD        "hive1234"
#define WEBSOCKET_PORT      5656
#define RESET_TO_DEFAULT    5 * 1000

class Hive 
{

public:
    Hive(bool debug = false);

    void setup();
    void run();

protected:
    uint32_t getChipId();

    void initLeds();
    void initWifi();
    void initMDNS();
    void initBLE();

    void saveConfiguration();
    bool loadConfiguration();
    void resetSettingsToDefault();

    void updateFirmware(String filename);
    void updateNetworking(String msg);
    
    float readBatteryVolts();
    int readBatteryPercentage();

    void setColor();
    void setColor(CRGB color);

    void colorBreathing();
    void colorCylon();
    void colorSwirl();
    void rainbow();
    CRGB wheel(byte wheelPos);

    CRGB stringToColor(String color);
    

    void debugPrint(String msg, bool withNewline = true);
    void debugPrint(uint8_t* msg, bool withNewline = true);
    void debugPrint(int msg, bool withNewline = true);


    void webSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length);
    void processMessage(uint8_t * payload, uint8_t num, bool isBLE);
    //void processMessage(Hive& oHive, uint8_t * payload, uint8_t num, bool isBLE);
    
    friend class MyCallbackHandler;

    String      _deviceId;
    String      _localIp;

    bool        _apMode;
    bool        _allowProgramRun;
    bool        _updatingFirmware;
    
    String      _currentSSID;
    String      _currentPassword;
    char        _deviceName[100];

    float       _batteryVoltage;
    long        _batterySampleCounter;
    bool        _configIsDirty;
    bool        _allowDebug;


    DynamicJsonDocument _jsonDocument;
    DynamicJsonDocument _jsonCurrentProgram;

    uint8_t     _colorBreathingCounter;
    int         _colorBreathingDirection;
    long        _colorBreathingDuration;

    int         _colorCylonIndex;
    int         _colorCylonDuration;
    int         _colorCylonDirection;

    WebSocketsServer* _webSocket;

    // BLE
    BLEServer*          _bleServer;
    BLEAdvertising*     _advertising;

    BLEService*         _controllerService;
    BLECharacteristic*  _programCharacteristic;
    BLECharacteristic*  _firmwareCharacteristic;
    BLECharacteristic*  _wifiSetterCharacteristic;
    BLECharacteristic*  _wifiInfoCharacteristic;

    
    
    BLEService*         _batteryService;
    BLECharacteristic*  _batteryLevelCharacteristic;



    int _i;


    CRGB        _leds[TOTAL_LEDS];    
};



#endif
