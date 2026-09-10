// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Modal Panes (docs/design/layouts.md): pane-sized modal content, designed
// at idealPaneWidth. On XS/S shirt sizes it presents as a full screen whose
// AppBar back button IS the dismissal; on L/XL as a centered dialog with
// barrier/Escape dismissal. It is ONE route that checks the shirt size on
// every build, so a pane that's open while the window is resized across the
// S/L boundary re-presents in place — no pop-and-reshow, no lost state, and
// `Navigator.pop(context, result)` resolves the same `await` either way.
//
// For brief messages or one-or-two-field prompts keep using plain
// `showDialog` — Modal Panes are for content that fills a pane.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'halo_dialog.dart';
import 'density.dart';
import 'layout.dart';
import 'mdi_icons.g.dart';
import 'platform_chrome.dart';
import 'spacing.dart';
import 'theme.dart';

/// `showDialog` with the app's shared modal sizing applied
/// ([haloDialogConstraints]) — use this instead of `showDialog` directly so
/// every dialog is held to the same box as a Modal Pane rather than each
/// growing to fit its own content.
Future<T?> showHaloDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierColor: haloBarrierColor(context),
  // Center first: showDialog hands its builder TIGHT full-screen constraints,
  // and a ConstrainedBox can't shrink below a tight incoming width — the cap
  // would silently do nothing. Center loosens them so the cap actually bites.
  builder: (context) => Center(
    child: ConstrainedBox(constraints: haloDialogConstraints(context), child: builder(context)),
  ),
);

/// Shows [builder]'s content as a Modal Pane and completes with the value
/// passed to `Navigator.pop`. Call it like `showDialog`.
///
/// With `scrollable: false` the body is NOT wrapped in a scroll view: it
/// gets a BOUNDED height (edge to edge, no padding) and manages its own
/// layout — for content built around Expanded sections or its own
/// scrollables (e.g. the Activities pane's accordion), which would otherwise
/// sit in unbounded height and fail to lay out. The dialog presentation
/// OFFERS that height rather than imposing it: a body that fills it (a flex
/// Column, a ListView) still gets the pane's full height, while one that
/// asks for less ([showFormPane]'s short forms) gets a card that fits it.
/// Full screen the pane IS the screen, so the height is the screen's either way.
///
/// Action rows are the pane's own job (every current pane's buttons depend
/// on its State — _busy, _testing, mode — which a route-level builder can't
/// see), so there is deliberately no `actions` parameter here.
///
/// [headerActions] is the exception, and a narrow one: buttons that belong to
/// the pane as a whole rather than to its content — the Exports pane's
/// settings gear. Unlike [trailing] they sit ALONGSIDE whatever dismissal the
/// header carries rather than replacing it, which is what a pane needs when it
/// wants an extra control and the usual dismissal both.
///
/// [fillHeight] takes the DIALOG presentation's full height instead of
/// shrink-wrapping the body, for a pane whose content changes size as the
/// operator works it — a list under a filter, sections that fold. Without it
/// the card grows and shrinks under the pointer and every row moves. The
/// full-screen presentation already fills the screen, so this changes
/// nothing there. Leave it off for a body that is simply short: a half-empty
/// full-height card is worse than a small one.
Future<T?> showModalPane<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool barrierDismissible = true,
  bool scrollable = true,
  Widget? leading,
  Widget? trailing,
  List<Widget> headerActions = const [],
  String closeLabel = 'Close',
  bool closeButton = true,
  bool fillHeight = false,
}) => Navigator.of(context).push(
  ModalPaneRoute<T>(
    builder: builder,
    title: title,
    barrierDismissible: barrierDismissible,
    scrollable: scrollable,
    leading: leading,
    trailing: trailing,
    headerActions: headerActions,
    closeLabel: closeLabel,
    closeButton: closeButton,
    fillHeight: fillHeight,
  ),
);

class ModalPaneRoute<T> extends PopupRoute<T> implements TapDismissibleRoute {
  final WidgetBuilder builder;
  final String? title;
  final bool scrollable;

