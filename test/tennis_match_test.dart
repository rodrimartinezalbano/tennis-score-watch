import 'package:flutter_test/flutter_test.dart';
import 'package:tennis_score_poc/tennis_match.dart';

TennisMatch _repeat(TennisMatch m, int times, {required bool mine}) {
  var result = m;
  for (var i = 0; i < times; i++) {
    result = mine ? result.pointForMe() : result.pointForRival();
  }
  return result;
}

TennisMatch _games(TennisMatch m, int games, {required bool mine}) =>
    _repeat(m, games * 4, mine: mine);

void main() {
  group(TennisMatch, () {
    test('counts points as 15, 30 and 40', () {
      var m = const TennisMatch();
      expect(m.pointsLabel, '0-0');
      m = m.pointForMe();
      expect(m.pointsLabel, '15-0');
      m = m.pointForRival().pointForRival();
      expect(m.pointsLabel, '15-30');
      m = m.pointForMe().pointForMe();
      expect(m.pointsLabel, '40-30');
    });

    test('handles deuce and advantage', () {
      var m = _repeat(const TennisMatch(), 3, mine: true);
      m = _repeat(m, 3, mine: false);
      expect(m.pointsLabel, 'Iguales');
      m = m.pointForMe();
      expect(m.pointsLabel, 'Ventaja yo');
      m = m.pointForRival();
      expect(m.pointsLabel, 'Iguales');
      m = m.pointForRival();
      expect(m.pointsLabel, 'Ventaja rival');
      m = m.pointForRival();
      expect((m.myGames, m.rivalGames), (0, 1));
    });

    test('wins a set 6-4 but needs two games of margin at 5-5', () {
      var m = _games(const TennisMatch(), 5, mine: true);
      m = _games(m, 4, mine: false);
      m = _games(m, 1, mine: true);
      expect(m.finishedSets, [(6, 4)]);

      m = _games(m, 5, mine: true);
      m = _games(m, 5, mine: false);
      m = _games(m, 1, mine: true);
      expect(m.finishedSets, [(6, 4)]);
      expect((m.myGames, m.rivalGames), (6, 5));
    });

    test('plays a tie-break at 6-6 to seven points by two', () {
      var m = _games(const TennisMatch(), 5, mine: true);
      m = _games(m, 6, mine: false);
      m = _games(m, 1, mine: true);
      expect(m.isTieBreak, isTrue);

      m = _repeat(m, 6, mine: true);
      m = _repeat(m, 6, mine: false);
      m = m.pointForMe();
      expect(m.pointsLabel, '7-6');
      expect(m.finishedSets, isEmpty);
      m = m.pointForMe();
      expect(m.finishedSets, [(7, 6)]);
    });

    test('ends the match after two sets and ignores more points', () {
      var m = _games(const TennisMatch(), 12, mine: true);
      expect(m.isOver, isTrue);
      expect(m.watchTitle, 'Ganaste!');
      expect(m.pointForRival(), same(m));
    });

    test('undo goes back one point, even across games', () {
      final start = _repeat(const TennisMatch(), 3, mine: true);
      final afterGame = start.pointForMe();
      expect(afterGame.myGames, 1);
      expect(afterGame.undo(), same(start));
      expect(const TennisMatch().canUndo, isFalse);
    });

    test('builds the watch title and subtitle', () {
      var m = _games(const TennisMatch(), 6, mine: true);
      m = _games(
        m,
        2,
        mine: false,
      ).pointForMe().pointForRival().pointForRival();
      expect(m.watchTitle, '15-30 | 0-2');
      expect(m.watchSubtitle, '6-0 · Set 2');
    });

    test('shows points and games in the title during the first set', () {
      final m = _games(const TennisMatch(), 3, mine: true).pointForRival();
      expect(m.watchTitle, '0-15 | 3-0');
      expect(m.watchSubtitle, 'Set 1');
    });

    test('marks the tie-break in the title', () {
      var m = _games(const TennisMatch(), 5, mine: true);
      m = _games(m, 6, mine: false);
      m = _games(m, 1, mine: true).pointForMe();
      expect(m.watchTitle, '1-0 | 6-6 TB');
    });

    test('lists the final sets when the match is over', () {
      final m = _games(const TennisMatch(), 12, mine: true);
      expect(m.watchSubtitle, '6-0 6-0');
    });

    group('with golden point', () {
      TennisMatch deuce() => _repeat(
        _repeat(const TennisMatch(goldenPoint: true), 3, mine: true),
        3,
        mine: false,
      );

      test('shows 40-40 instead of deuce', () {
        expect(deuce().pointsLabel, '40-40');
      });

      test('gives the game to whoever wins the point at 40-40', () {
        final mine = deuce().pointForMe();
        expect((mine.myGames, mine.rivalGames, mine.myPoints), (1, 0, 0));

        final rival = deuce().pointForRival();
        expect((rival.myGames, rival.rivalGames, rival.rivalPoints), (0, 1, 0));
      });

      test('keeps the option after games and sets', () {
        final m = _games(const TennisMatch(goldenPoint: true), 7, mine: true);
        expect(m.goldenPoint, isTrue);
        expect(m.undo().goldenPoint, isTrue);
      });

      test('still needs two points of margin in the tie-break', () {
        var m = _games(const TennisMatch(goldenPoint: true), 5, mine: true);
        m = _games(m, 6, mine: false);
        m = _games(m, 1, mine: true);
        m = _repeat(_repeat(m, 6, mine: true), 6, mine: false).pointForMe();
        expect(m.finishedSets, isEmpty);
        expect(m.pointsLabel, '7-6');
      });
    });

    group('with super tie-break', () {
      TennisMatch oneSetAll() {
        var m = _games(const TennisMatch(superTieBreak: true), 6, mine: true);
        return _games(m, 6, mine: false);
      }

      test('plays a super tie-break instead of a third set at one set all', () {
        final m = oneSetAll();
        expect(m.isSuperTieBreak, isTrue);
        expect(m.pointForMe().watchTitle, '1-0 | STB');
        expect(m.watchSubtitle, '6-0 0-6 · Super tie-break');
      });

      test('wins the match at ten points even from 9-9', () {
        var m = _repeat(oneSetAll(), 9, mine: true);
        m = _repeat(m, 9, mine: false);
        expect(m.isOver, isFalse);
        m = m.pointForRival();
        expect(m.isOver, isTrue);
        expect(m.watchTitle, 'Perdiste');
        expect(m.watchSubtitle, '6-0 0-6 [9-10]');
      });

      test('ends 10-8 without needing more points', () {
        var m = _repeat(oneSetAll(), 8, mine: false);
        m = _repeat(m, 10, mine: true);
        expect(m.isOver, isTrue);
        expect(m.finishedSets.last, (10, 8));
      });

      test('does not apply when someone wins the first two sets', () {
        final m = _games(
          const TennisMatch(superTieBreak: true),
          12,
          mine: true,
        );
        expect(m.isOver, isTrue);
        expect(m.isSuperTieBreak, isFalse);
      });

      test('plays a normal third set when the option is off', () {
        var m = _games(const TennisMatch(), 6, mine: true);
        m = _games(m, 6, mine: false);
        expect(m.isSuperTieBreak, isFalse);
        expect(m.pointForMe().watchTitle, '15-0 | 0-0');
      });
    });

    test('keeps the watch title in plain ASCII', () {
      var m = const TennisMatch(superTieBreak: true).chooseServer(mine: false);
      final titles = <String>[];
      for (var i = 0; i < 300 && !m.isOver; i++) {
        titles.add(m.watchTitle);
        m = m.press(mine: i % 3 != 0);
      }
      titles.add(m.watchTitle);
      for (final title in titles) {
        expect(title.codeUnits.every((c) => c < 128), isTrue, reason: title);
      }
    });
  });
}
