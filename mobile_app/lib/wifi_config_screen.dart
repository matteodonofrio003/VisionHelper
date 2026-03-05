import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'settings_screen.dart';

// Usa gli stessi UUID del main
const String ssidCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String passCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a9";

class WifiConfigScreen extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothService service;

  const WifiConfigScreen({super.key, required this.device, required this.service});

  @override
  State<WifiConfigScreen> createState() => _WifiConfigScreenState();
}

class _WifiConfigScreenState extends State<WifiConfigScreen> {
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  bool isSending = false;

  Future<void> _sendWifiData() async {
    setState(() => isSending = true);
    try {
      var charSsid = widget.service.characteristics.firstWhere((c) => c.uuid.toString() == ssidCharUuid);
      var charPass = widget.service.characteristics.firstWhere((c) => c.uuid.toString() == passCharUuid);
      
      await charSsid.write(utf8.encode(ssidController.text), withoutResponse: false);
      await charPass.write(utf8.encode(passController.text), withoutResponse: false);
      
      await widget.device.disconnect();
      if (mounted) {
        Navigator.pop(context); // Torna alla home
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Wi-Fi salvato! L'ESP32 si sta riavviando.", style: TextStyle(fontSize: 18)),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      debugPrint("Errore BLE: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Errore invio dati. Riprova.", style: TextStyle(fontSize: 18)),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // Sfondo scuro per alto contrasto
      appBar: AppBar(
        title: const Text("Configura Wi-Fi", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(size: 40),
      ),
      // SingleChildScrollView salva la UI dall'overflow della tastiera
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: const Text(
                "Inserisci i dati della rete Wi-Fi",
                style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            
            // Campo SSID Gigante
            TextField(
              controller: ssidController,
              style: const TextStyle(fontSize: 24, color: Colors.white),
              decoration: InputDecoration(
                labelText: "Nome Rete (SSID)",
                labelStyle: const TextStyle(fontSize: 20, color: Colors.yellowAccent),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.yellowAccent, width: 3),
                ),
                filled: true,
                fillColor: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 30),
            
            // Campo Password Gigante
            TextField(
              controller: passController,
              obscureText: true,
              style: const TextStyle(fontSize: 24, color: Colors.white),
              decoration: InputDecoration(
                labelText: "Password Wi-Fi",
                labelStyle: const TextStyle(fontSize: 20, color: Colors.yellowAccent),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.yellowAccent, width: 3),
                ),
                filled: true,
                fillColor: Colors.grey[800],
              ),
            ),
            
            const SizedBox(height: 50),
            
            // Tasto Salva Gigante
            Semantics(
              button: true,
              label: "Salva e invia credenziali Wi-Fi",
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: isSending ? const CircularProgressIndicator(color: Colors.black) : const Icon(Icons.wifi, size: 36),
                label: isSending ? const SizedBox.shrink() : const Text("SALVA WI-FI", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                onPressed: isSending ? null : _sendWifiData,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Tasto Impostazioni Voce Gigante
            Semantics(
              button: true,
              label: "Vai alle impostazioni voce",
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  side: const BorderSide(color: Colors.yellowAccent, width: 3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.record_voice_over, size: 36, color: Colors.yellowAccent),
                label: const Text("IMPOSTAZIONI VOCE", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(device: widget.device, service: widget.service),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}