  /// The constructor's `barrierDismissible` — despite the name, this only
  /// gates OUR OWN tap-outside `GestureDetector` in [_ModalPaneScaffold]
  /// (`_buildDialog`'s `onTap:`, below). It is deliberately NOT what the
  /// [barrierDismissible] getter returns: that one is read by Flutter's
  /// own `_DismissModalAction` to decide whether Escape does anything at
  /// all (`ModalRoute`'s `barrierDismissible` is the single flag the SDK
  /// overloads for both "tap the barrier" and "press Escape"), and a caller
  /// asking to block a stray tap outside — the only reason any caller here
  /// passes `false` — would silently lose Escape too as a side effect.
  /// [barrierDismissible] always returns true instead; a dismissal it lets
  /// through still goes via `Navigator.maybePop()` (both here and in
  /// Flutter's own action), so a pane's `PopScope` (e.g. `showFormPane`'s,
  /// guarding an in-flight submit) is exactly as effective against Escape
  /// as it already is against the close button and the tap-outside handler.
  final bool _tapOutsideDismissible;
  final Widget? leading;
  final Widget? trailing;

  /// Pane-level buttons shown before the close button — see [showModalPane].
  final List<Widget> headerActions;

  /// The dialog presentation's close-button accessible name (it is icon-only,
  /// and the app has no hover tooltips) — English default so the package stays
  /// i18n-free; the app passes a translated value.
  final String closeLabel;

  /// Whether the dialog presentation heads the pane with an X.
  ///
  /// Off for a pane whose own content ends in a footer band
  /// ([haloDialogFooterBand]): its Done IS the way out, and a second one in
  /// the header is both a verb the operator has to choose between and the
  /// thing that makes these panes read as a different family from every
  /// dialog beside them. The full-screen presentation is unaffected — there
  /// the leading control is the platform's back button, not a close box.
  final bool closeButton;

  /// Whether the DIALOG presentation takes its full allowed height rather
  /// than shrink-wrapping the body — see [showModalPane]. The full-screen
  /// presentation fills the screen either way.
  final bool fillHeight;

  /// Carries the body's Element (and State) across the presentation flip:
  /// the two presentations have different widget trees, so without this
  /// GlobalKey a resize across the S/L boundary would re-inflate the body
  /// and destroy in-progress input.
  final _bodyKey = GlobalKey();

  ModalPaneRoute({
    required this.builder,
    this.title,
    bool barrierDismissible = true,
    this.scrollable = true,
    this.leading,
    this.trailing,
    this.headerActions = const [],
    this.closeLabel = 'Close',
    this.closeButton = true,
    this.fillHeight = false,
  }) : _tapOutsideDismissible = barrierDismissible;

  @override
  Color? get barrierColor => navigator != null ? haloBarrierColor(navigator!.context) : Colors.black54;

  /// Always true — see [_tapOutsideDismissible]'s doc for why this is
  /// deliberately not the constructor's `barrierDismissible` value. Escape
  /// is a keyboard user's only way to back out of a pane that hides its
  /// close button off the visible viewport (a narrow window, a large font
  /// scale) — it must not be silently disabled by the same flag that keeps
  /// a stray tap outside from discarding in-progress edits.
  @override
  bool get barrierDismissible => true;

  /// The tap half of that split, for chrome that paints its own copy of this
  /// route's barrier — see [TapDismissibleRoute]. Without it such a barrier
  /// reads [barrierDismissible] above, and pops the pane on the one tap this
  /// pane was written to refuse.
  @override
  bool get tapOutsideDismissible => _tapOutsideDismissible;

  @override
  String? get barrierLabel => 'Dismiss';

  /// The framework's own auto-inserted `ModalBarrier` gets semantics from
  /// [barrierDismissible]/[barrierLabel] by default — a `role=button` DOM
  /// node the size of the whole screen. It's invisible here (our opaque
  /// transparent-background Scaffold paints over it, and `_buildDialog`'s
  /// own `GestureDetector` re-implements the tap-to-dismiss it would have
  /// provided), but its semantics geometry still exists and, with Flutter
  /// web's accessibility DOM on, sits in front of everything the pane
  /// contains in browser hit-testing — including a platform view (a
  /// webview/GL map) the content embeds, swallowing every click meant for
  /// it before the page ever sees them. False here removes only the
  /// semantics annotation; [barrierDismissible] (Escape) and our own
  /// GestureDetector (pointer taps) are untouched.
  @override
  bool get semanticsDismissible => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      _ModalPaneScaffold(route: this);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

class _ModalPaneScaffold extends StatelessWidget {
  final ModalPaneRoute<dynamic> route;

