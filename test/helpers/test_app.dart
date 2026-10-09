import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/app/app.dart';
import 'package:twelve_step_guide/app/providers.dart';
import 'package:twelve_step_guide/app/router.dart';
import 'package:twelve_step_guide/core/config/app_config.dart';
import 'package:twelve_step_guide/core/config/app_env.dart';
import 'package:twelve_step_guide/core/links/links.dart';
import 'package:twelve_step_guide/core/prefs/key_value_store.dart';
import 'package:twelve_step_guide/features/audio/domain/catalogue.dart';
import 'package:twelve_step_guide/features/content/domain/content_index.dart';
import 'package:twelve_step_guide/features/shell/shell_scaffold_key.dart';
import 'package:twelve_step_guide/features/sobriety/cheer.dart';

final testIndex = ContentIndex.fromJsonString(File('assets/content_index.json').readAsStringSync());
final testCatalogue = Catalogue.fromJsonString(
  File('assets/audio/catalogue.json').readAsStringSync(),
);
final testQuotes = File('assets/quotes.txt')
    .readAsLinesSync()
    .where((l) => l.trim().isNotEmpty)
    .toList();

/// A fixed "now" for tests: 9 October 2026, 10:00.
final testNow = DateTime(2026, 10, 9, 10);

class FakeLinkOpener implements LinkOpener {
  final opened = <String>[];
  final emails = <({String to, String subject, String body})>[];
  bool succeed = true;

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return succeed;
  }

  @override
  Future<bool> email({required String to, required String subject, required String body}) async {
    emails.add((to: to, subject: subject, body: body));
    return succeed;
  }
}

class FakeCheer implements CheerPlayer {
  int plays = 0;
  @override
  Future<void> play() async => plays++;
}

const phone = Size(390, 844);

/// Wraps the app, so screenshot tests can capture the whole screen.
const appBoundaryKey = ValueKey('app-boundary');
const tablet = Size(1024, 1366);

/// Pumps the whole app at [location] with in-memory storage and fakes.
Future<({MemoryStore store, FakeLinkOpener links, ProviderContainer container})> pumpApp(
  WidgetTester tester, {
  String location = '/steps',
  Map<String, Object>? prefs,
  AppEnv env = AppEnv.prod,
  Size size = phone,
  double ratio = 3,
  double textScale = 1,
  ThemeMode? themeMode,
  List<Override> overrides = const [],
  DateTime? now,
}) async {
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final store = MemoryStore({
    PrefKeys.onboardingDone: true,
    if (themeMode != null) PrefKeys.themeMode: themeMode.name,
    ...?prefs,
  });
  final links = FakeLinkOpener();
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(AppConfig(env: env)),
      kvStoreProvider.overrideWithValue(store),
      contentIndexProvider.overrideWithValue(testIndex),
      catalogueProvider.overrideWithValue(testCatalogue),
      quotesProvider.overrideWithValue(testQuotes),
      linkOpenerProvider.overrideWithValue(links),
      clockProvider.overrideWithValue(() => now ?? testNow),
      cheerPlayerProvider.overrideWithValue(FakeCheer()),
      launchInfoProvider.overrideWithValue(
        const LaunchInfo(
          launchCount: 5,
          isFirstLaunch: false,
          isUpgrade: false,
          version: '2.0.0',
          buildNumber: '100',
        ),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: appBoundaryKey,
      child: UncontrolledProviderScope(
        container: container,
        child: TwelveStepGuideApp(router: router),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (store: store, links: links, container: container);
}

/// Opens the drawer from anywhere in the shell.
Future<void> openDrawer(WidgetTester tester) async {
  shellScaffoldKey.currentState!.openDrawer();
  await tester.pumpAndSettle();
}
