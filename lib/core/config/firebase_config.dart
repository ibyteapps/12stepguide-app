import 'package:firebase_core/firebase_core.dart';

/// Firebase options from `config/<env>.json` (FLUTTER_ARCHITECTURE §10.6). They are public
/// identifiers, but the owner keeps Firebase files out of git (Q-T1), so they arrive like the
/// other build values. Without them the app runs with analytics and crash reporting off.
abstract final class FirebaseConfig {
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _bucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _androidKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const _androidApp = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const _iosApp = String.fromEnvironment('FIREBASE_IOS_APP_ID');

  /// Null when this build has no Firebase values for the platform.
  static FirebaseOptions? forPlatform({required bool isIOS}) {
    final key = isIOS ? _iosKey : _androidKey;
    final app = isIOS ? _iosApp : _androidApp;
    if (_projectId.isEmpty || _senderId.isEmpty || key.isEmpty || app.isEmpty) return null;
    return FirebaseOptions(
      apiKey: key,
      appId: app,
      messagingSenderId: _senderId,
      projectId: _projectId,
      storageBucket: _bucket.isEmpty ? null : _bucket,
    );
  }
}
