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
subprojects {
    afterEvaluate {
        if (project.name == "sentry_flutter") {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
                    apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
