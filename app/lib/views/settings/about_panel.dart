// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// About: version, build, the recent release notes, and the credits.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../config/release_notes.dart';
import '../../config/version.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../../services/halo_services.dart';
import '../ham2k_logo.dart';
import '../notice_history_view.dart';
import '../release_overlay.dart';
import '../update_check_row.dart';
import '../version_label.dart';

/// How many releases' notes show in the About screen's "Release Notes"
/// preview/modal — a handful of the most recent, not the full history.
const _aboutRecentReleaseCount = 3;

/// Tapping the About screen's version row copies the full app name and
/// version details — handy for pasting into a bug report or support email.
Future<void> _copyVersionDetailsToClipboard(BuildContext context) async {
  await Clipboard.setData(ClipboardData(text: '$ham2kAppName\n${versionDetailsText()}'));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(haloSnackBar(context.t.settings.about.copiedVersion));
}

class AboutPanel extends StatelessWidget {
  final HaLoServices services;

  const AboutPanel({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReleaseNotesEntry>>(
      future: loadReleaseNotes(),
      builder: (context, snapshot) {
        final releaseNotes = snapshot.data ?? const [];
        final recentReleases = releaseNotes.take(_aboutRecentReleaseCount).toList();
        // Match the running version explicitly rather than assuming
        // `releaseNotes.first` is it — release-notes.yaml's newest-first
        // order is a hand-maintained authoring convention, not something
        // the loader enforces, so notes written ahead of an actual version
        // bump (or a hotfix/rollback) could otherwise show a different
        // release here than the VersionLabel row below it. Falls back to
        // `.first` only when the running version has no entry yet.
        final currentRelease = releaseNotes.isEmpty
            ? null
            : releaseNotes.firstWhere((entry) => entry.version == kPublicVersion, orElse: () => releaseNotes.first);

        // CustomScrollView + SliverFillRemaining(hasScrollBody: false)
        // rather than a plain Column: on a short viewport (a phone in
        // landscape, or a resized-short desktop window) the fixed-height
        // rows above (240px header + two dividers + version row + title)
        // alone can exceed the available height, and a bare Column has no
        // scroll fallback for that — it just overflows. This fills the
        // remaining space normally when there's room (matching the old
        // Column+Expanded look) and degrades to a scrollable, naturally-
        // sized preview when there isn't, instead of throwing.
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _AboutHeader(release: currentRelease)),
            // Ordinary settings rows from here down — no dividers between
            // them and no width cap of their own: this panel reads as one
            // list with the rest of Settings, and its rows take the pane's
            // width and the ambient row inset like every other panel's.
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(MdiIcons.information),
                // VersionLabel renders SelectableText, whose own tap
                // recognizer (for cursor placement) would otherwise win
                // the gesture arena over this ListTile's onTap —
                // IgnorePointer keeps the whole row a single tap target
                // instead of a text-selection field.
                title: const IgnorePointer(child: VersionLabel(detailed: true, crossAxisAlignment: CrossAxisAlignment.start, boldFirstLine: true)),
                onTap: () => _copyVersionDetailsToClipboard(context),
                mouseCursor: SystemMouseCursors.click,
              ),
            ),
            // Both of these hide themselves entirely where they don't apply
            // (no update mechanism for this build; a preference that isn't
            // ours to honour), which is why neither is wrapped in anything
            // that would leave a gap behind.
            SliverToBoxAdapter(child: UpdateCheckRow(services: services)),
            SliverToBoxAdapter(child: AutomaticUpdateCheckRow(services: services)),
            // Notices & Messages sits here, between the version and the
            // release notes, as an entry point into the history view.
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(MdiIcons.bell),
                title: Text(context.t.settings.about.notices),
                subtitle: Text(context.t.settings.about.noticesDescription),
                trailing: const Icon(MdiIcons.chevronRight),
                onTap: () => showModalPane<void>(
                  context,
                  title: context.t.settings.about.notices,
                  closeLabel: context.t.common.close,
                  // NoticeHistoryView is its own scrolling ListView — the
                  // pane must not also wrap it in a SingleChildScrollView.
                  scrollable: false,
                  builder: (context) => NoticeHistoryView(services: services),
                ),
                mouseCursor: SystemMouseCursors.click,
              ),
            ),
            if (recentReleases.isNotEmpty)
              SliverMainAxisGroup(
                slivers: [
                  SectionHeader.pinned(context, context.t.settings.about.releaseNotes),
                  SliverFillRemaining(hasScrollBody: false, child: _ReleaseNotesPreview(releases: recentReleases)),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// The last few releases' notes as one markdown block — shared by the
/// clipped/faded preview and the modal pane's full (unclipped) view, so
/// they always show identical content.
String _combinedReleaseNotesMarkdown(List<ReleaseNotesEntry> releases) {
  final lines = <String>[];
  for (final release in releases) {
    lines.add('**${release.name}**');
    lines.add('');
    lines.addAll(release.changes.map((change) => '- $change'));
    lines.add('');
  }
  return lines.join('\n');
}

/// Tapping the preview opens the same content in a Modal Pane, scrollable
/// and un-clipped — the preview itself never scrolls (`ClipRect` fades it
/// out at the bottom instead), same non-scrollable-`SingleChildScrollView`
/// trick as `release_overlay.dart`'s collapsed notes: it gives the
/// `MarkdownBody` unbounded height along the scroll axis so its natural
/// (taller-than-available) size never trips a RenderFlex overflow.
class _ReleaseNotesPreview extends StatelessWidget {
  final List<ReleaseNotesEntry> releases;

  const _ReleaseNotesPreview({required this.releases});

  @override
  Widget build(BuildContext context) {
    final markdown = _combinedReleaseNotesMarkdown(releases);
    final styleSheet = withEmojiFallback(MarkdownStyleSheet.fromTheme(Theme.of(context)));
    return GestureDetector(
      key: const Key('aboutReleaseNotesPreview'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showModalPane<void>(
        context,
        title: context.t.settings.about.releaseNotes,
        closeLabel: context.t.common.close,
        builder: (context) => MarkdownBody(data: markdown, styleSheet: styleSheet),
      ),
      child: ClipRect(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0, 0.85, 1],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            // The rows' own inset, so the notes start under the section
            // band's title rather than at an inset of their own.
            padding: ListTileTheme.of(context).contentPadding ?? const EdgeInsets.symmetric(horizontal: Space.xl),
            child: MarkdownBody(data: markdown, styleSheet: styleSheet),
          ),
        ),
      ),
    );
  }
}

/// The About screen's top banner: the current release's cover photo fading
/// into the surface color (same technique as `ReleaseOverlayView`), with the
/// ham2k arc and app name over it.
class _AboutHeader extends StatelessWidget {
  final ReleaseNotesEntry? release;

  const _AboutHeader({required this.release});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // No ambient panel-body inset to cancel here (see _buildContent) — this
    // Stack already spans the pane's true width.
    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (release != null)
            ReleasePhoto(
              imageAssetPath: release!.imageAssetPath,
              errorBuilder: (context, error, stackTrace) => ColoredBox(color: theme.colorScheme.primaryContainer),
            )
          else
            ColoredBox(color: theme.colorScheme.primaryContainer),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [theme.colorScheme.surface.withValues(alpha: 0.3), theme.colorScheme.surface],
                stops: const [0.0, 0.9],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: Space.xl),
              child: GestureDetector(
                key: const Key('aboutWordmark'),
                onTap: () => showPhotoWordmarkModal(context, release: release),
                child: const Ham2kBrandMark(logoWidth: 140, showShadow: true, titleFontSizeDelta: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
