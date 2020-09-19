#include "Hive.h"

#include <memory>
#include <functional>
#include <string>
#include <Arduino.h>

#include <WiFi.h>
#include <WiFiMulti.h>
#include <WiFiClientSecure.h>
#include <WiFiAP.h>
#include "esp_system.h"
#include <HTTPClient.h>
#include <HTTPUpdate.h>
#include "SPIFFS.h"
#include <ESPmDNS.h>


class MyServerCallbacks: public BLEServerCallbacks {
	// TODO this doesn't take into account several clients being connected
	void onConnect(BLEServer* pServer) {
		Serial.println("BLE client connected");
		pServer->getAdvertising()->stop();
	};

	void onDisconnect(BLEServer* pServer) {
		Serial.println("BLE client disconnected");
		pServer->getAdvertising()->start();
	}
};

class MyCallbackHandler: public BLECharacteristicCallbacks {
	
    public:
        MyCallbackHandler(String ip) : _ip(ip) {}
    
    protected:
        String _ip;

        void onWrite(BLECharacteristic *pCharacteristic) {
            std::string value = pCharacteristic->getValue();
            if (value.length() == 0) {
                return;
            }
        };

        void onRead(BLECharacteristic *pCharacteristic) {
            pCharacteristic->setValue(_ip.c_str());
        }
};



Hive::Hive(bool debug) : _jsonDocument(2048), _jsonCurrentProgram(2048)
{
    _allowProgramRun = false;
    _allowDebug = debug;
    _configIsDirty = false;
    _updatingFirmware = false;

    _apMode = false;

    _batteryVoltage = 0;
    _batterySampleCounter = 0;
    _i = 0;

#ifndef HIVE_NANO
    _deviceId = "Hive-" + String(getChipId());
#else 
    _deviceId = "Hive_Nano-" + String(getChipId());
#endif
    _webSocket = new WebSocketsServer(WEBSOCKET_PORT);


 }
    
uint32_t Hive::getChipId()
{
    uint64_t macAddress = ESP.getEfuseMac();
    uint64_t macAddressTrunc = macAddress << 40;
    return macAddressTrunc >> 40;
}

void Hive::initMDNS()
{
    if (!MDNS.begin(_deviceId.c_str())) {
        debugPrint("Error setting up MDNS responder!");
    } else {
        debugPrint("mDNS responder started");    
    }
    MDNS.addService("hive", "tcp", WEBSOCKET_PORT);
}

void Hive::initBLE()
{
	// Initialize BLE and set output power
	BLEDevice::init(_deviceId.c_str());
	BLEDevice::setPower(ESP_PWR_LVL_P7);

	// Create BLE Server
	_pServer = BLEDevice::createServer();

	// Set server callbacks
	_pServer->setCallbacks(new MyServerCallbacks());

	// Create BLE Service
	_pService = _pServer->createService(BLEUUID(SERVICE_UUID), 20);

	// Create BLE Characteristic for WiFi settings
	_pCharacteristicWiFi = _pService->createCharacteristic(
		BLEUUID(WIFI_UUID),
		// WIFI_UUID,
		BLECharacteristic::PROPERTY_READ |
		BLECharacteristic::PROPERTY_WRITE
	);
    _pCharacteristicWiFi->addDescriptor(new BLEDescriptor(BLEUUID(WIFI_UUID)));
	_pCharacteristicWiFi->setCallbacks(new MyCallbackHandler(_localIp));

	// Start the service
	_pService->start();

	// Start advertising
	_pAdvertising = _pServer->getAdvertising();
    _pAdvertising->addServiceUUID(BLEUUID(SERVICE_UUID));
    _pAdvertising->setScanResponse(true);
    _pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
    _pAdvertising->setMinPreferred(0x12);    
	_pAdvertising->start();

}


