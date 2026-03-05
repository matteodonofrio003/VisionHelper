import 'package:flutter/material.dart';
import 'magnifier_wrapper.dart';

// Trasformato in StatefulWidget per poter gestire il controller dello scroll
class InstructionsScreen extends StatefulWidget {
  const InstructionsScreen({super.key});

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  // Questo controller farà da "ancora" per impedire alla pagina di saltare in alto
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MagnifierWrapper(
      child: Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          title: const Text("Come Riconfigurare", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(size: 40),
        ),
        body: SingleChildScrollView(
          controller: _scrollController, // Assegniamo l'ancora qui!
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.touch_app, size: 100, color: Colors.yellowAccent),
              const SizedBox(height: 40),
              Semantics(
                header: true,
                child: const Text(
                  "Modalità Configurazione",
                  style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              Semantics(
                label: "Per ricollegare l'app, tieni premuto il pulsante di scatto sul dispositivo per 5 secondi finché non senti la vibrazione.",
                child: const Text(
                  "1. Prendi il tuo VisionHelper.\n\n"
                  "2. Tieni premuto il pulsante fisico per 5 secondi.\n\n"
                  "3. Attendi la vibrazione e il segnale acustico.\n\n"
                  "4. Torna in questa schermata e premi l'icona Radar/Bluetooth per cercare.",
                  style: TextStyle(fontSize: 24, color: Colors.white, height: 1.5),
                ),
              ),
              const SizedBox(height: 60), 
              Semantics(
                button: true,
                label: "Ho capito, torna indietro",
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellowAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("HO CAPITO", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}