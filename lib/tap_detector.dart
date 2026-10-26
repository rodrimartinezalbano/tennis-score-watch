import 'dart:async';

/// Distingue un toque de un doble toque en ⏯ del reloj.
///
/// El reloj no avisa cuánto dura una pulsación, solo manda cada toque. Un
/// toque espera [window]: si llega otro antes, los dos cuentan como un solo
/// doble toque; si no, recién entonces cuenta como toque simple.
class TapDetector {
  TapDetector({
    required this.onSingle,
    required this.onDouble,
    this.window = const Duration(milliseconds: 500),
  });

  final void Function() onSingle;
  final void Function() onDouble;
  final Duration window;

  Timer? _pending;

  void tap() {
    final pending = _pending;
    if (pending != null && pending.isActive) {
      pending.cancel();
      _pending = null;
      onDouble();
      return;
    }
    _pending = Timer(window, () {
      _pending = null;
      onSingle();
    });
  }

  void dispose() => _pending?.cancel();
}