void Hive::setup()
{
    debugPrint("Hive firmeare version: " + String(FIRMWARE_VERSION));
    loadConfiguration();

    initLeds();
    initWifi();
    initMDNS();
    initBLE();

    _webSocket->begin();
    _webSocket->onEvent(std::bind(&Hive::webSocketEvent, this, std::placeholders::_1,std::placeholders:: _2, std::placeholders::_3, std::placeholders::_4));
    

}

void Hive::run()
{
    _webSocket->loop();

    // read battery voltage
    readBatteryVolts();

    static long initDelay = millis();
    // Allow 5 seconds buffer time until we start running the program
    // In case of bug in a program, the device may restart indefinitely, this will allow us 5 seconds window to push firmware update

    if (millis() - initDelay > 5000)
    {
        if (!_updatingFirmware && _jsonCurrentProgram.containsKey("Name")) 
        {
            String programName = _jsonCurrentProgram["Name"].as<String>();
            if (programName == "Solid")
            {
                setColor();
            }
            else if (programName == "Cylon")
            {
            colorCylon();
            }
            else if (programName == "Swirl")
            {
            colorSwirl();
            }
            else if (programName == "Breathing")
            {
            colorBreathing();
            }
            else if (programName == "Rainbow")
            {
            rainbow();
            }
        }
    }



    if (_apMode)
    {
        for (int i = 0; i < TOTAL_LEDS; i = i + 1)
        {
            _leds[i] = CRGB::Black;
        }

        for (int i = _i; i < TOTAL_LEDS; i = i + SLICE_LEDS)
        {
            _leds[i] = CRGB(10, 0, 0);
            _leds[min(TOTAL_LEDS - 1, i + 2)] = CRGB(0, 10, 0);
            _leds[min(TOTAL_LEDS - 1, i + 4)] = CRGB(0, 0, 10);
        }
        FastLED.show();

        _i++;
        if (_i == 11)
            _i = 1;
        delay(50);
    }
}

void Hive::initLeds() 
{
    FastLED.addLeds<WS2812B, DATA_PIN, GRB>(_leds, TOTAL_LEDS);
    FastLED.showColor(CRGB::Blue);
}

void Hive::initWifi()
{   
    WiFi.begin(_currentSSID.c_str(), _currentPassword.c_str());

    long long returnToDefualtCounter = millis();
    
    debugPrint("Trying to connect for " + String(RESET_TO_DEFAULT / 1000) + " seconds");
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        debugPrint(".", false);
        if ( (millis() - returnToDefualtCounter) > RESET_TO_DEFAULT)
        {
          resetSettingsToDefault();
          break;
        }
    }
    
   
    debugPrint("");
    debugPrint("WiFi connected");  
    debugPrint("IP address: ");
    _localIp = WiFi.localIP().toString();
    debugPrint(_localIp);
}

void Hive::resetSettingsToDefault() {
    debugPrint("\nResetting settings to default...");
    _currentSSID        = _deviceId;
    _currentPassword    =  DEFAULT_PSWD;                
    saveConfiguration();

    WiFi.softAP(_currentSSID.c_str(), _currentPassword.c_str());
    IPAddress myIP = WiFi.softAPIP();
    debugPrint(WiFi.softAPIP());
    
    _apMode = true;
    delay(2000);
}

void Hive::saveConfiguration()
{
    DynamicJsonDocument doc(2048);
    debugPrint("Saving config...");   
    doc["currentSSID"]         = _currentSSID;
    doc["currentPassword"]     = _currentPassword;
    
    String programData;
    serializeJson(_jsonCurrentProgram, programData);
    doc["currentProgram"] = programData;
    
    debugPrint("Saving this to config file:");
    if (_allowDebug)
    {
        serializeJson(doc, Serial);
        Serial.println("");
    }

    File configFile = SPIFFS.open("/config.json", "w");
    if (!configFile) 
    {
        debugPrint("failed to open config file for writing");
    }
    else
    {
        if (serializeJson(doc, configFile) == 0) {
            Serial.println(F("Failed to write to file"));
        }
        configFile.close();
    }
    _configIsDirty = false;
}

