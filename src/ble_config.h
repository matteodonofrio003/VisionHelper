// src/ble_config.h
#pragma once
#include <Arduino.h>

// Inizializza il server BLE e inizia a trasmettere la sua presenza (Advertising)
void initBLE();

// Ritorna vero se uno smartphone è attualmente connesso via BLE
bool isBLEConnected();

// Funzioni di utilità per leggere i dati salvati in memoria
String getSavedSSID();
String getSavedPassword();
//String getSavedAPIKey();
void stopBLE();
void clearCredentials();