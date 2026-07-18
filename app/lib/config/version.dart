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

const _publicVersionInfo = PublicVersion(main: MainVersion(year: 26, month: 8), patch: 0);

/// e.g. `26.8.0`.
final kPublicVersion = _publicVersionInfo.value;

/// e.g. `August '26`, `August '26 patch 2`, `August '26 pre 1`.
final kVersionName = _publicVersionInfo.displayName;

/// The product-line/build channel, part of the release identity — see
/// user_agent.dart. `next` is the Ham2K Logger Next line; a stable line would
/// set a different value here. This is the *product line*, not the `-preN`
/// pre-release counter ([PublicVersion.preRelease]) — the two are orthogonal,
/// so it lives here (bumped deliberately at release time) rather than being
/// derived. Kept beside [kPublicVersion] so both move together when cutting a
/// release.
const kAppFlavor = 'next';
