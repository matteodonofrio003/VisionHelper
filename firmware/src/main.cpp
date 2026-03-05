#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include "esp_camera.h"

#include "../include/config.h" 
#include "feedback.h"
#include "gemini_api.h"
#include "ble_config.h"

camera_fb_t * last_photo = nullptr;
WebServer server(80); 

// --- FUNZIONE VETRINA WEB ---
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
// ----------------------------

void setup() {
  Serial.begin(115200);
  Serial.println("\n--- Avvio VisionHelper ESP32 ---");
  
  initFeedback();
  redLedOn(); // Di default accendiamo il ROSSO, indica "Non connesso"

  initBLE();
  String ssid = getSavedSSID();
  String pass = getSavedPassword();

  // 3. Modalità PROVISIONING (Se manca l'SSID o la Password)
  if (ssid == "" || pass == "") {
    Serial.println("\n[!] ATTENZIONE: Credenziali Wi-Fi mancanti o incomplete!");
    Serial.println("Il dispositivo e' in modalita' CONFIGURAZIONE.");
    Serial.println("Connettiti via Bluetooth (VisionHelper_Config) per inserire i dati.");
    
    // Suono di avviso (due bip rapidi)
    playBuzzerBeep(); delay(150); playBuzzerBeep();
    
    // Il dispositivo resta bloccato qui finché non riceve ENTRAMBI i dati dall'App.
    // Il LED Rosso resta acceso per tutto il tempo.
    while (getSavedSSID() == "" || getSavedPassword() == "") {
      delay(1000);
    }
    
    Serial.println("\n[+] Dati Wi-Fi (SSID e Password) ricevuti completi!");
    Serial.println("Attendo 2 secondi prima di riavviare per applicare le modifiche...");
    delay(2000);
    ESP.restart();
  }

  Serial.println("\nCredenziali Wi-Fi trovate in memoria. Configuro l'hardware...");

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
    config.fb_count = 2;
  } else {
    config.frame_size = FRAMESIZE_SVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }

  if (esp_camera_init(&config) != ESP_OK) {
    Serial.println("ERRORE: Inizializzazione fotocamera fallita!");
    return;
  }

  sensor_t * s = esp_camera_sensor_get();
  if (s != NULL) {
    s->set_vflip(s, 1);
    s->set_hmirror(s, 1);
  }

  // Connessione Wi-Fi
  Serial.print("Connessione al Wi-Fi: ");
  Serial.println(ssid);
  WiFi.begin(ssid.c_str(), pass.c_str());
  
  int tentativi = 0;
  while (WiFi.status() != WL_CONNECTED && tentativi < 20) { 
    delay(500); 
    Serial.print("."); 
    tentativi++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWi-Fi Connesso! Dispositivo pronto all'uso.");
    
    // Switch dei LED: Spegne il rosso, accende il verde
    redLedOff();
    greenLedOn();

    stopBLE(); // Libera la PSRAM!
    
    // --- AVVIO SERVER WEB PER DEBUG ---
    server.on("/", HTTP_GET, handleWebView);
    server.begin();
    Serial.print("Vetrina foto attiva su: http://");
    Serial.println(WiFi.localIP());
    // ----------------------------------
    
    playBuzzerBeep(); 
  } else {
    Serial.println("\nERRORE: Impossibile connettersi al Wi-Fi. Usa il BLE per cambiare password.");
    // Il LED rosso era già acceso e lo lasciamo acceso per indicare l'errore
  }
}

void loop() {
  if (isBLEConnected()) {
    delay(100);
    return; 
  }

  server.handleClient();

  // --- LOGICA DI SCATTO ---
  // isButtonPressed() intercetta internamente la pressione da 5s. 
  // Restituisce true SOLO per le pressioni brevi (scatto foto).
  if (isButtonPressed()) {
    playBuzzerBeep(); 
    Serial.println("\n--- Nuova Acquisizione AI ---");
    Serial.println("1. Scatto foto in corso...");
    
    unsigned long startTime = millis();
    
    if (last_photo != nullptr) {
      esp_camera_fb_return(last_photo);
      last_photo = nullptr;
    }

    last_photo = esp_camera_fb_get();
    
    if (!last_photo) {
      Serial.println("ERRORE: Impossibile scattare la foto.");
      return;
    }

    Serial.printf("   Foto acquisita! (%zu bytes)\n", last_photo->len);
    Serial.println("2. Elaborazione AI in corso... (Attesa risposta da Gemini)");
    
    // Invio immagine alle API
    String descrizione = inviaImmagineAGemini(last_photo->buf, last_photo->len);
    
    // Stampa risultato
    Serial.println("\n--- Risultato Analisi Gemini ---");
    Serial.println(descrizione);
    Serial.println("--------------------------------");
    
    unsigned long endTime = millis();
    Serial.printf("Tempo totale di elaborazione: %lu ms\n", (endTime - startTime));
    
    Serial.print("Puoi vedere la foto appena analizzata su: http://");
    Serial.println(WiFi.localIP());
  }
}