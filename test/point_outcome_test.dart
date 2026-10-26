import 'package:flutter_test/flutter_test.dart';
import 'package:tennis_score_poc/match_history.dart';
import 'package:tennis_score_poc/tennis_match.dart';

/// Y/R punto mío/del rival, S/s saco yo/el rival, 2 = 2do saque,
/// W = ganador del último punto, E = error no forzado del último punto.
TennisMatch _play(TennisMatch m, String events) =>
    events.split('').fold(m, (m, c) => m.apply(MatchEvent.fromCode(c)));

List<PointOutcome> _outcomes(TennisMatch m) => [
  for (final set in m.history)
    for (final game in set.games)
      for (final point in game.points) point.outcome,
];

void main() {
  group('$TennisMatch point outcome', () {
    test('marks the last point as a winner and shows W on the watch', () {
      final m = _play(const TennisMatch(), 'SYW');
      expect(_outcomes(m), [PointOutcome.winner]);
      expect(m.watchTitle, '*15-0 W | 0-0');
    });

    test('a new mark replaces the previous one', () {
      final m = _play(const TennisMatch(), 'SYWE');
      expect(_outcomes(m), [PointOutcome.unforcedError]);
      expect(m.watchTitle, '*15-0 E | 0-0');
    });

    test('the watch stops showing the mark after the next point', () {
      final m = _play(const TennisMatch(), 'SYWR');
      expect(m.watchTitle, '*15-15 | 0-0');
      expect(_outcomes(m), [PointOutcome.winner, PointOutcome.none]);
    });

    test('does nothing before the first point', () {
      final m = const TennisMatch().chooseServer(mine: true);
      expect(m.tagLastPoint(PointOutcome.winner), same(m));
    });

    test('keeps the 2nd serve mark of the next point', () {
      final m = _play(const TennisMatch(), 'SY2W');
      expect(m.secondServe, isTrue);
      expect(m.watchTitle, '*15-0 W 2S | 0-0');
    });

    test('marks the point that closed a game', () {
      final m = _play(const TennisMatch(), 'SYYYYW');
      final game = m.history.single.games.single;
      expect(game.points.last.outcome, PointOutcome.winner);
      expect(game.points.last.score, isNull);
    });

    test('counts winners for who won and errors for who lost', () {
      // Yo: ganador. Rival: ganador. Rival gana por mi error. Yo gano por error del rival.
      final m = _play(const TennisMatch(), 'SYWRWRE');
      final c = m.outcomeCounts;
      expect(c.myWinners, 1);
      expect(c.rivalWinners, 1);
      expect(c.myErrors, 1);
      expect(c.rivalErrors, 0);
      expect(_play(m, 'YE').outcomeCounts.rivalErrors, 1);
    });

    test('undo removes the mark', () {
      final m = _play(const TennisMatch(), 'SYW').undo();
      expect(_outcomes(m), [PointOutcome.none]);
    });

    test('survives a replay', () {
      final m = _play(const TennisMatch(), 'SYWRE');
      expect(_outcomes(TennisMatch.replay(m.events)), _outcomes(m));
    });
  });
}
