package com.ibyteapps.aa12stepguide

import android.content.Intent
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The one Flutter activity.
 *
 * It is called `First` on purpose. The native app's launcher activity was
 * `com.ibyteapps.aa12stepguide.First`, and launchers store that component name for every
 * home-screen icon. If an update removes it, some launchers delete the user's icon. Keeping
 * the name means the icon survives the upgrade to 2.0 (MIGRATION_PLAN.md §2).
 *
 * Do not rename this class or its manifest entry.
 *
 * It extends audio_service's activity so the media service and the UI share one Flutter engine.
 */
class First : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LegacyMigrationPlugin.register(flutterEngine, this)
        // "Open settings" on the Reminders page when notifications are blocked.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> {
                        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        try {
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("unavailable", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val SYSTEM_CHANNEL = "com.ibyteapps.aa12stepguide/system"
    }
}
