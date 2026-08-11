import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../main.dart';
import 'ham2k_logo.dart';
import 'home_view.dart';

/// The Home view's left-edge navigation rail (docs/design/layouts.md).
///
/// Styled after Log Kitchen's sidebar: a light blue-grey column, a bold
/// label, and selection marked by colour rather than by a pill. Its label
/// sits BESIDE the icon rather than under it, which is the one place this
/// deliberately parts company with that sidebar.
///
/// Two widths, never zero: the rail is how Settings is reached, so hiding it
/// would take the only route there off the screen. The logo in the header
/// toggles between them.
class HomeNavigationRail extends StatelessWidget {
  /// Whether the labels are showing. The caller resolves this — it is the
  /// operator's stored preference AND with enough width to honour it.
  final bool expanded;

  /// Which destination the shell is showing. The rail is real navigation:
  /// whichever destination is up is the selected one, and the other is a live
  /// control back to it.
  final bool settingsSelected;

  final ValueChanged<bool> onDestination;

  /// Toggles [expanded]. The logo is the control, and it lives at the top of
  /// this column rather than in a view's header — the rail owns the whole left
  /// edge, so the header begins to its right and has no room for a mark that
  /// belongs to the navigation.

  const HomeNavigationRail({
    super.key,
    required this.expanded,
    required this.settingsSelected,
    required this.onDestination,
  });

  /// Icon-only. Wide enough for the glyph with Material's minimum touch target
  /// around it, and for the logo's own column — every pixel here comes out of
  /// the views beside it.
  static const collapsedWidth = 64.0;

  /// Icon with its label beside it. Wider than Log Kitchen's 112, which puts
  /// the label UNDER the icon: a label to the right needs room for the
  /// longest destination name at the default font scale, and Spanish
  /// ("Operaciones") is what sets this rather than English.
  static const expandedWidth = 188.0;

  /// Log Kitchen's icon size. Public because the header's logo sits directly
  /// above these glyphs and has to belong to the same column: a mark visibly
  /// smaller than the destinations under it reads as shrunken, whatever it
  /// measures on its own.
  static const iconSize = 35.0;

  /// The width the rail rests at — what a view sitting BESIDE it insets by.
  ///
  /// One stored preference, two meanings, because the two sizes have different
  /// room to give. Wide, the rail is a permanent fixture and the toggle buys
  /// LABELS. Narrow, labels would take a third of the window, so the toggle
  /// buys the rail ITSELF: off by default, with the logo and a settings button
  /// in the header instead, and on when the operator asks for it.
  ///
  /// Deliberately not animated: a view that tracked the width frame by frame
  /// would re-lay-out through every push (see [HomeRailShell]).
  static double widthFor(BuildContext context, {required bool expanded}) {
    final resting = ShirtSize.of(context).isTwoPane
        ? (expanded ? expandedWidth : collapsedWidth)
        : (expanded ? collapsedWidth : 0);
    // A landscape cutout falls on the RAIL, since the rail is what touches
    // that edge — and it is taken by GROWING, because the widths above are
    // sized to hold a glyph and a label and an inset subtracted from them
    // overflows instead of insetting. Nothing to grow when there is no rail.
    return resting == 0 ? 0 : resting + MediaQuery.paddingOf(context).left;
  }

  /// Whether the rail is on screen at all — false only on a narrow window with
  /// the toggle off, where the header carries the logo and a settings button.
  static bool presentIn(BuildContext context, {required bool expanded}) =>
      widthFor(context, expanded: expanded) > 0;

  /// The box the mark occupies, at the top of the icon column. The same in
  /// every state — see [HomeRailLogo], which is why it is a measurement and
  /// not a widget.
  ///
  /// The header's height exactly, on every platform including a chromeless
  /// macOS window: the mark belongs on the header's own line, beside the
  /// window buttons rather than under them. A box that reserved the
  /// traffic-light clearance vertically would push it down into the rail and
  /// leave the rail's first destination a row lower than the panes beside it.
  static double logoBoxHeightOf(BuildContext context) =>
      Theme.of(context).appBarTheme.toolbarHeight ?? kToolbarHeight;


