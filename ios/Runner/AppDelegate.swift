import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Reminders shown while the app is open, and taps on them, reach flutter_local_notifications.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Reads what the native 1.x app left on the device (MIGRATION_PLAN.md).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LegacyMigrationPlugin") {
      LegacyMigrationPlugin.register(with: registrar)
    }
  }
}
