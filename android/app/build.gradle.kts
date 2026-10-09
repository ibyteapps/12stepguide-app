import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. android/key.properties is gitignored and lives only on the owner's Mac (and,
// later, in CI as encrypted secrets). Without it, release builds are signed with the debug key so
// `flutter run --release` still works; Google Play rejects a debug-signed bundle, so such a build
// cannot reach the store by accident.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.ibyteapps.aa12stepguide"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // MUST NOT CHANGE: the applicationId of the published Play listing
        // (FLUTTER_ARCHITECTURE.md §0). A different id is a different app: users would lose
        // their recovery date, settings, donations and downloads.
        applicationId = "com.ibyteapps.aa12stepguide"
        // Flutter's floor. The native app supported API 23; MIGRATION_PLAN.md §8 (A-16).
        minSdk = 24
        // Play requires API 36 for updates from 31 Aug 2026. Set explicitly so a Flutter upgrade
        // cannot change it silently.
        targetSdk = 36
        // From pubspec.yaml (2.0.0+100). The native app shipped versionCode 29, so 100 replaces it.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Environments (FLUTTER_ARCHITECTURE.md §9). Each flavour pairs with config/<flavour>.json:
    //   flutter run --flavor dev --dart-define-from-file=config/dev.json
    // The app refuses to start if the two disagree (lib/core/config/app_config.dart).
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            // Installs beside the store app, so development never touches real user data.
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "12SG Dev"
        }
        create("staging") {
            dimension = "env"
            // Production id, so it upgrades over the store app like the real release will.
            // Test ads and analytics off (config/staging.json). Never promoted to production.
            manifestPlaceholders["appLabel"] = "12SG Staging"
        }
        create("prod") {
            dimension = "env"
            // Today's Play name. Whether it becomes "12 Step Guide" is decision A-02.
            manifestPlaceholders["appLabel"] = "12 Step Guide - AA"
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("upload") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("upload")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
