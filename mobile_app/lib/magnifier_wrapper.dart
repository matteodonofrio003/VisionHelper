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
    // Calcoliamo lo spazio occupato dalla barra di navigazione inferiore del telefono
    final double bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        // 1. IL CONTENUTO DELLA PAGINA SOTTOSTANTE
        Listener(
          onPointerDown: (event) {
            if (_isMagnifierActive) {
              setState(() => _pointerPosition = event.position);
            }
          },
          onPointerMove: (event) {
            if (_isMagnifierActive) {
              setState(() => _pointerPosition = event.position);
            }
          },
          child: widget.child,
        ),

        // 2. LA LENTE DI INGRANDIMENTO
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
                focalPointOffset: Offset.zero, 
              ),
            ),
          ),

        // 3. IL TASTO FLUTTUANTE DELLA LENTE (SEMPRE VISIBILE E ALLINEATO)
        Positioned(
          // Posizione calcolata: Barra di sistema + 16 pixel (margine standard del FloatingActionButton)
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