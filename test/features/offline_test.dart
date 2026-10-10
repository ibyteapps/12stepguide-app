import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/core/links/links.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

/// F-112 and UNIFIED_PRODUCT_SPEC §6 "No network": links and prices say the device is offline
/// rather than opening a blank page or loading for ever.
void main() {
  const prefs = {PrefKeys.coachMarkSeen: true};

  testWidgets('offline, Daily Reflections says so and opens nothing', (tester) async {
    final app = await pumpApp(tester, location: '/readings', online: false, prefs: prefs);
    await tester.tap(find.text('Daily Reflections'));
    await tester.pump();
    expect(find.text(OfflineAwareLinkOpener.message), findsOneWidget);
    expect(app.links.opened, isEmpty);
  });

  testWidgets('online, Daily Reflections opens', (tester) async {
    final app = await pumpApp(tester, location: '/readings', prefs: prefs);
    await tester.tap(find.text('Daily Reflections'));
    await tester.pump();
    expect(find.text(OfflineAwareLinkOpener.message), findsNothing);
    expect(app.links.opened, [AppLinks.dailyReflections]);
  });

  testWidgets('offline, a drawer link says so too', (tester) async {
    final app = await pumpApp(tester, online: false, prefs: prefs);
    await openDrawer(tester);
    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy policy'));
    await tester.pump();
    expect(find.text(OfflineAwareLinkOpener.message), findsOneWidget);
    expect(app.links.opened, isEmpty);
  });

  testWidgets('offline, mail still hands over to the mail app', (tester) async {
    final opened = <String>[];
    final links = OfflineAwareLinkOpener(
      inner: FakeLinkOpener(),
      isOffline: () => true,
      onOffline: () => opened.add('offline'),
    );
    expect(await links.email(to: AppLinks.supportEmail, subject: 's', body: 'b'), isTrue);
    expect(await links.open(AppLinks.terms), isFalse);
    expect(opened, ['offline']);
  });

  testWidgets('offline, the paywall asks for a connection instead of prices', (tester) async {
    await pumpApp(
      tester,
      location: '/paywall',
      online: false,
      purchases: FakePurchaseGateway(available: false),
      prefs: prefs,
    );
    await tester.pumpAndSettle();
    expect(find.text('Connect to the internet to see prices.'), findsOneWidget);
    expect(find.text("Purchases aren't available right now. Try again later."), findsNothing);
  });

  testWidgets('online with the store down, the paywall says purchases are unavailable', (
    tester,
  ) async {
    await pumpApp(
      tester,
      location: '/paywall',
      purchases: FakePurchaseGateway(available: false),
      prefs: prefs,
    );
    await tester.pumpAndSettle();
    expect(find.text("Purchases aren't available right now. Try again later."), findsOneWidget);
  });
}
