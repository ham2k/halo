# Vendored `flutter_inappwebview_macos` 1.2.0-beta.3, one line changed

This is a copy of upstream's package. Every file it carries is byte-identical
to the published one except `Package.swift`:

```diff
     platforms: [
-        .macOS("10.14"),
+        .macOS("10.15"),
     ],
```

Upstream's `example/` is the one thing left out — a whole Flutter app with
an Xcode project and app icons, none of which any build here reads. Only
`lib/`, `macos/`, `pubspec.yaml` and `LICENSE` are consumed by the
`dependency_overrides` entries that point here. `build.yaml`'s
`example/**.dart` exclude is upstream's and stays as-is; with nothing to
match it does nothing.

`dependency_overrides` bind only in the package resolved as root, so this
directory is named twice: once in `app/pubspec.yaml` and once in
`app_dist/pubspec.yaml`. Every instruction below that touches an override
applies to both files, and the two blocks are asserted identical by
`app_dist/test/webview_override_parity_test.dart`.

## Why

`WebAuthenticationSession.swift` conforms to
`ASWebAuthenticationPresentationContextProviding`, and its witness is
annotated `@available(macOS 10.15, *)`:

```swift
@available(macOS 10.15, *)
public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor
```

Swift requires a protocol witness to be available at the minimum the
conformance is declared for. Upstream's manifest declares 10.14, so the
package does not compile:

> error: protocol 'ASWebAuthenticationPresentationContextProviding' requires
> 'presentationAnchor(for:)' to be available in macOS 10.14 and newer

This never bit under CocoaPods — Flutter's podhelper raises every pod's
`MACOSX_DEPLOYMENT_TARGET` to the app's (10.15). Swift Package Manager
honours the package's own declaration and an app cannot raise it, so the
bug only appears once the plugin is consumed via SPM, which 1.2.0-beta.3 is
the first version to offer. iOS is unaffected: there the same witness is
annotated `@available(iOS 12.0, *)`, matching its declared `.iOS("12.0")`.

## Verifying this copy

Everything except the line above must match the published package. Diff
against a freshly extracted archive, **never against `~/.pub-cache`**: a
`flutter build macos` writes `.swiftpm/` and other residue into the cached
copy as well as into this one, so contamination that exists on both sides
cancels out and the check that is supposed to prove this copy clean reports
nothing. Run from the repo root:

```sh
upstream=$(mktemp -d)
curl -sSL https://pub.dev/api/archives/flutter_inappwebview_macos-1.2.0-beta.3.tar.gz \
  | tar xz -C "$upstream"
diff -r -x example -x PATCH.md \
     "$upstream" packages/flutter_inappwebview_macos_patched
```

(The archive unpacks the package's contents at the top level, so `$upstream`
is the package root.)

A clean run prints the `Package.swift` header line and exactly this hunk:

```
9c9
<         .macOS("10.14"),
---
>         .macOS("10.15"),
```

Every other line is a finding. `Only in packages/…: .swiftpm` is the residue
above showing through as intended — delete it and re-run.

## Re-vendoring a newer version

Copy the new package over this directory, drop its `example/`, re-apply the
one-line change if upstream still has it, update the version above and in
the archive URL, and re-run the diff. Do not hand-merge — this directory is
a copy, not a maintained fork.

`app/test/platform/webview_plugin_overrides_test.dart` asserts the `.macOS("10.15")`
line is present in this copy's `Package.swift`, so a re-vendor that forgets
to re-apply it fails the Dart suite rather than a tag-triggered macOS
release. That line is the only part of this patch a Dart test can see.

**If the clock-discipline check fails on a file in here, do not fix the
file.** `./scripts/test.sh` scans every `packages/*/lib` for direct
`DateTime.now()` reads and prints advice — rewrite it against `halo_core`, or
annotate the line `// clock:allow` — that is written for first-party code.
Both routes mean editing a copy whose entire value is being byte-identical to
what pub.dev published, and nothing fails when that happens: the diff above is
a command someone has to choose to run, and the next re-vendor silently
reverts the edit anyway. The fix is a narrow exemption in
`check_clock_discipline`, naming this package. Spell it out as a list there —
never key it on something a package carries, such as the presence of this
file, which would take every present and future vendored package out of the
guard as a side effect of documenting itself, with no per-package edit for a
reviewer to object to.

**Move the whole family together.** This copy is frozen against
`flutter_inappwebview_platform_interface` 1.4.0-beta.3, which is why
`app/pubspec.yaml` and `app_dist/pubspec.yaml` pin the interface and the
other implementations exactly rather than letting the umbrella's carets
float them. Bump this directory without bumping those pins (or the reverse)
and the build fails in the kernel snapshot on an interface member this copy
still references — after `flutter analyze` and the entire Dart suite pass
green. **Nothing in `./scripts/test.sh` compiles Swift**, so beyond that one
asserted line, a re-vendor is verified only by running `flutter build macos`
yourself. Those pins sit inside the two `dependency_overrides` blocks, so
raising them in one root only is the one half of a bump the parity test does
catch.

## Deleting this

Drop the directory as soon as an upstream release declares `.macOS("10.15")`
or later — along with **both** `flutter_inappwebview_macos` override
entries, the one in `app/pubspec.yaml` and the one in
`app_dist/pubspec.yaml`. A root whose entry is left behind keeps a `path:`
aimed at a directory that no longer exists, and the next `flutter pub get`
rooted there fails to resolve; `./scripts/test.sh` runs one in each root, so
the merge gate is where that surfaces.

While the directory is still present, a half-done deletion resolves fine and
instead turns `app_dist/test/webview_override_parity_test.dart` red, naming
the entry that only one side still carries. That test is the guard against
this, not a separate problem — the fix is to finish the removal in the other
root.

Upstream has not committed since 2026-02-10, so treat that as a thing to
check rather than a thing to wait for.
