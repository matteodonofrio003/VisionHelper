// src/main.cpp
#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include "esp_camera.h"

// Includiamo i nostri moduli
#include "../include/config.h"
#include "feedback.h"
#include "gemini_api.h"

WebServer server(80);

// Variabile globale per conservare l'ultima foto
camera_fb_t * last_photo = nullptr;

// Mostra l'ultima foto scattata senza acquisirne di nuove
void handleWebView() {
  if (last_photo == nullptr) {
    server.send(200, "text/plain", "Nessuna foto in memoria. Premi il bottone fisico per scattare!");
    return;
  }
  
  // Invia al browser la foto salvata in memoria
  server.setContentLength(last_photo->len);
  server.send(200, "image/jpeg", "");
  WiFiClient client = server.client();
  client.write(last_photo->buf, last_photo->len);
}

void setup() {
  Serial.begin(115200);
  Serial.println("\n--- Avvio VisionHelper ESP32 ---");
  
  initFeedback();

  // Configura Fotocamera
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
  config.pixel_format = PIXFORMAT_JPEG;

  if(psramFound()){
    config.frame_size = FRAMESIZE_VGA;
    config.jpeg_quality = 10;
    config.fb_count = 2; // Necessario per tenere 1 foto in memoria mentre la camera è pronta per la successiva
  } else {
    config.frame_size = FRAMESIZE_SVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }

  if (esp_camera_init(&config) != ESP_OK) {
    Serial.println("ERRORE: Inizializzazione fotocamera fallita!");
    return;
  }

  // --- NUOVO BLOCCO: Orientamento Fotocamera ---
  sensor_t * s = esp_camera_sensor_get();
  if (s != NULL) {
    s->set_vflip(s, 1);   // 1 = Capovolge verticalmente
    s->set_hmirror(s, 1); // 1 = Specchia orizzontalmente (Da destra a sinistra)
  }
  // ---------------------------------------------

  // Connessione Wi-Fi
  Serial.print("Connessione al Wi-Fi: ");
  Serial.println(SSID_NAME);
  WiFi.begin(SSID_NAME, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  
  Serial.println("\nWi-Fi Connesso!");
  
  // Avvia il server web per visualizzare l'ultima foto
  server.on("/", HTTP_GET, handleWebView);
  server.begin();
  
  Serial.print("Vetrina foto attiva su: http://");
  Serial.println(WiFi.localIP());
  Serial.println("Premi il bottone fisico per scattare e analizzare.");
}

void loop() {
  server.handleClient();

  if (isButtonPressed()) {
    playBuzzerBeep(); 
    Serial.println("\n--- Nuova Acquisizione AI ---");
    Serial.println("1. Scatto foto in corso...");
    
    unsigned long startTime = millis();
    
    // Svuotiamo la memoria dalla vecchia foto prima di scattare la nuova
    if (last_photo != nullptr) {
      esp_camera_fb_return(last_photo);
      last_photo = nullptr;
    }

    // Acquisiamo la nuova foto e la assegniamo alla variabile globale
    last_photo = esp_camera_fb_get();
    
    if (!last_photo) {
      Serial.println("ERRORE: Impossibile scattare la foto per Gemini.");
      return;
    }

    Serial.printf("   Foto acquisita! (%zu bytes)\n", last_photo->len);
    Serial.println("2. Elaborazione AI in corso... (Attesa risposta da Gemini)");
    
    // Invia Immagine alle API usando il buffer globale
    String descrizione = inviaImmagineAGemini(last_photo->buf, last_photo->len);
    
    // NOTA BENE: NON chiamiamo più esp_camera_fb_return(last_photo) qui!
    // La foto rimane in memoria a disposizione del server web.

    // Stampa Risultato
    Serial.println("\n--- Risultato Analisi Gemini ---");
    Serial.println(descrizione);
    Serial.println("--------------------------------");
    
    unsigned long endTime = millis();
    Serial.printf("Tempo totale di elaborazione: %lu ms\n", (endTime - startTime));
  }
}