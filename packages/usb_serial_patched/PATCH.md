# Vendored `usb_serial` 0.5.2, one Gradle file changed

This is a copy of upstream's package. Every file it carries is
byte-identical to the published one except `android/build.gradle`.

```diff
 buildscript {
     repositories {
         google()
-        jcenter()
+        mavenCentral()
     }

     dependencies {
-        classpath 'com.android.tools.build:gradle:4.1.0'
+        classpath 'com.android.tools.build:gradle:9.0.1'
     }
 }

-apply plugin: 'com.android.library'
+plugins {
+    id 'com.android.library'
+}

 rootProject.allprojects {
     repositories {
         google()
-        jcenter()
+        mavenCentral()
         maven { url "https://jitpack.io" }
     }
-
-    gradle.projectsEvaluated {
-        tasks.withType(JavaCompile) {
-            options.compilerArgs << "-Xlint:unchecked" << "-Xlint:deprecation"
-        }
-    }
-
 }
```

Upstream's `example/` is left out, same as the other vendored copies in
this directory — a whole Flutter app nothing here reads.

`dependency_overrides` binds only in the package resolved as root, so
`app/pubspec.yaml`'s override entry is the only one that matters — nothing
under `app_dist/` depends on `usb_serial`.

## Why

Upstream's `android/build.gradle` applies AGP with the legacy
`apply plugin: 'com.android.library'` statement. Under this app's AGP 9
(`app/android/settings.gradle.kts` pins `com.android.application` 9.0.1),
Gradle fails to associate that legacy `apply` with `com.android.library`
before the root project's Flutter tooling applies `kotlin-android` to every
subproject, so `kotlin-android` finds no Android plugin already applied:

```
> Failed to notify project evaluation listener.
   > java.lang.NullPointerException (no error message)
   > 'kotlin-android' plugin requires one of the Android Gradle plugins.
```

Switching to the `plugins { id 'com.android.library' }` block form (the
same form current, maintained Flutter plugins use, e.g.
`url_launcher_android`) resolves against the module's own `buildscript`
classpath and applies the plugin before `kotlin-android` sees the project.
`jcenter()` is dropped in the same edit — it has been shut down and was
only ever reachable as a fallback behind `google()`/`mavenCentral()` for
this dependency set anyway.

The `gradle.projectsEvaluated` block that added `-Xlint` compiler args to
every project's `JavaCompile` tasks is dropped: it did the same
`rootProject.allprojects` reach used for the repositories block, is
lint-only (no behavior change), and existing lint config elsewhere in this
build already covers Java compilation.

## Verifying this copy

Everything except the `android/build.gradle` hunk above must match the
published package. Diff against a freshly extracted archive, **never
against `~/.pub-cache`** — a build writes generated files into the cached
copy too. Run from the repo root:

```sh
upstream=$(mktemp -d)
curl -sSL https://pub.dev/api/archives/usb_serial-0.5.2.tar.gz \
  | tar xz -C "$upstream"
diff -r -x example -x build -x '*.iml' -x PATCH.md \
     "$upstream" packages/usb_serial_patched
```

A clean run prints only the `android/build.gradle` hunk above. `-x build`
and `-x '*.iml'` drop incidental files pub.dev bundles into the published
tarball (a stale analysis cache, an IDE project file) that this vendored
copy never carried in the first place — same reason `example` is excluded.

## Re-vendoring a newer version

Copy the new package over this directory, drop its `example/`, re-apply
the `android/build.gradle` change if upstream hasn't fixed the same thing
itself (check the file first — a version bump alone proves nothing), and
re-run the diff. Do not hand-merge — this directory is a copy, not a
maintained fork.

## Deleting this

Drop the directory once upstream ships an AGP-9-compatible
`android/build.gradle` — along with the `usb_serial` override entry in
`app/pubspec.yaml`.
