#include "Hive.h"

// Custom UUID generated from here: https://www.guidgenerator.com/online-guid-generator.aspx
/*
for further use
aefe5f62-1117-4f39-aa3e-ee7564860370
*/

#ifndef HIVE_NANO
#define CONTROLLER_SERVICE_UUID  "02675cf9-f599-4720-840d-6c0ecc607112"
#else
#define CONTROLLER_SERVICE_UUID  "9df5a533-9cce-4f9f-8469-b9eab92b1992"
#endif
#define PROGRAM_CHAR_UUID     "ec65a4a3-761b-432c-af88-2cee26319b47"
#define FIRMWARE_CHAR_UUID     "fa8f59be-4546-4f26-ba4d-1b9206ddf222"
#define WIFI_SETTER_CHAR_UUID     "96c7f61b-770a-4e49-b7df-41e838b7c63f"
#define WIFI_INFO_CHAR_UUID     "7bbf95cc-3972-4914-9709-055bd28b930e"

uint8_t* string2uint(std::string& value) 
{
    const char* msg = value.c_str();
    size_t length = strlen(msg) + 1;

    uint8_t* uMsg = new uint8_t[length];
    const char* beg = msg;
    const char* end = msg + length;
    size_t i = 0;
    for (; beg != end; ++beg, ++i)
    {
        uMsg[i] = (uint8_t)(*beg);
    }
    return uMsg;
}

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
        MyCallbackHandler(Hive& oHive) : _hive(oHive) {} //_ip(ip) {}
    
    protected:
        // String _ip;
        Hive& _hive;

        void onWrite(BLECharacteristic *pCharacteristic) {
            Serial.println(pCharacteristic->getUUID().toString().c_str());
            if (pCharacteristic->getUUID().toString() == PROGRAM_CHAR_UUID || 
                pCharacteristic->getUUID().toString() == WIFI_SETTER_CHAR_UUID) 
            {
                std::string value = pCharacteristic->getValue();
                uint8_t* uMsg = string2uint(value);
                _hive.processMessage(uMsg, 0, true);
            }
        };

        void onRead(BLECharacteristic *pCharacteristic) {
            Serial.print("onRead ");
            Serial.println(pCharacteristic->getUUID().toString().c_str());
        }
};

void Hive::initBLE()
{
	// Initialize BLE and set output power
	BLEDevice::init(_deviceId.c_str());
	BLEDevice::setPower(ESP_PWR_LVL_P7);

	// Create BLE Server
	_bleServer = BLEDevice::createServer();

	// Set server callbacks
	_bleServer->setCallbacks(new MyServerCallbacks());

    // -- Main Service -- //
	_controllerService = _bleServer->createService(CONTROLLER_SERVICE_UUID);

	_programCharacteristic = _controllerService->createCharacteristic(
		PROGRAM_CHAR_UUID,
		BLECharacteristic::PROPERTY_READ |
		BLECharacteristic::PROPERTY_WRITE | 
        BLECharacteristic::PROPERTY_NOTIFY
	);
    _programCharacteristic->addDescriptor(new BLEDescriptor(BLEUUID((uint16_t)0x2901)));
    _programCharacteristic->getDescriptorByUUID(BLEUUID((uint16_t)0x2901))->setValue("Program");
	_programCharacteristic->setCallbacks(new MyCallbackHandler(*this));
    _programCharacteristic->addDescriptor(new BLE2902());

    String cValue = _jsonCurrentProgram.as<String>();
    _programCharacteristic->setValue(cValue.c_str());

    // ---

    _firmwareCharacteristic = _controllerService->createCharacteristic(
		FIRMWARE_CHAR_UUID,
		BLECharacteristic::PROPERTY_READ |
		BLECharacteristic::PROPERTY_WRITE | 
        BLECharacteristic::PROPERTY_NOTIFY
	);
    _firmwareCharacteristic->addDescriptor(new BLEDescriptor(BLEUUID((uint16_t)0x2901)));
    _firmwareCharacteristic->getDescriptorByUUID(BLEUUID((uint16_t)0x2901))->setValue("Version");
	_firmwareCharacteristic->setCallbacks(new MyCallbackHandler(*this));
    _firmwareCharacteristic->addDescriptor(new BLE2902());
    _firmwareCharacteristic->setValue(FIRMWARE_VERSION);

    // ---

    _wifiSetterCharacteristic = _controllerService->createCharacteristic(
		WIFI_SETTER_CHAR_UUID,
		BLECharacteristic::PROPERTY_WRITE
	);
    _wifiSetterCharacteristic->addDescriptor(new BLEDescriptor(BLEUUID((uint16_t)0x2901)));
    _wifiSetterCharacteristic->getDescriptorByUUID(BLEUUID((uint16_t)0x2901))->setValue("Wi-Fi Settings");
	_wifiSetterCharacteristic->setCallbacks(new MyCallbackHandler(*this));
    _wifiSetterCharacteristic->addDescriptor(new BLE2902());

    // ---

    _wifiInfoCharacteristic = _controllerService->createCharacteristic(
		WIFI_INFO_CHAR_UUID,
		BLECharacteristic::PROPERTY_READ
	);
    _wifiInfoCharacteristic->addDescriptor(new BLEDescriptor(BLEUUID((uint16_t)0x2901)));
    _wifiInfoCharacteristic->getDescriptorByUUID(BLEUUID((uint16_t)0x2901))->setValue("Wi-Fi Information");
	_wifiInfoCharacteristic->setCallbacks(new MyCallbackHandler(*this));
    _wifiInfoCharacteristic->addDescriptor(new BLE2902());

    // ---

    _controllerService->start();
    // -- Main Service -- //

    // -- Battery Service -- //
    _batteryService = _bleServer->createService(BATTERY_SERVICE_UUID);

    _batteryLevelCharacteristic = _batteryService->createCharacteristic(BLEUUID((uint16_t)0x2A19), 
        BLECharacteristic::PROPERTY_READ | 
        BLECharacteristic::PROPERTY_NOTIFY
    );
    _batteryLevelCharacteristic->addDescriptor(new BLEDescriptor(BLEUUID((uint16_t)0x2901)));
    _batteryLevelCharacteristic->getDescriptorByUUID(BLEUUID((uint16_t)0x2901))->setValue("Percentage 0 - 100");
    _batteryLevelCharacteristic->addDescriptor(new BLE2902());

    _batteryService->start();
    // -- Battery Service -- //

	

    // Start advertising
    BLEAdvertisementData ad;
    ad.setManufacturerData("  Tovi Levis");
    _advertising = _bleServer->getAdvertising();
    _advertising->setAdvertisementData(ad);
    _advertising->addServiceUUID(CONTROLLER_SERVICE_UUID);
    _advertising->addServiceUUID(BATTERY_SERVICE_UUID);
    _advertising->setScanResponse(true);
    _advertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
    _advertising->setMinPreferred(0x12);    
    _advertising->start();

}
