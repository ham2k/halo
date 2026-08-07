// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The tester counterpart of the release overlay (release_overlay.dart):
// shown by `_TesterOverlayGate` in main.dart on the Dev and Next editions
// whenever `kBuildNumber` has advanced past
// `SettingsService.lastSeenTesterBuild`, listing every tester-notes entry
// (config/tester_notes.dart) in between — plus a caution-tape band and a
// standing work-in-progress warning. Deliberately the same full-bleed-photo
// layout as ReleaseOverlayView so it reads as "the what's new screen", with
// the tape making the tester variant unmistakable at a glance. Unlike the
// release overlay's collapsed-preview band, the notes band here is fixed at
// half height, fully readable and scrollable — no expand/collapse.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/release_notes.dart';
import '../config/tester_notes.dart';
import '../config/version.dart';
import '../i18n/strings.g.dart';
import 'ham2k_logo.dart';
import 'release_overlay.dart' show ReleasePhoto, overlayCreditsText, overlayCreditsStyle, overlayVersionLabelStyle;
import 'version_label.dart';

// Same fixed (theme-mode-independent) palette as release_overlay.dart — this
// panel also sits over a photo, not the app chrome.
const _panelBackground = Color(0xFFFBFCFE);
const _photoFallbackColor = Color(0xFFBCE9FF);
const _bandColor = Colors.white;
const _bandOpacity = 0.75;
const _bandHeightFactor = 0.5;
// The band's fixed chrome (tape padding, the button row, safe-area insets)
// needs this much room; on viewports where half the height is less (a phone
// in landscape at a large font scale), the band takes more than half rather
// than overflowing its Column.
const _bandMinHeight = 220.0;

const _tapeYellow = Color(0xFFF2C300);
const _tapeBlack = Color(0xFF1A1A1A);
const _tapeHeight = 53.0;

/// True while a [TesterOverlayView] is mounted and covering the app.
///
/// The overlay's own [Focus] node swallows focus-tree key events, but
/// HardwareKeyboard handlers run BEFORE the focus tree and can't be blocked
/// from here — without this signal, Enter dismisses the overlay AND advances
/// the onboarding flow beneath it in the same keystroke, and ⌘K opens the
/// command dialog invisibly under the overlay. Every global key handler
/// (onboarding_overlay.dart, main.dart's app chords) consults this and
/// stands down while the overlay owns the keyboard.
final ValueNotifier<bool> testerOverlayCovering = ValueNotifier(false);

/// The yellow/black "caution tape" band: [label] once in the center, with
/// full-height diagonal black bars filling the rest. Painted (not an image
/// asset) so it stays crisp at any width and UI scale.
class CautionTape extends StatelessWidget {
  final String label;

  const CautionTape({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _tapeHeight,
      decoration: const BoxDecoration(
        color: _tapeYellow,
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: CustomPaint(painter: _CautionTapePainter(label), size: Size.infinite),
    );
  }
}

class _CautionTapePainter extends CustomPainter {
  final String label;

  _CautionTapePainter(this.label);

  @override
  void paint(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: _tapeBlack, fontWeight: FontWeight.w900, fontSize: 30, letterSpacing: 1.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // The label sits once, centered; the bars stop clear of it on both
    // sides. On a tape narrower than the label (a phone, or any window at a
    // large UI scale) the label scales down to fit — unscaled it would clip
    // mid-word at both edges. The label is capped below the full tape width
    // so a run of bars survives on each side; scaling to exactly the width
    // minus the gaps would leave zero room for any bars at all.
    const gap = 24.0;
    const minBars = 48.0; // room kept for the bars on EACH side of the label
    final maxTextWidth = math.max(1.0, size.width - 2 * (gap + minBars));
    final scale = math.min(1.0, maxTextWidth / math.max(1.0, text.width));
    final drawnWidth = text.width * scale;
    final textLeft = (size.width - drawnWidth) / 2;
    _paintStripes(canvas, Rect.fromLTWH(0, 0, textLeft - gap, size.height));
    _paintStripes(canvas, Rect.fromLTRB(textLeft + drawnWidth + gap, 0, size.width, size.height));
    canvas.save();
    canvas.translate(textLeft, (size.height - text.height * scale) / 2);
    canvas.scale(scale);
    text.paint(canvas, Offset.zero);
    canvas.restore();
    text.dispose();
  }

