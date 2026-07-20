import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by a gitignored android/key.properties
// (storeFile, storePassword, keyAlias, keyPassword) — created locally per
// developer or by CI from secrets. When absent, release falls back to the
// debug key so `flutter run --release` and unsigned local builds still work.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.ham2k.logger"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ham2k.logger"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Fallback for tooling that resolves the merged manifest without a
        // flavor selected; every real build picks one of the flavors below.
        manifestPlaceholders["appLabel"] = "Portable Logger"
    }

    // Build editions (docs/releases.md §2.6), the Android counterpart of the
    // macOS/iOS HALO_EDITION seam: dev / next / prod install side by side via
    // the applicationId suffix, each with its own launcher icon (per-flavor
    // src/<edition>/res/mipmap-*) and home-screen label. Build with e.g.
    // `flutter build apk --flavor next --dart-define=HALO_EDITION=next` — the
    // --flavor keeps Gradle in step with the Dart-side kEdition.
    flavorDimensions += "edition"
    productFlavors {
        create("dev") {
            dimension = "edition"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "Portable Logger (Dev)"
        }
        create("next") {
            dimension = "edition"
            applicationIdSuffix = ".next"
            manifestPlaceholders["appLabel"] = "Portable Logger Next"
        }
        create("prod") {
            dimension = "edition"
            applicationIdSuffix = ".prod"
            manifestPlaceholders["appLabel"] = "Portable Logger"
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Sign with the release key when key.properties is present
            // (CI / configured devs); otherwise fall back to the debug key.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
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
