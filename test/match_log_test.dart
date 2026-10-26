import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tennis_score_poc/match_history.dart';
import 'package:tennis_score_poc/match_log.dart';
import 'package:tennis_score_poc/tennis_match.dart';

const _sYRY = [
  MatchEvent.iServe,
  MatchEvent.myPoint,
  MatchEvent.rivalPoint,
  MatchEvent.myPoint,
];

MatchRecord _makeRecord({
  int startedAtMs = 1000,
  List<MatchEvent> events = _sYRY,
  bool goldenPoint = false,
}) => MatchRecord(
  startedAt: DateTime.fromMillisecondsSinceEpoch(startedAtMs),
  goldenPoint: goldenPoint,
  superTieBreak: true,
  events: events,
);

void main() {
  group(MatchRecord, () {
    test('survives a JSON round trip', () {
      final record = _makeRecord(goldenPoint: true);
      final copy = MatchRecord.fromJson(record.toJson());
      expect(copy.id, record.id);
      expect(copy.goldenPoint, isTrue);
      expect(copy.superTieBreak, isTrue);
      expect(copy.events, _sYRY);
    });

    test('stores events as one letter each', () {
      const events = [...MatchEvent.values];
      expect(_makeRecord(events: events).toJson()['events'], 'YRSs2WE');
    });

    test('rebuilds the match, including who serves', () {
      final match = const TennisMatch()
          .chooseServer(mine: false)
          .pointForMe()
          .pointForRival();
      final copy = MatchRecord.fromMatch(match, DateTime(2026)).match;
      expect(copy.pointsLabel, '15-15');
      expect(copy.servingMine, isFalse);
    });
  });

  group(MatchLog, () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('saves, updates by id and keeps the newest first', () async {
      final log = MatchLog(prefs);
      await log.save(_makeRecord(startedAtMs: 1000));
      await log.save(_makeRecord(startedAtMs: 2000));
      await log.save(
        _makeRecord(startedAtMs: 1000, events: [MatchEvent.rivalPoint]),
      );

      expect(log.records.value.map((r) => r.id), [2000, 1000]);
      expect(log.records.value.last.events, [MatchEvent.rivalPoint]);
    });

    test('loads what was saved before', () async {
      await MatchLog(prefs).save(_makeRecord());
      expect(MatchLog(prefs).records.value.single.events, _sYRY);
    });

    test('does not keep a match without points', () async {
      final log = MatchLog(prefs);
      await log.save(_makeRecord());
      // Deshacer hasta quedar solo con la elección de saque.
      await log.save(_makeRecord(events: [MatchEvent.iServe]));
      expect(log.records.value, isEmpty);
    });

    test('deletes a match', () async {
      final log = MatchLog(prefs);
      final record = _makeRecord();
      await log.save(record);
      await log.delete(record);
      expect(MatchLog(prefs).records.value, isEmpty);
    });
  });
}
