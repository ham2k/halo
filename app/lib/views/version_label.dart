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
import '../i18n/strings.g.dart';

// Shared across every VersionLabel instance so a widget rebuild (e.g. a
// theme change dirtying a non-const VersionLabel) never hands FutureBuilder
// a new Future identity — that would reset it to ConnectionState.waiting
// and flicker the build-number suffix away and back.
final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

/// The same two lines [VersionLabel]'s `detailed` mode renders — `August
/// '26` then `Version 26.8.0 - Build 1` — as plain text, for callers that
/// copy the version details elsewhere (e.g. the About screen's version row).
/// Calls `PackageInfo.fromPlatform()` fresh rather than reusing
/// [_packageInfoFuture] — package_info_plus caches the resolved value
/// internally so this is still cheap, and a one-shot awaited call (unlike
/// [VersionLabel]'s non-blocking `FutureBuilder`) must not share a Future
/// that a widget test may have completed in another test's now-torn-down
/// Zone, which never notifies a listener registered in a later test.
Future<String> versionDetailsText() async {
  final buildNumber = (await PackageInfo.fromPlatform()).buildNumber;
  final version = buildNumber.isEmpty
      ? t.versionLabel.version(version: kPublicVersion)
      : t.versionLabel.versionBuild(version: kPublicVersion, build: buildNumber);
  return '$kEditionVersionName\n$version${_gitShaSuffix()}';
}

/// ` (a1b2c3d)` when the build baked in a git SHA via --dart-define (CI), else
/// empty. Appended to the About screen's version/build detail line so the exact
/// build is identifiable — handy for confirming an auto-update actually landed.
String _gitShaSuffix() => kGitSha.isEmpty ? '' : ' ($kGitSha)';

/// `August '26 · 26.8.0` until the native build number loads, then
/// `August '26 · 26.8.0 (build 1)`. With [detailed], instead renders two
/// centered lines — `August '26 patch 1` then, in a smaller size, `Version
/// 26.8.0 - Build 1` — for the About screen's header.
class VersionLabel extends StatelessWidget {
  final TextStyle? style;
  final String prefix;
  final bool detailed;
  final CrossAxisAlignment crossAxisAlignment;
  final bool boldFirstLine;

  /// Show ONLY the release name ([kVersionName]) — no edition qualifier and no
  /// version/build detail line — for places where the edition is shown
  /// separately (the edition badge SVG) and the build detail isn't wanted: the
  /// home right pane, the splash, and onboarding.
  final bool nameOnly;

  const VersionLabel({
    super.key,
    this.style,
    this.prefix = '',
    this.detailed = false,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.boldFirstLine = false,
    this.nameOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final textAlign = crossAxisAlignment == CrossAxisAlignment.start ? TextAlign.start : TextAlign.center;
    if (nameOnly) {
      return Text(kVersionName, style: style, textAlign: textAlign);
    }
    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (context, snapshot) {
        final buildNumber = snapshot.data?.buildNumber;
        if (detailed) {
          // Resolve a concrete base style (the About row passes none, inheriting
          // the ListTile's title style) so the bold name / smaller detail below
          // apply rather than no-op on a null style.
          final base = style ?? DefaultTextStyle.of(context).style;
          final firstLineStyle = boldFirstLine ? base.copyWith(fontWeight: FontWeight.bold) : base;
          // The detail line reads as secondary: normal weight, two points smaller.
          final detailStyle = base.copyWith(
            fontWeight: FontWeight.normal,
            fontSize: (base.fontSize ?? 14) - 2,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: crossAxisAlignment,
            children: [
              SelectableText(kEditionVersionName, style: firstLineStyle, textAlign: textAlign),
              SelectableText(
                (buildNumber == null || buildNumber.isEmpty
                        ? t.versionLabel.version(version: kPublicVersion)
                        : t.versionLabel.versionBuild(version: kPublicVersion, build: buildNumber)) +
                    _gitShaSuffix(),
                style: detailStyle,
                textAlign: textAlign,
              ),
            ],
          );
        }
        final version = (buildNumber == null || buildNumber.isEmpty)
            ? kPublicVersion
            : '$kPublicVersion (build $buildNumber)';
        return SelectableText('$prefix$kEditionVersionName · $version', style: style);
      },
    );
  }
}
