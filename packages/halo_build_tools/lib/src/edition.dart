// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// The build **edition** — the runtime mirror of the `HALO_EDITION` build
/// input, see docs/releases.md §2.6 and §8.
///
/// Three editions share one codebase, each a separately-installable app with
/// its own identity (`com.ham2k.logger.dev` / `.next` / `.prod`):
///
/// - [dev] — the plain, build-it-yourself edition. Unsigned, never
///   distributed, and carries none of the update planes. This is the
///   **default**: a public checkout has no `app_dist/`, so it can only ever
///   resolve `dev`.
/// - [next] — the official pre-release edition (§2.5), branded "Ham2K Logger
///   Next".
/// - [prod] — the official stable edition, branded "Ham2K Logger".
///
/// The native identity/name are set per-platform at build time (§8); this
/// enum is how Dart code keys off the same switch — for branding and, later,
/// for which update feeds (Shorebird/appcast/extension OTA) to contact. Only
/// `next`/`prod` talk to remote feeds; `dev` keeps them all off.
enum Edition {
  dev,
  next,
  prod;

  /// True for the two official, signed-and-distributed editions.
  bool get isOfficial => this != Edition.dev;

  /// A short human label for the edition, or `null` for [prod] (the plain
  /// "Ham2K Logger", which needs no qualifier). Used to distinguish builds in
  /// the UI — e.g. the About screen's version details.
  String? get label => switch (this) {
    Edition.dev => 'Dev',
    Edition.next => 'Next',
    Edition.prod => null,
  };

  /// The full product brand — the installed app name and the base of every
  /// downloadable-artifact name (§2.2/§2.6): "Ham2K Logger", "Ham2K Logger
  /// (Next)", or "Ham2K Logger (Dev)". The non-prod editions carry a
  /// parenthesised qualifier; prod has none. The Inno installer
  /// (app/windows/installer/ham2k-logger.iss) hardcodes the same mapping since
  /// it can't import Dart — keep the two in sync.
  String get productName => switch (this) {
    Edition.prod => 'Ham2K Logger',
    Edition.next => 'Ham2K Logger (Next)',
    Edition.dev => 'Ham2K Logger (Dev)',
  };
}

/// Parses an explicit edition name (`dev` / `next` / `prod`), or null if it's
/// none of those — for the `halo-ops --edition <name>` flag.
Edition? editionFromName(String name) => switch (name.trim().toLowerCase()) {
  'dev' => Edition.dev,
  'next' => Edition.next,
  'prod' => Edition.prod,
  _ => null,
};

/// The [Edition] a release cut from git branch [branch] targets.
///
/// Today Next is
/// cut from the `main` branch (a pushed `v*` tag builds the Next matrix), so
/// `main` → `next` — `dist`, its pre-rename name, stays mapped while the
/// transitional `dist` compat branch exists — and a dedicated `prod` branch
/// → `prod`. Everything else — feature branches — is `dev`, which halo-ops
/// won't tag. This is expected to change as the branch layout evolves
/// (codemagic.yaml notes a future "separate next/prod branches");
/// `--edition` overrides it meanwhile.
Edition editionForBranch(String branch) => switch (branch.trim()) {
  'prod' => Edition.prod,
  'next' => Edition.next,
  'main' || 'dist' => Edition.next,
  _ => Edition.dev,
};

/// The raw `HALO_EDITION` compile-time define (`--dart-define=HALO_EDITION=…`),
/// defaulting to `dev` when unset — which is every public checkout and every
/// plain `flutter run` (§2.6).
const _editionDefine = String.fromEnvironment('HALO_EDITION', defaultValue: 'dev');

/// The [Edition] this binary was built as. An unrecognized value falls back to
/// [Edition.dev] rather than throwing, so a mis-set define degrades to the
/// safe, non-distributed edition instead of breaking the build.
const Edition kEdition = _editionDefine == 'prod'
    ? Edition.prod
    : (_editionDefine == 'next' ? Edition.next : Edition.dev);
