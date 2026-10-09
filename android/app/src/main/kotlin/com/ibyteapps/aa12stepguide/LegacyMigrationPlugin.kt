package com.ibyteapps.aa12stepguide

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Read-only access to what the native 12 Step Guide app (0.2.x) left on this device
 * (FLUTTER_ARCHITECTURE.md §10.8, MIGRATION_PLAN.md §4.2).
 *
 * The native app kept everything in the default SharedPreferences file,
 * `com.ibyteapps.aa12stepguide_preferences.xml`. It is only read: SharedPreferences writes a file
 * only on commit/apply, and this class never edits it. The iOS-only methods return empty results.
 */
class LegacyMigrationPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.ibyteapps.aa12stepguide/legacy"

        /** The native app's preference file. Fixed: it belongs to the store package name. */
        const val LEGACY_PREFS = "com.ibyteapps.aa12stepguide_preferences"

        fun register(engine: FlutterEngine, context: Context) {
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler(LegacyMigrationPlugin(context.applicationContext))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readLegacyPrefs" -> result.success(readPrefs())
            "pendingLegacyNotifications", "listLegacyDownloads" -> result.success(emptyList<Any>())
            "cancelLegacyNotifications", "excludeFromBackup" -> result.success(null)
            else -> result.notImplemented()
        }
    }

    private fun readPrefs(): Map<String, Any> {
        val prefs = context.getSharedPreferences(LEGACY_PREFS, Context.MODE_PRIVATE)
        val out = HashMap<String, Any>()
        for ((key, value) in prefs.all) {
            when (value) {
                is Boolean, is Int, is Long, is String -> out[key] = value
                is Float -> out[key] = value.toDouble()
                else -> Unit // string sets are not used by the native app's migrated keys
            }
        }
        return out
    }
}
