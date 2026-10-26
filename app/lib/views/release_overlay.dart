// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The dismissible "what's new" overlay shown once per new version on
// startup. Shown by `_StartupGate` in main.dart when
// `config/release_notes.dart`'s current entry hasn't been dismissed yet
// (SettingsService.lastSeenReleaseVersion); dismissing it persists that
// version so it doesn't show again until the next release.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/release_notes.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'ham2k_logo.dart';
import 'version_label.dart';

// The shared photo-overlay drop shadow (single source of truth in ham2k_logo.dart,
// so the credits/version labels and the edition badge always match).
const _creditsAndVersionShadows = kOverlayDropShadows;
// Fixed regardless of the app's theme mode — halo_widgets/theme.dart's light
// ColorScheme.surface/primaryContainer values, hardcoded here rather than
// read from Theme.of(context) so this panel never picks up dark mode.
const _panelBackground = Color(0xFFFBFCFE);
const _photoFallbackColor = Color(0xFFBCE9FF);
const _bandColor = Colors.white;
const _bandOpacityCollapsed = 0.35;
const _bandOpacityExpanded = 0.75;
const _bandHeightFactorCollapsed = 0.25;
const _bandHeightFactorExpanded = 2 / 3;
const _bandAnimationDuration = Duration(milliseconds: 250);

/// A release photo (`ReleaseNotesEntry.imageAssetPath`) that precaches and
/// crossfades in once actually loaded, instead of popping in abruptly — a
/// JPEG several hundred KB, real weight on web. Shared by every place that
/// paints the same asset: this file's startup overlay and About-screen photo
/// modal below, the onboarding overlay, and the About screen's own header.
class ReleasePhoto extends StatefulWidget {
  final String imageAssetPath;
  final ImageErrorWidgetBuilder errorBuilder;

  const ReleasePhoto({super.key, required this.imageAssetPath, required this.errorBuilder});

  @override
  State<ReleasePhoto> createState() => _ReleasePhotoState();
}

class _ReleasePhotoState extends State<ReleasePhoto> {
  bool _ready = false;
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guarded to run once per mount: didChangeDependencies can re-fire (e.g.
    // a MediaQuery change), and re-listening to the same image's stream on
    // every one of those would be pure waste.
    if (_precached) return;
    _precached = true;
    // Resolves even on a failed/missing image (the completer completes from
    // the stream's onError branch too) — this build's own errorBuilder is
    // what actually renders the fallback; _ready just means "stop waiting",
    // not "succeeded".
    precacheImage(AssetImage(widget.imageAssetPath), context).then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _ready ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Image.asset(widget.imageAssetPath, fit: BoxFit.cover, errorBuilder: widget.errorBuilder),
    );
  }
}

/// The "KI2D" callsign in the credits line ("by KI2D and friends"/"por KI2D
/// y amigos") reads as a monospace callsign rather than plain prose — every
/// translation keeps the callsign untranslated, so splitting on the literal
/// substring works across locales. Public: the onboarding overlay renders
/// the same credits line.
Widget overlayCreditsText(String text, TextStyle style) {
  const callsign = 'KI2D';
  final index = text.indexOf(callsign);
  if (index < 0) return Text(text, textAlign: TextAlign.center, style: style);
  return Text.rich(
    TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, index)),
        TextSpan(
          text: callsign,
          style: style.copyWith(fontFamily: 'RobotoMono'),
        ),
        TextSpan(text: text.substring(index + callsign.length)),
      ],
    ),
    textAlign: TextAlign.center,
  );
}

/// The photo-overlay header typography shared by the release overlay, the
/// About photo modal, and the onboarding overlay — one source of truth so
/// the brand header reads at the same scale on all three.
TextStyle? overlayVersionLabelStyle(ThemeData theme) => theme.textTheme.titleMedium?.copyWith(
  fontSize: (theme.textTheme.titleMedium?.fontSize ?? 16) * 2,
  fontWeight: FontWeight.bold,
  color: Colors.white,
  shadows: _creditsAndVersionShadows,
);

