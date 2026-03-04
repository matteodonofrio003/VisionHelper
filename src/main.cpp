// src/main.cpp
#include <Arduino.h>
#include <WiFi.h>
#include "esp_camera.h"

// Includiamo i nostri moduli
#include "../include/config.h"
#include "feedback.h"
#include "gemini_api.h"

void setup() {
  Serial.begin(115200);
  Serial.println("\n--- Avvio VisionHelper ESP32 ---");
  
  // 1. Inizializza Hardware di Input/Output
  initFeedback();

  // 2. Configura Fotocamera
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM; config.pin_d1 = Y3_GPIO_NUM; config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM; config.pin_d4 = Y6_GPIO_NUM; config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM; config.pin_d7 = Y9_GPIO_NUM; config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM; config.pin_vsync = VSYNC_GPIO_NUM; config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM; config.pin_sccb_scl = SIOC_GPIO_NUM; 
  config.pin_pwdn = PWDN_GPIO_NUM; config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG; // Formato richiesto [cite: 8]

  if(psramFound()){
    config.frame_size = FRAMESIZE_VGA; // Risoluzione 640x480 [cite: 8]
    config.jpeg_quality = 10;
    config.fb_count = 2; 
    Serial.println("PSRAM OK - Risoluzione VGA impostata.");
  } else {
    config.frame_size = FRAMESIZE_SVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
    Serial.println("ATTENZIONE: PSRAM non trovata!");
  }

  if (esp_camera_init(&config) != ESP_OK) {
    Serial.println("ERRORE: Inizializzazione fotocamera fallita!");
    return;
  }

  // 3. Connessione Wi-Fi [cite: 9]
  Serial.print("Connessione al Wi-Fi: ");
  Serial.println(SSID_NAME);
  WiFi.begin(SSID_NAME, WIFI_PASS);
  
  while (WiFi.status() != WL_CONNECTED) { 
    delay(500); 
    Serial.print("."); 
  }
  Serial.println("\nWi-Fi Connesso! Dispositivo pronto all'uso.");
  Serial.println("Premi il bottone per scattare e analizzare l'immagine.");
}

void loop() {
  // Il debounce è gestito internamente dal modulo
  if (isButtonPressed()) {
    
    // Feedback immediato di avvenuto scatto [cite: 13]
    playBuzzerBeep(); 
    Serial.println("\n--- Nuova Acquisizione ---");
    Serial.println("1. Scatto foto in corso...");
    
    unsigned long startTime = millis(); // Misuriamo la latenza
    
    // Acquisizione Immagine [cite: 8]
    camera_fb_t * fb = esp_camera_fb_get();
    
    if (!fb) {
      Serial.println("ERRORE: Impossibile scattare la foto.");
      // Qui potresti inserire un feedback di errore lungo [cite: 15]
      return;
    }

    Serial.printf("   Foto acquisita! (%zu bytes)\n", fb->len);
    Serial.println("2. Elaborazione AI in corso... (Attesa risposta da Gemini)");
    
    // Invio Immagine alle API di Gemini [cite: 10]
    String descrizione = inviaImmagineAGemini(fb->buf, fb->len);
    
    // Libera immediatamente la memoria occupata dalla foto 
    esp_camera_fb_return(fb);

    // Stampa il risultato
    Serial.println("\n--- Risultato Analisi Gemini ---");
    Serial.println(descrizione);
    Serial.println("--------------------------------");
    
    unsigned long endTime = millis();
    Serial.printf("Tempo totale di elaborazione: %lu ms\n", (endTime - startTime));
    
    // Il dispositivo è pronto per un nuovo scatto
  }
}