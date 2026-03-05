import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'wifi_config_screen.dart';
import 'magnifier_wrapper.dart'; 
import 'instructions_screen.dart'; 

const String visionServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"; 

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
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
    FlutterBluePlus.onScanResults.listen((results) {
      if (mounted) setState(() => _devices = results.where((r) => r.device.advName == "VisionHelper_Config").toList()); 
    });
    FlutterBluePlus.isScanning.listen((state) {
      if (mounted) setState(() => _isScanning = state);
    });
  }

  // FIX APLICATO QUI: Assicuriamo lo spegnimento dello stato
  void _startScan() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _devices.clear();
    });
    
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Errore scansione: $e");
    } finally {
      // Questo viene eseguito SEMPRE, anche se la libreria va in timeout senza avvisare
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectAndConfigure(BluetoothDevice device) async {
    setState(() => _isConnecting = true);

    try {
      await device.connect(timeout: const Duration(seconds: 5));
      debugPrint("Connesso a ${device.advName}");

      List<BluetoothService> services = await device.discoverServices();
      BluetoothService? visionService;
      try {
        visionService = services.firstWhere((s) => s.uuid.toString() == visionServiceUuid);
      } catch (e) {
        await device.disconnect();
        setState(() => _isConnecting = false);
        return;
      }

      setState(() => _isConnecting = false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WifiConfigScreen(device: device, service: visionService!),
          ),
        );
      }

    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossibile connettersi.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MagnifierWrapper(
      child: Scaffold(
        appBar: AppBar(title: const Text("VisionHelper"), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
        body: _devices.isEmpty 
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Nessun VisionHelper trovato.", style: TextStyle(fontSize: 24, color: Colors.grey, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    const Text("Premi l'icona Blu in basso a destra per cercare.", style: TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
                    const SizedBox(height: 50),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), 
                        backgroundColor: Colors.yellowAccent, 
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      icon: const Icon(Icons.help_outline, size: 36),
                      label: const Text("COME RICONFIGURARE", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InstructionsScreen())),
                    ),
                  ],
                ),
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
                      : ElevatedButton(onPressed: () => _connectAndConfigure(device), child: const Text("Configura")),
                  ),
                );
              },
            ),
            
        // FIX APPLICATO QUI: Il bottone non scompare più, ma cambia stato
        floatingActionButton: SizedBox(
          width: 70, height: 70, 
          child: FloatingActionButton(
            heroTag: "scan_ble_btn",
            // Se sta scansionando, diventa grigio. Altrimenti è blu.
            backgroundColor: _isScanning || _isConnecting ? Colors.grey : Colors.blueAccent,
            foregroundColor: Colors.white,
            onPressed: _isScanning || _isConnecting ? null : _startScan,
            // Mostra la rotellina se sta scansionando
            child: _isScanning || _isConnecting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.bluetooth_searching, size: 36),
          ),
        ),
      ),
    );
  }
}