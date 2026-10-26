import 'match_history.dart';

/// Marcador de un partido de tenis al mejor de 3 sets, con tie-break a 6-6.
///
/// Con [goldenPoint], a 40-40 el siguiente punto gana el game (sin ventaja).
/// No aplica al tie-break.
///
/// Con [superTieBreak], si quedan 1-1 en sets el tercero se define con un
/// super tie-break: gana el primero que llega a 10 puntos, sin diferencia de
/// dos (a 9-9 el siguiente punto gana el partido).
///
/// Al empezar cada set, cada tie-break y el super tie-break se elige quién
/// saca. En los games el saque cambia cada game; en los tie-breaks, el primero
/// saca un punto y después se alterna cada dos.
///
/// Antes de un punto se puede marcar que se juega con 2do saque; la marca se
/// borra sola al anotar el punto.
///
/// Inmutable: cada evento devuelve un partido nuevo y guarda el anterior para
/// poder deshacer.
class TennisMatch {
  const TennisMatch._({
    required this.myPoints,
    required this.rivalPoints,
    required this.myGames,
    required this.rivalGames,
    required this.finishedSets,
    required this.previous,
    required this.goldenPoint,
    required this.superTieBreak,
    required this.lastEvent,
    required this.setServerMine,
    required this.tieBreakServerMine,
    required this.secondServe,
  });

  const TennisMatch({bool goldenPoint = false, bool superTieBreak = false})
    : this._(
        goldenPoint: goldenPoint,
        superTieBreak: superTieBreak,
        lastEvent: null,
        setServerMine: null,
        tieBreakServerMine: null,
        secondServe: false,
        myPoints: 0,
        rivalPoints: 0,
        myGames: 0,
        rivalGames: 0,
        finishedSets: const [],
        previous: null,
      );

  static const setsToWin = 2;
  static const superTieBreakPoints = 10;

  /// Reconstruye un partido a partir de sus eventos.
  static TennisMatch replay(
    List<MatchEvent> events, {
    bool goldenPoint = false,
    bool superTieBreak = false,
  }) {
    return events.fold(
      TennisMatch(goldenPoint: goldenPoint, superTieBreak: superTieBreak),
      (match, event) => match.apply(event),
    );
  }

  final int myPoints;
  final int rivalPoints;
  final int myGames;
  final int rivalGames;

  /// Sets terminados como (míos, del rival). Un super tie-break se guarda
  /// con sus puntos, p. ej. (10, 8).
  final List<(int, int)> finishedSets;
  final TennisMatch? previous;
  final bool goldenPoint;
  final bool superTieBreak;

  /// El evento que llevó a este estado (`null` al empezar).
  final MatchEvent? lastEvent;

  /// Quién sacó el primer game del set actual (`null` si no se eligió).
  final bool? setServerMine;

  /// Quién sacó el primer punto del tie-break o super tie-break actual.
  final bool? tieBreakServerMine;

  /// El próximo punto se juega con 2do saque.
  final bool secondServe;

  bool get isTieBreak => myGames == 6 && rivalGames == 6;

  bool get isSuperTieBreak =>
      superTieBreak && finishedSets.length == 2 && !isOver;

  int get mySets => finishedSets.where((s) => s.$1 > s.$2).length;
  int get rivalSets => finishedSets.where((s) => s.$2 > s.$1).length;

  bool get isOver => mySets == setsToWin || rivalSets == setsToWin;

  bool get canUndo => previous != null;

  bool get _isAnyTieBreak => isTieBreak || isSuperTieBreak;

  /// Hay que elegir quién saca: arranca un set, un tie-break o el super
  /// tie-break y todavía no se eligió.
  bool get needsServer {
    if (isOver || myPoints + rivalPoints > 0) return false;
    if (_isAnyTieBreak) return tieBreakServerMine == null;
    return myGames + rivalGames == 0 && setServerMine == null;
  }

  /// Quién saca el próximo punto, o `null` si no se eligió.
  bool? get servingMine {
    if (_isAnyTieBreak) {
      final first = tieBreakServerMine;
      if (first == null) return null;
      // Punto 1: el primero; puntos 2-3: el otro; 4-5: el primero; ...
      final pointNumber = myPoints + rivalPoints;
      return ((pointNumber + 1) ~/ 2).isEven ? first : !first;
    }
    final first = setServerMine;
    if (first == null) return null;
    return (myGames + rivalGames).isEven ? first : !first;
  }