bool Hive::loadConfiguration()
{
    debugPrint("mounting FS...");
    if (SPIFFS.begin(true)) 
    {
        debugPrint("mounted file system");
        if (SPIFFS.exists("/config.json")) 
        {
            // file exists, reading and loading
            debugPrint("reading config file");
            File configFile = SPIFFS.open("/config.json", "r");
            if (configFile) 
            {
                debugPrint("opened config file");
                size_t size = configFile.size();

                // Allocate a buffer to store contents of the file.
                std::unique_ptr<char[]> buf(new char[size]);

                DynamicJsonDocument doc(2048);
                deserializeJson(doc, configFile);
                if (_allowDebug)
                    serializeJson(doc, Serial);
                    
                _currentSSID        = doc["currentSSID"].as<String>();
                _currentPassword    = doc["currentPassword"].as<String>();

                if (doc.containsKey("currentProgram"))
                {
                    String programData = doc["currentProgram"].as<String>();
                    deserializeJson(_jsonCurrentProgram, programData);
                }
                
                if (_currentSSID == "")
                {
                    debugPrint("SSID is empty, using default");
                    _currentSSID = _deviceId;
                }

                if (_currentPassword == "")
                {
                    debugPrint("Password is empty, using default");
                    _currentPassword = DEFAULT_PSWD;
                }
            }
            else
            {
                debugPrint("Cannot open config file");
                return false;
            }
        }
    } 
    else 
    {
        debugPrint("failed to mount FS");
        return false;
    }
    
    return true;
}

void Hive::updateNetworking(String msg) 
{
    DynamicJsonDocument networkData(512);

    deserializeJson(networkData, msg);

    _currentSSID = networkData["SSID"].as<String>();
    _currentPassword = networkData["PASSWORD"].as<String>();

    saveConfiguration();

    delay(2000);
    esp_restart();
}

void Hive::updateFirmware(String filename)
{
    _updatingFirmware = true;
    WiFiClient client;
    
    debugPrint("Updating firmware...");
    t_httpUpdate_return ret = httpUpdate.update(client, filename);
    
    switch(ret) 
    {
        case HTTP_UPDATE_FAILED:
        debugPrint("HTTP_UPDATE_FAILD Error: " + httpUpdate.getLastErrorString());
        break;
    
        case HTTP_UPDATE_NO_UPDATES:
        debugPrint("HTTP_UPDATE_NO_UPDATES");
        break;
    
        case HTTP_UPDATE_OK:
        debugPrint("HTTP_UPDATE_OK");
        break;
    }
    _updatingFirmware = false;
}

float Hive::readBatteryVolts() 
{
    // Sample every 10 seconds
    if (millis() - _batterySampleCounter > 1000) 
    {
        _batteryVoltage = ((float)analogRead(BATTERY_PIN) / 4095) * BATTERY_HW_SCALE_FACTOR;
        Serial.println(_batteryVoltage);
        _batterySampleCounter = millis();
    }

    return _batteryVoltage;
}

int Hive::readBatteryPercentage() 
{
    int p = floor((_batteryVoltage - MIN_BATTERY_VOLTAGE) * 100 / (MAX_BATTERY_VOLTAGE - MIN_BATTERY_VOLTAGE));
    return max(0, min(100, p));
}

