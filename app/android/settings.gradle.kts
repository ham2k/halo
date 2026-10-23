pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")

// flutter_libserialport 0.6.0 still references jcenter(), removed by Gradle 9.
// Use a local build definition but preserve the published sources, including
// when the checkout and Pub cache are on different Windows drives.
val serialPortProject = project(":flutter_libserialport")
val serialPortSourceDir = serialPortProject.projectDir
serialPortProject.projectDir = file("compat/flutter_libserialport")
gradle.beforeProject {
    if (path == ":flutter_libserialport") {
        extra["haloSerialPortSourceDir"] = serialPortSourceDir
    }
}
