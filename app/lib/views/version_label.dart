// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Shows the version name and public version (docs/releases.md §2.1/§2.3,
// `kVersionName`/`kPublicVersion`) plus the build identity from
// [buildDetails].

import 'package:flutter/material.dart';

import '../config/version.dart';
import '../i18n/strings.g.dart';
import '../services/update_service.dart' show currentCodePush;

/// The build-identity parenthetical every version display shares —
/// `(build 125 - 04e3d1)`, or `(build 125)` when no SHA was baked in
/// (`--dart-define=HALO_GIT_SHA=…`, which only CI sets). Read from compiled
/// Dart, NOT from package_info_plus's native metadata: a Shorebird patch can
/// rewrite the former but not the latter, and a local `flutter run` reports a
/// native build number of `1` that matches no release.
///
/// A code push applied on top of the binary extends the build number rather
/// than taking a field of its own — `build 125.2` is build 125 at code push 2
/// (docs/releases.md §2.1). The two are only meaningful together: Shorebird's
/// counter restarts at 1 for each release, so a bare `.2` names nothing.
///
/// Dev builds normally show the SHA alone — `kBuildNumber` there is the last
/// release's number, not this build's, so printing it would name a build that
/// isn't running — and show nothing at all without a SHA, which is every local
/// run. A running code push is proof that this IS that release build (only
/// `shorebird release` output can carry one), so the build number is truthful
/// again and Dev names it too.
///
/// [edition]/[build]/[sha]/[codePush] default to this process's values and
/// exist only so tests can reach the other cells of that matrix: compile-time
/// constants can't be faked from a test binary.
String buildDetails({
  Edition edition = kEdition,
  int build = kBuildNumber,
  String sha = kGitSha,
  int? codePush,
}) {
  codePush ??= currentCodePush;
  final buildLabel = codePush == null ? '$build' : '$build.$codePush';
  final parts = <String>[
    if (edition != Edition.dev || codePush != null) t.versionLabel.build(build: buildLabel),
    if (sha.isNotEmpty) sha,
  ];
  return parts.isEmpty ? '' : '(${parts.join(' - ')})';
}

/// `Version 26.8.1 (build 125 - 04e3d1)` — the detail line under the version
/// name, dropping the parenthetical entirely when [buildDetails] is empty.
String versionDetailLine() {
  final version = t.versionLabel.version(version: kPublicVersion);
  final details = buildDetails();
  return details.isEmpty ? version : '$version $details';
}

/// The same two lines [VersionLabel]'s `detailed` mode renders — `August '26
/// ALPHA patch 1 (Dev Edition)` then `Version 26.8.1 (build 125 - 04e3d1)` —
/// as plain text, for callers that copy the version details elsewhere (e.g.
/// the About screen's version row).
String versionDetailsText() => '$kEditionVersionName\n${versionDetailLine()}';

/// `August '26 ALPHA patch 1 (Dev Edition) · 26.8.1 (04e3d1)`. With
/// [detailed], instead renders two centered lines — the same edition version
/// name, then in a smaller size `Version 26.8.1 (build 125 - 04e3d1)` — for
/// the About screen's version row.
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
          SelectableText(versionDetailLine(), style: detailStyle, textAlign: textAlign),
        ],
      );
    }
    final details = buildDetails();
    final version = details.isEmpty ? kPublicVersion : '$kPublicVersion $details';
    return SelectableText('$prefix$kEditionVersionName · $version', style: style);
  }
}
