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

// flutter_plugin_android_lifecycle now requires everything that depends on it to
// compile against Android API 36, but some plugins (mapbox_maps_flutter 2.25.1)
// hardcode compileSdk 35, failing :mapbox_maps_flutter:checkReleaseAarMetadata.
// Force every Android module (the app + plugins) to compileSdk 36. Compiling
// against a newer SDK is safe and independent of targetSdk/minSdk. Branch on
// state.executed because evaluationDependsOn(":app") above evaluates some
// subprojects early, and a plain afterEvaluate on an already-evaluated project
// throws — reconfigure directly if it's evaluated, else defer with afterEvaluate.
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
