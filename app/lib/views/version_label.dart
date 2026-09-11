// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Shows the version name and public version (docs/releases.md §2.1/§2.3,
// `kVersionName`/`kPublicVersion`) plus the build identity from
// [buildDetails].

import 'package:flutter/material.dart';

import '../config/version.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../services/update_service.dart' show currentCodePush;

/// The build-identity parenthetical every version display shares — `(build
/// 125)`, or `(04e3d1)` on a Dev build. Read from compiled Dart, NOT from
/// package_info_plus's native metadata: a Shorebird patch can rewrite the
/// former but not the latter, and a local `flutter run` reports a native build
/// number of `1` that matches no release.
///
/// ONE identity, never two. A build that has a truthful build number names
/// itself by it and says nothing about its commit; a build whose number would
/// be a lie names its commit instead. Which applies is the edition: on Dev
/// `kBuildNumber` is the LAST RELEASE's, so it is the SHA that identifies the
/// binary — and a Dev build with no SHA baked in says nothing at all rather
/// than borrow a number that is not its own.
///
/// A running code push moves a Dev build back into the first case: only
/// `shorebird release` output can carry one, so it is proof that this IS that
/// release build and the number is truthful again. The push extends the number
/// rather than taking a field of its own — `build 125.2` is build 125 at code
/// push 2 (docs/releases.md §2.1); Shorebird's counter restarts at 1 per
/// release, so a bare `.2` names nothing.
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
  final namesItsBuildNumber = edition != Edition.dev || codePush != null;
  final label = namesItsBuildNumber
      ? t.versionLabel.build(build: codePush == null ? '$build' : '$build.$codePush')
      : shaLabel(sha);
  return label.isEmpty ? '' : '($label)';
}

/// How many characters of a commit SHA a version display shows.
const kShaLabelLength = 7;

/// [sha] cut to [kShaLabelLength] for display. Pinned here rather than at each
/// producer because `git rev-parse --short` picks its length from how big the
/// repository is, so CI, the `mise` run tasks and a hand-typed define do not
/// agree on one — and whatever they baked is already inside a shipped binary.
/// Only the LABEL is cut: `kGitSha` itself stays whole for the machine-facing
/// readers (the flags environment, the web build-freshness check), which
/// compare it against values this app did not produce.
String shaLabel(String sha) => sha.length <= kShaLabelLength ? sha : sha.substring(0, kShaLabelLength);

/// `Version 26.8.1 (build 125)` — the detail line under the version
/// name, dropping the parenthetical entirely when [buildDetails] is empty.
String versionDetailLine() {
  final version = t.versionLabel.version(version: kPublicVersion);
  final details = buildDetails();
  return details.isEmpty ? version : '$version $details';
}

/// `Patch 1 PRE 1` — the patch and pre-release qualifiers this version carries,
/// in the operator's language, empty when it carries neither. Rendered from
/// [PublicVersion.displayParts] rather than from `patch`/`preRelease` directly,
/// so a component added to the version reaches this spelling and
/// [PublicVersion.displayName]'s canonical one together.
///
/// Capitalized where displayName is lower-case: this text opens a line of its
/// own (`Patch 1 PRE 1 (build 130)`) rather than trailing a name, and it is
/// translated, which the canonical spelling must never be.
///
/// The pre-release label is upper-cased to sit alongside the stage marker on
/// the line above (`August '26 ALPHA` / `Patch 1 PRE 1`); both are stage
/// markers to a reader, whatever the lower-case token in the version string.
/// EXCEPT when the two would come out identical — `-alpha1` under an `ALPHA`
/// stage — where upper-casing puts the same word on both lines and a reader
/// can't tell the product's stage from this build's pre-release counter. Case
/// is what keeps the two apart.
String versionQualifiers({
  PublicVersion version = kPublicVersionInfo,
  String stageLabel = kStageLabel,
}) {
  final parts = version.displayParts(stageLabel: stageLabel);
  final preReleaseLabel = parts.preReleaseLabel;
  return [
    if (parts.patch != null) t.versionLabel.patch(patch: parts.patch.toString()),
    if (preReleaseLabel != null)
      '${_preReleaseLabel(preReleaseLabel, stageLabel: stageLabel)} ${parts.preReleaseCounter}',
  ].join(' ');
}

