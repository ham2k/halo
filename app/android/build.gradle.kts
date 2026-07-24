allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// sentry_flutter 8.14.2's Android module pins Kotlin `languageVersion = "1.6"`
// (its kotlinOptions), which the Kotlin 2.3 compiler in the current Flutter
// toolchain has dropped — "Language version 1.6 is no longer supported; use
// version 2.0 or greater instead" — failing :sentry_flutter:compileReleaseKotlin.
// Raise just that module to the lowest still-supported version (2.0 is backward
// compatible with the plugin's 1.6-era source). Same root cause as the macOS
// sentry-cocoa pin: the old sentry_flutter lags the toolchain. Remove if
// sentry_flutter is bumped to a version built against current Kotlin.
//
// The override must run AFTER the plugin set 1.6, i.e. after the subproject is
// evaluated — but `evaluationDependsOn(":app")` above forces some subprojects to
// evaluate early, and calling `afterEvaluate` on an already-evaluated project
// throws ("project is already evaluated"). So branch on `state.executed`: if the
// project is already evaluated, reconfigure its (existing) Kotlin tasks now
// (`configureEach` runs immediately on them); otherwise defer with afterEvaluate.
// Either way `configureEach` lands after the plugin's 1.6 and wins.
subprojects {
    if (project.name == "sentry_flutter") {
        if (state.executed) {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
                    apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
                }
            }
        } else {
            afterEvaluate {
                tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                    compilerOptions {
                        languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
                        apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
                    }
                }
            }
        }
    }
}

// flutter_plugin_android_lifecycle now requires everything that depends on it to
// compile against Android API 36, but some plugins (mapbox_maps_flutter 2.25.1)
// hardcode compileSdk 35, failing :mapbox_maps_flutter:checkReleaseAarMetadata.
// Force every Android module (the app + plugins) to compileSdk 36. Compiling
// against a newer SDK is safe and independent of targetSdk/minSdk. Same
// state.executed dance as the Kotlin override above — evaluationDependsOn(":app")
// evaluates some subprojects early, so a plain afterEvaluate would throw.
subprojects {
    if (state.executed) {
        when (val android = extensions.findByName("android")) {
            is com.android.build.api.dsl.LibraryExtension ->
                if ((android.compileSdk ?: 0) < 36) android.compileSdk = 36
            is com.android.build.api.dsl.ApplicationExtension ->
                if ((android.compileSdk ?: 0) < 36) android.compileSdk = 36
        }
    } else {
        afterEvaluate {
            when (val android = extensions.findByName("android")) {
                is com.android.build.api.dsl.LibraryExtension ->
                    if ((android.compileSdk ?: 0) < 36) android.compileSdk = 36
                is com.android.build.api.dsl.ApplicationExtension ->
                    if ((android.compileSdk ?: 0) < 36) android.compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
