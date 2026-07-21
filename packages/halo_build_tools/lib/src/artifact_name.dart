// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'edition.dart';
import 'public_version.dart';

/// The **compact**, machine-facing base name — `halo-<edition>-<version>-(<build>)`,
/// e.g. `halo-next-26.8.1-alpha1-(73)` (docs/releases.md §2.2). CI appends
/// `-<platform>.zip` for each platform's artifacts archive
/// (`halo-next-26.8.1-alpha1-(73)-windows.zip`), or `.<ext>` for a
/// machine-consumed file inside it (`halo-next-26.8.1-alpha1-(73).apk`, and
/// later Sparkle/WinSparkle updates). Always carries the edition, the full
/// public version (incl. the `-preN` label), and the build in parens, so it
/// uniquely and sortably identifies a build.
String compactName({
  required Edition edition,
  required PublicVersion version,
  required int build,
}) => 'halo-${edition.name}-${version.value}-($build)';

/// The **full**, human-facing base name — `Ham2K Logger[ (<Edition>)] <version>[ (<build>)]`,
/// e.g. `Ham2K Logger (Next) 26.8.1-alpha1 (73)` or, for a stable release,
/// `Ham2K Logger 26.8.2`. The edition qualifier is dropped for prod, and the
/// build number is shown **only for pre-releases** (a stable release is
/// identified by its version alone). CI appends the per-file descriptor and
/// extension — e.g. ` Installer.exe`, `.dmg`, ` macOS.zip` — omitting the
/// platform word where the extension already implies it.
String fullName({
  required Edition edition,
  required PublicVersion version,
  required int build,
}) {
  // The brand + edition qualifier is [Edition.productName] — the same string
  // used for the installed app name — so artifact and installed names never
  // drift apart. The build number is shown only for pre-releases.
  final buildPart = version.preRelease == null ? '' : ' ($build)';
  return '${edition.productName} ${version.value}$buildPart';
}
