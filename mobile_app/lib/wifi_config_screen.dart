import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'settings_screen.dart';
import 'magnifier_wrapper.dart';

const String ssidCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String passCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a9";
// TODO: Aggiungi questo UUID sul tuo ESP32 per intercettare il comando di reset
const String clearCmdCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26c3"; 

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
  bool isProcessing = false;

  Future<void> _sendWifiData() async {
    setState(() => isProcessing = true);
    try {
      var charSsid = widget.service.characteristics.firstWhere((c) => c.uuid.toString() == ssidCharUuid);
      var charPass = widget.service.characteristics.firstWhere((c) => c.uuid.toString() == passCharUuid);
      
      await charSsid.write(utf8.encode(ssidController.text), withoutResponse: false);
      await charPass.write(utf8.encode(passController.text), withoutResponse: false);
      
      await widget.device.disconnect();
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wi-Fi salvato! L'ESP32 si sta riavviando.", style: TextStyle(fontSize: 18)), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Errore invio dati.", style: TextStyle(fontSize: 18)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  // NUOVA FUNZIONE PER CANCELLARE LA NVS
  Future<void> _clearCredentials() async {
    setState(() => isProcessing = true);
    try {
      // Scrive "1" nella caratteristica di comando per scatenare clearCredentials() su ESP32
      var charClear = widget.service.characteristics.firstWhere((c) => c.uuid.toString() == clearCmdCharUuid);
      await charClear.write(utf8.encode("1"), withoutResponse: false);
      
      await widget.device.disconnect();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Memoria cancellata! L'ESP32 è stato resettato.", style: TextStyle(fontSize: 18)), backgroundColor: Colors.blue));
      }
    } catch (e) {
      debugPrint("Errore BLE Clear: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Errore: Caratteristica non trovata.", style: TextStyle(fontSize: 18)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MagnifierWrapper(
      child: Scaffold(
        backgroundColor: Colors.grey[900], 
        appBar: AppBar(
          title: const Text("Configura Wi-Fi", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.black, foregroundColor: Colors.white, iconTheme: const IconThemeData(size: 40),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: const Text("Inserisci i dati della rete Wi-Fi", style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              const SizedBox(height: 40),
              
              TextField(
                controller: ssidController,
                style: const TextStyle(fontSize: 24, color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Nome Rete (SSID)", labelStyle: const TextStyle(fontSize: 20, color: Colors.yellowAccent),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white, width: 2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.yellowAccent, width: 3)),
                  filled: true, fillColor: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 30),
              
              TextField(
                controller: passController,
                obscureText: true,
                style: const TextStyle(fontSize: 24, color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Password Wi-Fi", labelStyle: const TextStyle(fontSize: 20, color: Colors.yellowAccent),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white, width: 2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.yellowAccent, width: 3)),
                  filled: true, fillColor: Colors.grey[800],
                ),
              ),
              
              const SizedBox(height: 50),
              
              Semantics(
                button: true, label: "Salva e invia credenziali Wi-Fi",
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  icon: isProcessing ? const CircularProgressIndicator(color: Colors.black) : const Icon(Icons.wifi, size: 36),
                  label: isProcessing ? const SizedBox.shrink() : const Text("SALVA WI-FI", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  onPressed: isProcessing ? null : _sendWifiData,
                ),
              ),
              const SizedBox(height: 20),

              // --- NUOVO TASTO PER CANCELLARE LE CREDENZIALI ---
              Semantics(
                button: true, label: "Cancella memoria di rete del dispositivo",
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 24), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                  ),
                  icon: const Icon(Icons.delete_forever, size: 36),
                  label: const Text("CANCELLA RETE", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  onPressed: isProcessing ? null : _clearCredentials,
                ),
              ),
              
              const SizedBox(height: 20),
              Semantics(
                button: true, label: "Vai alle impostazioni voce",
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 24), side: const BorderSide(color: Colors.yellowAccent, width: 3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  icon: const Icon(Icons.record_voice_over, size: 36, color: Colors.yellowAccent),
                  label: const Text("IMPOSTAZIONI VOCE", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen(device: widget.device, service: widget.service))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}