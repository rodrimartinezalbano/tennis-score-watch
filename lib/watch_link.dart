import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Botones de la pantalla de música del reloj.
enum WatchButton { play, pause, previous, next, volumeUp, volumeDown }

enum WatchStatus { disconnected, connecting, authenticating, connected }

/// Conexión directa con el reloj (lado Android: `WatchBridge.kt`), sin Mi Fitness.
///
/// La clave del reloj se guarda solo del lado nativo: Dart la manda una vez y
/// después solo sabe si hay una guardada.
class WatchLink {
  WatchLink() {
    _events.receiveBroadcastStream().listen(_onEvent);
  }

  static const _methods = MethodChannel('tennis/watch');
  static const _events = EventChannel('tennis/watch/events');

  final status = ValueNotifier(WatchStatus.disconnected);

  /// Por qué falló la última conexión, si falló.
  final statusDetail = ValueNotifier<String?>(null);

  /// Último botón recibido, para ver en el celular qué llega del reloj.
  final lastButton = ValueNotifier<WatchButton?>(null);

  /// Pulso en vivo que manda el reloj (lpm), o `null` si todavía no llegó.
  final heartRate = ValueNotifier<int?>(null);

  final _buttons = StreamController<WatchButton>.broadcast();
  Stream<WatchButton> get buttons => _buttons.stream;

  Future<({String mac, bool hasKey})> savedCredentials() async {
    final state = await _methods.invokeMapMethod<String, Object?>('getState');
    return (
      mac: state?['mac'] as String? ?? '',
      hasKey: state?['hasKey'] as bool? ?? false,
    );
  }

  /// [key] vacío deja la clave que ya estaba guardada.
  Future<void> saveCredentials({required String mac, String? key}) =>
      _methods.invokeMethod('saveCredentials', {'mac': mac, 'key': key});

  Future<void> connect() => _methods.invokeMethod('connect');

  Future<void> disconnect() => _methods.invokeMethod('disconnect');

  Future<void> setScore({required String title, required String artist}) =>
      _methods.invokeMethod('setScore', {'title': title, 'artist': artist});

  void _onEvent(Object? event) {
    if (event is! Map) return;
    switch (event['type']) {
      case 'status':
        status.value = _status(event['status'] as String?);
        statusDetail.value = event['detail'] as String?;
        if (status.value != WatchStatus.connected) heartRate.value = null;
      case 'button':
        final button = _button(event['button'] as String?);
        if (button == null) return;
        lastButton.value = button;
        _buttons.add(button);
      case 'heartRate':
        heartRate.value = event['bpm'] as int?;
    }
  }

  static WatchStatus _status(String? name) => switch (name) {
    'CONNECTING' => WatchStatus.connecting,
    'AUTHENTICATING' => WatchStatus.authenticating,
    'CONNECTED' => WatchStatus.connected,
    _ => WatchStatus.disconnected,
  };

  static WatchButton? _button(String? name) => switch (name) {
    'PLAY' => WatchButton.play,
    'PAUSE' => WatchButton.pause,
    'PREVIOUS' => WatchButton.previous,
    'NEXT' => WatchButton.next,
    'VOLUME_UP' => WatchButton.volumeUp,
    'VOLUME_DOWN' => WatchButton.volumeDown,
    _ => null,
  };
}
