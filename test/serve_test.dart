import 'package:flutter_test/flutter_test.dart';
import 'package:tennis_score_poc/match_history.dart';
import 'package:tennis_score_poc/tennis_match.dart';

/// Y/R punto mío/del rival, S/s saco yo/el rival.
TennisMatch _play(TennisMatch m, String events) =>
    events.split('').fold(m, (m, c) => m.apply(MatchEvent.fromCode(c)));

String _game({required bool mine}) => (mine ? 'Y' : 'R') * 4;

/// Llega a 6-6 en el primer set, con saque elegido para el set.
final _toTieBreak =
    'S${_game(mine: true) * 5}${_game(mine: false) * 6}${_game(mine: true)}';

void main() {
  group('$TennisMatch serve', () {
    test('asks who serves at the start of the match', () {
      const m = TennisMatch();
      expect(m.needsServer, isTrue);
      expect(m.servingMine, isNull);
      expect(m.watchTitle, 'Saca? Sig=yo Ant=rival');
    });

    test('the watch buttons choose the server first, then score points', () {
      var m = const TennisMatch().press(mine: false);
      expect(m.needsServer, isFalse);
      expect(m.servingMine, isFalse);
      expect(m.pointsLabel, '0-0');

      m = m.press(mine: true);
      expect(m.pointsLabel, '15-0');
    });

    test('alternates the server every game', () {
      var m = _play(const TennisMatch(), 'S');
      expect(m.servingMine, isTrue);
      m = _play(m, _game(mine: false));
      expect(m.servingMine, isFalse);
      m = _play(m, _game(mine: true));
      expect(m.servingMine, isTrue);
    });

    test('marks the server in the watch title', () {
      final mine = _play(const TennisMatch(), 'SY');
      expect(mine.watchTitle, '*15-0 | 0-0');
      final rival = _play(const TennisMatch(), 'sY');
      expect(rival.watchTitle, '15-0* | 0-0');
    });

    test('asks again at the start of every set', () {
      final m = _play(const TennisMatch(), 'S${_game(mine: true) * 6}');
      expect(m.finishedSets, [(6, 0)]);
      expect(m.needsServer, isTrue);
      expect(_play(m, 's').servingMine, isFalse);
    });

    test('does not ask between games of a set', () {
      final m = _play(const TennisMatch(), 'S${_game(mine: true)}');
      expect(m.needsServer, isFalse);
    });

    test('asks who serves first in the tie-break', () {
      final m = _play(const TennisMatch(), _toTieBreak);
      expect(m.isTieBreak, isTrue);
      expect(m.needsServer, isTrue);
      expect(m.watchTitle, 'TB Saca? Sig=yo Ant=rival');
    });

    test('in a tie-break the first serves one point, then every two', () {
      var m = _play(const TennisMatch(), '${_toTieBreak}s');
      final servers = <bool?>[];
      for (var i = 0; i < 7; i++) {
        servers.add(m.servingMine);
        // Alternar quién gana para que el tie-break no termine.
        m = _play(m, i.isEven ? 'Y' : 'R');
      }
      // Puntos 1..7: rival, yo, yo, rival, rival, yo, yo.
      expect(servers, [false, true, true, false, false, true, true]);
    });

    test('asks who serves first in the super tie-break', () {
      final m = _play(
        const TennisMatch(superTieBreak: true),
        'S${_game(mine: true) * 6}s${_game(mine: false) * 6}',
      );
      expect(m.isSuperTieBreak, isTrue);
      expect(m.needsServer, isTrue);
      expect(m.watchTitle, 'STB Saca? Sig=yo Ant=rival');

      final started = _play(m, 'SYR');
      expect(started.servingMine, isFalse);
    });

    test('undo brings back the server question', () {
      final m = _play(const TennisMatch(), 'S').undo();
      expect(m.needsServer, isTrue);
    });

    test('records who served in the history', () {
      final m = _play(const TennisMatch(), 'sYR');
      final game = m.history.single.games.single;
      expect(game.firstServerMine, isFalse);
      expect(game.points.map((p) => p.servedByMe), [false, false]);
    });

    test('records tie-break serves point by point', () {
      final m = _play(const TennisMatch(), '${_toTieBreak}SYRY');
      final tieBreak = m.history.single.games.last;
      expect(tieBreak.kind, GameKind.tieBreak);
      expect(tieBreak.firstServerMine, isTrue);
      expect(tieBreak.points.map((p) => p.servedByMe), [true, false, false]);
    });
  });
}