  /// Lo que hace un botón del reloj: elige quién saca si hace falta, y si
  /// no, suma el punto.
  TennisMatch press({required bool mine}) => needsServer
      ? chooseServer(mine: mine)
      : (mine ? pointForMe() : pointForRival());

  TennisMatch apply(MatchEvent event) => switch (event) {
    MatchEvent.myPoint => pointForMe(),
    MatchEvent.rivalPoint => pointForRival(),
    MatchEvent.iServe => chooseServer(mine: true),
    MatchEvent.rivalServes => chooseServer(mine: false),
    MatchEvent.secondServe => toggleSecondServe(),
    MatchEvent.winner => tagLastPoint(PointOutcome.winner),
    MatchEvent.unforcedError => tagLastPoint(PointOutcome.unforcedError),
  };

  /// Marca cómo terminó el último punto. Una marca nueva reemplaza a la anterior; sin
  /// puntos jugados no hace nada. Conserva la marca de 2do saque del punto siguiente.
  TennisMatch tagLastPoint(PointOutcome outcome) {
    if (outcome == PointOutcome.none || !events.any((e) => e.isPoint)) {
      return this;
    }
    final event = outcome == PointOutcome.winner
        ? MatchEvent.winner
        : MatchEvent.unforcedError;
    return _copy(event: event, secondServe: secondServe);
  }

  /// Marca del último punto, solo mientras sea lo último que pasó (para el reloj).
  PointOutcome get justTagged => switch (lastEvent) {
    MatchEvent.winner => PointOutcome.winner,
    MatchEvent.unforcedError => PointOutcome.unforcedError,
    _ => PointOutcome.none,
  };

  /// Marca o desmarca el 2do saque del próximo punto. No aplica mientras hay
  /// que elegir quién saca ni con el partido terminado.
  TennisMatch toggleSecondServe() {
    if (isOver || needsServer) return this;
    return _copy(event: MatchEvent.secondServe, secondServe: !secondServe);
  }

  TennisMatch chooseServer({required bool mine}) {
    if (!needsServer) return this;
    final event = mine ? MatchEvent.iServe : MatchEvent.rivalServes;
    return _isAnyTieBreak
        ? _copy(event: event, tieBreakServerMine: mine)
        : _copy(event: event, setServerMine: mine);
  }

  TennisMatch pointForMe() => _point(mine: true);
  TennisMatch pointForRival() => _point(mine: false);

  TennisMatch undo() => previous ?? this;

  TennisMatch _point({required bool mine}) {
    if (isOver) return this;
    final event = mine ? MatchEvent.myPoint : MatchEvent.rivalPoint;

    final my = myPoints + (mine ? 1 : 0);
    final rival = rivalPoints + (mine ? 0 : 1);

    if (isSuperTieBreak) {
      final won = my == superTieBreakPoints || rival == superTieBreakPoints;
      if (!won) return _copy(event: event, myPoints: my, rivalPoints: rival);
      return _copy(
        event: event,
        newSet: true,
        myPoints: 0,
        rivalPoints: 0,
        finishedSets: [...finishedSets, (my, rival)],
      );
    }

    final target = isTieBreak ? 7 : 4;
    final noAdvantage = goldenPoint && !isTieBreak;
    final gameWon =
        (my >= target || rival >= target) &&
        (noAdvantage || (my - rival).abs() >= 2);

    if (!gameWon) {
      return _copy(event: event, myPoints: my, rivalPoints: rival);
    }

    final myGamesNow = myGames + (mine ? 1 : 0);
    final rivalGamesNow = rivalGames + (mine ? 0 : 1);
    final setWon =
        isTieBreak ||
        ((myGamesNow >= 6 || rivalGamesNow >= 6) &&
            (myGamesNow - rivalGamesNow).abs() >= 2);

    if (!setWon) {
      return _copy(
        event: event,
        myPoints: 0,
        rivalPoints: 0,
        myGames: myGamesNow,
        rivalGames: rivalGamesNow,
      );
    }

    return _copy(
      event: event,
      newSet: true,
      myPoints: 0,
      rivalPoints: 0,
      myGames: 0,
      rivalGames: 0,
      finishedSets: [...finishedSets, (myGamesNow, rivalGamesNow)],
    );
  }

