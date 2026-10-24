// Android build compatibility for published flutter_libserialport 0.6.0.
// Its sources remain in the Pub cache; the app resolves the AGP/Kotlin plugins.
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val upstreamProjectDir = extra["haloSerialPortSourceDir"] as File

android {
    namespace = "org.sigrok.flutter_libserialport"
    compileSdk = 36

    defaultConfig {
        minSdk = 21
    }

    sourceSets["main"].apply {
        java.setSrcDirs(
            listOf(
                upstreamProjectDir.resolve("src/main/java"),
                upstreamProjectDir.resolve("src/main/kotlin"),
            ),
        )
        manifest.srcFile(upstreamProjectDir.resolve("src/main/AndroidManifest.xml"))
    }
    externalNativeBuild {
        cmake {
            path = upstreamProjectDir.resolve("libserialport/CMakeLists.txt")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    lint {
        disable += "InvalidPackage"
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
