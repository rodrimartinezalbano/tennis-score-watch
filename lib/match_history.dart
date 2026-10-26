/// Lo que puede pasar en un partido. [code] es como se guarda.
enum MatchEvent {
  myPoint('Y'),
  rivalPoint('R'),
  iServe('S'),
  rivalServes('s'),

  /// Marca (o desmarca) que el próximo punto se juega con 2do saque.
  secondServe('2'),

  /// El último punto terminó con un golpe ganador (winner o ace) de quien lo ganó.
  winner('W'),

  /// El último punto terminó con un error no forzado de quien lo perdió.
  unforcedError('E');

  const MatchEvent(this.code);

  final String code;

  bool get isPoint => this == myPoint || this == rivalPoint;

  static MatchEvent fromCode(String code) =>
      values.firstWhere((e) => e.code == code);
}

/// Cómo terminó un punto.
enum PointOutcome { none, winner, unforcedError }

/// Desglose de un partido: sets → games → puntos.
enum GameKind { normal, tieBreak, superTieBreak }

class PointRecord {
  const PointRecord({
    required this.mine,
    required this.score,
    required this.servedByMe,
    this.secondServe = false,
    this.outcome = PointOutcome.none,
  });

  final bool mine;

  /// Ganador de quien ganó el punto, o error no forzado de quien lo perdió.
  final PointOutcome outcome;

  /// Se jugó con 2do saque de quien sacaba.
  final bool secondServe;

  /// `null` si no se eligió quién sacaba.
  final bool? servedByMe;

  /// Marcador del game después del punto, o `null` si el punto lo cerró.
  final String? score;
}

class GameRecord {
  const GameRecord({
    required this.kind,
    required this.points,
    required this.wonByMe,
    required this.firstServerMine,
    required this.scoreAfter,
  });

  final GameKind kind;
  final List<PointRecord> points;

  /// `null` mientras el game está en juego.
  final bool? wonByMe;

  /// Quién sacó el primer punto (`null` si no se eligió).
  final bool? firstServerMine;

  /// Games del set después de este game (o puntos, en un super tie-break).
  final (int, int)? scoreAfter;
}

class SetRecord {
  const SetRecord({
    required this.number,
    required this.games,
    required this.result,
  });

  final int number;
  final List<GameRecord> games;

  /// `null` mientras el set está en juego.
  final (int, int)? result;
}
