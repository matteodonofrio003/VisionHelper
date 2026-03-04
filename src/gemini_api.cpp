#include "gemini_api.h"
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include "mbedtls/base64.h" 
#include "config.h"

String inviaImmagineAGemini(uint8_t* imgBuffer, size_t imgLen) {
    if (WiFi.status() != WL_CONNECTED) return "Errore: Wi-Fi non connesso";

    // 1. Conversione Immagine in Base64
    size_t out_len;
    mbedtls_base64_encode(NULL, 0, &out_len, imgBuffer, imgLen);
    
    char* base64_image = (char*)ps_malloc(out_len);
    if (!base64_image) return "Errore: Memoria insufficiente per Base64";
    
    mbedtls_base64_encode((unsigned char*)base64_image, out_len, &out_len, imgBuffer, imgLen);

    // 2. Preparazione richiesta HTTPS
    WiFiClientSecure client;
    client.setInsecure(); 
    
    HTTPClient http;
    String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=";
    url += GEMINI_API_KEY;

    http.begin(client, url);
    http.setTimeout(10000); // Timeout per evitare loop infiniti
    http.addHeader("Content-Type", "application/json");

    // 3. Costruzione del Payload JSON (Compatibile ArduinoJson v7)
    JsonDocument doc;
    JsonArray contents_array = doc["contents"].to<JsonArray>();
    JsonObject content_obj = contents_array.add<JsonObject>();
    
    JsonArray parts_array = content_obj["parts"].to<JsonArray>();
    
    JsonObject part_text = parts_array.add<JsonObject>();
    part_text["text"] = "Descrivi brevemente e in italiano cosa vedi in questa immagine per un utente ipovedente.";
    
    JsonObject part_img = parts_array.add<JsonObject>();
    JsonObject inline_data = part_img["inline_data"].to<JsonObject>(); 
    inline_data["mime_type"] = "image/jpeg";
    inline_data["data"] = base64_image;

    String requestBody;
    serializeJson(doc, requestBody);
    
    free(base64_image); // Libera la PSRAM

    // 4. Invio della richiesta POST
    int httpResponseCode = http.POST(requestBody);
    String response = "";

    if (httpResponseCode > 0) {
        String responseRaw = http.getString();
        
        // --- STAMPE DI DEBUG ---
        Serial.print("Codice HTTP: "); 
        Serial.println(httpResponseCode);
        Serial.println("Risposta Raw da Google: ");
        Serial.println(responseRaw);
        // -----------------------

        JsonDocument respDoc;
        deserializeJson(respDoc, responseRaw);
        
        const char* text = respDoc["candidates"][0]["content"]["parts"][0]["text"];
        if (text) response = String(text);
        else response = "L'AI non ha restituito una descrizione valida.";
    } else {
        response = "Errore HTTPS: " + String(httpResponseCode);
    }

    http.end();
    
    return response;
}