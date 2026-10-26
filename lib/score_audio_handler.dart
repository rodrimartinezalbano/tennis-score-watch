import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'match_history.dart';
import 'match_log.dart';
import 'tap_detector.dart';
import 'tennis_match.dart';
import 'watch_link.dart';

/// Lleva el partido y lo conecta con el reloj (por [watch], sin Mi Fitness):
///
/// - ⏭ → punto mío (o "saco yo" al empezar set/tie-break)
/// - ⏮ → punto del rival (o "saca el rival")
/// - ⏯ → marca/desmarca 2do saque; doble toque (menos de 500 ms) → deshacer
/// - Vol + → el último punto fue un ganador; Vol − → fue un error no forzado
///
/// También publica el marcador como "canción" del celular: la notificación
/// muestra el marcador y el servicio en primer plano mantiene viva la app con
/// la pantalla apagada. El partido se guarda en [log] con cada evento.
class ScoreAudioHandler extends BaseAudioHandler {
  ScoreAudioHandler(this.log, this.watch) {
    _watchButtons = watch.buttons.listen(_onWatchButton);
    _publish();
  }

  final MatchLog log;
  final WatchLink watch;
  late final StreamSubscription<WatchButton> _watchButtons;

  final _player = AudioPlayer();

  final match = ValueNotifier(const TennisMatch());

  /// Cuándo empezó el partido actual; lo identifica en [log].
  DateTime startedAt = DateTime.now();

  late final _taps = TapDetector(
    onSingle: () => unawaited(toggleSecondServe()),
    onDouble: () => unawaited(undo()),
  );

  Future<void> start() async {
    // Un audio en silencio en loop mantiene el servicio en primer plano: así
    // la app sigue recibiendo los botones del reloj con la pantalla apagada.
    await _player.setAsset('assets/silence.wav');
    await _player.setLoopMode(LoopMode.one);
    await _player.setVolume(0);
    unawaited(_player.play());
    _publish();
  }

  Future<void> newMatch(TennisMatch fresh) async {
    // El partido anterior ya quedó guardado con su último evento.
    startedAt = DateTime.now();
    match.value = fresh;
    _publish();
  }

  Future<void> toggleSecondServe() => _apply(match.value.toggleSecondServe());

  Future<void> undo() => _apply(match.value.undo());

  Future<void> tagLastPoint(PointOutcome outcome) =>
      _apply(match.value.tagLastPoint(outcome));

  void _onWatchButton(WatchButton button) {
    switch (button) {
      case WatchButton.next:
        unawaited(_apply(match.value.press(mine: true)));
      case WatchButton.previous:
        unawaited(_apply(match.value.press(mine: false)));
      // El reloj alterna play/pausa según lo que muestra; los dos son ⏯.
      case WatchButton.play || WatchButton.pause:
        _taps.tap();
      case WatchButton.volumeUp:
        unawaited(tagLastPoint(PointOutcome.winner));
      case WatchButton.volumeDown:
        unawaited(tagLastPoint(PointOutcome.unforcedError));
    }
  }

  // Los botones de la notificación del celular hacen lo mismo que los del reloj.
  @override
  Future<void> skipToNext() async => _onWatchButton(WatchButton.next);

  @override
  Future<void> skipToPrevious() async => _onWatchButton(WatchButton.previous);

  @override
  Future<void> play() async => _onWatchButton(WatchButton.play);

  @override
  Future<void> pause() async => _onWatchButton(WatchButton.pause);

  @override
  Future<void> stop() async {
    _taps.dispose();
    await _watchButtons.cancel();
    await _player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
    );
    await super.stop();
  }

  Future<void> _apply(TennisMatch next) async {
    if (identical(next, match.value)) return;
    match.value = next;
    _publish();
    await log.save(MatchRecord.fromMatch(next, startedAt));
  }

  void _publish() {
    final m = match.value;
    unawaited(watch.setScore(title: m.watchTitle, artist: m.watchSubtitle));
    mediaItem.add(
      MediaItem(
        id: 'tennis-score',
        title: m.watchTitle,
        artist: m.watchSubtitle,
        album: 'Tenis',
      ),
    );
    playbackState.add(
      PlaybackState(
        controls: const [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.playPause,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: true,
      ),
    );
  }
}
