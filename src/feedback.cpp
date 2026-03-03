// src/feedback.cpp
#include <Arduino.h>
#include "feedback.h"
#include "../include/config.h"

// Variabili per il debounce
int lastButtonState = HIGH; // HIGH perché usiamo PULLUP
int buttonState = HIGH;
unsigned long lastDebounceTime = 0;
unsigned long debounceDelay = 50; // 50 millisecondi di "sordità" ai rimbalzi

void initFeedback() {
    pinMode(BUTTON_PIN, INPUT_PULLUP);
    pinMode(BUZZER_PIN, OUTPUT);
    digitalWrite(BUZZER_PIN, LOW);
}

bool isButtonPressed() {
    int reading = digitalRead(BUTTON_PIN);
    bool isPressedEvent = false;

    // Se il segnale cambia (perché hai premuto o per un rimbalzo)
    if (reading != lastButtonState) {
        lastDebounceTime = millis(); // Resetta il timer
    }

    // Se il segnale è rimasto stabile più a lungo del tempo di debounce
    if ((millis() - lastDebounceTime) > debounceDelay) {
        
        // E se lo stato effettivo è cambiato
        if (reading != buttonState) {
            buttonState = reading;

            // Registriamo l'evento SOLO quando il segnale scende a LOW (pressione)
            if (buttonState == LOW) {
                isPressedEvent = true;
            }
        }
    }

    // Salva la lettura per il prossimo ciclo
    lastButtonState = reading;
    
    // Restituirà true una sola volta per ogni pressione completa!
    return isPressedEvent; 
}

void playBuzzerBeep() {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(100);
    digitalWrite(BUZZER_PIN, LOW);
}