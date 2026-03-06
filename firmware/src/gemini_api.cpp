// src/gemini_api.cpp
#include "gemini_api.h"
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include "mbedtls/base64.h" 
#include "../include/config.h" // Legge la API Key da qui!

// Definizione del System Prompt ottimizzato per ipovedenti
const char* SYSTEM_PROMPT = 
    "Agisci come VisionHelper, un assistente per persone ipovedenti. "
    "Analizza l'immagine e fornisci una descrizione rapida (max 30 parole). "
    "Usa il sistema a ore per la posizione degli oggetti (es. 'Bottiglia d'acqua a ore 2'). "
    "Se vedi del testo, leggilo chiaramente. Se ci sono pericoli (es. liquidi versati, ostacoli), "
    "segnalalo immediatamente. Sii oggettivo e non usare frasi introduttive come 'Vedo...' o 'L'immagine mostra...'.";

String inviaImmagineAGemini(uint8_t* imgBuffer, size_t imgLen) {
    if (WiFi.status() != WL_CONNECTED) return "Errore: Wi-Fi non connesso";

    // 1. Conversione Immagine in Base64
    size_t out_len;
    mbedtls_base64_encode(NULL, 0, &out_len, imgBuffer, imgLen);
    
    // Allocazione dinamica in PSRAM per evitare crash di sistema [cite: 29]
    char* base64_image = (char*)ps_malloc(out_len);
    // Verifica del puntatore NULL per prevenire PSRAM Overflow 
    if (!base64_image) return "Errore: Memoria insufficiente per Base64"; 
    
    mbedtls_base64_encode((unsigned char*)base64_image, out_len, &out_len, imgBuffer, imgLen);

    // 2. Preparazione richiesta HTTPS
    WiFiClientSecure client;
    client.setInsecure(); 
    
    HTTPClient http;
    String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=";
    url += GEMINI_API_KEY;

    http.begin(client, url);
    // Timeout di 10s per le richieste HTTPS come da requisiti di affidabilità [cite: 30]
    http.setTimeout(10000); 
    http.addHeader("Content-Type", "application/json");

    // 3. Costruzione del Payload JSON (Compatibile ArduinoJson v7)
    JsonDocument doc;
    JsonArray contents_array = doc["contents"].to<JsonArray>();
    JsonObject content_obj = contents_array.add<JsonObject>();
    
    JsonArray parts_array = content_obj["parts"].to<JsonArray>();
    
    // Inserimento del System Prompt unito alla richiesta
    JsonObject part_text = parts_array.add<JsonObject>();
    part_text["text"] = String(SYSTEM_PROMPT) + " Descrivi l'oggetto o l'ambiente puntato.";
    
    JsonObject part_img = parts_array.add<JsonObject>();
    JsonObject inline_data = part_img["inline_data"].to<JsonObject>(); 
    inline_data["mime_type"] = "image/jpeg";
    inline_data["data"] = base64_image;

    String requestBody;
    serializeJson(doc, requestBody);
    
    // Liberiamo immediatamente la memoria dopo la richiesta HTTP [cite: 85]
    free(base64_image); 

    // 4. Invio della richiesta POST e tracciamento latenza
    Serial.println("Inviando immagine a Gemini...");
    unsigned long startTime = millis();
    int httpResponseCode = http.POST(requestBody);
    unsigned long endTime = millis();
    
    float latenza = (endTime - startTime) / 1000.0;
    String response = "";

    if (httpResponseCode > 0) {
        String responseRaw = http.getString();
        
        JsonDocument respDoc;
        deserializeJson(respDoc, responseRaw);
        
        const char* text = respDoc["candidates"][0]["content"]["parts"][0]["text"];
        if (text) {
            response = String(text);
            
            // --- STAMPE DI DEBUG: Simulazione Voce e Performance ---
            Serial.println("\n=========================================");
            Serial.println("[SIMULAZIONE OUTPUT VOCALE - MAX98357A]");
            Serial.println("Testo che verrà riprodotto: ");
            Serial.println("\"" + response + "\"");
            Serial.println("-----------------------------------------");
            Serial.print("Latenza di Rete + IA: "); 
            Serial.print(latenza);
            Serial.println(" secondi");
            Serial.println("Target latenza totale: 6-8 secondi"); // 
            Serial.println("=========================================\n");
            // -------------------------------------------------------
        }
        else {
            response = "Errore: L'AI non ha restituito una descrizione valida.";
        }
    } else {
        response = "Errore HTTPS: " + String(httpResponseCode);
        Serial.println(response);
    }

    http.end();
    
    return response;
}