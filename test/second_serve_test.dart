import 'package:flutter_test/flutter_test.dart';
import 'package:tennis_score_poc/match_history.dart';
import 'package:tennis_score_poc/tennis_match.dart';

/// Y/R punto mío/del rival, S/s saco yo/el rival, 2 = 2do saque.
TennisMatch _play(TennisMatch m, String events) =>
    events.split('').fold(m, (m, c) => m.apply(MatchEvent.fromCode(c)));

void main() {
  group('$TennisMatch second serve', () {
    test('marks the next point and shows 2S in the watch title', () {
      final m = _play(const TennisMatch(), 'SY2');
      expect(m.secondServe, isTrue);
      expect(m.watchTitle, '*15-0 2S | 0-0');
    });

    test('a second tap cancels the mark', () {
      final m = _play(const TennisMatch(), 'SY22');
      expect(m.secondServe, isFalse);
      expect(m.watchTitle, '*15-0 | 0-0');
    });

    test('the mark goes away after the point', () {
      final m = _play(const TennisMatch(), 'S2R');
      expect(m.secondServe, isFalse);
      expect(m.pointsLabel, '0-15');
    });

    test('records which points were played on a second serve', () {
      final m = _play(const TennisMatch(), 's2YR2Y');
      final points = m.history.single.games.single.points;
      expect(points.map((p) => p.secondServe), [true, false, true]);
      expect(points.map((p) => p.servedByMe), [false, false, false]);
    });

    test('cannot be marked while choosing the server or after the match', () {
      expect(const TennisMatch().toggleSecondServe().secondServe, isFalse);
      final over = _play(const TennisMatch(), 'S${'Y' * 4 * 6}S${'Y' * 4 * 6}');
      expect(over.isOver, isTrue);
      expect(over.toggleSecondServe(), same(over));
    });

    test('undo removes the mark', () {
      final m = _play(const TennisMatch(), 'S2').undo();
      expect(m.secondServe, isFalse);
    });

    test('survives a replay', () {
      final m = _play(const TennisMatch(), 'S2Y2');
      expect(TennisMatch.replay(m.events).secondServe, isTrue);
    });
  });
}