/// `September '26 ALPHA Parche 1` — the whole version name in the operator's
/// language, for the surfaces that show one line rather than the splash's two.
/// [kVersionName] stays canonical English: notice rules match on it, the
/// extension host is handed it, and release tags spell it.
///
/// [version]/[stageLabel] default to this process's values and exist so tests
/// can reach a version that HAS qualifiers: the shipping constants are a patch-0
/// release for most of a cycle, and against those this function and the
/// canonical name are the same string whether or not it renders the qualifiers
/// at all.
String localizedVersionName({
  PublicVersion version = kPublicVersionInfo,
  String stageLabel = kStageLabel,
}) {
  final parts = version.displayParts(stageLabel: stageLabel);
  return [
    parts.mainName,
    parts.stageLabel,
    versionQualifiers(version: version, stageLabel: stageLabel),
  ].where((part) => part.isNotEmpty).join(' ');
}

/// `Patch 1 PRE 1 (build 130)` — everything about this build that isn't in
/// [kVersionMainName], as the second line of [VersionLabel]'s `nameAndBuild`
/// mode. Each part drops out when it doesn't apply, so a stable patch-0
/// release reads as a bare `(build 130)` and a local Dev build of one is
/// empty (its caller then renders no second line at all).
///
/// [bareBuildNumber] names the BINARY — the build number alone, no code push
/// and no SHA, on a Dev build too. Only the tester overlay wants this: its
/// notes are KEYED by that number, and a header reading `build 130.2` over
/// notes titled "What's new in build 130" names an identity the notes index
/// doesn't contain. Nowhere else may use it to fill an empty line: on Dev
/// the number is the LAST RELEASE's, so anything claiming to identify the
/// RUNNING binary with it is lying, and it replaces the SHA that isn't.
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
  final parts = <String>[
    versionQualifiers(version: version, stageLabel: stageLabel),
    if (bareBuildNumber)
      '(${t.versionLabel.build(build: build.toString())})'
    else
      buildDetails(edition: edition, build: build, sha: sha, codePush: codePush),
  ];
  return parts.where((part) => part.isNotEmpty).join(' ');
}

/// `August '26 ALPHA patch 1 (Dev Edition)` then `Version 26.8.1 (04e3d1)` as
/// plain text, for callers that copy the version details elsewhere (e.g. the
/// About screen's version row). An official edition's second line names its
/// build instead — `Version 26.8.1 (build 125)` — see [buildDetails].
///
/// CANONICAL English, where `detailed` mode renders the same two lines in the
/// operator's language: this text is pasted into bug reports and matched
/// against notice rules, so it must not vary by locale.
String versionDetailsText() => '$kEditionVersionName\n${versionDetailLine()}';

String _preReleaseLabel(String label, {String stageLabel = kStageLabel}) =>
    label.toUpperCase() == stageLabel.toUpperCase() ? label.toLowerCase() : label.toUpperCase();

/// `August '26 ALPHA patch 1 (Dev Edition) · 26.8.1 (04e3d1)`. With
/// [detailed], instead renders two centered lines — the same edition version
/// name, then in a smaller size `Version 26.8.1 (build 125)` — for
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
      // The name the OPERATOR reads, in their language — the canonical English
      // spelling still reaches the clipboard (versionDetailsText), notice-rule
      // matching and the extension host, which must not vary by locale.
      final name = withEdition(localizedVersionName());
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          SelectableText(name, style: firstLineStyle, textAlign: textAlign),
          SelectableText(versionDetailLine(), style: detailStyle, textAlign: textAlign),
        ],
      );
    }
    // Canonical English, unlike `detailed` above: this is the developer System
    // Information row, read alongside the version NUMBER and quoted into bug
    // reports, where a translated name matches nothing.
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