  TennisMatch _copy({
    required MatchEvent event,
    bool newSet = false,
    bool? setServerMine,
    bool? tieBreakServerMine,
    int? myPoints,
    int? rivalPoints,
    int? myGames,
    int? rivalGames,
    List<(int, int)>? finishedSets,
    // Cualquier otro evento (un punto) borra la marca de 2do saque.
    bool secondServe = false,
  }) {
    return TennisMatch._(
      myPoints: myPoints ?? this.myPoints,
      rivalPoints: rivalPoints ?? this.rivalPoints,
      myGames: myGames ?? this.myGames,
      rivalGames: rivalGames ?? this.rivalGames,
      finishedSets: finishedSets ?? this.finishedSets,
      previous: this,
      goldenPoint: goldenPoint,
      superTieBreak: superTieBreak,
      lastEvent: event,
      secondServe: secondServe,
      // Un set nuevo vuelve a preguntar quién saca.
      setServerMine: newSet ? null : setServerMine ?? this.setServerMine,
      tieBreakServerMine: newSet
          ? null
          : tieBreakServerMine ?? this.tieBreakServerMine,
    );
  }

  /// Todos los estados del partido, del primero al actual.
  List<TennisMatch> get _timeline {
    final states = <TennisMatch>[];
    for (TennisMatch? m = this; m != null; m = m.previous) {
      states.add(m);
    }
    return states.reversed.toList();
  }

  /// Todos los eventos del partido, en orden.
  List<MatchEvent> get events => [
    for (final state in _timeline) ?state.lastEvent,
  ];

  GameKind get _gameKind => isSuperTieBreak
      ? GameKind.superTieBreak
      : isTieBreak
      ? GameKind.tieBreak
      : GameKind.normal;

  /// Cada punto jugado, en orden, con la marca de cómo terminó.
  List<_PointStep> get _pointSteps {
    final steps = <_PointStep>[];
    final timeline = _timeline;
    for (var i = 1; i < timeline.length; i++) {
      final after = timeline[i];
      switch (after.lastEvent) {
        case MatchEvent.myPoint || MatchEvent.rivalPoint:
          steps.add(
            _PointStep(
              before: timeline[i - 1],
              after: after,
              mine: after.lastEvent == MatchEvent.myPoint,
            ),
          );
        case MatchEvent.winner when steps.isNotEmpty:
          steps.last.outcome = PointOutcome.winner;
        case MatchEvent.unforcedError when steps.isNotEmpty:
          steps.last.outcome = PointOutcome.unforcedError;
        case _:
          break;
      }
    }
    return steps;
  }

  /// Ganadores y errores no forzados de cada uno.
  ({int myWinners, int rivalWinners, int myErrors, int rivalErrors})
  get outcomeCounts {
    var myWinners = 0, rivalWinners = 0, myErrors = 0, rivalErrors = 0;
    for (final step in _pointSteps) {
      switch (step.outcome) {
        case PointOutcome.winner:
          step.mine ? myWinners++ : rivalWinners++;
        // El error es de quien perdió el punto.
        case PointOutcome.unforcedError:
          step.mine ? rivalErrors++ : myErrors++;
        case PointOutcome.none:
          break;
      }
    }
    return (
      myWinners: myWinners,
      rivalWinners: rivalWinners,
      myErrors: myErrors,
      rivalErrors: rivalErrors,
    );
  }

