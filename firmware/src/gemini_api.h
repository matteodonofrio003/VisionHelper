#pragma once
#include <Arduino.h>

/**
 * Invia l'immagine JPEG alle API di Google Gemini.
 * @param imgBuffer Puntatore ai dati dell'immagine nella PSRAM 
 * @param imgLen Lunghezza del buffer dell'immagine
 * @return La descrizione testuale ricevuta o un messaggio di errore
 */
String inviaImmagineAGemini(uint8_t* imgBuffer, size_t imgLen);