/// The header the photo overlays share — brand mark, credits, and the version's
/// two lines — pinned to the TOP of the photo, above the notes band.
///
/// It sits in a Stack-tight column with no room to grow and nothing to scroll,
/// so a block taller than the viewport (a phone in landscape, or any window at a
/// large Font Scale, which divides the logical viewport —
/// docs/design/ui-scaling.md) would paint overflow stripes across the release
/// photo; scaling it down as one block is what keeps the version name larger
/// than the build line under it.
///
/// Two constraints hold that in place, and both are easy to lose:
/// * the fixed inner WIDTH makes the [FittedBox] scale on height alone. Handed
///   unbounded width instead, it shrinks the whole header — brand mark included
///   — to whatever the unwrappable version name asks for.
/// * the [Align]: under the Stack's tight constraints the header would
///   otherwise take the full photo and float down its middle. Align also
///   loosens those constraints, which is what lets the block size to its
///   content and scale.
///
/// It deliberately measures only itself, never the notes band below. Scaling to
/// the room above the band reads as the tidier rule and is a trap: the band's
/// height lives in another coordinate space (this subtree is already inset by
/// SafeArea and the callers' padding), it animates while this doesn't, and the
/// onboarding band is content-sized on its first step — so the arithmetic ends
/// up subtracting a height that is wrong, stale, or larger than what is left,
/// and the header silently stops painting. The cost is that a short viewport's
/// notes band covers the version lines — fully, on a small phone — which is
/// what the layout did before this header existed.
///
/// [bareBuildNumber] is the tester overlay's rule — see [versionBuildLine].
Widget overlayVersionHeader(BuildContext context, {required double logoWidth, bool bareBuildNumber = false}) {
  final theme = Theme.of(context);
  final creditsStyle = overlayCreditsStyle(theme);
  return LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.topCenter,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: constraints.maxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Space.xl),
              Ham2kBrandMark(logoWidth: logoWidth, showShadow: true),
              const SizedBox(height: Space.md),
              overlayCreditsText(context.t.startScreen.credits, creditsStyle),
              const SizedBox(height: Space.xs),
              // The RUNNING build's version, not the notes entry's `name` — all
              // three overlays name what the reader is running, and the notes
              // below say which release they describe.
              VersionLabel(nameAndBuild: true, style: overlayVersionLabelStyle(theme), detailStyle: creditsStyle, bareBuildNumber: bareBuildNumber),
            ],
          ),
        ),
      ),
    ),
  );
}

TextStyle overlayCreditsStyle(ThemeData theme) =>
    TextStyle(fontSize: (overlayVersionLabelStyle(theme)?.fontSize ?? 32) * 0.75 * 0.85, color: Colors.white, shadows: _creditsAndVersionShadows);

class ReleaseOverlayView extends StatefulWidget {
  final ReleaseNotesEntry release;
  final VoidCallback onDismiss;

  const ReleaseOverlayView({super.key, required this.release, required this.onDismiss});

  @override
  State<ReleaseOverlayView> createState() => _ReleaseOverlayViewState();
}

class _ReleaseOverlayViewState extends State<ReleaseOverlayView> {
  bool _expanded = false;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    // This panel's colors are fixed regardless of the app's light/dark theme
    // mode (it sits over a photo, not the app chrome), so the subtree is
    // pinned to the light theme — anything not explicitly forced below
    // (markdown styles beyond p/listBullet/strong, scrollbars, ink) would
    // otherwise paint dark-mode colors onto the white band.
    //
    // Content in its own widget below the pin, same rule as
    // [OnboardingOverlayView], which documents why: nothing on a class that
    // pins a theme may read one.
    return Theme(
      data: buildHaLoTheme(Brightness.light),
      child: _ReleaseOverlayContent(release: widget.release, onDismiss: widget.onDismiss, expanded: _expanded, onToggleExpanded: _toggleExpanded),
    );
  }
}

