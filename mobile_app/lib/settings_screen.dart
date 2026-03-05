import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// TODO: Questi UUID andranno aggiunti nel firmware ESP32
const String voiceGenCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26b1"; // 1 per Maschio, 0 per Femmina
const String voiceSpdCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26b2"; // Es. "1.5"

class SettingsScreen extends StatefulWidget {
  final BluetoothDevice device;
  final BluetoothService service;

  const SettingsScreen({super.key, required this.device, required this.service});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _voiceSpeed = 1.0; 
  bool _isMaleVoice = true;
  bool _isSaving = false;

  Future<void> _saveAndSendSettings() async {
    setState(() => _isSaving = true);

    try {
      // Troviamo le caratteristiche (se l'ESP32 non le ha ancora, darà errore, ma è normale in fase di dev)
      var charGen = widget.service.characteristics.firstWhere((c) => c.uuid.toString() == voiceGenCharUuid);
      var charSpd = widget.service.characteristics.firstWhere((c) => c.uuid.toString() == voiceSpdCharUuid);

      // Convertiamo i dati: '1' o '0' per il genere, e stringa per la velocità
      String genderVal = _isMaleVoice ? "1" : "0";
      String speedVal = _voiceSpeed.toStringAsFixed(1);

      await charGen.write(utf8.encode(genderVal), withoutResponse: false);
      await charSpd.write(utf8.encode(speedVal), withoutResponse: false);

      // Disconnessione (l'ESP32 si riavvierà per applicare la NVS )
      await widget.device.disconnect();

      if (mounted) {
        Navigator.pop(context); // Chiude SettingsScreen
        Navigator.pop(context); // Chiude il Dialog originale (se aperto)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impostazioni salvate! L'ESP32 si sta riavviando.")),
        );
      }
    } catch (e) {
      debugPrint("Errore BLE: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Errore. Assicurati di aver aggiornato il firmware dell'ESP32.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], 
      appBar: AppBar(
        title: const Text("Voci e Accessibilità", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(size: 40), 
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- SEZIONE VELOCITÀ ---
            Semantics(
              label: "Velocità corrente: ${_voiceSpeed.toStringAsFixed(1)}. Usa lo slider.",
              header: true,
              child: Text(
                "Velocità: ${_voiceSpeed.toStringAsFixed(1)}x",
                style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 20, 
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 25), 
              ),
              child: Semantics(
                slider: true,
                value: _voiceSpeed.toStringAsFixed(1),
                child: Slider(
                  value: _voiceSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 3, 
                  activeColor: Colors.yellowAccent,
                  inactiveColor: Colors.grey[700],
                  onChanged: (val) => setState(() => _voiceSpeed = val),
                ),
              ),
            ),
            
            const SizedBox(height: 60),

            // --- SEZIONE TIPO VOCE ---
            Semantics(
              header: true,
              child: const Text(
                "Tipo di Voce",
                style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildAccessibleButton(
                      label: "Maschile",
                      icon: Icons.person,
                      isSelected: _isMaleVoice,
                      onTap: () => setState(() => _isMaleVoice = true),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildAccessibleButton(
                      label: "Femminile",
                      icon: Icons.person_3,
                      isSelected: !_isMaleVoice,
                      onTap: () => setState(() => _isMaleVoice = false),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            Semantics(
              button: true,
              label: "Salva e invia",
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _isSaving ? null : _saveAndSendSettings,
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text("SALVA E RIAVVIA", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibleButton({required String label, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: "Seleziona voce $label",
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.yellowAccent : Colors.grey[800],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: isSelected ? 4 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 60, color: isSelected ? Colors.black : Colors.white),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}