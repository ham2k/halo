// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One tab in a group's strip, and the floating copy of it that follows a
// drag. The quiet tone for a tab's own actions is derived here too, from
// the strip's colours.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'density.dart';
import 'layout.dart';
import 'mdi_icons.g.dart';
import 'platform_chrome.dart' show isMobilePlatform;
import 'spacing.dart';
import 'tab_chrome.dart';
import 'theme.dart' show textWidth;

import 'dock_chrome.dart';

/// A tab's action while the dock is being USED, painted quiet and coming up
/// to full strength under the pointer.
///
/// Quiet because it is not what the tab is FOR: the tab is a name to read and
/// a place to tap, and a control at full contrast beside every name competes
/// with the one thing the strip exists to say. It has to stay findable
/// though, so it darkens against the header rather than fading out — visible
/// at a glance, unmistakable once aimed at.
///
/// The recolour is a [ColorFilter], not a colour passed down: the action is
/// the CALLER's widget and has already chosen its own colour. srcIn repaints
/// whatever it is handed.
class _QuietTabAction extends StatefulWidget {
  final Widget child;

  const _QuietTabAction({required this.child});

  @override
  State<_QuietTabAction> createState() => _QuietTabActionState();
}

class _QuietTabActionState extends State<_QuietTabAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final active = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final quiet = quietTabActionTone(header, active);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: TweenAnimationBuilder<Color?>(
        duration: const Duration(milliseconds: 150),
        tween: ColorTween(end: _hovered ? active : quiet),
        builder: (context, color, child) => ColorFiltered(colorFilter: ColorFilter.mode(color ?? quiet, BlendMode.srcIn), child: child),
        child: widget.child,
      ),
    );
  }
}

/// Where a quiet tab action's resting tone starts, as a fraction of the way
/// from the header toward black.
const double _quietening = 0.35;

/// The least contrast an interactive control may have against what it sits on
/// (WCAG 1.4.11). A control the operator cannot find is not quiet, it is
/// missing — and for an extension panel this button is the only way to its
/// settings form, with no hover to bring it up on a touch screen.
const double _minQuietContrast = 3.0;

/// The resting tone for a [_QuietTabAction] on [header]: [_quietening] of the
/// way to black, and further if that does not clear [_minQuietContrast].
/// Derived rather than fixed because the header colour is the edition's, and a
/// constant that reads on one is invisible on another.
///
/// Darkening is the whole look — the control recedes INTO its header rather
/// than fading off it. A header already so dark that nothing below it clears
/// the floor has no quiet tone to offer, so [active] is used unchanged: a
/// control at full strength is a worse-looking header than intended, and an
/// invisible one is a feature the operator cannot reach.
@visibleForTesting
Color quietTabActionTone(Color header, Color active) {
  for (var t = _quietening; t < 1.0; t += 0.05) {
    final tone = Color.lerp(header, Colors.black, t)!;
    if (_contrastBetween(tone, header) >= _minQuietContrast) return tone;
  }
  return active;
}