/// The overlay's content, built BELOW the light-theme pin — see
/// [_ReleaseOverlayViewState.build] for why this is a widget and not a method.
class _ReleaseOverlayContent extends StatelessWidget {
  final ReleaseNotesEntry release;
  final VoidCallback onDismiss;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  const _ReleaseOverlayContent({required this.release, required this.onDismiss, required this.expanded, required this.onToggleExpanded});

  @override
  Widget build(BuildContext context) {
    // Theme.of below the pin, never a bare `buildHaLoTheme()` read — a
    // standalone ThemeData isn't fully resolved the way a Theme threaded
    // through the widget tree is (its textTheme font sizes come back null,
    // tripping flutter_markdown's assertion).
    final theme = Theme.of(context);
    final creditsStyle = overlayCreditsStyle(theme);
    // flutter_markdown's `fromTheme` bases `p`/`listBullet` on bodyMedium.
    // `color: Colors.black` is explicit on all three — bodyMedium's own
    // color isn't set, so without this they'd inherit whatever color
    // Flutter's default TextTheme picks for the (fixed, but still
    // technically light) `theme` above.
    final notesFontSize = (theme.textTheme.bodyMedium?.fontSize ?? 14) * 1.2;
    final notesStyle = theme.textTheme.bodyMedium?.copyWith(fontSize: notesFontSize, color: Colors.black);
    MarkdownStyleSheet notesStyleSheet(MarkdownStyleSheet base) => base.copyWith(
      p: notesStyle,
      listBullet: notesStyle,
      strong: theme.textTheme.bodyMedium?.copyWith(fontSize: notesFontSize * 1.15, fontWeight: FontWeight.bold, color: Colors.black),
    );

    // "What's new in this release" is bold via markdown's `**...**` rather
    // than a separate Text, so `strong` above is the only place its
    // size/weight is set.
    final notesLines = <String>["**What's new in this release**", '', ...release.changes.map((change) => '- $change')];
    final notesMarkdown = notesLines.join('\n');

    return Material(
      color: _panelBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The band's own available height (not the screen's) — matters on
          // the desktop modal presentation, where this widget is confined to
          // a pane-sized box smaller than the window (see main.dart).
          final totalHeight = constraints.maxHeight;
          final bandHeight = totalHeight * (expanded ? _bandHeightFactorExpanded : _bandHeightFactorCollapsed);
          final bandOpacity = expanded ? _bandOpacityExpanded : _bandOpacityCollapsed;

          // Tapping anywhere in the view dismisses it, EXCEPT the notes text
          // (its own GestureDetector below toggles expand/collapse instead)
          // and the Continue button (its own tap target) — both are
          // descendants with their own `onTap`, which (same pattern as
          // halo_widgets' modal_pane.dart barrier/card split) wins over this
          // outer handler for their specific regions instead of also
          // triggering it.
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ReleasePhoto(
                    imageAssetPath: release.imageAssetPath,
                    errorBuilder: (context, error, stackTrace) => ColoredBox(color: _photoFallbackColor),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xl),
                    child: overlayVersionHeader(context, logoWidth: 180),
                  ),
                ),
                // The caption and the notes band are siblings in ONE
                // Positioned/Column, not two separate Positioned widgets — a
                // standalone Positioned here for just the caption breaks the
                // photo's rendering (a reproducible CanvasKit compositing
                // issue with this many overlapping top-level Positioned
                // layers). Tapping the notes area (not the Continue button)
                // toggles between a short, non-scrollable preview and an
                // expanded, scrollable view; the band's height/opacity and the
                // caption's fade-out both animate off of `expanded`.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (release.photoCaption.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(Space.xxl, 0, Space.xxl, Space.md),
                          child: AnimatedOpacity(
                            duration: _bandAnimationDuration,
                            curve: Curves.easeInOut,
                            opacity: expanded ? 0 : 1,
                            child: Text(
                              release.photoCaption,
                              textAlign: TextAlign.center,
                              style: creditsStyle.copyWith(fontFamily: 'RobotoMono', fontSize: creditsStyle.fontSize! * 0.85),
                            ),
                          ),
                        ),
                      AnimatedContainer(
                        duration: _bandAnimationDuration,
                        curve: Curves.easeInOut,
                        height: bandHeight,
                        color: _bandColor.withValues(alpha: bandOpacity),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: onToggleExpanded,
                                    child: ClipRect(
                                      child: expanded
                                          ? SingleChildScrollView(
                                              child: HaloMarkdown(data: notesMarkdown, style: notesStyleSheet),
                                            )
                                          // A `ShaderMask` in `dstIn` mode fades
                                          // the notes' own alpha directly
                                          // (revealing whatever's underneath,
                                          // same as a real fade-to-transparent)
                                          // — a decorative gradient-colored box
                                          // painted on top instead only
                                          // approximates that, and doesn't read
                                          // as a fade at all against the band's
                                          // own semi-transparent color.
                                          : ShaderMask(
                                              shaderCallback: (bounds) => const LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [Colors.white, Colors.white, Colors.transparent],
                                                stops: [0, 0.75, 1],
                                              ).createShader(bounds),
                                              blendMode: BlendMode.dstIn,
                                              // `SingleChildScrollView`
                                              // (scrolling disabled) rather
                                              // than the bare `MarkdownBody`
                                              // directly: it gives its child
                                              // unbounded height along the
                                              // scroll axis, so the notes'
                                              // natural (taller-than-the-band)
                                              // size never trips a RenderFlex
                                              // overflow — `ClipRect` above
                                              // still clips it to the band's
                                              // height.
                                              child: SingleChildScrollView(
                                                physics: const NeverScrollableScrollPhysics(),
                                                child: HaloMarkdown(data: notesMarkdown, style: notesStyleSheet),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: Space.md),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(onPressed: onDismiss, child: Text(context.t.onboarding.kContinue)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The shared "blurred backdrop + centered elevated card" chrome behind
/// both the startup release overlay (main.dart's `_ReleaseOverlayGateState`)
/// and the About screen's photo modal below — wide/two-pane layouts only;
/// each caller handles the narrow-layout (full-screen, no chrome) branch
/// itself, since they differ in where [child] paints from (an existing
/// `Stack` vs. a fresh `Navigator` route).
///
/// Fixed (not just max-bounded) width/height: content inside [child] that
/// needs a determinate parent size to divide (an `Expanded`/scrollable
/// section) requires this — same reasoning as `modal_pane.dart`'s
/// non-scrollable dialog case (its own `minHeight: maxPaneHeight`). Sized
/// deliberately outside `modal_pane.dart`'s usual `idealPaneWidth` width
/// convention: 70% of the window's width. The height is the shared
/// `haloDialogConstraints` cap, which `HaloDialogFrame` places.
Widget wideModalChrome({required BuildContext context, required Widget child, required VoidCallback onDismiss}) {
  final windowSize = MediaQuery.sizeOf(context);
  final paneWidth = windowSize.width * 0.7;
  final maxPaneHeight = haloDialogConstraints(context).maxHeight;
  final Widget content = BackdropFilter(
    // Blurs whatever's painted just behind this in the same compositing
    // layer (the home screen, or — for the About modal — the settings pane).
    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
    // Tapping the barrier (outside the card) dismisses, same as
    // ModalPaneRoute's dialog barrier (modal_pane.dart). [child] is expected
    // to have its own top-level GestureDetector(onDismiss) covering the card
    // itself, which — same absorption pattern as modal_pane.dart's
    // barrier/card split — wins over this one for taps that land on the
    // card, so there's no need to separately guard against double-dismissal.
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.2),
        child: HaloDialogFrame(
          child: SizedBox(
            width: paneWidth,
            height: maxPaneHeight,
            // A sharper, darker glow than Material's soft ambient elevation
            // shadow: a symmetric (offset-zero) dark halo hugging the card's
            // rounded corners, so it reads crisply against the blurred
            // backdrop. The Material below carries no elevation of its own —
            // it's just the rounded, clipped surface for [child].
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.85), blurRadius: 22, spreadRadius: 2)],
              ),
              child: Material(elevation: 0, borderRadius: BorderRadius.circular(28), clipBehavior: Clip.antiAlias, child: child),
            ),
          ),
        ),
      ),
    ),
  );
  return _BlurredModalActiveScope(child: content);
}

