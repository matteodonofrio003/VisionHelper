import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// --- SERVICE & CHARACTERISTIC UUIDs DAL FIRMWARE ESP32 ---
const String visionServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String ssidCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String passCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a9";

void main() {
  runApp(const VisionHelperApp());
}

class VisionHelperApp extends StatelessWidget {
  const VisionHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VisionHelper Config',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const ScanScreen(),
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<ScanResult> _devices = [];
  bool _isScanning = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _initBle();
  }

  Future<void> _initBle() async {
    // Richiesta permessi Android (Fondamentale per la scansione)
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Ascolto asincrono dei risultati di scansione (come un interrupt)
    FlutterBluePlus.onScanResults.listen((results) {
      if (mounted) {
        setState(() {
          // Filtriamo solo l'ESP32 con il nome specifico
          _devices = results.where((r) => r.device.advName == "VisionHelper_Config").toList();
        });
      }
    });

    // Ascolto dello stato della scansione
    FlutterBluePlus.isScanning.listen((state) {
      if (mounted) {
        setState(() => _isScanning = state);
      }
    });
  }

  void _startScan() async {
    _devices.clear();
    // Scansione attiva per 5 secondi
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  // --- LOGICA DI CONNESSIONE E PROVISIONING ---
  Future<void> _connectAndConfigure(BluetoothDevice device) async {
    setState(() => _isConnecting = true);

    try {
      // 1. Connessione al dispositivo
      await device.connect(timeout: const Duration(seconds: 5));
      debugPrint("Connesso a ${device.advName}");

      // 2. Scoperta dei servizi GATT
      List<BluetoothService> services = await device.discoverServices();
      
      BluetoothService? visionService;
      try {
        visionService = services.firstWhere((s) => s.uuid.toString() == visionServiceUuid);
      } catch (e) {
        debugPrint("Servizio VisionHelper non trovato sul dispositivo.");
        await device.disconnect();
        setState(() => _isConnecting = false);
        return;
      }

      setState(() => _isConnecting = false);

      // 3. Mostra il dialog per inserire le credenziali Wi-Fi
      if (mounted) {
        _showProvisioningDialog(device, visionService);
      }

    } catch (e) {
      debugPrint("Errore di connessione: $e");
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossibile connettersi al dispositivo.")),
        );
      }
    }
  }

  void _showProvisioningDialog(BluetoothDevice device, BluetoothService service) {
    final TextEditingController ssidController = TextEditingController();
    final TextEditingController passController = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Impedisce la chiusura toccando fuori
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Configura Wi-Fi"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Inserisci le credenziali della rete a cui l'ESP32 dovrà connettersi."),
                const SizedBox(height: 16),
                TextField(
                  controller: ssidController,
                  decoration: const InputDecoration(labelText: "Nome Rete (SSID)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passController,
                  decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                  obscureText: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSending ? null : () {
                  device.disconnect();
                  Navigator.pop(context);
                },
                child: const Text("Annulla"),
              ),
              ElevatedButton(
                onPressed: isSending ? null : () async {
                  setDialogState(() => isSending = true);

                  try {
                    // Trova le caratteristiche
                    var charSsid = service.characteristics.firstWhere((c) => c.uuid.toString() == ssidCharUuid);
                    var charPass = service.characteristics.firstWhere((c) => c.uuid.toString() == passCharUuid);

                    // Scrivi i valori codificati in UTF-8
                    await charSsid.write(utf8.encode(ssidController.text), withoutResponse: false);
                    await charPass.write(utf8.encode(passController.text), withoutResponse: false);

                    debugPrint("Credenziali inviate con successo");

                    // Chiusura connessione e dialog
                    await device.disconnect();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Configurazione inviata! L'ESP32 si riavvierà a breve.")),
                      );
                    }
                  } catch (e) {
                    debugPrint("Errore durante la scrittura GATT: $e");
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Errore durante l'invio dei dati.")),
                      );
                    }
                    setDialogState(() => isSending = false);
                  }
                },
                child: isSending 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text("Invia all'ESP32"),
              )
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("VisionHelper"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _devices.isEmpty 
        ? const Center(
            child: Text(
              "Nessun VisionHelper trovato.\nPremi la lente per cercare.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
        : ListView.builder(
            itemCount: _devices.length,
            itemBuilder: (context, index) {
              final device = _devices[index].device;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.bluetooth_connected, color: Colors.blueGrey),
                  title: Text(device.advName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(device.remoteId.str),
                  trailing: _isConnecting 
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () => _connectAndConfigure(device),
                        child: const Text("Configura"),
                      ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning || _isConnecting ? null : _startScan,
        child: _isScanning 
            ? const CircularProgressIndicator(color: Colors.white) 
            : const Icon(Icons.search),
      ),
    );
  }
}