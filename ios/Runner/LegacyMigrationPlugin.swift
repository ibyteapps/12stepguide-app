import Flutter
import UIKit
import UserNotifications

/// Read-only access to what the native 12 Step Guide app (1.x) left on this device
/// (FLUTTER_ARCHITECTURE.md §10.8, MIGRATION_PLAN.md). The only changes it can make are the
/// explicit `cancelLegacyNotifications` and `excludeFromBackup` calls.
final class LegacyMigrationPlugin: NSObject, FlutterPlugin {
  static let channelName = "com.ibyteapps.aa12stepguide/legacy"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(LegacyMigrationPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "readLegacyPrefs":
      result(readPrefs())
    case "pendingLegacyNotifications":
      pendingNotifications(result)
    case "cancelLegacyNotifications":
      let ids = (call.arguments as? [String: Any])?["ids"] as? [String] ?? []
      cancelNotifications(ids, result)
    case "listLegacyDownloads":
      result(listDocuments())
    case "excludeFromBackup":
      guard let path = (call.arguments as? [String: Any])?["path"] as? String else {
        result(FlutterError(code: "bad-args", message: "path missing", details: nil))
        return
      }
      excludeFromBackup(path, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// The standard UserDefaults domain, where the native app kept its unprefixed keys.
  /// System and SDK keys are skipped; dates become milliseconds since 1970.
  private func readPrefs() -> [String: Any] {
    let skipped = ["Apple", "NS", "com.apple", "AK", "PK", "INNext", "WebKit"]
    var out: [String: Any] = [:]
    for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
      if skipped.contains(where: { key.hasPrefix($0) }) { continue }
      switch value {
      case let date as Date:
        out[key] = Int64(date.timeIntervalSince1970 * 1000)
      case let string as String:
        out[key] = string
      case let number as NSNumber:
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
          out[key] = number.boolValue
        } else if CFNumberIsFloatType(number) {
          out[key] = number.doubleValue
        } else {
          out[key] = number.int64Value
        }
      default:
        continue  // data, arrays and dictionaries are not needed
      }
    }
    return out
  }

  private static func isLegacy(_ id: String) -> Bool {
    id.hasPrefix("HourNotification")
      || id == "KEY_DATA_STRING_ON_AWAKENING_NOTIFICATION_TIME"
      || id == "KEY_DATA_STRING_NIGHT_NOTIFICATION_TIME"
      || id == "3days" || id == "7days"
  }

  /// Pending requests the native app scheduled. The hour and minute come from each request's
  /// calendar trigger, never from parsing the id (MIGRATION_PLAN §6).
  private func pendingNotifications(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
      let items: [[String: Any]] = requests.filter { Self.isLegacy($0.identifier) }.map {
        var item: [String: Any] = ["id": $0.identifier]
        if let trigger = $0.trigger as? UNCalendarNotificationTrigger {
          if let hour = trigger.dateComponents.hour { item["hour"] = hour }
          if let minute = trigger.dateComponents.minute { item["minute"] = minute }
        }
        if let action = $0.content.userInfo["action"] as? String { item["action"] = action }
        return item
      }
      DispatchQueue.main.async { result(items) }
    }
  }

  /// Removes the native app's pending and delivered notifications, so users do not get every
  /// reminder twice after the update (the one deliberate change to legacy state).
  private func cancelNotifications(_ ids: [String], _ result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    let legacyIds = ids.filter(Self.isLegacy)
    center.removePendingNotificationRequests(withIdentifiers: legacyIds)
    center.getDeliveredNotifications { delivered in
      let deliveredIds = delivered.map { $0.request.identifier }.filter(Self.isLegacy)
      center.removeDeliveredNotifications(withIdentifiers: deliveredIds)
      DispatchQueue.main.async { result(nil) }
    }
  }

  /// Files in Documents, where the native app saved downloaded recordings by file name.
  private func listDocuments() -> [[String: Any]] {
    let fm = FileManager.default
    guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first,
      let names = try? fm.contentsOfDirectory(atPath: docs.path)
    else { return [] }
    var out: [[String: Any]] = []
    for name in names {
      let url = docs.appendingPathComponent(name)
      guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
        values.isRegularFile == true
      else { continue }
      out.append(["name": name, "bytes": values.fileSize ?? 0, "path": url.path])
    }
    return out
  }

  /// Downloaded recordings can be downloaded again, so they are kept out of iCloud backups.
  private func excludeFromBackup(_ path: String, _ result: @escaping FlutterResult) {
    var url = URL(fileURLWithPath: path)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    do {
      try url.setResourceValues(values)
      result(nil)
    } catch {
      result(FlutterError(code: "exclude-failed", message: error.localizedDescription, details: nil))
    }
  }
}