/// A blurred-background modal (built by [wideModalChrome]) brackets itself
/// with [enterBlurredModal]/[exitBlurredModal] for as long as it's mounted, so
/// the macOS traffic-light mask hides for its duration. The depth is updated
/// synchronously here; the mask's own rebuild is deferred a frame inside those
/// helpers (touching the notifier mid-build would markNeedsBuild the mask).
class _BlurredModalActiveScope extends StatefulWidget {
  final Widget child;
  const _BlurredModalActiveScope({required this.child});

  @override
  State<_BlurredModalActiveScope> createState() => _BlurredModalActiveScopeState();
}

class _BlurredModalActiveScopeState extends State<_BlurredModalActiveScope> {
  @override
  void initState() {
    super.initState();
    enterBlurredModal();
  }

  @override
  void dispose() {
    exitBlurredModal();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The About screen's wordmark, tapped, opens this — same blurred-backdrop
/// full-bleed-photo look as the startup release overlay above, and the same
/// top section (brand mark, credits, release name) and photo-credit caption
/// at the bottom, but nothing to read or act on below that: no notes band,
/// no Continue button — dismissed by a tap anywhere instead.
Future<void> showPhotoWordmarkModal(BuildContext context, {required ReleaseNotesEntry? release}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    pageBuilder: (context, animation, secondaryAnimation) => HoldSizeWhileCovered(child: _PhotoWordmarkOverlay(release: release)),
  );
}

class _PhotoWordmarkOverlay extends StatelessWidget {
  final ReleaseNotesEntry? release;

