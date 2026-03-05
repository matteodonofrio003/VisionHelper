import 'package:flutter/material.dart';

class MagnifierWrapper extends StatefulWidget {
  final Widget child; // La schermata che vogliamo avvolgere

  const MagnifierWrapper({super.key, required this.child});

  @override
  State<MagnifierWrapper> createState() => _MagnifierWrapperState();
}

class _MagnifierWrapperState extends State<MagnifierWrapper> {
  bool _isMagnifierActive = false;
  Offset _pointerPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. IL CONTENUTO DELLA PAGINA SOTTOSTANTE
        // Usiamo Listener invece di GestureDetector per tracciare il dito 
        // senza bloccare lo scrolling naturale della pagina.
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

        // 2. LA LENTE DI INGRANDIMENTO (visibile solo se attiva)
        if (_isMagnifierActive)
          Positioned(
            // Centriamo la lente esattamente sotto/sopra il dito
            left: _pointerPosition.dx - 80, 
            top: _pointerPosition.dy - 80,
            child: IgnorePointer( // Fondamentale: la lente è "fantasma" ai tocchi
              child: RawMagnifier(
                decoration: const MagnifierDecoration(
                  shape: CircleBorder(
                    side: BorderSide(color: Colors.yellowAccent, width: 4),
                  ),
                ),
                size: const Size(160, 160),
                magnificationScale: 2.0, // Ingrandimento 2x
                // Spostiamo leggermente il punto focale per non coprirlo col dito
                focalPointOffset: const Offset(0, -20), 
              ),
            ),
          ),

        // 3. IL TASTO FLUTTUANTE PER ATTIVARE/DISATTIVARE LA LENTE
        Positioned(
          bottom: 30,
          left: 20, // Lo mettiamo a sinistra per non intralciare altri bottoni
          child: FloatingActionButton(
            heroTag: "magnifier_toggle_btn", // Serve se ci sono più FAB sullo schermo
            backgroundColor: _isMagnifierActive ? Colors.yellowAccent : Colors.grey[800],
            foregroundColor: _isMagnifierActive ? Colors.black : Colors.white,
            onPressed: () {
              setState(() {
                _isMagnifierActive = !_isMagnifierActive;
                // Imposta una posizione iniziale di default se viene accesa
                if (_isMagnifierActive) {
                  _pointerPosition = Offset(
                    MediaQuery.of(context).size.width / 2,
                    MediaQuery.of(context).size.height / 2,
                  );
                }
              });
            },
            child: const Icon(Icons.search, size: 36),
          ),
        ),
      ],
    );
  }
}