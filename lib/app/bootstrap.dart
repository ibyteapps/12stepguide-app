import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import 'app.dart';

/// Starts the app. Later phases add, in order: error handlers, Firebase, the legacy
/// migration, consent and the provider scope (FLUTTER_ARCHITECTURE.md §4, `bootstrap.dart`).
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppConfig config;
  try {
    config = AppConfig.fromBuild();
  } on ConfigException catch (error) {
    // A misbuilt binary says why on screen instead of running with the wrong ids or ads.
    runApp(ConfigErrorApp(message: error.message));
    return;
  }

  runApp(TwelveStepGuideApp(config: config));
}
