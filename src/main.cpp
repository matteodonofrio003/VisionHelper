// src/main.cpp
#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include "esp_camera.h"

// Includiamo i moduli personalizzati
#include "../include/config.h"
#include "feedback.h"

WebServer server(80);

// Funzione richiamata quando si visita l'indirizzo IPS
void handleWebCapture() {
  Serial.println("Richiesta web ricevuta: Scatto foto...");
  camera_fb_t * fb = esp_camera_fb_get();
  
  if (!fb) {
    server.send(500, "text/plain", "Errore fotocamera");
    return;
  }

  server.setContentLength(fb->len);
  server.send(200, "image/jpeg", "");
  WiFiClient client = server.client();
  client.write(fb->buf, fb->len);
  
  esp_camera_fb_return(fb);
}

void setup() {
  Serial.begin(115200);
  
  // 1. Inizializza Pulsante e Buzzer
  initFeedback();

  // 2. Configura Fotocamera
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM; config.pin_d1 = Y3_GPIO_NUM; config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM; config.pin_d4 = Y6_GPIO_NUM; config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM; config.pin_d7 = Y9_GPIO_NUM; config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM; config.pin_vsync = VSYNC_GPIO_NUM; config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM; config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM; config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;

  if(psramFound()){
    config.frame_size = FRAMESIZE_VGA;
    config.jpeg_quality = 10;
    config.fb_count = 2;
  } else {
    config.frame_size = FRAMESIZE_SVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }

  if (esp_camera_init(&config) != ESP_OK) {
    Serial.println("Errore avvio fotocamera!");
    return;
  }

  // 3. Connessione Wi-Fi
  WiFi.begin(SSID_NAME, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.print("\nIP Web Server: http://");
  Serial.println(WiFi.localIP());

  // 4. Avvia Server
  server.on("/", HTTP_GET, handleWebCapture);
  server.begin();
}

void loop() {
  // Gestisce le richieste in entrata dal browser
  server.handleClient();

  // Ora isButtonPressed() gestisce tutto il debounce internamente!
  if (isButtonPressed()) {
    Serial.println("Bottone fisico premuto! Feedback uditivo in corso...");
    playBuzzerBeep();
    
    camera_fb_t * fb = esp_camera_fb_get();
    if (fb) {
      Serial.printf("Test di scatto hardware completato. Dimensione: %zu bytes\n", fb->len);
      esp_camera_fb_return(fb); // Liberiamo la memoria
    } else {
      Serial.println("Errore di scatto hardware!");
    }
  }
}