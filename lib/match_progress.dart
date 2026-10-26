import 'package:flutter/material.dart';

import 'match_history.dart';
import 'tennis_match.dart';

/// Reglas del partido en una línea.
String rulesLabel(TennisMatch match) => [
  match.goldenPoint ? 'Con punto de oro' : 'Con ventaja',
  if (match.superTieBreak) 'Super TB en el 3er set',
].join(' · ');

/// Ganadores y errores no forzados, yo-rival. Vacío si no se marcó ninguno.
String outcomeLabel(TennisMatch match) {
  final c = match.outcomeCounts;
  if (c.myWinners + c.rivalWinners + c.myErrors + c.rivalErrors == 0) return '';
  return 'Winners ${c.myWinners}-${c.rivalWinners} · '
      'Errores no forzados ${c.myErrors}-${c.rivalErrors}';
}

/// El partido set a set, game a game y punto a punto. Lo más reciente arriba.
class MatchProgress extends StatelessWidget {
  const MatchProgress({required this.match, super.key});

  final TennisMatch match;

  @override
  Widget build(BuildContext context) {
    final sets = match.history.reversed.toList();
    if (sets.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Todavía no se jugó ningún punto.'),
      );
    }
    return ListView.builder(
      itemCount: sets.length,
      itemBuilder: (context, i) => _SetSection(set: sets[i]),
    );
  }
}

class _SetSection extends StatelessWidget {
  const _SetSection({required this.set});

  final SetRecord set;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final result = set.result;
    final games = set.games.reversed.toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result == null
                ? 'Set ${set.number} · en juego'
                : 'Set ${set.number} · ${result.$1}-${result.$2}',
            style: text.titleMedium,
          ),
          const Divider(),
          for (final (i, game) in games.indexed)
            _GameRow(game: game, number: games.length - i),
        ],
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.number});

  final GameRecord game;
  final int number;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = switch (game.kind) {
      GameKind.normal => 'Game $number',
      GameKind.tieBreak => 'Tie-break',
      GameKind.superTieBreak => 'Super tie-break',
    };
    final score = game.scoreAfter;
    final winner = switch (game.wonByMe) {
      null => 'en juego',
      true => 'Yo',
      false => 'Rival',
    };
    final firstServe = game.kind == GameKind.normal ? 'saca' : 'saca primero';
    final server = switch (game.firstServerMine) {
      null => null,
      true => '$firstServe yo',
      false => '$firstServe rival',
    };
    // En los tie-breaks el saque cambia dentro del game: se marca por punto.
    final markServe = game.kind != GameKind.normal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              name,
              if (score != null) '${score.$1}-${score.$2}',
              winner,
              ?server,
            ].join(' · '),
            style: text.labelLarge,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final p in game.points)
                _PointChip(point: p, markServe: markServe),
            ],
          ),
        ],
      ),
    );
  }
}

class _PointChip extends StatelessWidget {
  const _PointChip({required this.point, required this.markServe});

  final PointRecord point;

  /// Agrega `*` del lado de quien sacó el punto, como en el reloj.
  final bool markServe;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = point.mine
        ? colors.primaryContainer
        : colors.errorContainer;
    final foreground = point.mine
        ? colors.onPrimaryContainer
        : colors.onErrorContainer;
    // El punto que cierra el game no tiene marcador: muestra quién lo ganó.
    final score = point.score ?? (point.mine ? 'Game yo' : 'Game rival');
    final label = switch (markServe ? point.servedByMe : null) {
      true => '*$score',
      false => '$score*',
      null => score,
    };
    // W = ganador de quien ganó el punto; E = error no forzado de quien lo perdió.
    final tag = switch (point.outcome) {
      PointOutcome.winner => ' W',
      PointOutcome.unforcedError => ' E',
      PointOutcome.none => '',
    };
    final text = '$label$tag${point.secondServe ? ' 2S' : ''}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: TextStyle(
            color: foreground,
            fontWeight: point.score == null ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }
}
