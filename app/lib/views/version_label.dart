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

/// `Patch 1 PRE 1 (build 130)` — everything about this build that isn't in
/// [kVersionMainName], as the second line of [VersionLabel]'s `nameAndBuild`
/// mode. Each part drops out when it doesn't apply, so a stable patch-0
/// release reads as a bare `(build 130)` and a local Dev build of one is
/// empty (its caller then renders no second line at all).
///
/// The pre-release label is upper-cased to sit alongside the stage marker on
/// the line above (`August '26 ALPHA` / `Patch 1 PRE 1`); both are stage
/// markers to a reader, whatever the lower-case token in the version string.
/// EXCEPT when the two would come out identical — `-alpha1` under an `ALPHA`
/// stage — where upper-casing puts the same word on both lines and a reader
/// can't tell the product's stage from this build's pre-release counter. Case
/// is what keeps the two apart.
///
/// [bareBuildNumber] names the BINARY — the build number alone, no code push
/// and no SHA, on a Dev build too. Only the tester overlay wants this: its
/// notes are KEYED by that number, and a header reading `build 130.2 - 04e3d1`
/// over notes titled "What's new in build 130" names an identity the notes
/// index doesn't contain.
///
/// [version]/[edition]/[build]/[sha]/[codePush]/[stageLabel] default to this
/// process's values and exist only so tests can reach the other cells of that
/// matrix — including the collision above, which is otherwise only reachable
/// while the product happens to sit in the stage the version names.
String versionBuildLine({
  PublicVersion version = kPublicVersionInfo,
  Edition edition = kEdition,
  int build = kBuildNumber,
  String sha = kGitSha,
  int? codePush,
  bool bareBuildNumber = false,
  String stageLabel = kStageLabel,
}) {
  final preRelease = version.preRelease;
  final parts = <String>[
    if (version.patch != 0) t.versionLabel.patch(patch: version.patch.toString()),
    if (preRelease != null)
      '${_preReleaseLabel(version.preReleaseLabel, stageLabel: stageLabel)} $preRelease'
          '${version.preReleasePatch == null ? '' : '.${version.preReleasePatch}'}',
    if (bareBuildNumber)
      '(${t.versionLabel.build(build: build.toString())})'
    else
      buildDetails(edition: edition, build: build, sha: sha, codePush: codePush),
  ];
  return parts.where((part) => part.isNotEmpty).join(' ');
}

/// The same two lines [VersionLabel]'s `detailed` mode renders — `August '26
/// ALPHA patch 1 (Dev Edition)` then `Version 26.8.1 (build 125 - 04e3d1)` —
/// as plain text, for callers that copy the version details elsewhere (e.g.
/// the About screen's version row).
String versionDetailsText() => '$kEditionVersionName\n${versionDetailLine()}';

String _preReleaseLabel(String label, {String stageLabel = kStageLabel}) =>
    label.toUpperCase() == stageLabel.toUpperCase() ? label.toLowerCase() : label.toUpperCase();

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

  /// Two lines — `August '26 ALPHA` over `Patch 1 (build 130)` — for the photo
  /// overlays (release, tester, onboarding) and the home right pane. No edition
  /// qualifier: those surfaces all show the edition on the brand mark's badge.
  /// The second line is dropped when [versionBuildLine] has nothing to say.
  ///
  /// Neither line wraps: the two shrink together to fit the width they are
  /// given (see [_oneLine]).
  final bool nameAndBuild;

  /// The second line's style in [nameAndBuild] mode. Required there: the two
  /// callers sit at sizes an order apart (a 32pt name over a photo, a 14pt one
  /// in the home pane), and no single ratio off [style] reads well at both.
  final TextStyle? detailStyle;

  /// Name the BINARY's build number — see [versionBuildLine]. Only the tester
  /// overlay sets this.
  final bool bareBuildNumber;

  const VersionLabel({
    super.key,
    this.style,
    this.prefix = '',
    this.detailed = false,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.boldFirstLine = false,
    this.nameAndBuild = false,
    this.detailStyle,
    this.bareBuildNumber = false,
  }) : assert(!nameAndBuild || detailStyle != null, 'nameAndBuild needs an explicit detailStyle');

  @override
  Widget build(BuildContext context) {
    final textAlign = crossAxisAlignment == CrossAxisAlignment.start ? TextAlign.start : TextAlign.center;
    if (nameAndBuild) {
      final buildLine = versionBuildLine(bareBuildNumber: bareBuildNumber);
      // ONE box around both lines, never one each: a short build line never
      // needs shrinking, so per-line fitting would scale the two by different
      // factors and leave the secondary line out-sizing the name above it.
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: textAlign == TextAlign.start ? Alignment.centerLeft : Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: crossAxisAlignment,
          children: [
            _oneLine(kVersionMainName, style, textAlign),
            if (buildLine.isNotEmpty) _oneLine(buildLine, detailStyle, textAlign),
          ],
        ),
      );
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

  /// [text] as ONE unwrappable line — these lines sit under a brand mark over a
  /// photo, where a wrap reads as a layout bug. Narrow panes are handled by the
  /// block-level [FittedBox] above, not by wrapping.
  Widget _oneLine(String text, TextStyle? lineStyle, TextAlign textAlign) =>
      Text(text, style: lineStyle, textAlign: textAlign, maxLines: 1, softWrap: false);
}