  /// The rail's leading inset — exactly where a glyph CENTRED in the icon
  /// column sits, so that the destinations do not shift sideways when the
  /// labels come out. Not a rung of the Space vocabulary, deliberately: it is
  /// derived from the two widths it has to reconcile.
  static const leadingInset = (collapsedWidth - iconSize) / 2;


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t.home.nav;
    // The rail is against the window's left edge, so a landscape cutout falls
    // on IT, not on the panes. Taken by GROWING the rail rather than by
    // padding its contents: its widths are sized to hold a glyph and a label,
    // and an inset subtracted from them overflows instead of insetting. The
    // destinations then sit clear of the cutout, and the panes to the right
    // never see it.
    final leftInset = MediaQuery.paddingOf(context).left;
    // In dark mode a black shadow disappears into dark surfaces — the
    // boundary reads better as a light "glow" instead. Same rule, and the
    // same numbers, as the `surfaces` split divider: the two are one idiom,
    // and a rail with its own shadow vocabulary would drift from it.
    final dark = theme.brightness == Brightness.dark;
    final shadowColor = dark ? Colors.white : theme.colorScheme.shadow;
    final shadowAlpha = dark ? ResizableSplitView.dividerShadowAlphaDark : ResizableSplitView.dividerShadowAlpha;
    // The chrome above and below the rail, continued THROUGH it: the mark's
    // slot and the Settings destination sit on the header's own colour, at the
    // header's own height, so the top and bottom of the window read as one
    // band each rather than as a header with a notch cut out of it.
    final chromeColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final safeTop = MediaQuery.paddingOf(context).top;
    final capTop = safeTop + logoBoxHeightOf(context);

    return SizedBox(
      width: (expanded ? expandedWidth : collapsedWidth) + leftInset,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              // A light surface, not the header's: the rail is a surface the
              // panes sit beside, and the boundary is drawn by the shadow they
              // cast onto it rather than by a change of colour.
              color: theme.colorScheme.surfaceContainerHighest,
              // SCROLLS when the box is too short for it — a rail standing
              // clear of the keyboard on a landscape phone at a large font
              // scale is shorter than its own two chrome caps. Tall enough,
              // `minHeight` keeps it exactly as it was, so the Expanded below
              // still pins Settings to the bottom.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The mark's slot. The mark ITSELF is drawn by the window
                  // (see [HomeRailLogo]) — only its ground and its space belong
                  // to the rail, so the destinations start below the header
                  // line whether or not the rail is the thing under it.
                  SizedBox(height: capTop, child: ColoredBox(color: chromeColor)),
                  Expanded(
                    child: Padding(
                      // The LEFT inset is handled by [leftInset] widening the
                      // whole rail; this is where it is spent. Padding it off a
                      // fixed 64pt box instead would eat a 44pt cutout out of
                      // it and overflow the 35pt glyph.
                      padding: EdgeInsets.only(left: leftInset),
                      child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: Space.md),
                                  _RailDestination(
                                    solid: MdiIcons.notebookMultiple,
                                    // MDI has no `notebook-multiple-outline`,
                                    // so this one destination cannot be built
                                    // the two-tone way (see [_TwoToneIcon]) and
                                    // falls back to the muted solid.
                                    outline: null,
                                    label: t.operations,
                                    expanded: expanded,
                                    selected: !settingsSelected,
                                    // Inert only while it names where the
                                    // operator already is — a control that
                                    // reloads the screen you are on is a
                                    // control that does nothing.
                                    onTap: settingsSelected ? () => onDestination(false) : null,
                                  ),
                                  const Spacer(),
                                ],
                      ),
                    ),
                  ),
                  // The bottom cap: Settings, on the chrome's colour, in the
                  // rail's own column rather than beside it. It is as tall as
                  // Quick Lookup's resting height because the two read as one
                  // row across the foot of the window — and BOTTOM-aligned, so
                  // a lookup line growing that bar upward leaves the glyph on
                  // the window's edge instead of drifting up a taller cell.
                  SizedBox(
                    height: HomeQuickLookup.heightOf(context) + MediaQuery.paddingOf(context).bottom,
                    child: ColoredBox(
                      color: chromeColor,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: leftInset,
                          bottom: MediaQuery.paddingOf(context).bottom + Space.md,
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _RailDestination(
                            solid: MdiIcons.cog,
                            outline: MdiIcons.cogOutline,
                            label: t.settings,
                            expanded: expanded,
                            selected: settingsSelected,
                            // On chrome rather than on the rail's own surface,
                            // so it takes the chrome's foreground: the muted
                            // surface colours the other destinations use are
                            // unreadable on it.
                            onChrome: true,
                            // A TOGGLE, unlike Operations: pressing the entry
                            // for the screen already open puts Settings away
                            // again, which is the gesture the operator reaches
                            // for after opening it from here.
                            onTap: () => onDestination(!settingsSelected),
                          ),
                        ),
                      ),
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
          // The chrome and the panes all cast INWARD onto the rail — the rail
          // is what receives it, so the shadows are drawn here rather than by
          // any of them: one painted by the caster would fall on the caster's
          // own side of the boundary. Paint-only, so every destination under
          // them stays clickable.
          _RailShadow(
            edge: AxisDirection.up,
            top: capTop,
            color: shadowColor,
            alpha: shadowAlpha,
          ),
          _RailShadow(
            edge: AxisDirection.right,
            top: capTop,
            color: shadowColor,
            alpha: shadowAlpha,
          ),
        ],
      ),
    );
  }
}

