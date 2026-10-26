import 'package:flutter_test/flutter_test.dart';
import 'package:tennis_score_poc/match_history.dart';
import 'package:tennis_score_poc/tennis_match.dart';

TennisMatch _play(TennisMatch m, String points) => points
    .split('')
    .fold(m, (m, c) => c == 'Y' ? m.pointForMe() : m.pointForRival());

String _game({required bool mine}) => (mine ? 'Y' : 'R') * 4;

void main() {
  group('$TennisMatch history', () {
    test('is empty before the first point', () {
      expect(const TennisMatch().history, isEmpty);
    });

    test('lists every point of a game with the score after it', () {
      final m = _play(const TennisMatch(), 'YRYYY');
      final game = m.history.single.games.single;
      expect(game.points.map((p) => p.score), [
        '15-0',
        '15-15',
        '30-15',
        '40-15',
        null,
      ]);
      expect(game.points.map((p) => p.mine), [true, false, true, true, true]);
      expect(game.wonByMe, isTrue);
      expect(game.scoreAfter, (1, 0));
    });

    test('keeps the game in progress open at the end', () {
      final m = _play(const TennisMatch(), '${_game(mine: false)}Y');
      final games = m.history.single.games;
      expect(games, hasLength(2));
      expect(games.first.wonByMe, isFalse);
      expect(games.last.wonByMe, isNull);
      expect(games.last.points.single.score, '15-0');
      expect(m.history.single.result, isNull);
    });

    test('closes the set with its result and starts the next one', () {
      final m = _play(const TennisMatch(), '${_game(mine: true) * 6}R');
      expect(m.history, hasLength(2));
      expect(m.history.first.result, (6, 0));
      expect(m.history.first.games.last.scoreAfter, (6, 0));
      expect(m.history.last.number, 2);
      expect(m.history.last.result, isNull);
    });

    test('marks tie-break and super tie-break games', () {
      final toTieBreak =
          _game(mine: true) * 5 + _game(mine: false) * 6 + _game(mine: true);
      var m = _play(
        const TennisMatch(superTieBreak: true),
        '${toTieBreak}YYYYYYY',
      );
      expect(m.history.first.games.last.kind, GameKind.tieBreak);
      expect(m.history.first.result, (7, 6));

      m = _play(m, '${_game(mine: false) * 6}YR');
      final superTb = m.history.last.games.single;
      expect(superTb.kind, GameKind.superTieBreak);
      expect(superTb.points.map((p) => p.score), ['1-0', '1-1']);
    });

    test('drops the undone point', () {
      final m = _play(const TennisMatch(), 'YR').undo();
      expect(m.history.single.games.single.points, hasLength(1));
    });
  });

  group('$TennisMatch replay', () {
    test('rebuilds the same score and rules from the point winners', () {
      final original = _play(
        const TennisMatch(goldenPoint: true, superTieBreak: true),
        'YYYRRRY${_game(mine: false)}YR',
      );
      final copy = TennisMatch.replay(
        original.events,
        goldenPoint: true,
        superTieBreak: true,
      );
      expect(copy.events, original.events);
      expect(copy.watchTitle, original.watchTitle);
      expect(copy.resultLabel, '1-1');
    });
  });

  group('$TennisMatch resultLabel', () {
    test('shows finished sets plus the set in progress', () {
      final m = _play(const TennisMatch(), _game(mine: true) * 7);
      expect(m.resultLabel, '6-0 1-0');
    });

    test('shows super tie-break points in brackets', () {
      final m = _play(
        const TennisMatch(superTieBreak: true),
        '${_game(mine: true) * 6}${_game(mine: false) * 6}YYR',
      );
      expect(m.resultLabel, '6-0 0-6 [2-1]');
    });
  });
}
