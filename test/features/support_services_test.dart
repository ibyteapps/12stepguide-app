// P6: review prompt cadence (A-26), crash-report redaction (FLUTTER_ARCHITECTURE §10.6).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';
import 'package:twelve_step_guide/core/telemetry/telemetry.dart';
import 'package:twelve_step_guide/features/support/review_prompt.dart';

import '../helpers/test_app.dart';

void main() {
  group('review prompt cadence (A-26)', () {
    test('launch 7, 15 and 30, once each', () {
      final store = MemoryStore();
      final asks = [
        for (var launch = 1; launch <= 40; launch++)
          if (ReviewCadence.shouldAsk(launchCount: launch, store: store)) launch,
      ];
      expect(asks, [7, 15, 30]);
    });

    test('never for someone who rated (Android, m006), and at most three times', () {
      expect(
        ReviewCadence.shouldAsk(launchCount: 7, store: MemoryStore({PrefKeys.reviewRated: true})),
        isFalse,
      );
      expect(
        ReviewCadence.shouldAsk(
          launchCount: 15,
          store: MemoryStore({PrefKeys.reviewPromptCount: 3}),
        ),
        isFalse,
      );
    });

    testWidgets('asked a few seconds after the app opens on launch 7, then remembered', (
      tester,
    ) async {
      var requests = 0;
      final app = await pumpApp(
        tester,
        launchCount: 7,
        overrides: [reviewRequesterProvider.overrideWithValue(() async => requests++)],
      );
      expect(requests, 0);
      await tester.pump(const Duration(seconds: 5));
      expect(requests, 1);
      expect(app.store.getStringList(PrefKeys.reviewPromptedAtLaunches), ['7']);
      expect(app.store.getInt(PrefKeys.reviewPromptCount), 1);
    });
  });

  group('crash reports carry no personal data', () {
    test('emails and dates are removed from error text', () {
      final e = RedactedError(
        FormatException('bad date 2019-03-14 for someone@example.com, also 14/03/2019'),
      );
      expect(e.toString(), isNot(contains('2019-03-14')));
      expect(e.toString(), isNot(contains('someone@example.com')));
      expect(e.toString(), isNot(contains('14/03/2019')));
      expect(e.toString(), startsWith('FormatException'));
    });
  });

  test('the providers used by the review prompt resolve', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(reviewRequesterProvider), isA<Future<void> Function()>());
  });
}
