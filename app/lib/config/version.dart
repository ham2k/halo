// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The public-facing version — see docs/releases.md §2.1 and §2.3. This lives
// in compiled Dart (not package_info_plus/native metadata) so a Shorebird
// patch can rewrite it: bump the fields below when cutting a patch release.
//
// Do NOT read the app's version from package_info_plus — that reads the
// frozen native build identity (§2.2), which a patch can't change. The same
// goes for the build number shown anywhere in the UI, and for the one notice
// rules are matched against: [kBuildNumber] below is what both use.
// package_info_plus's build number is still what the User-Agent reports,
// deliberately — that describes the native binary, not what the user is
// looking at.

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:halo_core/halo_core.dart';

// Re-exported so the app's single version entry point also carries the build
// edition (Dev/Next/Regular — docs/releases.md §2.6). Set at build time via
// `--dart-define=HALO_EDITION=…`; defaults to Dev.
export 'package:halo_build_tools/halo_build_tools.dart' show Edition, kEdition, PublicVersion, VersionDisplayParts;

/// The single source of truth for the public version (§2.1/§2.3). Exposed (not
/// just its derived strings) so CI tooling can project it, together with
/// [kBuildNumber], into the native per-platform version fields via
/// [PlatformVersions] — see tool/print_build_versions.dart.
const kPublicVersionInfo = PublicVersion(
  main: MainVersion(year: 26, month: 9),
  patch: 0,
);

/// The product-wide stage marker carried by every human version name —
/// `August '26 ALPHA patch 1` — across all versions and editions. It is not
/// part of [kPublicVersionInfo]: the version's own `-preN` suffix marks ONE
/// build's place in a release cycle (§2.1), while this marks the product's
/// maturity and outlives any single version. Set it to `''` to drop it
/// everywhere at once.
const kStageLabel = 'ALPHA';

/// The native build number (`CFBundleVersion` / Android `versionCode` /
/// Windows·Linux `FILEVERSION` build), shared across every platform — a simple
/// monotonic integer. You don't edit it by hand: `halo-ops release` advances
/// it per release from the `v<version>+<build>` tag ledger and writes it here
/// (§2.2). Must stay small enough to fit every platform's field —
/// Windows/Linux cap it at 16 bits.
const kBuildNumber = 144;

/// The short git SHA of the commit this build was cut from, baked in at build
/// time via `--dart-define=HALO_GIT_SHA=…` (CI). Empty for local/dev builds.
/// Shown in the About panel to identify exactly which build is running.
const kGitSha = String.fromEnvironment('HALO_GIT_SHA');

/// Per-edition build expiration dates (`YYYY-MM-DD`, UTC; empty = never
/// expires). You don't edit these by hand: `halo-ops release` writes them —
/// today + 14 days for the cutting edition (Next), + 6 months for Regular,
/// and Dev is re-stamped to today + 14 days on EVERY cut (dev builds are
/// made from dist commits, so they inherit the latest stamp) — so a stale
/// install nags on every launch to go get a newer build (the dialog in
/// views/staleness_dialog.dart). Like [kBuildNumber] these live in
/// compiled Dart so a Shorebird patch can rewrite them.
const kDevExpirationDate = '2026-09-01';
const kNextExpirationDate = '2026-09-01';
const kProdExpirationDate = '';

/// When THIS build expires: the running edition's date from above, or null
/// when that field is empty or malformed (e.g. an OSS checkout that never
/// saw a release cut).
final DateTime? kBuildExpiration = switch (kEdition) {
  Edition.dev => DateTime.tryParse(kDevExpirationDate),
  Edition.next => DateTime.tryParse(kNextExpirationDate),
  Edition.prod => DateTime.tryParse(kProdExpirationDate),
};

/// Whether [kBuildExpiration] has passed — true starting the day AFTER the
/// expiration date (a build expiring 2026-08-06 still works all of the
/// 6th, UTC). [now] is injectable for tests.
bool isBuildExpired({DateTime? now}) {
  final expiration = kBuildExpiration;
  if (expiration == null) return false;
  return expirationHasPassed(expiration, (now ?? nowLocal()).toUtc());
}

/// e.g. `26.8.1`, or `26.8.1-pre2` once a pre-release is cut.
final kPublicVersion = kPublicVersionInfo.value;

/// e.g. `August '26 ALPHA`, `August '26 ALPHA patch 2`,
/// `August '26 ALPHA patch 2 pre 1`.
final kVersionName = kPublicVersionInfo.displayName(stageLabel: kStageLabel);

/// This build's version name in pieces (release line, stage marker, patch,
/// pre-release) — what the UI renders from, so the splash's two lines and
/// [kVersionName] can't spell the same version differently.
final kVersionParts = kPublicVersionInfo.displayParts(stageLabel: kStageLabel);

/// e.g. `August '26 ALPHA` — the release line and stage marker alone, with the
/// patch and pre-release parts left to `versionBuildLine()`, which puts them on
/// their own line beneath (views/version_label.dart). This is a display split
/// of [kVersionName], not a second identity: nothing outside the UI uses it.
final kVersionMainName = [
  kVersionParts.mainName,
  if (kVersionParts.stageLabel.isNotEmpty) kVersionParts.stageLabel,
].join(' ');

/// [kVersionName] with the edition qualifier appended for the non-stable
/// editions — `August '26 ALPHA (Dev Edition)`, `… (Next Edition)` — so a
/// build's edition is visible wherever the version name is shown. Unchanged
/// for Regular (`kEdition.label` is null). The word "Edition" is spelled out
/// here rather than in `Edition.label`, which stays the bare token that build
/// tooling names artifacts and flavors with.
final kEditionVersionName = withEdition(kVersionName);

/// [name] with this build's edition qualifier appended — the ONE place that
/// grammar is spelled, so the About row's translated name and [kVersionName]
/// can't name the edition two different ways.
String withEdition(String name) {
  final label = kEdition.label;
  return label == null ? name : '$name ($label Edition)';
}

/// The product-line/build channel in the User-Agent (user_agent.dart), e.g.
/// `Ham2K Logger/26.8.0 (macos dev 1)`. Derived from [kEdition]
/// (docs/releases.md §2.6) so it always matches the build's edition: a
/// development build reports `dev`, and the public builds report `next` /
/// `prod` — every platform's CI sets `HALO_EDITION` for its official builds
/// (macOS/iOS xcconfig, Android `--flavor`, Windows/Linux env), so the channel
/// follows the edition rather than being hard-coded.
final kAppFlavor = kEdition.name;