  /// Parallelograms leaning 45°, marching across [strip]. The phase is
  /// anchored to the canvas origin (not the strip's own left edge) so the
  /// bars left and right of the label stay in step with each other.
  void _paintStripes(Canvas canvas, Rect strip) {
    if (strip.width <= 0) return;
    final paint = Paint()..color = _tapeBlack;
    const stripe = 28.0; // black width; the yellow gap between bars matches
    const period = stripe * 2;
    canvas.save();
    canvas.clipRect(strip);
    for (double x = strip.left - strip.left % period - period - strip.height; x < strip.right; x += period) {
      canvas.drawPath(
        Path()
          ..moveTo(x, strip.bottom)
          ..lineTo(x + strip.height, strip.top)
          ..lineTo(x + strip.height + stripe, strip.top)
          ..lineTo(x + stripe, strip.bottom)
          ..close(),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CautionTapePainter oldDelegate) => oldDelegate.label != label;
}

class TesterOverlayView extends StatefulWidget {
  /// The pending tester-notes entries, newest first.
  final List<TesterNotesEntry> entries;

  /// The newest release's entry — only its photo is used, so the backdrop
  /// matches the release overlay's imagery. Null (flat fallback color) when
  /// release notes are unavailable.
  final ReleaseNotesEntry? release;
  final VoidCallback onDismiss;

  const TesterOverlayView({super.key, required this.entries, required this.release, required this.onDismiss});

  @override
  State<TesterOverlayView> createState() => _TesterOverlayViewState();
}

class _TesterOverlayViewState extends State<TesterOverlayView> {
  final _focusNode = FocusNode(debugLabel: 'TesterOverlay');

  /// Whatever held focus before the overlay took it — restored on dismissal
  /// so the logging call field (whose autofocus fires once, at mount) isn't
  /// left dead after the overlay closes.
  FocusNode? _previousFocus;

  @override
  void initState() {
    super.initState();
    testerOverlayCovering.value = true;
    // Taken explicitly, not via `autofocus` — autofocus is only honored when
    // nothing else holds focus, and over the home screen the logging call
    // field already does. The overlay owns the keyboard while shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _previousFocus = FocusManager.instance.primaryFocus;
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    testerOverlayCovering.value = false;
    final previous = _previousFocus;
    if (previous != null && previous.context != null) previous.requestFocus();
    _focusNode.dispose();
    super.dispose();
  }

  /// Esc and Enter continue (same as tapping); everything else is swallowed
  /// so no focus-tree keystroke leaks into whatever sits beneath. Global
  /// HardwareKeyboard handlers dispatch ahead of this node — those stand
  /// down via [testerOverlayCovering] instead.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      widget.onDismiss();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    // A fixed light panel over a photo, so the subtree is pinned to the
    // light theme — same pin as ReleaseOverlayView: anything not explicitly
    // forced below (markdown styles beyond p/listBullet/strong, scrollbars,
    // ink) would otherwise paint dark-mode colors onto the white band.
    //
    // Content in its own widget below the pin, same rule as
    // [OnboardingOverlayView], which documents why: nothing on a class that
    // pins a theme may read one.
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: Theme(
        data: buildHaLoTheme(Brightness.light),
        child: _TesterPanel(
          entries: widget.entries,
          release: widget.release,
          onDismiss: widget.onDismiss,
        ),
      ),
    );
  }
}

/// The overlay's content, built BELOW the light-theme pin — see
/// [_TesterOverlayViewState.build] for why this is a widget and not a method.
class _TesterPanel extends StatelessWidget {
  final List<TesterNotesEntry> entries;
  final ReleaseNotesEntry? release;
  final VoidCallback onDismiss;

