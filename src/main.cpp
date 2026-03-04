// src/main.cpp
#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include "esp_camera.h"

#include "../include/config.h"
#include "feedback.h"

WebServer server(80);

// Variabile globale per conservare l'ultima foto scattata
camera_fb_t * last_photo = nullptr;

// Funzione richiamata quando si visita l'indirizzo IP
void handleWebCapture() {
  // Se non abbiamo ancora scattato nessuna foto
  if (last_photo == nullptr) {
    server.send(200, "text/plain", "Nessuna foto in memoria. Premi il bottone fisico per scattarne una!");
    return;
  }

  // Se la foto c'è, la mostriamo senza scattarne una nuova
  server.setContentLength(last_photo->len);
  server.send(200, "image/jpeg", "");
  WiFiClient client = server.client();
  client.write(last_photo->buf, last_photo->len);
  
  Serial.println("Foto visualizzata sul browser.");
}

void setup() {
  Serial.begin(115200);
  
  initFeedback();

  // Configura Fotocamera
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM; config.pin_d1 = Y3_GPIO_NUM; config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM; config.pin_d4 = Y6_GPIO_NUM; config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM; config.pin_d7 = Y9_GPIO_NUM; config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM; config.pin_vsync = VSYNC_GPIO_NUM; config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM; config.pin_sccb_scl = SIOC_GPIO_NUM; // Nomi corretti senza warning!
  config.pin_pwdn = PWDN_GPIO_NUM; config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;

  if(psramFound()){
    config.frame_size = FRAMESIZE_VGA;
    config.jpeg_quality = 10;
    config.fb_count = 2; // Lasciamo 2 buffer per evitare colli di bottiglia
  } else {
    config.frame_size = FRAMESIZE_SVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }

  if (esp_camera_init(&config) != ESP_OK) {
    Serial.println("Errore avvio fotocamera!");
    return;
  }

  // Connessione Wi-Fi
  WiFi.begin(SSID_NAME, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.print("\nIP Web Server: http://");
  Serial.println(WiFi.localIP());

  // Avvia Server
  server.on("/", HTTP_GET, handleWebCapture);
  server.begin();
}

void loop() {
  server.handleClient();

  // Se il bottone viene premuto (grazie al debounce nel nostro modulo!)
  if (isButtonPressed()) {
    Serial.println("Bottone premuto! Scatto foto in corso...");
    playBuzzerBeep(); // Feedback all'utente
    
    // 1. Se c'è già una vecchia foto in memoria, la cancelliamo per fare spazio
    if (last_photo != nullptr) {
      esp_camera_fb_return(last_photo);
      last_photo = nullptr;
    }

    // 2. Scattiamo la NUOVA foto e la salviamo nella variabile globale
    last_photo = esp_camera_fb_get();
    
    if (last_photo) {
      Serial.printf("Foto acquisita con successo! Dimensione: %zu bytes\n", last_photo->len);
      Serial.println("Ora puoi ricaricare la pagina web per vederla.");
    } else {
      Serial.println("Errore: Impossibile scattare la foto!");
    }
  }
}