/// One edge of the well the rail sits in — the band of shadow whatever is on
/// the far side of that edge casts into it.
class _RailShadow extends StatelessWidget {
  /// Which way the shadow falls: [AxisDirection.up] for the band under the top
  /// cap, [AxisDirection.down] for the one over the bottom cap,
  /// [AxisDirection.right] for the one the panes cast along the rail's edge.
  final AxisDirection edge;
  final double? top;
  final Color color;
  final double alpha;

  const _RailShadow({required this.edge, this.top, required this.color, required this.alpha});

  @override
  Widget build(BuildContext context) {
    final width = ResizableSplitView.dividerShadowWidth;
    return Positioned(
      left: edge == AxisDirection.right ? null : 0,
      right: 0,
      // Defaults to the box's own top rather than to null: a Positioned given
      // only `bottom` is not stretched, it is sized by its child — and this
      // one has none, so it would paint nothing at all.
      top: edge == AxisDirection.down ? null : (top ?? 0),
      bottom: edge == AxisDirection.up ? null : 0,
      width: edge == AxisDirection.right ? width : null,
      height: edge == AxisDirection.right ? null : width,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: switch (edge) {
                AxisDirection.up => Alignment.topCenter,
                AxisDirection.down => Alignment.bottomCenter,
                _ => Alignment.centerRight,
              },
              end: switch (edge) {
                AxisDirection.up => Alignment.bottomCenter,
                AxisDirection.down => Alignment.topCenter,
                _ => Alignment.centerLeft,
              },
              colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0.0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// A Material two-tone icon, built from the icon font rather than from an SVG.
///
/// Material's own two-tone set is one glyph drawn twice — a fill at 30% under
/// a full-strength outline — which is exactly what this stacks, using MDI's
/// solid and `-outline` variants of the same icon. The selected destination
/// skips all of it and draws the solid glyph alone, so selection reads as a
/// weight change rather than only a colour change.
///
/// Not every MDI icon HAS an outline variant. Given none, the unselected state
/// is the solid glyph muted — no crisp edge, but the same relationship to the
/// selected one.
class _TwoToneIcon extends StatelessWidget {
  final IconData solid;
  final IconData? outline;
  final bool selected;
  final Color color;
  final double size;

  /// Material's own two-tone fill opacity.
  static const _fillOpacity = 0.3;

  /// What an outline-less icon is dimmed to instead. Deliberately heavier than
  /// [_fillOpacity]: a bare 30% glyph with no outline over it reads as
  /// disabled rather than as unselected.
  static const _soloOpacity = 0.55;

  const _TwoToneIcon({
    required this.solid,
    required this.outline,
    required this.selected,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (selected) return Icon(solid, size: size, color: color);
    final outlineIcon = outline;
    if (outlineIcon == null) {
      return Icon(solid, size: size, color: color.withValues(alpha: _soloOpacity));
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(solid, size: size, color: color.withValues(alpha: _fillOpacity)),
        Icon(outlineIcon, size: size, color: color),
      ],
    );
  }
}

class _RailDestination extends StatelessWidget {
  final IconData solid;
  final IconData? outline;
  final String label;
  final bool expanded;
  final bool selected;

  /// Whether this destination sits on the chrome's colour rather than on the
  /// rail's own surface — it then takes the chrome's foreground, since the
  /// muted surface colours the other destinations use are unreadable on it.
  final bool onChrome;

  /// Null for a destination that names where the operator already is — it
  /// still renders, and still announces its name and its selected state, but
  /// it is not a control.
  final VoidCallback? onTap;

  const _RailDestination({
    required this.solid,
    required this.outline,
    required this.label,
    required this.expanded,
    required this.selected,
    required this.onTap,
    this.onChrome = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Selection is a COLOUR here, not a background: the app's primary against
    // the muted `onSurfaceVariant` the other destinations take. Log Kitchen
    // marks its current section the same way, and a pill would fight the
    // shadow that already divides this column from the panes.
    final onChromeColor = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final color = onChrome
        // Selected reads as FULL STRENGTH against a dimmed rest, the same
        // distinction the surface destinations draw with hue.
        ? onChromeColor.withValues(alpha: selected ? 1.0 : 0.7)
        : (selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant);
    final icon = _TwoToneIcon(
      solid: solid,
      outline: outline,
      selected: selected,
      color: color,
      size: HomeNavigationRail.iconSize,
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      // Collapsed, the glyph is all there is, so the accessible name is the
      // only place this destination is named. The app shows no hover tooltips
      // (docs/design/user-interface.md).
      label: expanded ? null : label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          mouseCursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Row(
              // Centred while collapsed, so the glyph sits under the header's
              // logo; packed to the leading edge once there is a label to read.
              // Always packed to the leading edge, at the inset a centred
              // glyph would land on anyway — centring the collapsed state
              // instead moves every glyph sideways the moment labels appear.
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: HomeNavigationRail.leadingInset),
                icon,
                if (expanded) ...[
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's mark, and the control that toggles the rail — drawn by the window
/// at a FIXED position rather than by the rail or by the header.
///
/// It has to be fixed because the operator's own gesture is what moves the rail
/// out from under it: on a narrow window the mark starts over the header and
/// ends over a rail that has just appeared beneath it, and a mark that belonged
/// to either one would jump between them, or be clipped in as the rail widens.
/// Its box is the same in every state — the icon column's width, the header's
/// height — so there is nothing for it to jump between.
class HomeRailLogo extends StatelessWidget {
  static const _logoLift = 2.0;

  final VoidCallback onToggle;

  const HomeRailLogo({super.key, required this.onToggle});

  /// The column the mark occupies, cutout included — what a view beside it
  /// holds open so its own leading control lands clear of the mark.
  static double widthOf(BuildContext context) =>
      HomeNavigationRail.collapsedWidth + MediaQuery.paddingOf(context).left;

  /// Where that column starts, measured from the window's leading edge.
  ///
  /// Zero everywhere except a chromeless macOS window, where the native
  /// window buttons own that corner and the mark takes its place after them,
  /// on the same line. Zero again in native full screen, where the buttons
  /// leave the header entirely.
  static double leftOf(BuildContext context) =>
      isMacOSChromelessWindow ? macOSTrafficLightClearance(context) : 0;

  /// What a header BESIDE the mark must hold open for it, given the rail
  /// width that header already starts after.
  ///
  /// Usually nothing: the mark stands in the rail's own column, which the
  /// header is already clear of. It is the arrangements where the mark
  /// reaches past that column — no rail at all, or a macOS window where the
  /// buttons have pushed the mark off the rail and onto the header's line —
  /// that need the room, and only for the part that actually overhangs.
  static double headerReserveOf(BuildContext context, {required double railWidth}) =>
      max(0.0, leftOf(context) + widthOf(context) - railWidth);

  /// Sized to sit fully inside the slot it shares with the header's title — the
  /// SHORTER of the icon column's width and the header's height, less a little
  /// air. Never off the labelled width: the mark belongs to the icon column,
  /// which is the part that does not change, and scaling it with the rail would
  /// blow it up to 200-odd points the moment the operator asked for labels.
  static double sizeOf(BuildContext context) =>
      min(HomeNavigationRail.collapsedWidth,
          Theme.of(context).appBarTheme.toolbarHeight ?? kToolbarHeight) -
      Space.xs;

  @override
  Widget build(BuildContext context) {
    final logoSize = sizeOf(context);
    return SizedBox(
      // Clearing a landscape cutout, which falls on this corner.
      width: widthOf(context),
      height: HomeNavigationRail.logoBoxHeightOf(context),
      child: Padding(
        padding: EdgeInsets.only(left: MediaQuery.paddingOf(context).left),
        child: Semantics(
          button: true,
          label: context.t.home.toggleNav,
          // Its own Material: this is a sibling of the views, not inside any
          // Scaffold, so there is no ancestor to print an ink response on.
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              mouseCursor: SystemMouseCursors.click,
              // No hover or press wash: the mark is artwork, not a button
              // surface, and a highlight painted behind it reads as a stray
              // dark square — one the pointer can leave stuck there by exiting
              // over a widget that rebuilt under it.
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              // Lifted off the bottom of its box by a hair: sitting exactly on
              // the header's baseline the mark reads a touch low against the
              // title beside it, which has descender room under it that this
              // does not.
              child: Padding(
                padding: const EdgeInsets.only(bottom: _logoLift),
                child: Align(
                alignment: Alignment.bottomLeft,
                child: SizedBox(
                  width: HomeNavigationRail.collapsedWidth,
                  child: ClipRect(
                    child: OverflowBox(
                      // Both minimums released, not just the maximums: a tight
                      // width is a MINIMUM too, and a mark narrower than the
                      // column would inherit it and leave the constraints
                      // non-normalized.
                      minWidth: 0,
                      minHeight: 0,
                      maxWidth: logoSize,
                      maxHeight: logoSize,
                      // Bottom-anchored, so the mark sits on the rail's first
                      // destination whatever it measures.
                      alignment: Alignment.bottomCenter,
                      child: SvgPicture.asset(ham2kSquareLogoAsset, width: logoSize, height: logoSize),
                    ),
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

/// Puts the navigation rail down the left of the window, with everything else
/// filling what is left.
///
/// Plain horizontal composition: a fixed-width rail, then the rest — every
/// view's header, its panes, and the status footer. The rail is a sibling of
/// the whole window rather than of the routes, so a status item shortens the
/// views and never the navigation.
///
/// A Stack rather than a Row, and for Z-ORDER rather than for overlap. Which
/// side of the routes the rail is painted on follows [HomeRailState.covered]:
/// over them for the views that sit BESIDE it, under them for the one that
/// owns the whole window. Not a free choice either way — the overlay a route
/// lives in takes every pointer that lands in it, so a rail painted underneath
/// is a rail nothing can press, which is only acceptable while something is
/// covering it anyway.
///
/// [routes] spans the WHOLE window and the rail sits on top of it. A view that
/// were inset by the rail's animating width would re-lay-out on every frame of
/// it — the whole logging screen, sixty times, while it is also sliding in —
/// and that push is visibly sluggish. Views that must clear the rail take the
/// inset themselves, from [HomeNavigationRail.widthFor], which does not
/// animate: a pushed view covers the rail's column anyway, and by the time it
/// has arrived the rail has finished narrowing out from under it.
///
/// [chrome] — notices and the status footer — is a band across the WHOLE
/// window below both, belonging to no view: it says the same things over Home,
/// over Settings and over an operation, so it neither moves for navigation nor
/// stops at the rail. The rail's column ends at the top of it.
///
/// What the home layer owns — Quick Lookup, and the Settings cap at the foot
/// of the rail beside it — is deliberately NOT here. Drawn inside the routes,
/// a view that covers the window covers those too, and Settings shown in
/// Home's place slides over the field it replaces. Held out here instead, each
/// of them would need telling which view is up.
///
/// The rail widens and narrows by CLIPPING rather than squeezing: the contents
/// keep the wider of the two widths for the whole animation and the window
/// around them moves, so glyphs and labels slide in and out at their own size
/// instead of compressing into an unreadable sliver.
///
/// The rail never hides and never animates for navigation. Only [chrome] —
/// notices and the status footer — answers to it, going full width while a
/// covering view is up: the routes bury the rail's column, but the footer sits
/// BESIDE it, and a strip of rail left showing under a full-window view is the
/// one piece the view cannot bury on its own.
///
/// [keyboard] is never inset. The numbers row and the space held for the
/// on-screen keyboard belong to the keyboard, which spans the window and does
/// not stop at the rail.
class HomeRailShell extends StatefulWidget {
  final HaLoServices services;
  final Widget routes;
  final List<Widget> chrome;

  final List<Widget> keyboard;


  const HomeRailShell({
    super.key,
    required this.services,
    required this.routes,
    this.chrome = const [],
    this.keyboard = const [],
  });

  @override
  State<HomeRailShell> createState() => _HomeRailShellState();
}

class _HomeRailShellState extends State<HomeRailShell> {
  /// The one entry, built once and kept: `Overlay.initialEntries` is read on
  /// the overlay's FIRST build and never again, so an entry recreated per build
  /// is simply discarded. Stateful for exactly that reason — the entry has to
  /// outlive the build that made it, and be told when to rebuild.
  late final OverlayEntry _entry = OverlayEntry(
    // Positioned.fill, because an entry is laid out LOOSE in the overlay's
    // theatre — left to itself this shell would size to its children instead
    // of to the window.
    builder: (context) => Positioned.fill(child: _shell(context)),
  );

  /// Marked by hand as well as through the rebuild the overlay above passes
  /// down, because that pass-down is the overlay's own business and this is the
  /// documented way to say the entry's content changed. What must never come
  /// back is a builder that reads anything captured at creation: [chrome]
  /// arrives as a whole new widget when a notice is raised or dismissed, and a
  /// builder holding the first one shows a notice only after a hot restart and
  /// never lets it be dismissed.
  @override
  void didUpdateWidget(HomeRailShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  // No `dispose` of the entry here: the Overlay below owns what it was handed
  // and disposes it with itself, and an entry disposed while still attached
  // asserts.

  @override
  Widget build(BuildContext context) {
    // The Overlay is OUTERMOST because the chrome below holds a TEXT FIELD and
    // this shell sits ABOVE the Navigator: text selection needs an Overlay
    // ancestor, and the app's own is inside the routes, below here.
    return Overlay(initialEntries: [_entry]);
  }

  Widget _shell(BuildContext context) {
    return ListenableBuilder(
      listenable: homeRail,
      builder: (context, child) {
        // The stored preference AND enough width to honour it. At XS/S the
        // labels would take a third of the window from the views, so the rail
        // is icon-only there whatever is stored — and the preference is left
        // alone, so widening brings the labels back.
        final expanded = homeRail.expanded && ShirtSize.of(context).isTwoPane;
        final resting = HomeNavigationRail.widthFor(context, expanded: homeRail.expanded);
        // The tween follows the RESTING width — the toggle — and never
        // visibility, which is applied straight through below. Home animates
        // its own inset off the same value, so the two move together.
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: resting),
          duration: layoutAnimationDuration,
          curve: layoutAnimationCurve,
          builder: (context, animated, _) {
            // Contents at the WIDER of the two widths for the whole animation:
            // collapsing, the labels have to still be there to be clipped
            // away — rebuilt at the narrow width on the first frame they are
            // simply gone, and what is left is a 188-wide hole closing around
            // an already-collapsed rail, which reads as no animation at all.
            // Against the icon-only width WITH the cutout in it, which is what
            // `animated` is measured in: compared with the bare 64 instead, a
            // rail grown by a notch reads as already past collapsed and brings
            // the labels out under a clip too narrow to show them — a sliver
            // of the first glyph at the rail's edge, on device only, where a
            // cutout exists at all.
            final iconOnly = HomeNavigationRail.collapsedWidth + MediaQuery.paddingOf(context).left;
            final showingLabels = expanded || animated > iconOnly;
            // Carries the cutout too: this is a TIGHT width for the rail, so
            // one that left the inset out would clamp away the widening the
            // rail does for it and squeeze the glyph out of its own column.
            final contents = showingLabels
                ? HomeNavigationRail.expandedWidth + MediaQuery.paddingOf(context).left
                : iconOnly;
            // KEYED, both of them, because the two swap places in the Stack
            // below. Without keys the framework matches children by position,
            // finds a Positioned in each slot, and updates each element with
            // the OTHER one's widget — re-inflating the whole route tree and
            // the rail on every push, which is a visible stutter at exactly
            // the moment a view is trying to animate in.
            final views = Positioned.fill(key: const ValueKey('views'), child: child!);
            final rail = Positioned(
              key: const ValueKey('rail'),
              left: 0,
              top: 0,
              bottom: 0,
              width: animated,
              child: ClipRect(
                child: OverflowBox(
                  minWidth: contents,
                  maxWidth: contents,
                  alignment: Alignment.centerLeft,
                  child: HomeNavigationRail(
                    expanded: showingLabels,
                    settingsSelected: homeRail.showSettings,
                    onDestination: (settings) => homeRail.showSettings = settings,
                  ),
                ),
              ),
            );
            final logo = Positioned(
              key: const ValueKey('logo'),
              // After the native window buttons on a chromeless macOS window,
              // hard against the edge everywhere else. The mark shares the
              // header's line with them rather than sitting under them, so on
              // the Mac it stands to the RIGHT of the rail's column while
              // still belonging to the rail — the rail keeps its own width and
              // does not grow to hold both.
              left: HomeRailLogo.leftOf(context),
              // Below the status bar, which the rail clears with a SafeArea of
              // its own — the mark is drawn OUTSIDE the rail and would
              // otherwise sit in the clock.
              top: MediaQuery.paddingOf(context).top,
              child: HomeRailLogo(
                onToggle: () {
                  homeRail.expanded = !homeRail.expanded;
                  unawaited(widget.services.settings.setHomeNavExpanded(homeRail.expanded));
                },
              ),
            );
            // The mark belongs to the rail and travels with it — a view that
            // covers the rail covers the mark too, and neither needs telling.
            final navigation = [rail, logo];
            return Column(
              children: [
                // The routes and the rail beside them, and NOTHING else: the
                // band below is a sibling of this Stack rather than a layer in
                // it, which is what lets the rail be an overlay (it has to be —
                // the overlay a route lives in takes every pointer that lands
                // in it) without covering the band's own controls.
                Expanded(
                  child: Stack(
                    children: homeRail.covered ? [...navigation, views] : [views, ...navigation],
                  ),
                ),
                // Notices and the status footer, spanning the WINDOW and
                // belonging to no view: they say the same things over Home,
                // over Settings and over an operation, so they stay put while
                // views come and go above them. Nothing here answers to the
                // rail — the rail's column ends at the top of this band, and
                // the chrome the HOME layer owns (Quick Lookup, and the rail's
                // Settings cap beside it) is drawn inside the routes, where a
                // covering view hides it without being asked to.
                ...widget.chrome,
                // The numbers row and the space held for the keyboard span the
                // WINDOW, below all of it: they are the keyboard's own real
                // estate, and the keyboard does not stop at the rail.
                ...widget.keyboard,
              ],
            );
          },
        );
      },
      child: widget.routes,
    );
  }
}

/// A route that arrives from the RIGHT, moving left into place — and leaves the
/// way it came, sliding back off to the right and revealing what was under it.
///
/// Away from the rail's edge, deliberately: this is a view that COVERS the
/// navigation rather than coming out of it, and one entering over the rail
/// from the rail's own side reads as the rail having produced it.
///
/// Nothing is applied to the route BELOW: it stays where it is, which is what
/// makes going back a reveal rather than a second slide.
PageRoute<T> slideInFromRight<T>(WidgetBuilder builder) => _SlideInFromRightRoute<T>(builder);

/// Nothing about the rail changes for this route — the rail is simply painted
/// under it instead of over it, which `HomeRailRouteObserver` works out from
/// the navigator rather than from anything this route declares. It covers the
/// rail on its way in like it covers everything else, and stays over it for
/// the whole way out: the count only drops when the route is gone.
class _SlideInFromRightRoute<T> extends PageRouteBuilder<T> {
  /// Longer than [layoutAnimationDuration], which paces pane widths and the
  /// rail's own toggle. This is a whole view crossing a whole window rather
  /// than a column changing size — the same duration over that much further
  /// reads as a snap. Out matches in: nothing about leaving is more urgent
  /// than arriving.
  static const _duration = Duration(milliseconds: 400);

  _SlideInFromRightRoute(WidgetBuilder builder)
      : super(
          transitionDuration: _duration,
          reverseTransitionDuration: _duration,
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: layoutAnimationCurve)),
            child: child,
          ),
        );

}