  /// El partido punto a punto, agrupado en games y sets.
  List<SetRecord> get history {
    final sets = <SetRecord>[];
    var games = <GameRecord>[];
    var points = <PointRecord>[];
    bool? firstServerMine;

    for (final step in _pointSteps) {
      final before = step.before;
      final after = step.after;
      final mine = step.mine;
      final servedByMe = before.servingMine;
      if (points.isEmpty) firstServerMine = servedByMe;
      // Solo cerrar un game vuelve los puntos a 0-0.
      final gameOver = after.myPoints == 0 && after.rivalPoints == 0;
      points.add(
        PointRecord(
          mine: mine,
          score: gameOver ? null : after.pointsLabel,
          servedByMe: servedByMe,
          secondServe: before.secondServe,
          outcome: step.outcome,
        ),
      );
      if (!gameOver) continue;

      final setResult = after.finishedSets.length > before.finishedSets.length
          ? after.finishedSets.last
          : null;
      games.add(
        GameRecord(
          kind: before._gameKind,
          points: points,
          wonByMe: mine,
          firstServerMine: firstServerMine,
          scoreAfter: setResult ?? (after.myGames, after.rivalGames),
        ),
      );
      points = [];

      if (setResult != null) {
        sets.add(
          SetRecord(number: sets.length + 1, games: games, result: setResult),
        );
        games = [];
      }
    }

    if (points.isNotEmpty) {
      games.add(
        GameRecord(
          kind: _gameKind,
          points: points,
          wonByMe: null,
          firstServerMine: firstServerMine,
          scoreAfter: null,
        ),
      );
    }
    if (games.isNotEmpty) {
      sets.add(SetRecord(number: sets.length + 1, games: games, result: null));
    }
    return sets;
  }

  /// Puntos del game actual, pensado para la pantalla chica del reloj.
  String get pointsLabel {
    if (isTieBreak || isSuperTieBreak) return '$myPoints-$rivalPoints';
    if (goldenPoint && myPoints == 3 && rivalPoints == 3) return '40-40';
    if (myPoints >= 3 && rivalPoints >= 3) {
      if (myPoints == rivalPoints) return 'Iguales';
      return myPoints > rivalPoints ? 'Ventaja yo' : 'Ventaja rival';
    }
    const names = ['0', '15', '30', '40'];
    return '${names[myPoints]}-${names[rivalPoints]}';
  }

  /// Línea principal ("título de la canción"): puntos y games. Es la única
  /// que muestra el Redmi Watch 5 Lite.
  ///
  /// Un `*` marca quién saca: a la izquierda yo, a la derecha el rival.
  /// `W`/`E` aparece justo después de marcar el último punto como ganador o
  /// error no forzado. `2S` indica que el próximo punto se juega con 2do saque.
  /// Solo caracteres ASCII: la fuente del reloj puede no tener `•`, `·` o
  /// `¿` y cortar el texto.
  String get watchTitle {
    if (isOver) return mySets > rivalSets ? 'Ganaste!' : 'Perdiste';
    if (needsServer) {
      final what = isSuperTieBreak
          ? 'STB '
          : isTieBreak
          ? 'TB '
          : '';
      return '${what}Saca? Sig=yo Ant=rival';
    }
    final served = switch (servingMine) {
      true => '*$pointsLabel',
      false => '$pointsLabel*',
      null => pointsLabel,
    };
    final tag = switch (justTagged) {
      PointOutcome.winner => ' W',
      PointOutcome.unforcedError => ' E',
      PointOutcome.none => '',
    };
    final points = '$served$tag${secondServe ? ' 2S' : ''}';
    if (isSuperTieBreak) return '$points | STB';
    final tb = isTieBreak ? ' TB' : '';
    return '$points | $myGames-$rivalGames$tb';
  }

  /// Sets terminados, p. ej. `6-4 3-6 [10-8]`. El super tie-break va entre
  /// corchetes.
  String get setsLabel => [
    for (final (i, (my, rival)) in finishedSets.indexed)
      superTieBreak && i == 2 ? '[$my-$rival]' : '$my-$rival',
  ].join(' ');

  /// Resultado para el historial: sets terminados y, si sigue, el set actual.
  String get resultLabel {
    if (isOver) return setsLabel;
    final current = isSuperTieBreak
        ? '[$myPoints-$rivalPoints]'
        : '$myGames-$rivalGames';
    return finishedSets.isEmpty ? current : '$setsLabel $current';
  }

  /// Línea secundaria ("artista"): sets terminados. El reloj no la muestra,
  /// pero sí la notificación del celular.
  String get watchSubtitle {
    if (finishedSets.isEmpty) return 'Set 1';
    if (isOver) return setsLabel;
    if (isSuperTieBreak) return '$setsLabel · Super tie-break';
    return '$setsLabel · Set ${finishedSets.length + 1}';
  }
}

/// Un punto jugado: el estado antes y después, y cómo terminó (se marca después).
class _PointStep {
  _PointStep({required this.before, required this.after, required this.mine});

  final TennisMatch before;
  final TennisMatch after;
  final bool mine;
  PointOutcome outcome = PointOutcome.none;
}