void Hive::colorBreathing() 
{
    if (millis() - _jsonCurrentProgram["Duration"].as<long>() > _jsonCurrentProgram["Delay"].as<int>()) 
    {
        CRGB color = stringToColor(_jsonCurrentProgram["Color"].as<String>());

        _jsonCurrentProgram["Duration"] = millis();
        if (_leds[0] != color) // Assume that we already called colorBreathing and all the LEDs are the same
        {
            for( uint16_t i = 0; i < TOTAL_LEDS; i++) 
            {
                _leds[i] = color;
            }
        }
        FastLED.setBrightness(_jsonCurrentProgram["Brightness"].as<int>());
        FastLED.show();
        
        _jsonCurrentProgram["Brightness"] = _jsonCurrentProgram["Brightness"].as<int>() + _jsonCurrentProgram["Direction"].as<int>();
        if (_jsonCurrentProgram["Brightness"].as<int>() == _jsonCurrentProgram["MaxBrightness"].as<int>()) 
        {
            _jsonCurrentProgram["Direction"] = -1;
        } 
        else if (_jsonCurrentProgram["Brightness"].as<int>() == 5 && _jsonCurrentProgram["Direction"].as<int>() == -1) 
        {
            _jsonCurrentProgram["Direction"] = 1;
        }
    }
}

void Hive::colorCylon()
{
    if (millis() - _jsonCurrentProgram["Duration"].as<long>() > _jsonCurrentProgram["Delay"].as<int>()) 
    {
        CRGB color = stringToColor(_jsonCurrentProgram["Color"].as<String>());

        _jsonCurrentProgram["Duration"] = millis();

        for (int i = 0; i < TOTAL_LEDS; i++) 
        {
            if (i < _jsonCurrentProgram["Position"].as<int>() || i > _jsonCurrentProgram["Position"].as<int>() + SLICE_LEDS)
            {
                _leds[i] = CRGB::Black;
            }
            else
            {
                _leds[i] = color;
            }
        }
        FastLED.show();        

        _jsonCurrentProgram["Position"] = max(0, min(TOTAL_LEDS, _jsonCurrentProgram["Position"].as<int>() + (_jsonCurrentProgram["Direction"].as<int>() * SLICE_LEDS)));
        
        if (_jsonCurrentProgram["Position"].as<int>() == TOTAL_LEDS) 
        {
            _jsonCurrentProgram["Direction"] = -1;
        }
        else if (_jsonCurrentProgram["Position"].as<int>() == 0) 
        {
            _jsonCurrentProgram["Direction"] = 1;
        }
    }    
}

void Hive::colorSwirl() 
{
    if (millis() - _jsonCurrentProgram["Duration"].as<long>() > _jsonCurrentProgram["Delay"].as<int>()) 
    {
        CRGB color1 = stringToColor(_jsonCurrentProgram["Color1"].as<String>());
        CRGB color2 = stringToColor(_jsonCurrentProgram["Color2"].as<String>());

        _jsonCurrentProgram["Duration"] = millis();

        for (int i = 0; i < TOTAL_LEDS; i = i + SLICE_LEDS) 
        {
            for (int j = 0; j < SLICE_LEDS / 2; j++)
            {
                int idx = min(TOTAL_LEDS, i + j + _jsonCurrentProgram["Position"].as<int>());
                _leds[idx] = color1;
            }
            for (int j = SLICE_LEDS / 2; j < SLICE_LEDS; j++)
            {
                int idx = min(TOTAL_LEDS, i + j + _jsonCurrentProgram["Position"].as<int>());
                _leds[idx] = color2;
            }            
        }

        _jsonCurrentProgram["Position"] = _jsonCurrentProgram["Position"].as<int>() + 1;
        if (_jsonCurrentProgram["Position"] == SLICE_LEDS) 
        {
            _jsonCurrentProgram["Position"] = 1;
        }

        FastLED.show();        
    }    
}

void Hive::rainbow()
{
    static uint16_t j = 0;    
    if (millis() - _jsonCurrentProgram["Duration"].as<long>() > _jsonCurrentProgram["Delay"].as<int>()) 
    {
        for (int i = 0; i < TOTAL_LEDS; i++) {
            _leds[i] =  wheel((i + j) & 255);
        }
        FastLED.show();
        j++;
        if (j >= 256)
            j=0;

        _jsonCurrentProgram["Duration"] = millis(); 
    }
}

