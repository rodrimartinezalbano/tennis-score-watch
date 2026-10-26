import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'match_history.dart';
import 'tennis_match.dart';

/// Un partido guardado. Solo guarda los eventos y las reglas; el resto se
/// reconstruye con [TennisMatch.replay].
class MatchRecord {
  const MatchRecord({
    required this.startedAt,
    required this.goldenPoint,
    required this.superTieBreak,
    required this.events,
  });

  factory MatchRecord.fromMatch(TennisMatch match, DateTime startedAt) {
    return MatchRecord(
      startedAt: startedAt,
      goldenPoint: match.goldenPoint,
      superTieBreak: match.superTieBreak,
      events: match.events,
    );
  }

  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    return MatchRecord(
      startedAt: DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int),
      goldenPoint: json['goldenPoint'] as bool,
      superTieBreak: json['superTieBreak'] as bool,
      events: (json['events'] as String)
          .split('')
          .map(MatchEvent.fromCode)
          .toList(),
    );
  }

  final DateTime startedAt;
  final bool goldenPoint;
  final bool superTieBreak;
  final List<MatchEvent> events;

  /// Identifica el partido: se vuelve a guardar con cada punto.
  int get id => startedAt.millisecondsSinceEpoch;

  TennisMatch get match => TennisMatch.replay(
    events,
    goldenPoint: goldenPoint,
    superTieBreak: superTieBreak,
  );

  Map<String, dynamic> toJson() => {
    'startedAt': id,
    'goldenPoint': goldenPoint,
    'superTieBreak': superTieBreak,
    'events': events.map((e) => e.code).join(),
  };
}

/// Partidos guardados en el celular, del más nuevo al más viejo.
class MatchLog {
  MatchLog(this._prefs) {
    final raw = _prefs.getStringList(_key) ?? const [];
    records.value = [
      for (final item in raw)
        MatchRecord.fromJson(jsonDecode(item) as Map<String, dynamic>),
    ];
  }

  // v2: guarda eventos (puntos y saques). Los de v1 eran partidos de prueba.
  static const _key = 'match_log_v2';

  final SharedPreferences _prefs;

  final records = ValueNotifier<List<MatchRecord>>(const []);

  /// Guarda o actualiza el partido. Uno sin puntos no se guarda.
  Future<void> save(MatchRecord record) async {
    final others = records.value.where((r) => r.id != record.id);
    if (!record.events.any((e) => e.isPoint)) {
      return _write(others.toList());
    }
    await _write(
      [record, ...others]..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
    );
  }

  Future<void> delete(MatchRecord record) =>
      _write(records.value.where((r) => r.id != record.id).toList());

  Future<void> _write(List<MatchRecord> list) async {
    records.value = list;
    await _prefs.setStringList(_key, [
      for (final r in list) jsonEncode(r.toJson()),
    ]);
  }
}
