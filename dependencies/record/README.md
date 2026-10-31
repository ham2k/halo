# Recorder dependencies

The KX3 panadapter needs native validation of the selected stereo input and
sample rate. The published recorder backends do not provide all of those
guarantees. HaLo keeps the required patches and authored capture sources here;
upstream package sources are downloaded during build preparation and stay out
of Git. Installed applications never download source code.

`UPSTREAM.json` pins each pub.dev archive by version and SHA-256, lists the
patch and authored overlay, and records the hash of every resulting source
file. Five small, authored package manifests and a forwarding Android plugin
entry point are tracked under `packages/record_*_patched/`; the manifest's
`scaffolds` lists identify these inputs. They let Flutter discover the plugins
before their upstream sources are downloaded, with the same package metadata
before and after preparation.

The preparation tool verifies the archive, applies the patch, adds the overlay
and scaffolds, and verifies the complete source inventory before publishing
each generated package. Downloaded source text is normalized to LF so Windows
and Unix hosts produce the same tree. Scaffold hashes also use LF, while their
checkout bytes are preserved. Upstream MIT licenses remain in the generated
packages; authored sources retain their MPL-2.0 headers.

## Preparing a checkout

Normal setup, run, deployment, and test tasks prepare these packages before
resolving the app. To prepare them directly:

```sh
mise run prepare-record
```

The equivalent command works from a shell with the Flutter SDK's `dart` on
PATH, including PowerShell:

```sh
cd packages/halo_build_tools
dart run bin/prepare_record.dart
```

Plain `flutter pub get` works from a fresh checkout using the tracked scaffolds.
Normal `flutter build windows` and `flutter run -d windows` prepare the full
packages automatically during CMake configuration, before native plugin or
Dart compilation. Windows CI does not need a separate preparation step.

Use preparation before an IDE analyzes the app, or before plain test and build
commands for other platforms. The repository's setup, run, deployment, and test
entry points already do this. Flutter discovers plugins before its Dart build
hooks run, so a hook inside a missing package cannot install that package.
Preparation completes all five packages, even for web builds, although browser
capture does not use their native implementations.

Verified archives are cached outside the checkout. `HALO_RECORD_CACHE` selects
an explicit cache directory. Each checkout gets its own generated package
copies so native build tools cannot modify another checkout's sources. Valid
source trees are reused without discarding build outputs. Missing or modified
generated sources are reconstructed from the pinned inputs.
Missing or edited tracked scaffolds are refused before downloading or replacing
sources. Preserve any intended edits and restore the tracked file, or update its
hash in `UPSTREAM.json` together with the change. Preparation also checks for
scaffold edits made while a download or patch operation is in progress.

For an offline build, first resolve `halo_build_tools` dependencies and run
`dart run bin/prepare_record.dart --prefetch` while online. Later,
`dart run bin/prepare_record.dart --offline` prepares from the verified archive
cache without downloading recorder sources. Normal Flutter dependency and
engine caches are still required for an entirely offline build.

## Updating a backend

1. Select the new published version and verify its archive SHA-256.
2. Review the upstream changes against the package-specific notes below.
3. Update the focused patch, authored overlay, and tracked package scaffolds,
   then the expected source hashes in `UPSTREAM.json`. Do not edit generated
   upstream files as the final fix.
4. Prepare from a cold cache, run `./scripts/test.sh`, and verify the affected
   native build and stereo hardware capture. Remove a patch when upstream
   provides the same capture guarantees.

The five package notes describe the maintained changes and hardware limits:
[Android](record_android.md), [iOS](record_ios.md),
[Linux](record_linux.md), [macOS](record_macos.md),
and [Windows](record_windows.md).

Other platform release and code-push tooling must run preparation before
compilation. Treat changes under `dependencies/record/` and to the tracked
scaffolds as native dependency changes requiring a rebuilt application.
