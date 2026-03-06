// src/feedback.cpp
#include <Arduino.h>
#include "feedback.h"
#include "../include/config.h"
#include "ble_config.h" // Aggiunto per poter chiamare clearCredentials()

// Variabili per il controllo temporale della pressione
unsigned long pressStartTime = 0;
bool isPressing = false;
bool longPressTriggered = false;

void initFeedback() {
    pinMode(BUTTON_PIN, INPUT_PULLUP);
    pinMode(BUZZER_PIN, OUTPUT);
    pinMode(VIBRATION_PIN, OUTPUT);
    pinMode(GREEN_LED_PIN, OUTPUT);
    pinMode(RED_LED_PIN, OUTPUT);
    
    digitalWrite(BUZZER_PIN, LOW);
    digitalWrite(VIBRATION_PIN, LOW); // Sicurezza extra: spegniamo il motore all'avvio
    digitalWrite(GREEN_LED_PIN, LOW);
    digitalWrite(RED_LED_PIN, LOW);
}

bool isButtonPressed() {
    int reading = digitalRead(BUTTON_PIN);
    bool shortPressEvent = false;

    // 1. EVENTO: Il pulsante viene premuto fisicamente verso il basso (LOW)
    if (reading == LOW && !isPressing) {
        pressStartTime = millis();
        isPressing = true;
        longPressTriggered = false;
        
        // RF.7: Segnale acustico immediato alla pressione
        playBuzzerBeep(); 
    }

    // 2. STATO: Il pulsante è attualmente mantenuto premuto
    if (isPressing && reading == LOW) {
        unsigned long duration = millis() - pressStartTime;

        // PRE-ALLARME: Dopo 3 secondi, inizia a fare dei beep e vibrare per avvisare
        if (duration > 3000 && duration < 5000 && !longPressTriggered) {
            digitalWrite(BUZZER_PIN, (millis() / 100) % 2); 
            digitalWrite(VIBRATION_PIN, (millis() / 100) % 2); // Feedback tattile pre-reset
        }

        // RESET: Raggiunti i 5 secondi di pressione continua
        if (duration >= 5000 && !longPressTriggered) {
            longPressTriggered = true;
            
            Serial.println("\n[!!!] PRESSIONE LUNGA RILEVATA: RESET IN CORSO [!!!]");
            
            // RF.5: Feedback tattile e uditivo continuo per indicare l'avvenuto reset
            digitalWrite(BUZZER_PIN, HIGH);
            digitalWrite(VIBRATION_PIN, HIGH);
            delay(1500);
            digitalWrite(BUZZER_PIN, LOW);
            digitalWrite(VIBRATION_PIN, LOW);

            // RF.8: Cancella le credenziali dalla NVS ed esegue il riavvio hardware
            clearCredentials();
            delay(500);
            ESP.restart();
        }
    }

    // 3. EVENTO: Il pulsante viene rilasciato
    if (reading == HIGH && isPressing) {
        digitalWrite(BUZZER_PIN, LOW); // Assicura che il pre-allarme si spenga
        digitalWrite(VIBRATION_PIN, LOW); 
        
        unsigned long duration = millis() - pressStartTime;
        
        // Se rilasciato prima dei 5s ed è passato il Debounce software (Gestione Rimbalzi)
        if (duration > 50 && !longPressTriggered) {
            shortPressEvent = true; // È una pressione breve valida, autorizza lo scatto!
        }
        isPressing = false;
    }

    return shortPressEvent; 
}

void playBuzzerBeep() {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(100);
    digitalWrite(BUZZER_PIN, LOW);
}

// --- PATTERN DI VIBRAZIONE ---

void vibrationShort() {
    // Stato CAPTURE: Vibrazione breve di conferma
    digitalWrite(VIBRATION_PIN, HIGH);
    delay(200);
    digitalWrite(VIBRATION_PIN, LOW);
}

void vibrationIntermittent() {
    // Stato PROCESSING: Vibrazione intermittente durante l'invio API
    for (int i = 0; i < 3; i++) {
        digitalWrite(VIBRATION_PIN, HIGH);
        delay(150);
        digitalWrite(VIBRATION_PIN, LOW);
        delay(150);
    }
}

void vibrationLong() {
    // Stato ERROR: Vibrazione lunga per errori API
    digitalWrite(VIBRATION_PIN, HIGH);
    delay(1000);
    digitalWrite(VIBRATION_PIN, LOW);
}

// -----------------------------------------------------------

void greenLedOn() {
    digitalWrite(GREEN_LED_PIN, HIGH);
}

void greenLedOff() {
    digitalWrite(GREEN_LED_PIN, LOW);
}

void redLedOn() {
    digitalWrite(RED_LED_PIN, HIGH);
}

void redLedOff() {
    digitalWrite(RED_LED_PIN, LOW);
}