double _contrastBetween(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// One tab in a group header: tap to select, drag to move the module. The
/// drag-indicator dots mark it as a handle.
class DockTab extends StatelessWidget {
  final String title;
  final bool selected;

  /// See [DockLayoutView.editing]. Off, this tab is only a tab — no
  /// [Draggable] wraps it at all, so there is no drag gesture competing with
  /// the tap, and no grab cursor promising a move that isn't offered.
  final bool editing;

  /// Whether this is its group's ONLY module, in which case it is not a tab
  /// at all: no selection indicator, no tap, not announced as a tab, and its
  /// title reads from the leading edge, as a pane's title bar.
  /// A tab bar of one offers a choice that does not exist.
  final bool solo;

  /// Position in the strip, for the editing outline — see
  /// [TabFramePainter.isFirst].
  final bool isFirst;
  final bool isLast;

  final bool showHandle;

  /// See [DockLayoutView.pinnedModuleIds]. The tab still frames and fills like
  /// any other while editing — it is part of the same arrangement — it simply
  /// has no drag on it.
  final bool pinned;

  /// The module's own action (a settings button), shown at the tab's trailing
  /// edge while this tab is the active one.
  final Widget? action;

  final VoidCallback onTap;
  final String moduleId;
  final ValueChanged<String> onDragStarted;
  final VoidCallback onDragEnded;

  const DockTab({
    super.key,
    required this.title,
    required this.selected,
    required this.editing,
    required this.solo,
    required this.isFirst,
    required this.isLast,
    required this.showHandle,
    required this.pinned,
    required this.action,
    required this.onTap,
    required this.moduleId,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  /// The grab handle exists only while editing ([showHandle] IS `editing`),
  /// so there is one size and one strength: it is the control the operator
  /// is there to use, not a hint that a tab could be moved.
  static const double editingHandleSize = 20;

  /// The least the SHOWING tab is squeezed to while editing: both slots — its
  /// grab handle and its options button — and enough between them for three
  /// letters and an ellipsis. Less than that and the one tab whose name the
  /// operator still needs is showing nothing but punctuation.
  ///
  /// Measured rather than guessed at, so it holds at every font scale: a
  /// fixed number is a number for one scale, and the strip would collapse
  /// early at Larger and late at Smallest.
  static double activeMinWidth(BuildContext context) {
    // [textWidth], not a bare TextPainter: it folds in the ambient text style
    // and the current textScaler, so this holds under OS/accessibility text
    // sizing too. A hand-rolled painter measures the unscaled string and
    // under-reserves by however much the operator has turned their text up.
    final width = textWidth(context, 'Abc…', Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold) ?? const TextStyle());
    // Every box between the tab's two edges: the handle, the action, the
    // label's own inset either side of it (see [_tabContent]) and the tab's
    // padding. Leave one out and the floor is that much short — the tab
    // ellipsizes below the three letters this exists to keep.
    return editingHandleSize + _editingActionSize + width + Space.sm * 2 + Space.xxs * 2;
  }

  /// The least a tab is given while the dock is being USED: enough for three
  /// letters and an ellipsis beside whatever else that tab holds. Below it
  /// the strip scrolls rather than shrinking further, because a tab showing
  /// nothing but punctuation names no pane.
  ///
  /// Measured, not guessed at, and summed over EVERY box between the tab's
  /// two edges — the label's own insets, the tab's own padding, and the
  /// action slot when this tab carries one — for the same reasons as
  /// [activeMinWidth]: one term left out is a tab that ellipsizes below the
  /// three letters this floor exists to keep, and a constant is a number for
  /// one font scale.
  ///
  /// [hasAction] is a tab that carries its module's action, and it counts as
  /// the SMALLEST that slot shrinks to ([minActionSizeOf]) rather than the
  /// tap target it gets with room to spare — the slot gives way first (see [_actionSlot]), so
  /// reserving the tap target here would scroll strips that read perfectly
  /// well. Left out altogether, that tab's name is squeezed away to nothing
  /// while every neighbour still reads fine, which looks like a missing
  /// title rather than a strip out of room.
  static double readableMinWidth(BuildContext context, {bool hasAction = false, bool solo = false}) {
    final width = textWidth(context, 'Abc…', Theme.of(context).textTheme.titleSmall ?? const TextStyle());
    // A pane heading keeps a title bar's wider trailing inset; a tab's
    // trailing side is the gap to its action, not an edge — see [_tabContent].
    return width + Space.lg + (solo ? Space.lg : Space.sm) + Space.xxs * 2 + (hasAction ? minActionSizeOf(context) : 0);
  }

  /// The least a tab being squeezed can be given: its grab handle and the
  /// tab's own padding, both fixed boxes. Below this the Row overflows
  /// instead of shrinking, and the handle paints over the neighbouring tab.
  static const double squeezedMinWidth = editingHandleSize + Space.xxs * 2;

  /// What a tab's action is given while editing — its own icon and a little
  /// around it, rather than the chrome-height tap target it gets while the
  /// dock is being USED.
  ///
  /// The slots are deliberately UNEQUAL here, unlike everywhere else in this
  /// tab: equal slots keep the label centred and fixed as the selection
  /// moves, and that is worth two full chrome heights when an operator is
  /// reading tab names. Mid-rearrange it is not — a squeezed tab spending
  /// 96pt on a 20pt handle and a 24pt glyph shows "SP…" where it could show
  /// the word.
  static const double _editingActionSize = 32;

  /// The least the action slot shrinks to while the dock is being USED — its
  /// glyph and a little around it, the box editing gives it, and the tab is
  /// themed to match so the glyph actually gets that width (see
  /// [_actionSlot]). The slot is what gives way in a tight tab, not the name:
  /// a strip whose tabs are all ellipsis is a strip that says nothing, and
  /// the pane a settings button belongs to is the one already open below it.
  ///
  /// On a touch PLATFORM it does not shrink at all. `chromeHeightOf` holds
  /// the strip's height at the tap-target minimum there for this control's
  /// sake; taking the same points off its width instead would undo that
  /// silently, on the one platform with no pointer to aim with. Such a strip
  /// scrolls sooner, which is the honest answer: the button has to stay
  /// pressable.
  static double minActionSizeOf(BuildContext context) => isMobilePlatform ? LayoutDensity.chromeHeightOf(context) : _editingActionSize;

  /// A tab's contents: the grab handle pinned to its leading edge, the
  /// module's action to its trailing edge, and the label centered between
  /// them.
  ///
  /// Both edge slots are the SAME width and are held open whether or not
  /// they currently hold anything — that is what keeps the label both
  /// centered in the tab and fixed in place. A slot that collapsed when
  /// empty would swing the label sideways every time the selection moved
  /// (the handle and the action only show on the active tab), and unequal
  /// slots would leave a tab with a settings button reading off-center
  /// against its neighbours.
  ///
  /// An action is assumed no wider than one chrome row is tall (the tap
  /// target an icon button in this strip gets).
  /// A tab's contents: the grab handle (while editing) at the leading edge,
  /// then the module's name, then its action — packed together, with the
  /// slack after them.
  ///
  /// They read as ONE thing that way: the name says what the pane is and the
  /// action acts on it, and a control at the far edge of a wide tab reads as
  /// the strip's rather than as that pane's. The name is left-aligned for the
  /// same reason a pane title is — it is a heading, and a heading starts
  /// where the eye already is.
  Widget _tabContent(BuildContext context, Color labelColor, {required TextStyle? style}) {
    return Row(
      children: [
        if (showHandle)
          SizedBox(
            width: editingHandleSize,
            child: Icon(MdiIcons.dragVertical, size: editingHandleSize, color: labelColor),
          ),
        Expanded(
          // The action's slot is sized against what this tab actually has,
          // which only a LayoutBuilder here can say: the slot is inflexible,
          // so a Row would hand it its full tap target and leave the name
          // whatever is left — nothing at all, in a tab narrow enough. Only
          // where that width is READ, though: a LayoutBuilder has no
          // intrinsic dimensions to give, and a tab with nothing to size this
          // way should stay measurable.
          child: action == null || editing
              ? _tabRow(context, labelColor, style: style, available: double.infinity)
              : LayoutBuilder(
                  builder: (context, constraints) => _tabRow(context, labelColor, style: style, available: constraints.maxWidth),
                ),
        ),
      ],
    );
  }

  /// The name and, where there is one, the action beside it — [available] is
  /// the width the two share, which decides how much of it the action's slot
  /// may take.
  Widget _tabRow(BuildContext context, Color labelColor, {required TextStyle? style, required double available}) {
    return Row(
      children: [
        // Flexible, so a squeezed tab's name gives up its width down to
        // nothing rather than forcing the tab to stay as wide as one
        // line of text.
        Flexible(
          child: Padding(
            // A pane heading takes a title bar's inset. A tab with no handle
            // starts its name at that same inset — nothing else stands
            // between the name and the tab's edge — while a tab being
            // rearranged gives it back to the handle already sitting
            // there. The trailing side stays tight either way: it is
            // the gap to the options button, not an edge.
            padding: EdgeInsetsDirectional.only(start: showHandle ? Space.sm : Space.lg, end: solo ? Space.lg : Space.sm),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // A pane's name is what the operator is arranging BY while
              // editing — the tab is otherwise a handle and a border
              // with some text between them.
              style: (editing ? style?.copyWith(fontWeight: FontWeight.bold) : style)?.copyWith(color: labelColor),
            ),
          ),
        ),
        if (action != null) _actionSlot(context, available: available),
      ],
    );
  }

  /// The action's own width while the dock is being USED, given [available]
  /// for the name and the action together: its full tap target where the
  /// name still gets three letters beside it, and down to [minActionSizeOf]
  /// where it does not. Shrinking the tap target is the trade — a control
  /// pressed now and then, against the name of the pane it belongs to.
  ///
  /// Between those two ends the slot gives up exactly what the name needs,
  /// so a tab at [readableMinWidth] shows three letters and the smallest
  /// slot — which is why that floor reserves that slot and no more. The two
  /// read the SAME sum, minus the tab's own padding, which is outside
  /// [available]: derived rather than copied, because a label inset that
  /// moved in one and not the other would leave a tab at the floor showing
  /// fewer letters than both doc comments promise.
  double _usedActionSize(BuildContext context, double available) {
    assert(available.isFinite, 'a tab is laid out in a bounded strip — see _buildGroup');
    final tapTarget = LayoutDensity.chromeHeightOf(context);
    final forTheName = readableMinWidth(context, solo: solo) - Space.xxs * 2;
    return math.min(tapTarget, math.max(minActionSizeOf(context), available - forTheName));
  }

  /// A slot tightened to its glyph: an IconButton's default padding is 8pt a
  /// side, so a 32pt slot would otherwise lay the button out at 32 and give
  /// the 24pt glyph 16 — painting outside its own box, off-centre, and into
  /// whatever clips the strip.
  static Widget _tightIconButton(Widget child, double size) => IconButtonTheme(
    data: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: Size.square(size), padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    ),
    child: child,
  );

  /// The module's action, sized to what is in it: its glyph while editing
  /// (see [_editingActionSize]), and [_usedActionSize] otherwise. A slot
  /// below the full tap target is tightened either way — the width is the
  /// same trade, and a glyph that does not fit its slot is not a smaller
  /// control, it is a clipped one.
  Widget _actionSlot(BuildContext context, {required double available}) {
    final size = editing ? _editingActionSize : _usedActionSize(context, available);
    final squeezed = size < LayoutDensity.chromeHeightOf(context);
    // Tightened to its glyph. The tap target shrinks with it, which is the
    // trade: a control pressed now and then, against letters in the name of
    // the pane it belongs to.
    final child = editing ? action! : _QuietTabAction(child: action!);
    return SizedBox(width: size, child: squeezed ? _tightIconButton(child, size) : child);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabTheme = theme.tabBarTheme;
    // Only used for the drag ghost below — the live tab's own label color
    // comes from TabChrome, which resolves the same way.
    final ghostLabelColor = (selected ? tabTheme.labelColor : tabTheme.unselectedLabelColor) ?? theme.colorScheme.onPrimary;
    // A group of one is a pane with a title bar, not a tab bar of one: no
    // TabChrome at all, so there is no selection indicator, no tap, and
    // nothing announced to a screen reader as a tab. Its colour comes from
    // the app bar's, as a title bar's does, rather than from the
    // tab theme's label roles — which are about selected-vs-not, a
    // distinction this has no second thing to make.
    final tab = solo
        ? Semantics(
            header: true,
            label: title,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
              child: _tabContent(context, theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary, style: theme.textTheme.titleSmall),
            ),
          )
        : TabChrome(
            selected: selected,
            semanticLabel: title,
            // Far tighter than a stock tab's label padding: the handle and the
            // action live in this inset, and a grab handle set in from its own
            // tab's edge reads as decoration next to the label rather than as
            // the tab's own corner.
            padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
            onTap: onTap,
            // While editing, the outline marks the showing tab and its bottom
            // is deliberately open — the pane runs into it. The stock
            // indicator sits across exactly that opening.
            showIndicator: !editing,
            builder: (context, labelColor) => _tabContent(context, labelColor, style: Theme.of(context).textTheme.titleSmall),
          );
    // Outside edit mode the tab is only a tab. Not a disabled Draggable but
    // no Draggable at all: one that merely refuses still enters the gesture
    // arena against the tap, so tabs would answer a click late — or not at
    // all, once the pointer moved a few pixels first.
    if (!editing) return tab;
    // A Material rather than a DecoratedBox: it becomes the nearest one above
    // the tab's InkWell, so hover and press still land ON the fill instead of
    // splashing on the strip underneath, out of sight.
    final filledTab = selected
        ? Material(
            color: editingSelectedTabColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(editingFrameRadius)),
            child: tab,
          )
        : tab;
    // A foreground painter, so the outline lands over the tab's own selection
    // indicator and over the fill, rather than under either.
    final framedTab = CustomPaint(
      foregroundPainter: TabFramePainter(selected: selected, isFirst: isFirst, isLast: isLast),
      child: filledTab,
    );
    // Framed and filled like its neighbours, but with no drag and no grab
    // cursor: it belongs to the arrangement being edited, it just isn't one of
    // the pieces that moves. See [DockLayoutView.pinnedModuleIds].
    if (pinned) return framedTab;
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Draggable<String>(
        data: moduleId,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: () => onDragStarted(moduleId),
        onDragEnd: (_) => onDragEnded(),
        onDraggableCanceled: (_, _) => onDragEnded(),
        feedback: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(6),
          color: theme.colorScheme.primary,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
            child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onPrimary)),
          ),
        ),
        // Not TabChrome here: while its counterpart is being dragged
        // elsewhere, this dimmed placeholder shouldn't itself be tappable
        // or announced as a tab.
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: Container(
            decoration: TabChrome.indicatorDecoration(selected: selected, labelColor: ghostLabelColor, tabTheme: tabTheme),
            padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
            child: _tabContent(context, ghostLabelColor, style: theme.textTheme.titleSmall),
          ),
        ),
        child: framedTab,
      ),
    );
  }
}

