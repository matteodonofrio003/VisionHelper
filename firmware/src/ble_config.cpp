// src/ble_config.cpp
#include "ble_config.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Preferences.h>

Preferences preferences;
bool deviceConnected = false;

#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_UUID_SSID         "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CHAR_UUID_PASS         "beb5483e-36e1-4688-b7f5-ea07361b26a9"

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Smartphone connesso via BLE! In attesa di dati...");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Smartphone disconnesso. Riavvio per applicare le nuove impostazioni...");
      delay(1000);
      
      // Appena l'app si scollega l'ESP32 si riavvia
      ESP.restart(); 
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String value = pCharacteristic->getValue().c_str();
      String uuid = pCharacteristic->getUUID().toString().c_str();

      if (value.length() > 0) {
        preferences.begin("vision_config", false); 

        if (uuid == CHAR_UUID_SSID) {
            preferences.putString("ssid", value);
            Serial.print("Nuovo SSID salvato: "); Serial.println(value);
        } 
        else if (uuid == CHAR_UUID_PASS) {
            preferences.putString("password", value);
            Serial.println("Nuova Password Wi-Fi salvata!");
        } 
        
        preferences.end();
      }
    }
};

void initBLE() {
  Serial.println("Avvio del server BLE in corso...");
  BLEDevice::init("VisionHelper_Config");
  
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  BLECharacteristic *pCharSSID = pService->createCharacteristic(
                                         CHAR_UUID_SSID,
                                         BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE
                                       );
  pCharSSID->setCallbacks(new MyCallbacks());

  BLECharacteristic *pCharPass = pService->createCharacteristic(
                                         CHAR_UUID_PASS,
                                         BLECharacteristic::PROPERTY_WRITE
                                       );
  pCharPass->setCallbacks(new MyCallbacks());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06); 
  BLEDevice::startAdvertising();
  
  Serial.println("BLE Pronto per ricevere Wi-Fi!");
}

bool isBLEConnected() { return deviceConnected; }

String getSavedSSID() {
    preferences.begin("vision_config", true);
    String ssid = preferences.getString("ssid", "");
    preferences.end();
    return ssid;
}

String getSavedPassword() {
    preferences.begin("vision_config", true);
    String pass = preferences.getString("password", "");
    preferences.end();
    return pass;
}


void stopBLE() {
    BLEDevice::deinit(true); // Spegne l'antenna per poter liberare la RAM
    deviceConnected = false;
    Serial.println("Bluetooth disattivato per fare spazio all'AI.");
}

// Funzione per cancellare le credenziali salvate
void clearCredentials() {
    preferences.begin("vision_config", false); // Apre in modalità scrittura
    preferences.clear();                       // Cancella TUTTE le chiavi
    preferences.end();                         // Chiude la memoria
    Serial.println("[DEBUG] Memoria NVS formattata. Al prossimo controllo risulterà vuota.");
}