  const _PhotoWordmarkOverlay({required this.release});

  @override
  Widget build(BuildContext context) {
    void dismiss() => Navigator.of(context).pop();

    if (!ShirtSize.of(context).isTwoPane) {
      return _PhotoWordmarkContent(release: release, onDismiss: dismiss);
    }
    return wideModalChrome(
      context: context,
      onDismiss: dismiss,
      child: _PhotoWordmarkContent(release: release, onDismiss: dismiss),
    );
  }
}

class _PhotoWordmarkContent extends StatelessWidget {
  final ReleaseNotesEntry? release;
  final VoidCallback onDismiss;

  const _PhotoWordmarkContent({required this.release, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    // Pinned to the light theme like ReleaseOverlayView above — everything
    // here is forced white today, but the pin keeps any future addition on
    // the fixed palette too. Content in its own widget below the pin, same
    // rule as [OnboardingOverlayView].
    return Theme(
      data: buildHaLoTheme(Brightness.light),
      child: _PhotoWordmarkBody(release: release, onDismiss: onDismiss),
    );
  }
}

/// Built BELOW [_PhotoWordmarkContent]'s pin, so its context is the pinned one.
class _PhotoWordmarkBody extends StatelessWidget {
  final ReleaseNotesEntry? release;
  final VoidCallback onDismiss;

  const _PhotoWordmarkBody({required this.release, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    // Same sizing math as ReleaseOverlayView above, so the brand mark,
    // credits, release name, and caption all read at the same relative
    // scale here as they do on the startup overlay.
    final theme = Theme.of(context);
    final creditsStyle = overlayCreditsStyle(theme);
    final caption = release?.photoCaption;

    return GestureDetector(
      onTap: onDismiss,
      child: Material(
        color: _photoFallbackColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (release != null) ReleasePhoto(imageAssetPath: release!.imageAssetPath, errorBuilder: (context, error, stackTrace) => const SizedBox.shrink()),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xl),
                child: overlayVersionHeader(context, logoWidth: 180),
              ),
            ),
            if (caption != null && caption.isNotEmpty)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.xxl, 0, Space.xxl, Space.xl),
                    child: Text(
                      caption,
                      textAlign: TextAlign.center,
                      style: creditsStyle.copyWith(fontFamily: 'RobotoMono', fontSize: creditsStyle.fontSize! * 0.85),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
