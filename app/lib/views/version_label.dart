// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Shows the version name and public version (docs/releases.md §2.1/§2.3,
// `kVersionName`/`kPublicVersion`) plus the native build number, read via
// package_info_plus per §2.3's "use package_info_plus only to display the
// build" rule. There's no Shorebird integration yet, so no patch number is
// shown — the build number is whatever CI (or, today, app/pubspec.yaml's
// `+N`) baked into the binary.

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/version.dart';

// Shared across every VersionLabel instance so a widget rebuild (e.g. a
// theme change dirtying a non-const VersionLabel) never hands FutureBuilder
// a new Future identity — that would reset it to ConnectionState.waiting
// and flicker the build-number suffix away and back.
final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

/// `August '26 · 26.8.0` until the native build number loads, then
/// `August '26 · 26.8.0 (build 1)`.
class VersionLabel extends StatelessWidget {
  final TextStyle? style;
  final String prefix;

  const VersionLabel({super.key, this.style, this.prefix = ''});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (context, snapshot) {
        final buildNumber = snapshot.data?.buildNumber;
        final version = (buildNumber == null || buildNumber.isEmpty)
            ? kPublicVersion
            : '$kPublicVersion (build $buildNumber)';
        return SelectableText('$prefix$kVersionName · $version', style: style);
      },
    );
  }
}
