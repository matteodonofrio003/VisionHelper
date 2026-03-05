import 'package:flutter/material.dart';

class MagnifierWrapper extends StatefulWidget {
  final Widget child;

  const MagnifierWrapper({super.key, required this.child});

  @override
  State<MagnifierWrapper> createState() => _MagnifierWrapperState();
}

class _MagnifierWrapperState extends State<MagnifierWrapper> {
  bool _isMagnifierActive = false;
  Offset _pointerPosition = Offset.zero;

  static const double _magnifierRadius = 80.0; 
  static const double _fingerGap = 120.0; 

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. IL CONTENUTO DELLA PAGINA SOTTOSTANTE
        // Fix: Se la lente è attiva, "congeliamo" la pagina assorbendo i tocchi.
        // In questo modo è impossibile far scorrere la pagina per sbaglio!
        AbsorbPointer(
          absorbing: _isMagnifierActive,
          child: widget.child,
        ),

        // 2. IL VETRO INVISIBILE CHE CATTURA IL DITO (Attivo solo con la lente)
        if (_isMagnifierActive)
          Positioned.fill(
            child: GestureDetector(
              onPanDown: (details) {
                setState(() => _pointerPosition = details.globalPosition);
              },
              onPanUpdate: (details) {
                setState(() => _pointerPosition = details.globalPosition);
              },
              // Un contenitore trasparente per catturare i tocchi su tutto lo schermo
              child: Container(color: Colors.transparent), 
            ),
          ),

        // 3. LA LENTE DI INGRANDIMENTO
        if (_isMagnifierActive)
          Positioned(
            left: _pointerPosition.dx - _magnifierRadius,
            top: _pointerPosition.dy - _fingerGap - _magnifierRadius,
            child: IgnorePointer(
              child: RawMagnifier(
                decoration: const MagnifierDecoration(
                  shape: CircleBorder(
                    side: BorderSide(color: Colors.yellowAccent, width: 6),
                  ),
                ),
                size: const Size(_magnifierRadius * 2, _magnifierRadius * 2),
                magnificationScale: 2.0,
                focalPointOffset: const Offset(0, _fingerGap), 
              ),
            ),
          ),

        // 4. IL TASTO FLUTTUANTE DELLA LENTE (Sempre cliccabile perché è in cima)
        Positioned(
          bottom: bottomSafeArea + 16, 
          left: 16, 
          width: 70, height: 70, 
          child: FloatingActionButton(
            heroTag: "magnifier_toggle_btn", 
            backgroundColor: _isMagnifierActive ? Colors.yellowAccent : Colors.grey[800],
            foregroundColor: _isMagnifierActive ? Colors.black : Colors.white,
            onPressed: () {
              setState(() {
                _isMagnifierActive = !_isMagnifierActive;
                if (_isMagnifierActive) {
                  // Posiziona la lente al centro quando la accendi
                  _pointerPosition = Offset(screenSize.width / 2, screenSize.height / 2);
                }
              });
            },
            child: Icon(_isMagnifierActive ? Icons.search_off : Icons.search, size: 36), 
          ),
        ),
      ],
    );
  }
}