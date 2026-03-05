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
    }

    // 2. STATO: Il pulsante è attualmente mantenuto premuto
    if (isPressing) {
        unsigned long duration = millis() - pressStartTime;

        // PRE-ALLARME (Opzionale): Dopo 3 secondi, inizia a fare dei beep veloci per avvisare
        if (duration > 3000 && duration < 5000 && !longPressTriggered) {
            digitalWrite(BUZZER_PIN, (millis() / 100) % 2); 
        }

        // RESET: Raggiunti i 5 secondi di pressione continua
        if (duration >= 5000 && !longPressTriggered) {
            longPressTriggered = true;
            
            Serial.println("\n[!!!] PRESSIONE LUNGA RILEVATA: RESET IN CORSO [!!!]");
            
            // Feedback Tattile e Uditivo continuo per 1.5 secondi
            digitalWrite(BUZZER_PIN, HIGH);
            digitalWrite(VIBRATION_PIN, HIGH);
            delay(1500);
            digitalWrite(BUZZER_PIN, LOW);
            digitalWrite(VIBRATION_PIN, LOW);

            // Cancella le credenziali dalla NVS ed esegue il riavvio hardware
            clearCredentials();
            delay(500);
            ESP.restart();
        }

        // 3. EVENTO: Il pulsante viene rilasciato
        if (reading == HIGH) {
            digitalWrite(BUZZER_PIN, LOW); // Assicura che il pre-allarme si spenga
            
            // Se è stato rilasciato prima dei 5 secondi (ed è passato un minimo di debounce)
            if (duration > 50 && !longPressTriggered) {
                shortPressEvent = true; // È una pressione breve valida, autorizza lo scatto!
            }
            isPressing = false;
        }
    }

    return shortPressEvent; 
}

void playBuzzerBeep() {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(100);
    digitalWrite(BUZZER_PIN, LOW);
}

void vibration() {
    digitalWrite(VIBRATION_PIN, HIGH);
    delay(2000);
    digitalWrite(VIBRATION_PIN, LOW);
}

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