#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include "esp_camera.h"

const char* ssid = "Tuo Wifi";       // INSERISCI IL TUO SSID
const char* password = "Tua Pass";    // INSERISCI LA TUA PASSWORD

WebServer server(80);

// Definizione Pin per Freenove ESP32-WROVER
#define PWDN_GPIO_NUM    -1
#define RESET_GPIO_NUM   -1
#define XCLK_GPIO_NUM    21
#define SIOD_GPIO_NUM    26
#define SIOC_GPIO_NUM    27
#define Y9_GPIO_NUM      35
#define Y8_GPIO_NUM      34
#define Y7_GPIO_NUM      39
#define Y6_GPIO_NUM      36
#define Y5_GPIO_NUM      19
#define Y4_GPIO_NUM      18
#define Y3_GPIO_NUM       5
#define Y2_GPIO_NUM       4
#define VSYNC_GPIO_NUM   25
#define HREF_GPIO_NUM    23
#define PCLK_GPIO_NUM    22

void handleCapture() {
  Serial.println("Scatto foto in corso...");
  camera_fb_t * fb = esp_camera_fb_get();
  
  if (!fb) {
    Serial.println("Errore: Impossibile acquisire l'immagine.");
    server.send(500, "text/plain", "Errore fotocamera");
    return;
  }

  // Invia l'immagine JPEG  al browser
  server.setContentLength(fb->len);
  server.send(200, "image/jpeg", "");
  WiFiClient client = server.client();
  client.write(fb->buf, fb->len);
  
  Serial.printf("Foto inviata al browser! Dimensione: %zu bytes\n", fb->len);
  
  // Libera la memoria (PSRAM) 
  esp_camera_fb_return(fb);
}

void setup() {
  Serial.begin(115200);
  Serial.println();

  // 1. Configurazione Fotocamera
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG; // Output JPEG richiesto 

  // Imposta risoluzione in base alla PSRAM 
  if(psramFound()){
    config.frame_size = FRAMESIZE_VGA; // Risoluzione 640x480 
    config.jpeg_quality = 10;
    config.fb_count = 2;
  } else {
    config.frame_size = FRAMESIZE_SVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }

  esp_err_t err = esp_camera_init(&config);
  // Configurazione avanzata del sensore
  sensor_t * s = esp_camera_sensor_get();
  if (s != NULL) {
    s->set_sharpness(s, 1); // Valori da -2 a 2 (1 o 2 aumentano la nitidezza)
    s->set_contrast(s, 1);  // Valori da -2 a 2 (aumenta un po' il contrasto)
    
    // Se l'immagine è capovolta
    // s->set_vflip(s, 1);   // Capovolge verticalmente
    // s->set_hmirror(s, 1); // Specchia orizzontalmente
  }
  if (err != ESP_OK) {
    Serial.printf("Errore inizializzazione camera: 0x%x\n", err);
    return;
  }

  // 2. Connessione Wi-Fi
  Serial.print("Connessione al Wi-Fi: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("");
  Serial.println("Wi-Fi connesso!");
  Serial.print("Indirizzo IP per vedere la foto: http://");
  Serial.println(WiFi.localIP());

  // 3. Avvio Web Server
  server.on("/", HTTP_GET, handleCapture);
  server.begin();
}

void loop() {
  server.handleClient();
}