/// The edit-mode chrome for a pane that has no header of its own: a grab
/// handle, the pane's name, and its layout-options button, in a small block
/// laid OVER the pane's top-left corner.
///
/// Over, not above. A strip conjured for the duration of an edit costs a whole
/// chrome height, and a pane at [dockMinPaneExtent] has none to give — so the
/// arrangement overflowed for precisely as long as it was being rearranged.
/// Floating it means a pane is the same height edit mode or not, which is also
/// what lets [dockMinPaneExtent] be ONE number rather than one per state.
///
/// Sized to its content, so it covers as little of the pane as it can, and
/// faded out toward its right and bottom edges rather than stopping at a hard
/// border: the block sits on top of somebody's content, and a rectangle with a
/// crisp edge reads as a piece of that content rather than as chrome over it.
class FloatingPaneChrome extends StatelessWidget {
  final String title;
  final String moduleId;

  /// See [DockLayoutView.pinnedModuleIds]. The chrome stays — it is where the
  /// pane's layout options live — it simply cannot be picked up.
  final bool pinned;

  final Widget? action;
  final ValueChanged<String> onDragStarted;
  final VoidCallback onDragEnded;

  const FloatingPaneChrome({
    super.key,
    required this.title,
    required this.moduleId,
    required this.pinned,
    required this.action,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  /// How far past the content the fade runs before it is fully transparent.
  /// The gradient needs somewhere to happen: ending it at the last glyph puts
  /// a hard edge exactly where the block is trying not to have one.
  static const double _fadeExtent = 28.0;

  /// Clear space between the controls and where the fade begins, so the block
  /// reads as chrome sitting on the pane rather than as a label crowded
  /// against its own edge.
  static const double _runUp = Space.xl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final onHeader = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final unit = LayoutDensity.chromeHeightOf(context);
    final handle = Icon(MdiIcons.dragVertical, size: DockTab.editingHandleSize, color: onHeader);
    final label = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(color: onHeader, fontWeight: FontWeight.bold),
    );
    // Deliberately NOT a DockTab: a tab is a choice among tabs, and this is
    // the only thing in its pane. Borrowing the tab's frame and fill made it
    // read as a one-tab strip that had come loose — the pane's own outline
    // ([PaneFramePainter]) is what marks the block now, and this carries just
    // the three controls on the fade.
    //
    // The pane offering this block is, by construction, at LEAST
    // [dockMinPaneExtent]'s floor — three units in a row, or one wide by
    // three tall when the pane can't spare the width. Reading its own real
    // constraint (via the enclosing LayoutBuilder below) rather than
    // assuming the roomier shape keeps the two in agreement: a floor that
    // promised vertical stacking must get a block that actually stacks.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= unit * 3;
        final content = wide
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  handle,
                  const SizedBox(width: Space.xxs),
                  Flexible(child: label),
                  if (action != null) ...[const SizedBox(width: Space.xs), action!],
                ],
              )
            : SizedBox(
                width: unit,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    handle,
                    const SizedBox(height: Space.xxs),
                    label,
                    if (action != null) ...[const SizedBox(height: Space.xs), action!],
                  ],
                ),
              );
        final blockWidth = wide ? null : unit + _fadeExtent;
        final blockHeight = wide ? unit + _fadeExtent : unit * 3 + _fadeExtent;
        return IgnorePointer(
          // Paint-only outside the block itself: the fade extends past the
          // controls, and a transparent tail that swallowed taps would take
          // them from the pane underneath.
          ignoring: false,
          child: SizedBox(
            width: blockWidth,
            height: blockHeight,
            child: DecoratedBox(
              // Diagonal, which fades BOTH free edges with one gradient — the
              // block is anchored top-left, so right and bottom are the two
              // sides that meet the pane's content.
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [header, header, header.withValues(alpha: 0)],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Padding(
                padding: wide
                    ? const EdgeInsets.only(left: Space.md, right: _runUp + _fadeExtent, bottom: _fadeExtent)
                    : const EdgeInsets.only(left: Space.md, top: Space.md, right: _fadeExtent, bottom: _runUp + _fadeExtent),
                child: SizedBox(
                  width: wide ? null : unit,
                  height: wide ? unit : null,
                  // Pinned: the block still carries the pane's title and its
                  // layout options, it just isn't a handle.
                  child: pinned
                      ? content
                      : MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: Draggable<String>(
                            data: moduleId,
                            dragAnchorStrategy: pointerDragAnchorStrategy,
                            onDragStarted: () => onDragStarted(moduleId),
                            onDragEnd: (_) => onDragEnded(),
                            onDraggableCanceled: (_, _) => onDragEnded(),
                            feedback: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(6),
                              color: theme.colorScheme.primary,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                                child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onPrimary)),
                              ),
                            ),
                            childWhenDragging: Opacity(opacity: 0.4, child: content),
                            child: content,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