  const _ModalPaneScaffold({required this.route});

  @override
  Widget build(BuildContext context) {
    // Checked on every build: a window resize across the S/L boundary
    // re-presents the open pane in place. Both presentations share the
    // GlobalKey'd body (so its State reparents instead of re-inflating) and
    // scope their own ScaffoldMessenger: without it, SnackBars raised from
    // pane content land on the Scaffold BENEATH the route — dimmed behind
    // the dialog's barrier and invisible.
    if (ShirtSize.of(context).isTwoPane) return _buildDialog(context);
    return _buildFullScreen(context);
  }

  /// The Builder matters: it hands [ModalPaneRoute.builder] a context that
  /// lives INSIDE the route's scoped ScaffoldMessenger (and Scaffold), so
  /// `ScaffoldMessenger.of` / `Scaffold.of` from the builder's own context
  /// resolve to the route's — same contract as `showDialog`.
  Widget _body() => KeyedSubtree(
    key: route._bodyKey,
    child: Builder(builder: route.builder),
  );

  Widget _buildFullScreen(BuildContext context) {
    return ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(
          // Full-screen presentation puts this AppBar at the window top, so
          // it doubles as the window header.
          flexibleSpace: windowHeaderGestureArea(),
          // The back button is the dismissal — same Navigator.pop as the
          // dialog presentation's close button.
          leadingWidth: route.leading != null ? null : macOSAwareLeadingWidth(context),
          leading: route.leading ?? macOSAwareBackButton(context),
          title: route.title == null ? null : shrinkToFitText(Text(route.title!)),
          actions: [
            ...route.headerActions,
            if (route.trailing != null) route.trailing!,
            windowsCaptionSpacer(context),
          ],
        ),
        body: SafeArea(
          child: route.scrollable
              ? SingleChildScrollView(padding: const EdgeInsets.all(Space.xxl), child: _body())
              // Tight height, because here the pane IS the screen: the
              // Scaffold's body slot is LOOSE, and a body that shrink-wraps
              // given the chance would float its pinned actions up under the
              // last field instead of leaving them on the bottom edge.
              : SizedBox(height: double.infinity, child: _body()),
        ),
      ),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final theme = Theme.of(context);
    // The same box every dialog gets, so panes and plain dialogs read as one
    // family (haloDialogConstraints also guards the height against going
    // negative on a window shorter than the header clearance).
    final dialogConstraints = haloDialogConstraints(context);
    // The transparent full-screen Scaffold exists so the route-scoped
    // ScaffoldMessenger has somewhere to show SnackBars ABOVE the barrier
    // (and it absorbs the keyboard inset like any Scaffold). It covers the
    // framework's ModalBarrier, so the outer GestureDetector re-provides
    // tap-outside dismissal; Escape still goes through the route's own
    // barrierDismissible handling.
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // maybePop, not pop: dismissals (barrier, close button, Escape,
          // the full-screen back button) must respect a PopScope inside the
          // pane's own content — e.g. showFormPane blocks dismissal while a
          // submit is in flight. Deliberate pops (a pane's own Save/Cancel)
          // still call Navigator.pop directly.
          onTap: route._tapOutsideDismissible ? () => Navigator.of(context).maybePop() : null,
          // Neither this detector nor the card's own below should surface as
          // an actionable semantics node: with Flutter's web accessibility
          // DOM on, a `role=button` node sized to the FULL screen/card sits
          // in front of everything under it in browser hit-testing — including
          // any platform view (a webview/GL map) the pane's content embeds,
          // silently swallowing every click meant for it. A screen-reader
          // user reaches the pane's own dismissal instead — the header's close
          // button, or the footer's Done on a pane that declines it
          // ([closeButton]); this pair is pure gesture plumbing with nothing
          // to announce.
          excludeFromSemantics: true,
          child: SafeArea(
            child: Center(
              child: GestureDetector(
                // Taps on the card itself must not fall through to the
                // barrier handler above.
                onTap: () {},
                excludeFromSemantics: true,
                child: ConstrainedBox(
                  // Bounded, never floored: the card is as tall as its body
                  // asks for, up to the shared max. A body built around
                  // Expanded sections still fills this box on its own — that
                  // is what a flex Column does with a bounded height — so it
                  // gets the determinate height it needs without forcing a
                  // body that wants less (a short form) into a full-height card.
                  // [ModalPaneRoute.fillHeight] is the exception, and it needs
                  // no floor here: the Column below takes this box's max on
                  // its own once its mainAxisSize says to.
                  constraints: dialogConstraints,
                  child: Material(
                    color: theme.dialogTheme.backgroundColor ?? haloDialogBandColor(context),
                    elevation: modalSurfaceElevation,
                    shadowColor: haloDialogShadowColor,
                    surfaceTintColor: theme.colorScheme.surfaceTint,
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The same banded header a dialog gets — one shared
                        // widget, so the two families can't drift apart.
                        HaloDialogHeader(
                          leading: route.leading,
                          title: route.title == null ? null : Text(route.title!),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ...route.headerActions,
                              if (route.trailing != null)
                                route.trailing!
                              else if (route.closeButton)
                                IconButton(
                                  icon: Icon(MdiIcons.close, semanticLabel: route.closeLabel),
                                  // maybePop — see the barrier handler above.
                                  onPressed: () => Navigator.of(context).maybePop(),
                                ),
                            ],
                          ),
                        ),
                        // Surface-coloured body framed by the bands. Material,
                        // not ColoredBox: InkWell content paints its splashes
                        // on the nearest Material ancestor.
                        if (route.scrollable)
                          Flexible(
                            // Tight under fillHeight, and that ONE word is
                            // what fills the card: a tight flex child claims
                            // the whole of the box's max height, which the
                            // Column then takes whatever its mainAxisSize
                            // says. Loose, the card is as tall as the body.
                            fit: route.fillHeight ? FlexFit.tight : FlexFit.loose,
                            child: Material(
                              color: theme.colorScheme.surface,
                              child: SizedBox(
                                width: double.infinity,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
                                  child: _body(),
                                ),
                              ),
                            ),
                          )
                        else
                          Flexible(
                            // Edge to edge, no padding — a non-scrollable body
                            // manages its own layout (see showModalPane's doc).
                            // Loose by default: it OFFERS the remaining height
                            // rather than forcing it, so a body that wants less
                            // gets a card that fits it. fillHeight is exactly
                            // the opposite ask — see the scrollable branch.
                            fit: route.fillHeight ? FlexFit.tight : FlexFit.loose,
                            child: Material(color: theme.colorScheme.surface, child: _body()),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [onAnimation] hands the caller the pane's own slide animation (0 closed,
/// 1 fully down) as soon as the route exists, so the screen underneath can
/// animate *with* the pane — nothing else can observe a dismissal until the
/// pushed future completes, which is already after the pane is gone.
///
/// [leftInset], when given, left-aligns the pane at that offset from the
/// screen's left edge instead of centering it — for matching the pane up
/// with a specific control in the header behind it. [rightInset] does the
/// same from the right edge, for a control living at that end of the header.
/// Pass at most one.
///
/// [narrowLeftInset] overrides [leftInset] for [headerLeading] on a narrow
/// layout — see [TopModalPaneRoute.narrowLeftInset].
Future<T?> showTopModalPane<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Widget? title,
  bool barrierDismissible = true,
  bool scrollable = true,
  Widget? leading,
  Widget? trailing,
  String closeLabel = 'Close',
  ValueChanged<Animation<double>>? onAnimation,
  double? leftInset,
  double? narrowLeftInset,
  double? rightInset,
  double? maxWidth,
  EdgeInsetsGeometry? contentPadding,
  VoidCallback? onDismiss,
  Widget? headerTrailing,
  Widget? headerLeading,
  bool showHeader = true,
  bool keepHeaderVisible = false,
}) {
  assert(leftInset == null || rightInset == null, 'a top pane aligns to one edge or the other, not both');
  final route = TopModalPaneRoute<T>(
    maxWidth: maxWidth,
    headerTrailing: headerTrailing,
    headerLeading: headerLeading,
    contentPadding: contentPadding,
    builder: builder,
    title: title,
    barrierDismissible: barrierDismissible,
    scrollable: scrollable,
    leading: leading,
    trailing: trailing,
    closeLabel: closeLabel,
    leftInset: leftInset,
    narrowLeftInset: narrowLeftInset,
    rightInset: rightInset,
    onDismiss: onDismiss,
    showHeader: showHeader,
    keepHeaderVisible: keepHeaderVisible,
  );
  final result = Navigator.of(context).push(route);
  // After push: the route's animation is created by install(), which the
  // push above triggers.
  final animation = route.animation;
  if (animation != null) onAnimation?.call(animation);
  return result;
}

class TopModalPaneRoute<T> extends PopupRoute<T> implements TapDismissibleRoute {
  final WidgetBuilder builder;
  final Widget? title;
  final bool scrollable;

  /// Same split as [ModalPaneRoute._tapOutsideDismissible] — despite the
  /// constructor param's name, this only gates the tap-outside
  /// `GestureDetector`s below. [barrierDismissible] itself always returns
  /// true, so Escape (Flutter's own `_DismissModalAction`, which reads
  /// `ModalRoute.barrierDismissible`) isn't silently disabled by a caller
  /// asking only to block a stray tap outside.
  final bool _tapOutsideDismissible;
  final Widget? leading;
  final Widget? trailing;

  /// See [ModalPaneRoute.closeLabel].
  final String closeLabel;

  /// See [showTopModalPane]'s doc comment. Both null centers.
  final double? leftInset;
  final double? rightInset;

  /// Where [headerLeading] sits on a NARROW layout, when that should not be
  /// [leftInset].
  ///
  /// The two differ because they line up with different things. On wide,
  /// [leftInset] aligns the card — and the control above it — with a
  /// specific control in the header behind. On narrow the card is
  /// full-bleed and has nothing to align with, so [headerLeading] is free to
  /// take the header's own leading corner, which the control it stands in
  /// for has vacated.
  ///
  /// Resolved per build rather than folded into [leftInset] by the caller:
  /// a window resized across the breakpoint while the pane is up would
  /// otherwise keep whichever answer was right when it opened.
  final double? narrowLeftInset;

  /// A narrower card than the shared [maxDialogWidth], for a pane whose
  /// content is a list of short rows rather than a form. Wide layouts only —
  /// a narrow one is full-screen regardless.
  final double? maxWidth;

  /// Around a scrollable body. Defaults to a form's generous inset; pass
  /// [EdgeInsets.zero] for content that supplies its own — full-bleed rows
  /// and section bands read as inset panels floating in the pane otherwise.
  final EdgeInsetsGeometry? contentPadding;

  /// Called when tapping outside the sheet (barrier below or header above).
  final VoidCallback? onDismiss;

  /// Controls drawn at the trailing edge of the strip of view header this
  /// pane leaves uncovered.
  ///
  /// They belong to the VIEW, not to this pane — but the view's own header is
  /// not reachable while a modal route is up: the route's barrier takes the
  /// tap wherever it lands, and the dismiss gesture over the header takes
  /// what's left. A control rendered down there can be seen and never
  /// pressed. Rendered here it sits above both and gets its own taps, while
  /// looking like what it is: part of the header, above the sheet.
  ///
  /// Wide layouts only — a narrow one covers the header completely, so there
  /// is no strip to put anything in.
  final Widget? headerTrailing;

  /// Same idea as [headerTrailing] — reachable above the dismiss layer,
  /// wide layouts only — but positioned at [leftInset] instead of the
  /// trailing edge, for a control that belongs where the pane's own leading
  /// button would otherwise sit (see [showHeader]: a pane with no header of
  /// its own has no leading button to draw there itself), or at
  /// [narrowLeftInset] on a narrow layout that sets one. Left unaligned
  /// (flush to the screen edge) when both are null.
  final Widget? headerLeading;

  /// False removes the [HaloDialogHeader] band entirely — no leading, title,
  /// or trailing, and no height reserved for them — for a pane whose own
  /// accept/dismiss controls live in the view's header instead (reached
  /// through [headerTrailing] there, since the header behind the pane isn't
  /// otherwise tappable — see [headerTrailing]'s own doc). [leading],
  /// [title], and [trailing] are ignored when this is false; dismissal still
  /// works via the barrier, Escape, and [onDismiss].
  final bool showHeader;

  /// True keeps the view's own header uncovered on a narrow layout too,
  /// the way a wide one always does — the pane starts below it instead of
  /// swallowing the whole screen, and [headerLeading]/[headerTrailing]
  /// draw there regardless of [ShirtSize]. For a pane whose header
  /// controls (leading and/or trailing) live entirely in the view behind
  /// it rather than in its own [showHeader] band — a narrow pane with
  /// nowhere else to put them still needs the default full-screen
  /// coverage, so this defaults to false.
  final bool keepHeaderVisible;

  final _bodyKey = GlobalKey();

  TopModalPaneRoute({
    required this.builder,
    this.title,
    bool barrierDismissible = true,
    this.scrollable = true,
    this.leading,
    this.trailing,
    this.closeLabel = 'Close',
    this.leftInset,
    this.narrowLeftInset,
    this.rightInset,
    this.maxWidth,
    this.contentPadding,
    this.onDismiss,
    this.headerTrailing,
    this.headerLeading,
    this.showHeader = true,
    this.keepHeaderVisible = false,
  }) : _tapOutsideDismissible = barrierDismissible;

  @override
  Color? get barrierColor => Colors.transparent;

  /// The tap half of the split, for chrome that paints its own copy of this
  /// route's barrier — see [TapDismissibleRoute].
  @override
  bool get tapOutsideDismissible => _tapOutsideDismissible;

  /// Always true — see [_tapOutsideDismissible]'s doc.
  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  /// See [ModalPaneRoute.semanticsDismissible] — same framework-barrier
  /// semantics footprint, same fully custom (and here, fully painted-by-hand
  /// via [_TopModalPaneScaffold]'s own `AnimatedBuilder`) tap-to-dismiss.
  @override
  bool get semanticsDismissible => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 600);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      _TopModalPaneScaffold(route: this);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class _TopModalPaneScaffold extends StatelessWidget {
  final TopModalPaneRoute<dynamic> route;

  const _TopModalPaneScaffold({required this.route});

  Widget _body() => KeyedSubtree(
    key: route._bodyKey,
    child: Builder(builder: route.builder),
  );

  /// Shared shape for [TopModalPaneRoute.headerTrailing] and
  /// [TopModalPaneRoute.headerLeading] — same visibility guard and vertical
  /// band, differing only in which edge they pin to, what alignment they
  /// use within it, and what they hold. Null (rather than a hidden
  /// `Positioned`) when not shown, so a null-aware spread in the caller's
  /// `Stack` drops it entirely — the same absence [headerTrailing]/
  /// [headerLeading] being null already produces.
  Widget? _headerOverlay({
    required bool visible,
    required Widget? content,
    required double top,
    required double height,
    double? left,
    double? right,
    required AlignmentDirectional alignment,
    required ThemeData theme,
  }) {
    if (!visible || content == null) return null;
    return Positioned(
      top: top,
      left: left,
      right: right,
      height: height,
      // Content here sits outside the real AppBar (this is a floating
      // overlay standing in for it), so it needs the same icon color
      // spelled out explicitly instead of inheriting it — without this,
      // icons resolve through the ambient default IconTheme instead and
      // flash a different color than the header they're covering.
      child: IconTheme.merge(
        data: IconThemeData(color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary),
        child: Align(alignment: alignment, child: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerHeight = theme.appBarTheme.toolbarHeight ?? kToolbarHeight;
    final screenSize = MediaQuery.sizeOf(context);
    // Below S: no room for a floating card — the sheet becomes the screen,
    // the WHOLE screen, covering the header behind it (its own top row
    // supplies the controls); a SafeArea inside the sheet keeps content off
    // the status bar, and only the device's bottom safe area (home
    // indicator) is cleared outside.
    final isNarrow = !ShirtSize.of(context).isTwoPane;
    // keepHeaderVisible reserves the same clearance a wide layout always
    // gets, rather than the full-screen 0 a narrow one otherwise starts
    // at — see [TopModalPaneRoute.keepHeaderVisible].
    final topOffset =
        (isNarrow && !route.keepHeaderVisible) ? 0.0 : MediaQuery.of(context).padding.top + headerHeight;
    // How far left of [TopModalPaneRoute.leftInset] the sheet's edge sits, so
    // that the caller's header control lands centered over the sheet's own
    // leading button: the caller centers its control's content 12px in, and
    // HaloDialogHeader centers a leading button 36px in (its 12px padding
    // plus half a 48px icon-button box). With no leading button there is
    // nothing to line up against, and the header's inset is 24 rather than
    // 12 — so the sheet sits exactly where the caller asked.
    final leftNudge = route.leading == null ? 0.0 : 24.0;
    final sheetWidth = isNarrow
        ? screenSize.width
        // The nudge widens the sheet rather than shifting it: its right
        // edge stays at leftInset + its width.
        : math.min(screenSize.width, (route.maxWidth ?? maxDialogWidth) + (route.leftInset == null ? 0.0 : leftNudge));
    // Never negative: a window shorter than the clearance below (no native
    // min-size floor on web/Linux; a large font scale divides the logical
    // height further) would otherwise assert on invalid constraints — same
    // guard as haloDialogConstraints.
    final sheetMaxHeight = math.max(
      0.0,
      isNarrow
          ? screenSize.height - topOffset - MediaQuery.of(context).padding.bottom
          // Wide: still a floating card — allowed down to half a header's
          // height above the screen's bottom edge rather than the generic
          // haloDialogConstraints' 1.5-header-height clearance.
          : screenSize.height - topOffset - headerHeight / 2,
    );
    // Not applied in the full-width narrow case. Floored at zero for the same
    // reason as [sheetMaxHeight]: callers measure the control to align with,
    // and a control measured while its own route is still animating in reports
    // a position off the left of the window — a negative inset that asserts
    // inside Padding rather than merely misplacing the sheet.
    final leftInset = isNarrow
        ? null
        : (route.leftInset == null ? null : math.max(0.0, route.leftInset! - leftNudge));
    // No nudge on this side: [rightInset] lines the sheet's own right EDGE up
    // with the caller's control, rather than lining a control up with the
    // sheet's leading button the way [leftInset] does.
    final rightInset = isNarrow ? null : (route.rightInset == null ? null : math.max(0.0, route.rightInset!));

    final curvedAnimation = CurvedAnimation(parent: route.animation!, curve: Curves.easeOutCubic);

    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Dimmed barrier *only* below the header
            Positioned(
              top: topOffset,
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: curvedAnimation,
                  builder: (context, child) {
                    final barrier = haloBarrierColor(context);
                    return Container(color: barrier.withValues(alpha: barrier.a * curvedAnimation.value));
                  },
                ),
              ),
            ),
            // Gestures to dismiss when tapping the dimmed barrier below the header
            Positioned(
              top: topOffset,
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: route._tapOutsideDismissible
                    ? () {
                        if (route.onDismiss != null) {
                          route.onDismiss!();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      }
                    : null,
                // Same reason as _buildDialog's pair: a full-screen
                // `role=button` node in the web accessibility DOM sits in
                // front of every platform view the pane's content embeds and
                // swallows its clicks. Pure gesture plumbing — a
                // screen-reader user dismisses through the pane's own close
                // button or Done.
                excludeFromSemantics: true,
                child: const SizedBox.expand(),
              ),
            ),
            // Gestures to dismiss when tapping the view header area (above topOffset)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topOffset,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: route._tapOutsideDismissible
                    ? () {
                        if (route.onDismiss != null) {
                          route.onDismiss!();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      }
                    : null,
                excludeFromSemantics: true,
                child: const SizedBox.expand(),
              ),
            ),
            // The sheet container, clipped so its entry animation stays below the header
            Positioned(
              top: topOffset,
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(curvedAnimation),
                  child: Align(
                    alignment: switch ((leftInset, rightInset)) {
                      (null, null) => Alignment.topCenter,
                      (null, _) => Alignment.topRight,
                      _ => Alignment.topLeft,
                    },
                    child: Padding(
                      padding: EdgeInsets.only(left: leftInset ?? 0, right: rightInset ?? 0),
                      child: GestureDetector(
                        // Taps on the sheet itself must not fall through to
                        // the barrier handler above.
                        onTap: () {},
                        excludeFromSemantics: true,
                        child: LayoutDensityScope.forHeight(
                          // A pane-sized card is bounded well below the window
                          // (theme.dart's haloDialogConstraints), so a form
                          // inside one has far less height than the window
                          // suggests. Tightens only — never roomier than what
                          // the window itself allows.
                          height: sheetMaxHeight,
                          child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: sheetWidth,
                            maxHeight: sheetMaxHeight,
                            // Narrow: always fills to the bottom edge, same as
                            // the full-width requirement. Wide: only when not
                            // scrollable.
                            minHeight: (isNarrow || !route.scrollable) ? sheetMaxHeight : 0,
                          ),
                          child: Material(
                          color: theme.dialogTheme.backgroundColor ?? haloDialogBandColor(context),
                          elevation: modalSurfaceElevation,
                          shadowColor: haloDialogShadowColor,
                          surfaceTintColor: theme.colorScheme.surfaceTint,
                          // Square at the bottom in the narrow case — it
                          // reaches the screen's true edge there, so a
                          // rounded corner would just look clipped.
                          borderRadius:
                              isNarrow ? BorderRadius.zero : const BorderRadius.vertical(bottom: Radius.circular(28)),
                          clipBehavior: Clip.antiAlias,
                          // Narrow only, and only when the header behind it
                          // isn't being kept visible: the sheet starts at the
                          // screen's very top then, so its first row must
                          // clear the status bar itself. Wide (or
                          // keepHeaderVisible) starts below the app's header
                          // instead — a SafeArea there would double-inset.
                          child: SafeArea(
                            top: isNarrow && !route.keepHeaderVisible,
                            bottom: false,
                            left: false,
                            right: false,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (route.showHeader)
                                    HaloDialogHeader(
                                      leading: route.leading,
                                      title: route.title,
                                      trailing: route.trailing ?? IconButton(
                                        icon: Icon(MdiIcons.close, semanticLabel: route.closeLabel),
                                        onPressed: () => Navigator.of(context).maybePop(),
                                      ),
                                    ),
                                  if (route.scrollable)
                                    Flexible(
                                      child: Material(
                                        color: theme.colorScheme.surface,
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SingleChildScrollView(
                                            padding: route.contentPadding ??
                                                const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
                                            child: _body(),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Expanded(
                                      child: Material(
                                        color: theme.colorScheme.surface,
                                        child: _body(),
                                      ),
                                    ),
                                ],
                              ),
                          ),
                        ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ),
            ),
            // LAST in the stack, so it takes its own taps: everything above
            // it in this list — the header's dismiss gesture included — is
            // behind it for hit testing. See [TopModalPaneRoute.headerTrailing]
            // for why the view cannot host these controls itself.
            ?_headerOverlay(
              visible: !isNarrow || route.keepHeaderVisible,
              content: route.headerTrailing,
              top: MediaQuery.of(context).padding.top,
              height: headerHeight,
              left: 0,
              right: 0,
              alignment: AlignmentDirectional.centerEnd,
              theme: theme,
            ),
            // Same reasoning as headerTrailing above, positioned at the same
            // leftInset the card itself uses instead of the trailing edge —
            // see [TopModalPaneRoute.headerLeading]. The card's own nudged
            // `leftInset` only means anything for the card narrow forces to
            // null (sheetWidth is full-bleed there regardless) — a narrow
            // keepHeaderVisible pane instead lines this control up with the
            // raw [TopModalPaneRoute.leftInset] the caller measured against
            // the view's own header, which is laid out the same way on
            // narrow as it is on wide.
            ?_headerOverlay(
              visible: !isNarrow || route.keepHeaderVisible,
              content: route.headerLeading,
              top: MediaQuery.of(context).padding.top,
              height: headerHeight,
              left: isNarrow ? (route.narrowLeftInset ?? route.leftInset ?? 0) : (leftInset ?? 0),
              alignment: AlignmentDirectional.centerStart,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}
