import 'package:flutter_test/flutter_test.dart';
import 'package:tennis_score_poc/tap_detector.dart';

void main() {
  group(TapDetector, () {
    late List<String> calls;
    late TapDetector taps;

    setUp(() {
      calls = [];
      taps = TapDetector(
        onSingle: () => calls.add('single'),
        onDouble: () => calls.add('double'),
      );
      addTearDown(taps.dispose);
    });

    // testWidgets corre con tiempo simulado: pump avanza los timers.
    testWidgets('one tap counts as single after the window', (tester) async {
      taps.tap();
      await tester.pump(const Duration(milliseconds: 499));
      expect(calls, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls, ['single']);
    });

    testWidgets('two taps within 500 ms count as one double tap', (
      tester,
    ) async {
      taps.tap();
      await tester.pump(const Duration(milliseconds: 300));
      taps.tap();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, ['double']);
    });

    testWidgets('two taps more than 500 ms apart are two singles', (
      tester,
    ) async {
      taps.tap();
      await tester.pump(const Duration(milliseconds: 600));
      taps.tap();
      await tester.pump(const Duration(milliseconds: 600));
      expect(calls, ['single', 'single']);
    });

    testWidgets('three quick taps are a double tap and then a single', (
      tester,
    ) async {
      taps
        ..tap()
        ..tap()
        ..tap();
      await tester.pump(const Duration(milliseconds: 600));
      expect(calls, ['double', 'single']);
    });
  });
}