  const _TesterPanel({required this.entries, required this.release, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    // A local, so the null check below promotes it — a PUBLIC field never
    // does. (Dart promotes private final fields; this one can't be private,
    // it's a constructor parameter of a widget.)
    final release = this.release;
    // Theme.of below the pin, never a bare `buildHaLoTheme()` read — a
    // standalone ThemeData isn't fully resolved the way a Theme threaded
    // through the widget tree is (its textTheme font sizes come back null,
    // tripping flutter_markdown's assertion).
    final theme = Theme.of(context);
    final versionLabelStyle = overlayVersionLabelStyle(theme);
    final creditsStyle = overlayCreditsStyle(theme);
    final notesFontSize = (theme.textTheme.bodyMedium?.fontSize ?? 14) * 1.2;
    final notesStyleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(fontSize: notesFontSize, color: Colors.black),
      listBullet: theme.textTheme.bodyMedium?.copyWith(fontSize: notesFontSize, color: Colors.black),
      strong: theme.textTheme.bodyMedium?.copyWith(
        fontSize: notesFontSize * 1.15,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );

    // The standing warning leads, then each pending build's notes, newest
    // first — a tester several builds behind catches up in one read.
    final notesLines = <String>[
      '**${context.t.testerOverlay.warningTitle}**',
      '',
      context.t.testerOverlay.warningBody,
      for (final entry in entries) ...[
        '',
        '**${context.t.testerOverlay.whatsNew(build: entry.build)}**',
        '',
        ...entry.changes.map((change) => '- $change'),
      ],
    ];
    final notesMarkdown = notesLines.join('\n');

    // The RUNNING build (kBuildNumber), not the newest notes entry, which can
    // lag it when a build ships without notes of its own. Named here even in a
    // Dev build, where the home and About displays (version_label.dart's
    // buildDetails) normally suppress it: tester notes are KEYED by build number, so the
    // heading says which notes these are. No code-push suffix either — notes
    // are keyed by the binary, and a push carries none of its own.
    final buildLabel = context.t.testerOverlay.build(build: kBuildNumber.toString());

    final panel = Material(
      color: _panelBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;
          final bandHeight = math.max(totalHeight * _bandHeightFactor, math.min(totalHeight, _bandMinHeight));

          // A tap anywhere — the notes text included — dismisses; only the
          // Continue button carves out its own tap target (same absorption
          // pattern as ReleaseOverlayView). Scrolling the notes is a drag,
          // which never triggers this tap handler.
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: release == null
                      ? const ColoredBox(color: _photoFallbackColor)
                      : ReleasePhoto(
                          imageAssetPath: release.imageAssetPath,
                          errorBuilder: (context, error, stackTrace) => const ColoredBox(color: _photoFallbackColor),
                        ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: Space.xl),
                        const Center(child: Ham2kBrandMark(logoWidth: 180, showShadow: true)),
                        const SizedBox(height: Space.md),
                        overlayCreditsText(context.t.startScreen.credits, creditsStyle),
                        const SizedBox(height: Space.xs),
                        // The full release name (kVersionName), like the
                        // splash and onboarding, with the build number —
                        // what tester-notes entries are keyed by — beneath.
                        VersionLabel(nameOnly: true, style: versionLabelStyle),
                        Text(buildLabel, textAlign: TextAlign.center, style: creditsStyle),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: bandHeight,
                  child: ColoredBox(
                    color: _bandColor.withValues(alpha: _bandOpacity),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        // Extra top room so the notes start below the tape,
                        // which straddles the band's top edge.
                        padding: const EdgeInsets.fromLTRB(Space.xxl, _tapeHeight, Space.xxl, Space.md),
                        // Caps the notes and the Continue button at the ideal
                        // reading width, centered — same convention as the
                        // onboarding steps (onboarding_overlay.dart) —
                        // otherwise both stretch edge-to-edge full screen.
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: idealPaneWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  // The LayoutBuilder reads the viewport
                                  // height the scroll view is about to get,
                                  // so the gap below the notes is a full
                                  // "page" — the GIF and the thank-you only
                                  // appear to a tester who deliberately
                                  // scrolls past the end of the text.
                                  child: LayoutBuilder(
                                    builder: (context, viewport) => SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          MarkdownBody(data: notesMarkdown, styleSheet: notesStyleSheet),
                                          SizedBox(height: viewport.maxHeight),
                                          // A vintage-web nod to match the
                                          // tape: the classic animated
                                          // construction-guy GIF, at its
                                          // native pixel size.
                                          Center(child: Image.asset('assets/images/under.gif')),
                                          const SizedBox(height: Space.md),
                                          Text(
                                            context.t.testerOverlay.thanks,
                                            textAlign: TextAlign.center,
                                            style: notesStyleSheet.p,
                                          ),
                                        ],
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
                    ),
                  ),
                ),
                // The tape rides the notes band's top edge, above it in paint
                // order. IgnorePointer: it's decoration — taps through it
                // still dismiss via the outer handler.
                // Clamped at 0: on a viewport shorter than the band's own
                // minimum the band fills the whole height, and an unclamped
                // offset would push the tape above the Stack's clip.
                Positioned(
                  left: 0,
                  right: 0,
                  top: math.max(0, totalHeight - bandHeight - _tapeHeight / 2),
                  child: IgnorePointer(child: CautionTape(label: context.t.testerOverlay.tape)),
                ),
              ],
            ),
          );
        },
      ),
    );
    return panel;
  }
}
