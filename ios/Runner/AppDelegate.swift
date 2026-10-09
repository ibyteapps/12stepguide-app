import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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