CRGB Hive::wheel(byte wheelPos)
{
    wheelPos = 255 - wheelPos;

    if (wheelPos < 85) {
        return CRGB(255 - wheelPos * 3, 0, wheelPos * 3);
    }

    if  (wheelPos < 170) {
        wheelPos -= 85;
        return CRGB(0, wheelPos * 3, 255 - wheelPos * 3);
    }

    wheelPos -= 170;
    return CRGB(wheelPos * 3, 255 - wheelPos * 3, 0);    
}


void Hive::setColor()
{
    if (!_jsonCurrentProgram["Executed"].as<bool>()) 
    {
        CRGB color = stringToColor(_jsonCurrentProgram["Color"].as<String>());
        _jsonCurrentProgram["Executed"] = true;
        setColor(color);
        debugPrint("Color was set!");
    }
}

void Hive::setColor(CRGB color)
{
    for (int i = 0; i < TOTAL_LEDS; i++)
    {
        _leds[i] = color;
    }
    FastLED.show();
}

CRGB Hive::stringToColor(String color)
{
    int r, g, b;
    sscanf(color.c_str(), "%02x%02x%02x", &r, &g, &b);
    return CRGB(r, g, b);
}

void Hive::webSocketEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) 
{
    switch(type) 
    {
        case WStype_DISCONNECTED:
            debugPrint(String(num) + "Disconnected!");
            break;
        case WStype_CONNECTED:
            {
                debugPrint("Connected!");
                DynamicJsonDocument doc(50);
                doc["DEVICE_TYPE"] = FIRMWARE_DEVICE_TYPE;
                doc["FIRMWARE"] = FIRMWARE_VERSION;
                String sendData;
                serializeJson (doc, sendData);
				// // send message to client
				_webSocket->sendTXT(num, sendData.c_str());
            }
            break;
        case WStype_TEXT:
            {
                debugPrint("Text Message received:");
                debugPrint(payload);
                deserializeJson(_jsonDocument, payload);
                String command = _jsonDocument["Command"].as<String>();

                if (command == "FIRMWARE_UPDATE") {
                    String filename = _jsonDocument["Value"].as<String>();
                    debugPrint("Firmware URL: ", false);
                    debugPrint(filename.c_str());
                    updateFirmware(filename);
                } 
                else if (command == "PROGRAM") 
                {
                    // Copy the program data to another json document
                    String programData;
                    serializeJson(_jsonDocument["Value"], programData);
                    deserializeJson(_jsonCurrentProgram, programData);
                    saveConfiguration();
                }
                else if (command == "NETWORK") 
                {
                    // Copy the program data to another json document
                    updateNetworking(_jsonDocument["Value"].as<String>());
                } 
                else if (command == "BATTERY") {
                    DynamicJsonDocument doc(50);
                    doc["VOLTS"] = _batteryVoltage;
                    doc["PERCENTAGE"] = readBatteryPercentage();
                    String sendData;
                    serializeJson (doc, sendData);
                    // // send message to client
                    _webSocket->sendTXT(num, sendData.c_str());

                }
            }
            break;
        case WStype_BIN:
            debugPrint("Binary Message received");
            break;
		case WStype_ERROR:			
		case WStype_FRAGMENT_TEXT_START:
		case WStype_FRAGMENT_BIN_START:
		case WStype_FRAGMENT:
		case WStype_FRAGMENT_FIN:
			break;
    }

}

void Hive::debugPrint(String msg, bool withNewline)
{
    if (_allowDebug)
    {
        if (withNewline)
            Serial.println(msg.c_str());
        else
            Serial.print(msg.c_str());
    }
}

void Hive::debugPrint(uint8_t* msg, bool withNewline)
{
    if (_allowDebug)
    {
        if (withNewline)
            Serial.printf("%s\n", msg);
        else
            Serial.printf("%s", msg);
    }
}

void Hive::debugPrint(int msg, bool withNewline)
{
    if (_allowDebug)
    {
        if (withNewline)
            Serial.println(msg);
        else
            Serial.print(msg);
    }
}
