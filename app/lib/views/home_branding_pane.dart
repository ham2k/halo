// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The home view's right column on two-pane layouts — the release photo, the
// brand, and what build this is.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/dev_label.dart';
import '../config/release_notes.dart';
import 'ham2k_logo.dart';
import 'release_overlay.dart';
import 'version_label.dart';

/// The home view's right column on two-pane layouts: the operation list has
/// nothing useful to spend the extra width on, so it shows the wordmark and
/// version instead.
class BrandingPane extends StatelessWidget {
  const BrandingPane({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // The current release's photo, behind everything. A FutureBuilder
        // rather than a field: the notes are parsed from a bundled YAML once
        // per launch and cached by [loadReleaseNotes], so this costs one
        // already-resolved future after the first pane to ask.
        //
        // Every failure here paints NOTHING and leaves the pane on its own
        // background: a release with no photo committed yet, an asset that
        // fails to decode, or notes that will not parse. The pane's job is
        // the version, and it still does it.
        FutureBuilder<List<ReleaseNotesEntry>>(
          future: loadReleaseNotes(),
          builder: (context, snapshot) {
            final release = snapshot.data?.firstOrNull;
            if (release == null) return const SizedBox.shrink();
            return ReleasePhoto(imageAssetPath: release.imageAssetPath, errorBuilder: (_, _, _) => const SizedBox.shrink());
          },
        ),
        // A scrim, not a tint on the text: the photo is a real photograph and
        // its brightness is not ours to predict, so the contrast the branding
        // needs is bought here rather than assumed.
        //
        // Strong enough to carry `onSurfaceVariant` text over an arbitrary
        // photo, light enough that the photo still reads as one — past about
        // 0.7 it stops being a background and becomes a tint nobody can tell
        // from a flat fill. Heavier in dark mode, where the text is light and
        // a bright photo is what would swallow it.
        Positioned.fill(
          child: ColoredBox(color: theme.colorScheme.surface.withValues(alpha: theme.brightness == Brightness.dark ? 0.62 : 0.55)),
        ),
        _brandingContent(context, theme),
      ],
    );
  }

  Widget _brandingContent(BuildContext context, ThemeData theme) {
    return Container(
      alignment: Alignment.center,
      // No keyboard padding here: `StatusBarOverlay` holds the keyboard's
      // height back for the whole app and consumes the inset, so this pane is
      // already only as tall as the space above the keyboard. Padding by
      // `viewInsets.bottom` as well would shrink the branding to a sliver
      // pinned near the top on iPad landscape.
      // Scale the branding down rather than overflow when the pane is short —
      // e.g. landscape two-pane with the keyboard up shrinks it well below
      // the logo+text's natural height. No effect at full height.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(ham2kSquareLogoAsset, width: 234),
            const SizedBox(height: Space.xs),
            // The square mark already says "Ham2K", so per the branding rules
            // (docs/design/user-interface.md) only the product name — "Power
            // Logger" or "Portable Logger" — goes below it.
            // Outlined the way the brand lockup's name is (About, the release
            // overlay), because this one stands over the same arbitrary release
            // photo and can't rely on the scrim alone.
            Ham2kOutlinedShadowText(
              text: ham2kProductName,
              style: (theme.textTheme.headlineSmall ?? const TextStyle()).copyWith(
                fontFamily: 'RobotoSlab',
                fontWeight: FontWeight.w800,
                fontSize: (theme.textTheme.headlineSmall?.fontSize ?? 24) * 1.56,
              ),
              color: Colors.grey.shade900,
            ),
            // Edition badge below the name, centered, a bit smaller (Regular has
            // none). Pinned by WIDTH, so the badge spans the same measure under
            // the name whichever edition's wordmark it is. It stands over the
            // release photo like the splash lockup, so it wears the same shadow.
            if (ham2kEditionBadgeAsset != null) ...[const SizedBox(height: Space.md), Ham2kEditionBadge(width: 130, shadows: ham2kEditionBadgeShadows)],
            // A free-form dev label (DEV_LABEL) — marks which dev build/session is
            // running; absent in release builds. Unlike the header (where it takes the
            // badge's place), here it's shown alongside it, between the badge and the
            // version name.
            if (devLabel.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              // Slanted by hand, not by `FontStyle.italic`: the bundled
              // RobotoSlab is a variable font with a weight axis and no italic
              // face, so asking for italic renders upright. Negative skew leans
              // the top right — y grows downward, so the shift has to shrink
              // with y.
              Transform(
                transform: Matrix4.skewX(-0.2),
                alignment: Alignment.center,
                child: Text(
                  devLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'RobotoSlab',
                    fontWeight: FontWeight.w700,
                    fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) * 1.2,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
            const SizedBox(height: Space.xl),
            // The release name, without the edition qualifier (the edition is
            // already shown by the badge SVG above), over its patch and build
            // line — a bug report from a release build is the one that most
            // needs to say which build it came from.
            VersionLabel(
              nameAndBuild: true,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) * 1.2,
                color: theme.colorScheme.onSurface,
              ),
              detailStyle: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
