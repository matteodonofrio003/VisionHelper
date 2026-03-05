import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'wifi_config_screen.dart'; // Importiamo la nuova schermata

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

  void _startScan() async {
    _devices.clear();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
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

      // Invece di aprire il popup, navighiamo alla nuova pagina full-screen
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
    return Scaffold(
      appBar: AppBar(title: const Text("VisionHelper"), backgroundColor: Theme.of(context).colorScheme.inversePrimary),
      body: _devices.isEmpty 
        ? const Center(child: Text("Nessun VisionHelper trovato.\nPremi la lente per cercare.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)))
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
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning || _isConnecting ? null : _startScan,
        child: _isScanning ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.search),
      ),
    );
  }
}