// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The public-facing version — see docs/releases.md §2.1 and §2.3. This lives
// in compiled Dart (not package_info_plus/native metadata) so a Shorebird
// patch can rewrite it: bump the fields below when cutting a patch release.
//
// Do NOT read the app's version from package_info_plus — that reads the
// frozen native build identity (§2.2), which a patch can't change. Use
// package_info_plus only to display the *build* number alongside this.

import 'package:halo_build_tools/halo_build_tools.dart';

// Re-exported so the app's single version entry point also carries the build
// edition (Dev/Next/Regular — docs/releases.md §2.6). Set at build time via
// `--dart-define=HALO_EDITION=…`; defaults to Dev.
export 'package:halo_build_tools/halo_build_tools.dart' show Edition, kEdition;

/// The single source of truth for the public version (§2.1/§2.3). Exposed (not
/// just its derived strings) so CI tooling can project it, together with
/// [kBuildNumber], into the native per-platform version fields via
/// [PlatformVersions] — see tool/print_build_versions.dart.
const kPublicVersionInfo = PublicVersion(
  main: MainVersion(year: 26, month: 8),
  patch: 1,
  preRelease: 1,
  preReleaseLabel: 'alpha',
);

/// The native build number (`CFBundleVersion` / Android `versionCode` /
/// Windows·Linux `FILEVERSION` build), shared across every platform — a simple
/// monotonic integer. You don't edit it by hand: `scripts/release.sh` advances
/// it per release from the `v<version>+<build>` tag ledger and writes it here
/// (§2.2). Small enough to fit every platform's field (Windows/Linux cap it at
/// 16 bits), so unlike the old date-encoded id it needs no per-platform
/// narrowing.
const kBuildNumber = 78;

/// e.g. `26.8.1-alpha1`.
final kPublicVersion = kPublicVersionInfo.value;

/// e.g. `August '26`, `August '26 patch 2`, `August '26 pre 1`.
final kVersionName = kPublicVersionInfo.displayName;

/// [kVersionName] with the edition qualifier appended for the non-stable
/// editions — `August '26 (Dev)`, `August '26 (Next)` — so a build's edition
/// is visible wherever the version name is shown. Unchanged for Regular
/// (`kEdition.label` is null), so stable builds read exactly as before.
final kEditionVersionName = kEdition.label == null ? kVersionName : '$kVersionName (${kEdition.label})';

/// The product-line/build channel in the User-Agent (user_agent.dart), e.g.
/// `Ham2K Logger/26.8.0 (macos dev 1)`. Derived from [kEdition]
/// (docs/releases.md §2.6) so it always matches the build's edition: a
/// development build reports `dev`, and the public builds report `next` /
/// `prod` — every platform's CI sets `HALO_EDITION` for its official builds
/// (macOS/iOS xcconfig, Android `--flavor`, Windows/Linux env), so the channel
/// follows the edition rather than being hard-coded.
final kAppFlavor = kEdition.name;
