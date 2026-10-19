// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The secondary control row, ported from app-polo's SecondaryExchangePanel:
// a horizontal strip of chips — one per control, built-in (Time, Radio) or
// extension-contributed (POTA's park reference, etc.) — each showing a
// compact summary of its current value. Tapping a chip expands that
// control's input panel above the row; tapping the same chip again
// collapses it. Only one control is expanded at a time, which is what lets
// this scale to many extensions contributing controls without the panel's
// footprint growing — the alternative (every control's inputs always
// visible) is what app-polo moved away from as more activities registered
// logging controls.
//
// The chip strip itself can be dragged to scroll (desktop mice don't get
// click-drag scrolling by default — only touch/trackpad do, unless
// explicitly opted in), and a caret expands it into a multi-row grid (up to
// 4 rows tall, scrollable beyond that) so every control can be seen at
// once instead of scrolled through one at a time. Show/hide and reordering
// of which controls appear at all lives one level up (LoggingControls owns
// that state and persistence); this widget just renders whatever ordered
// list it's given, plus a settings button the caller wires up to open
// that management UI.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/scheduler.dart' show Ticker;

import 'package:halo_i18n/halo_i18n.dart';

import 'call_info_summary.dart' show glyphGlowColor;
import 'mdi_icons.g.dart';
import 'density.dart';
import 'spacing.dart';
import 'theme.dart';
import 'wall_clock.dart';

/// One run of a chip's summary: [text], and the color it paints in — null
/// keeps the chip's own foreground, which is what all but one run ever wants.
typedef SummaryPart = ({String text, Color? color});

/// [SecondaryControlSpec.liveIconColor]: the icon's color now, given the
/// one it would otherwise have.
typedef LiveIconColor = Color Function(Color base);

/// [SecondaryControlSpec.liveTint]: a [color] the icon and label are drawn
/// toward, by [strength] (0 none, 1 all of it), re-read every frame.
typedef LiveTint = ({Color color, ValueGetter<double> strength});

/// One control the row can show. Built by the screen/panel that owns the
/// relevant state — some specs wrap a built-in Dart widget (Time, Radio),
/// others wrap an extension-described input (POTA's refList) rendered
/// through the UI catalog. Either way, by the time it reaches this widget
/// it's just an icon, a summary, and a builder — the row doesn't know or
/// care where a control came from.
class SecondaryControlSpec {
  final String key;
  final IconData icon;
  final String summary;
  final WidgetBuilder expandedBuilder;

  /// For a summary that follows the wall clock (the Time chip, the Spotting
  /// chip's countdown): when set, the chip re-evaluates this once per second
  /// via [OncePerSecond] — every frame under [liveTint] — and shows its
  /// result instead of [summary]; the rebuild stays scoped to the chip's
  /// label instead of whatever State owns the spec.
  final ValueGetter<String>? liveSummary;

  /// The summary as colored runs, for a chip where one PART of the value is
  /// wrong rather than the whole chip (the Radio chip's sideband: `7.185 •
  /// LSB` with only `LSB` in the error color). When set it renders INSTEAD of
  /// [summary] — which is still required, and must still spell out the same
  /// text, because it is what a spec without parts renders and what anything
  /// reading a spec rather than the built chip sees. Build one from the other
  /// rather than writing the text twice.
  ///
  /// Not a substitute for [alert]: that says the chip's whole value is
  /// unusable, and it repaints the chip's ground, which would swallow a run's
  /// color. The two never fire together on the Radio chip — see its call site.
  final List<SummaryPart>? summaryParts;

  /// The control's accent color for its icon (issue #187), or null for the
  /// default theme color. Callers only set this once the field actually
  /// holds a reference — the accent marks a filled-in field, not just an
  /// active extension.
  final Color? iconColor;

  /// A glow behind the icon, re-evaluated once per second via [OncePerSecond]
  /// like [liveSummary]: 0 is none, 1 is full strength. For a chip announcing
  /// something about to happen on its own — the Spotting chip's next
  /// auto-respot. In [glyphGlowColor]: a white halo on a light fill cannot be
  /// seen.
  final ValueGetter<double>? liveIconGlow;

  /// The icon's color, re-evaluated once per second like [liveIconGlow],
  /// given the color it would otherwise have ([iconColor], or the chip's
  /// foreground): for a status that fades back to normal on its own — the
  /// Spotting chip's last self-spot. Ignored while disabled or alerting, as
  /// [iconColor] is.
  final LiveIconColor? liveIconColor;

  /// Draws the icon and the label toward a color, re-evaluated every frame
  /// rather than every second: for a pulse that has to move smoothly — the
  /// Spotting chip's last seconds before an auto-respot. While set, the icon
  /// ignores [liveIconColor] and the label is [liveSummary] (else [summary]),
  /// without [summaryParts]; ignored itself while disabled or alerting, as
  /// they are.
  final LiveTint? liveTint;

  /// The node the caller uses to put the keyboard on this chip, and to hang
  /// its key handling off (APP-19's focus ladder: arrows walk the strip, Up
  /// leaves for the QSO list, Down returns to the main fields). Owned by the
  /// caller — this row only hands it to the chip, so the whole keyboard
  /// policy stays in one place next to the rest of the panel's.
  final FocusNode? focusNode;

  /// Whether the chip can be tapped/opened. False renders it in Material's
  /// disabled state (dimmed, no interaction) rather than removing it from
  /// the row — used while editing an event/annotation row, where every
  /// control but Time is disabled instead of hidden, so the row's shape
  /// doesn't change between editing a contact and an event.
  final bool enabled;

  /// Paints the chip in the theme's error pair instead of the tertiary one,
  /// for something wrong with the value the chip is summarizing that is only
  /// cheap to fix while the station is still on the air. The Radio control
  /// sets it when there is no band to log on — nothing tuned, or a frequency
  /// outside every ham band; an activity control sets it for a reference its
  /// own pattern rejects, which is kept and logged either way.
  ///
  /// Both are conditions the operator cannot see once the control is shut, and
  /// a chip is shut for most of a QSO. It outranks [iconColor]: an arbitrary
  /// accent has no guaranteed contrast against the error fill.
  final bool alert;

  /// Paints the chip's ground in this color, open or shut, with white
  /// content — for a control in a mode the operator has to see from across
  /// the panel (the Time chip in manual time entry). The open chip is drawn
  /// darker, so it still reads as open. Outranks [iconColor]; [alert]
  /// outranks it.
  final Color? fill;

  const SecondaryControlSpec({
    required this.key,
    required this.icon,
    required this.summary,
    required this.expandedBuilder,
    this.liveSummary,
    this.summaryParts,
    this.iconColor,
    this.liveIconGlow,
    this.liveIconColor,
    this.liveTint,
    this.focusNode,
    this.enabled = true,
    this.alert = false,
    this.fill,
  });

  /// A copy with the given fields replaced.
  ///
  /// The panel that builds these wraps every spec on its way to the row —
  /// attaching the focus node and the expanded panel's key handling — and
  /// doing that by re-listing the fields at the call site silently drops
  /// whatever was added here since: the chip renders the default and
  /// nothing fails. `secondary_control_spec_copy_test` pins every field to
  /// this method for that reason.
  ///
  /// Null means "keep", so this cannot CLEAR a field. Nothing needs to, and
  /// clearing would take a sentinel per nullable field — more machinery
  /// than the one caller earns.
  SecondaryControlSpec copyWith({
    String? key,
    IconData? icon,
    String? summary,
    WidgetBuilder? expandedBuilder,
    ValueGetter<String>? liveSummary,
    List<SummaryPart>? summaryParts,
    Color? iconColor,
    ValueGetter<double>? liveIconGlow,
    LiveIconColor? liveIconColor,
    LiveTint? liveTint,
    FocusNode? focusNode,
    bool? enabled,
    bool? alert,
    Color? fill,
  }) => SecondaryControlSpec(
    key: key ?? this.key,
    icon: icon ?? this.icon,
    summary: summary ?? this.summary,
    expandedBuilder: expandedBuilder ?? this.expandedBuilder,
    liveSummary: liveSummary ?? this.liveSummary,
    summaryParts: summaryParts ?? this.summaryParts,
    iconColor: iconColor ?? this.iconColor,
    liveIconGlow: liveIconGlow ?? this.liveIconGlow,
    liveIconColor: liveIconColor ?? this.liveIconColor,
    liveTint: liveTint ?? this.liveTint,
    focusNode: focusNode ?? this.focusNode,
    enabled: enabled ?? this.enabled,
    alert: alert ?? this.alert,
    fill: fill ?? this.fill,
  );
}

/// Lets mouse click-drag scroll the chip strip, in addition to the
/// touch/trackpad drag Flutter's default behavior already allows.
class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {...super.dragDevices, PointerDeviceKind.mouse};
}

class SecondaryControlRow extends StatefulWidget {
  final List<SecondaryControlSpec> controls;
  final String? selectedKey;
  final ValueChanged<String?> onSelect;

  /// Extra content shown at the end of the chip row (e.g. a DUPE indicator).
  /// It's not a control — it doesn't expand or get selected.
  final Widget? trailing;

  /// Opens the show/hide + reorder settings dialog. The gear button is
  /// hidden if this is null.
  final VoidCallback? onOpenSettings;

  /// How far the parent's own horizontal padding insets this widget from
  /// the true edge of the view. The expanded control panel's background
  /// bleeds out by this much on each side so it reaches the view's actual
  /// edges instead of stopping at the parent's padding.
  final double horizontalBleed;

  /// The expanded control opens BELOW the pills rather than above them — a
  /// logging panel drawn above its QSO list, whose pills sit over the panel's
  /// bottom edge.
  final bool panelBelow;

  const SecondaryControlRow({
    super.key,
    required this.controls,
    required this.selectedKey,
    required this.onSelect,
    this.trailing,
    this.onOpenSettings,
    this.horizontalBleed = 0,
    this.panelBelow = false,
  });

  @override
  State<SecondaryControlRow> createState() => _SecondaryControlRowState();
}

class _SecondaryControlRowState extends State<SecondaryControlRow> with SingleTickerProviderStateMixin {
  final _rowKey = GlobalKey();
  final Map<String, GlobalKey> _expandedKeys = {};
  final Map<String, GlobalKey> _chipKeys = {};
  final Map<String, GlobalKey> _animatedChipKeys = {};

  static const _duration = Duration(milliseconds: 200);

  /// Whether the caret has expanded the strip into a multi-row grid.
  bool _gridExpanded = false;

  /// Chip keys currently rendered, including ones mid-exit, in display
  /// order. Rebuilt from `widget.controls` on every reconcile (so a
  /// reorder — e.g. via the settings dialog's drag list — is reflected
  /// immediately), with still-exiting keys appended after: a control
  /// dropped from `widget.controls` (hidden via settings, or an activity
  /// control that stopped applying) isn't removed from here right away —
  /// it's flagged in [_exitingKeys] and fades out via [_AnimatedChip]
  /// first, actually leaving once that chip's own fade-out animation
  /// completes (see `_handleChipExited`), so the strip doesn't just snap
  /// when a chip disappears.
  final List<String> _displayOrder = [];
  final Map<String, SecondaryControlSpec> _specByKey = {};
  final Set<String> _exitingKeys = {};

  /// A single chip's rendered height, measured post-frame from whichever
  /// chip happens to be built first — used to cap the expanded grid at
  /// ~4 rows. Defaults to a reasonable guess (a compact ChoiceChip's actual
  /// height) until the first real measurement lands.
  double _chipHeight = 32;

  /// Where the expanded panel's content sits within its (full-width)
  /// background: centered on the pill that opened it, snapping to the
  /// pill's near edge (panel edge to pill edge, not to the row's edge)
  /// when centering wouldn't fit — computed in `_measure` from the chip's
  /// and panel's own measured widths so the panel visually hangs below its
  /// pill. Defaults to left until the first post-frame measurement lands.
  Alignment _expandedAlignment = Alignment.centerLeft;

  /// The one-line strip's own scroll position — explicit (rather than the
  /// `SingleChildScrollView`'s implicit one) purely so [_measure] can listen
  /// to it. A focus change scrolls the newly-selected pill toward the
  /// centre of the strip (`LoggingFocusLadder`'s own
  /// `Scrollable.ensureVisible`, found via the nearest ancestor `Scrollable`
  /// — it doesn't need this controller to work), and that scroll runs as a
  /// 150ms animation entirely inside the `Scrollable`'s own position: it
  /// never touches this widget's `build`, so without this listener
  /// `_expandedAlignment` would stay pinned to wherever the pill sat the one
  /// post-frame moment `_measure` last ran (typically its PRE-scroll
  /// position), leaving the panel visibly anchored to the wrong spot once
  /// the pill finishes sliding to centre.
  final _stripScrollController = ScrollController();

  GlobalKey _chipKeyFor(String key) => _chipKeys.putIfAbsent(key, GlobalKey.new);

  // A GlobalKey per control (rather than one shared key) since the panel's
  // outgoing and incoming children can briefly coexist mid cross-fade
  // (AnimatedSwitcher in build) when one control is tapped right after
  // another — a shared key would collide. didUpdateWidget additionally
  // mints a FRESH key on every selection change (see there) so a control
  // re-selected while its previous panel instance is still retiring in
  // the switcher never sees the same GlobalKey mounted twice.
  GlobalKey _expandedKeyFor(String key) => _expandedKeys.putIfAbsent(key, GlobalKey.new);

  /// Bumped on every selection change; folded into the panel content's
  /// switcher key so re-selecting a control whose outgoing panel is still
  /// mid cross-fade produces a DIFFERENT child key — AnimatedSwitcher only
  /// compares against its current child, so an identical key re-entering
  /// while an outgoing copy retires would otherwise crash with duplicate
  /// keys (rapid X→Y→X pill taps).
  int _panelGeneration = 0;

  // A GlobalKey (rather than a plain ValueKey) so the same `_AnimatedChip`
  // — and so its live AnimationController — carries over when the caret
  // toggles between the one-line row and the grid: those two layouts are
  // structurally different widgets (a scrolling Row vs. a Wrap), so without
  // a GlobalKey each chip would be torn down and rebuilt on every toggle,
  // replaying its entrance fade for chips that never actually left.
  GlobalKey _animatedChipKeyFor(String key) => _animatedChipKeys.putIfAbsent(key, GlobalKey.new);

  /// Drives the expanded panel's slide: 0 = tucked away behind the top
  /// border, 1 = fully out. The content itself is fully built and laid out
  /// the whole time — this only controls how much of the area has slid up
  /// into view (and how much of the border→pills gap has been given up to
  /// it).
  late final AnimationController _panelController = AnimationController(vsync: this, duration: _duration)
    ..addStatusListener((status) {
      // Only once the close slide fully lands does the retained content
      // actually get dropped (freeing focus nodes etc.); mid-slide it must
      // stay built so it can ride back up.
      if (status == AnimationStatus.dismissed) setState(() => _panelSpec = null);
    });
  late final CurvedAnimation _panelReveal = CurvedAnimation(parent: _panelController, curve: Curves.easeInOut);

  /// The control whose panel content is showing. Retained through the
  /// close animation (when `widget.selectedKey` has already gone null) so
  /// the panel slides away still populated instead of blanking first.
  SecondaryControlSpec? _panelSpec;

  @override
  void initState() {
    super.initState();
    if (widget.selectedKey != null) _panelController.value = 1;
    _scheduleMeasure();
    _reconcileControls();
    // Re-measures once the strip's own scroll settles (a drag, or the
    // ensureVisible animation a focus change starts) — see
    // `_stripScrollController`'s doc for why this can't just run once up
    // front. Debounced rather than wired straight to `_scheduleMeasure`: a
    // single 150ms scroll animation notifies on nearly every frame, and
    // re-measuring (plus the rebuild a changed alignment triggers) on each
    // one is wasted work an operator crossing between controls with the
    // keyboard would otherwise pay on every keystroke.
    _stripScrollController.addListener(_scheduleMeasureAfterScrollSettles);
  }

  /// Whether the panel should currently be out: a control is selected AND
  /// it still exists in `widget.controls`. The second half matters when
  /// the selected control is removed (hidden via settings, or an activity
  /// control that stopped applying) without the caller clearing its
  /// selection — the panel must close rather than stay stuck open showing
  /// a control that no longer exists.
  bool get _panelShouldBeOpen => widget.selectedKey != null && widget.controls.any((c) => c.key == widget.selectedKey);

  @override
  void didUpdateWidget(covariant SecondaryControlRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedKey != oldWidget.selectedKey && widget.selectedKey != null) {
      _panelGeneration++;
      _expandedKeys[widget.selectedKey!] = GlobalKey();
    }
    // Driven from the derived state rather than just selectedKey changes,
    // so the panel also closes when its control disappears from
    // widget.controls with the selection left stale. forward() at 1 /
    // reverse() at 0 are no-ops, so calling on every update is fine.
    _panelShouldBeOpen ? _panelController.forward() : _panelController.reverse();
    _scheduleMeasure();
    _reconcileControls();
  }

  /// Updates [_displayOrder]/[_specByKey]/[_exitingKeys] from
  /// `widget.controls`, ahead of this frame's `build` — called from
  /// `initState`/`didUpdateWidget` rather than via `setState` since a
  /// rebuild is already about to happen (or, for `initState`, hasn't
  /// happened yet) either way. Actual removal of a departed key happens
  /// later, from `_handleChipExited` once that chip's own fade-out
  /// animation reports it's done — tying removal to the animation
  /// finishing (rather than a fixed `Timer`) means a control that
  /// disappears and reappears within the fade window is simply left alone,
  /// instead of a stale timer force-removing it after the fact.
  void _reconcileControls() {
    final incoming = {for (final control in widget.controls) control.key: control};

    for (final key in _specByKey.keys) {
      if (!incoming.containsKey(key)) _exitingKeys.add(key);
    }
    _exitingKeys.removeAll(incoming.keys);

    _specByKey.removeWhere((key, _) => !incoming.containsKey(key) && !_exitingKeys.contains(key));
    _specByKey.addAll(incoming);

    _displayOrder
      ..clear()
      ..addAll(incoming.keys)
      ..addAll(_exitingKeys);

    // Keys with no chip left showing (fully reconciled away) don't need
    // their measurement/animation GlobalKeys held onto forever. The panel
    // spec's key stays live even after its chip is gone — the panel can
    // still be mid close-slide with that Builder mounted, and dropping its
    // GlobalKey here would mint a fresh one next build, remounting (and
    // blanking) the closing panel's content mid-animation.
    final live = _displayOrder.toSet();
    if (_panelSpec case final spec?) live.add(spec.key);
    _chipKeys.removeWhere((key, _) => !live.contains(key));
    _expandedKeys.removeWhere((key, _) => !live.contains(key));
    _animatedChipKeys.removeWhere((key, _) => !live.contains(key));
  }

  /// Called by a chip's own `_AnimatedChip` once its fade-out animation
  /// finishes — the point at which it's actually safe to drop it from
  /// display state, rather than guessing at a fixed delay.
  void _handleChipExited(String key) {
    if (!mounted || !_exitingKeys.contains(key)) return;
    setState(() {
      _displayOrder.remove(key);
      _specByKey.remove(key);
      _exitingKeys.remove(key);
      _chipKeys.remove(key);
      // The panel spec's GlobalKey survives the chip (see the matching
      // guard in _reconcileControls): its Builder can still be mounted for
      // the tail of the panel's close slide.
      if (_panelSpec?.key != key) _expandedKeys.remove(key);
      _animatedChipKeys.remove(key);
    });
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  Timer? _scrollMeasureDebounce;

  /// [_scheduleMeasure], coalesced across the burst of notifications one
  /// scroll (drag or animation) produces — only the last one within this
  /// window actually schedules a measurement. 32ms is short enough that the
  /// panel still catches up right after the scroll stops, not perceptibly
  /// later, but long enough to collapse a ~150ms animation's every-frame
  /// notifications down to the one that matters.
  void _scheduleMeasureAfterScrollSettles() {
    _scrollMeasureDebounce?.cancel();
    _scrollMeasureDebounce = Timer(const Duration(milliseconds: 32), () {
      _scrollMeasureDebounce = null;
      if (mounted) _scheduleMeasure();
    });
  }

  @override
  void dispose() {
    _scrollMeasureDebounce?.cancel();
    _panelReveal.dispose();
    _panelController.dispose();
    _stripScrollController.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted) return;

    final anyChipBox = widget.controls.isEmpty ? null : _chipKeys[widget.controls.first.key]?.currentContext?.findRenderObject() as RenderBox?;
    if (anyChipBox != null && anyChipBox.attached) {
      final height = anyChipBox.size.height;
      if (height > 0 && (height - _chipHeight).abs() > 0.5) {
        setState(() => _chipHeight = height);
      }
    }

    if (widget.selectedKey == null) return;
    final rowBox = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    final chipBox = _chipKeys[widget.selectedKey]?.currentContext?.findRenderObject() as RenderBox?;
    if (rowBox == null || chipBox == null || !rowBox.attached || !chipBox.attached) return;

    final chipLeft = chipBox.localToGlobal(Offset.zero, ancestor: rowBox).dx;
    final chipWidth = chipBox.size.width;
    final chipCenter = chipLeft + chipWidth / 2;
    final availableWidth = rowBox.size.width;

    // The panel centers on the pill that opened it. When centering would
    // push it past the row's edge, it snaps to the PILL's near edge (panel
    // left edge to pill left edge, or panel right edge to pill right edge)
    // rather than flushing against the row's own edge — keeping the panel
    // visually attached to its pill. A final clamp still keeps it on
    // screen for pills scrolled partially off the strip.
    final expandedBox = _expandedKeys[widget.selectedKey]?.currentContext?.findRenderObject() as RenderBox?;
    final expandedWidth = expandedBox != null && expandedBox.attached ? expandedBox.size.width : null;
    Alignment alignment;
    if (expandedWidth == null || expandedWidth >= availableWidth) {
      alignment = Alignment.center;
    } else {
      final centered = chipCenter - expandedWidth / 2;
      // Mutually exclusive branches: a panel that overflows BOTH ways when
      // centered (very wide panel, pill near an edge) takes only the
      // branch for the side it ran off of, and the clamp resolves the
      // rest — chaining both snaps would fling it to the far edge instead.
      double panelLeft;
      if (centered < 0) {
        panelLeft = chipLeft;
      } else if (centered + expandedWidth > availableWidth) {
        panelLeft = chipLeft + chipWidth - expandedWidth;
      } else {
        panelLeft = centered;
      }
      panelLeft = panelLeft.clamp(0.0, availableWidth - expandedWidth);
      final x = 2 * panelLeft / (availableWidth - expandedWidth) - 1;
      alignment = Alignment(x.clamp(-1.0, 1.0), 0);
    }
    if (alignment != _expandedAlignment) {
      setState(() => _expandedAlignment = alignment);
    }
  }

  /// Every control's panel gets at least this much content height (the
  /// tallest built-in panel — Radio's field row — sets the bar), so the
  /// area doesn't jump between sizes when switching controls and shorter
  /// panels (Time) don't open a skinnier strip than the design intends.
  /// Read from the density rather than fixed: this is the floor an open
  /// control's panel occupies inside the logging panel, and the logging panel
  /// is the app's one rigid block.
  static double _panelMinContentHeightOf(BuildContext context) => LayoutDensity.metricsOf(context).controlPanelMinHeight;

  /// Border→pills spacing when the panel is closed, and panel→pills
  /// spacing once it's fully out — the panel "absorbs" most of the closed
  /// gap as it slides up, ending closer to the pills than the border was.
  static double _closedGapOf(BuildContext context) => LayoutDensity.metricsOf(context).chipStripClosedGap;
  static double _openGapOf(BuildContext context) => LayoutDensity.metricsOf(context).chipStripOpenGap;

  /// Width of the gradient mask over the one-line strip's trailing edge.
  /// The scroll content ends with a spacer of the same width, so at
  /// maximum scroll the last pill (settings gear / DUPE) clears the mask
  /// and can actually be seen — the mask sits permanently over the
  /// viewport's last stretch, so without the spacer that pill could never
  /// escape it.
  static const double _maskWidth = 64;

  @override
  Widget build(BuildContext context) {
    SecondaryControlSpec? selected;
    for (final control in widget.controls) {
      if (control.key == widget.selectedKey) selected = control;
    }
    // Retain the outgoing control's spec while the close slide plays (the
    // status listener clears it once dismissed); refresh to the live spec
    // whenever there is one so summaries/inputs stay current.
    if (selected != null) _panelSpec = selected;

    final theme = Theme.of(context);
    const spacing = 6.0;

    final chips = [
      for (final key in _displayOrder)
        if (_specByKey[key] case final control?)
          _AnimatedChip(
            key: _animatedChipKeyFor(key),
            duration: _duration,
            exiting: _exitingKeys.contains(key),
            onExited: () => _handleChipExited(key),
            child: _ControlChip(
              key: _chipKeyFor(key),
              control: control,
              // Excludes a mid-exit chip: it's no longer in widget.controls,
              // so a stale widget.selectedKey pointing at it (the caller
              // hasn't cleared selection yet) shouldn't still highlight it.
              selected: key == widget.selectedKey && !_exitingKeys.contains(key),
              onTap: () => widget.onSelect(key == widget.selectedKey ? null : key),
            ),
          ),
      ?widget.trailing,
      if (widget.onOpenSettings != null) _SettingsPill(height: _chipHeight, onTap: widget.onOpenSettings!),
    ];

    return Column(
      key: _rowKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      verticalDirection: widget.panelBelow ? VerticalDirection.up : VerticalDirection.down,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => OverflowBox(
            // Bleeds past the parent's own horizontal padding so the
            // background below reaches the view's true edges instead of
            // stopping short at that padding. OverflowBox (rather than a
            // negative Padding, which Flutter rejects outright) lets a
            // child be wider than the space its parent offered.
            minWidth: 0,
            maxWidth: constraints.maxWidth + widget.horizontalBleed * 2,
            // The Column above sizes to its children (mainAxisSize.min),
            // handing this an unbounded height — deferToChild sizes the
            // OverflowBox to its child's own height instead of trying to
            // fill that infinite constraint.
            fit: OverflowBoxFit.deferToChild,
            // The panel area lives tucked "behind" the border above; since
            // the whole logging panel is bottom-anchored, growing this slot
            // pushes the border upward — the dark area, with its content
            // already fully built and laid out inside it, rides up with
            // that top edge (topCenter pins the child to the top of the
            // reveal window). Closing reverses the same slide.
            child: SizeTransition(
              sizeFactor: _panelReveal,
              // Mirrored when the panel opens downward: its content rides
              // down with the bottom edge instead.
              alignment: widget.panelBelow ? Alignment.bottomCenter : Alignment.topCenter,
              child: _panelSpec == null
                  ? SizedBox(width: constraints.maxWidth)
                  : Container(
                      // Same solid color as a selected pill — this is the
                      // "extended area" that gets the pill background, not
                      // the chip strip itself — full width, flush against
                      // the top and sides, with its own regular inner
                      // padding around the content.
                      width: constraints.maxWidth + widget.horizontalBleed * 2,
                      color: theme.colorScheme.tertiary,
                      // Horizontal inset matches the pill row's own — that
                      // row has no padding of its own, so its chips sit
                      // exactly `horizontalBleed` in from the true edge
                      // (the parent's own padding, which this panel
                      // otherwise bleeds past).
                      padding: EdgeInsets.symmetric(horizontal: widget.horizontalBleed, vertical: Space.md),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: _panelMinContentHeightOf(context)),
                        // A closing panel's fields stay mounted for the
                        // 200ms slide, but must not keep keyboard focus —
                        // keystrokes right after deselecting would land in
                        // the invisible field (and Enter would submit it)
                        // instead of the main entry row.
                        child: ExcludeFocus(
                          excluding: !_panelShouldBeOpen,
                          // Switching straight between two controls while
                          // the panel is out (the slide controller stays
                          // at 1) cross-fades just the content, inside the
                          // steady dark area. The generation in the key
                          // makes every switch a fresh child, so rapidly
                          // re-selecting a control whose outgoing panel is
                          // still retiring can't collide with it.
                          child: AnimatedSwitcher(
                            duration: _duration,
                            child: KeyedSubtree(
                              key: ValueKey('${_panelSpec!.key}#$_panelGeneration'),
                              child: Align(
                                alignment: _expandedAlignment,
                                child: Builder(key: _expandedKeyFor(_panelSpec!.key), builder: _panelSpec!.expandedBuilder),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        // The border→pills breathing room shrinks as the panel slides out,
        // ceding most of itself to the panel: closed, the pills sit
        // _closedGap below the border; open, they sit only _openGap below
        // the panel's bottom edge.
        AnimatedBuilder(
          animation: _panelReveal,
          builder: (context, _) {
            final closed = _closedGapOf(context);
            final open = _openGapOf(context);
            return SizedBox(height: closed - (closed - open) * _panelReveal.value);
          },
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                // The one-line strip below deliberately paints past this
                // Stack's left edge (OverflowBox bleed to the window edge)
                // — default hardEdge clipping would cut that off.
                clipBehavior: Clip.none,
                children: [
                  // AnimatedSize (rather than a manual cross-fade) animates
                  // the height change between the single-line strip and the
                  // multi-row grid — the content swap itself stays instant
                  // (only one of the two is ever built). The Row and Wrap
                  // below are
                  // different widget types, so Flutter already rebuilds
                  // this subtree fresh on every toggle regardless — each
                  // chip's GlobalKey (`_animatedChipKeyFor`) is what
                  // actually carries its live AnimationController across
                  // that rebuild, not an extra key on this container.
                  AnimatedSize(
                    duration: _duration,
                    curve: Curves.easeInOut,
                    alignment: Alignment.topLeft,
                    child: _gridExpanded
                        ? ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: _chipHeight * 4 + spacing * 3),
                            child: SingleChildScrollView(
                              child: Wrap(spacing: spacing, runSpacing: spacing, children: chips),
                            ),
                          )
                        : LayoutBuilder(
                            // The strip's viewport bleeds left past the
                            // parent's padding to the window's true edge
                            // (right-aligned OverflowBox: all the extra
                            // width goes leftward), so scrolled chips run
                            // off the screen edge instead of clipping at
                            // the padding. The leading spacer inside the
                            // scroll content re-establishes that same inset
                            // for the strip at rest, so the first chip
                            // still lines up with everything else.
                            builder: (context, strip) => OverflowBox(
                              minWidth: 0,
                              maxWidth: strip.maxWidth + widget.horizontalBleed,
                              alignment: Alignment.centerRight,
                              fit: OverflowBoxFit.deferToChild,
                              child: SizedBox(
                                width: strip.maxWidth + widget.horizontalBleed,
                                child: ScrollConfiguration(
                                  behavior: _DragScrollBehavior(),
                                  child: SingleChildScrollView(
                                    controller: _stripScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(width: widget.horizontalBleed),
                                        for (final chip in chips) ...[chip, if (chip != chips.last) const SizedBox(width: spacing)],
                                        // Lets the last pill scroll clear of
                                        // the trailing gradient mask (see
                                        // _maskWidth).
                                        const SizedBox(width: _maskWidth),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  // Painted OVER the strip's trailing edge (an overlay in
                  // this Stack, not a sibling — a sibling would sit beside
                  // the already-clipped strip and never actually cover the
                  // chips): a background-colored mask ramping from
                  // transparent at its left edge to solid at the strip's
                  // right edge, so chips scrolling toward the caret
                  // dissolve across it instead of hard-clipping at the
                  // strip's edge. Paint-only; IgnorePointer keeps the chips
                  // under it scrollable/tappable. Only for the one-line
                  // strip — the grid wraps instead of clipping sideways.
                  Positioned(
                    right: 0,
                    top: 0,
                    width: _maskWidth,
                    height: _chipHeight,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: _duration,
                        opacity: _gridExpanded ? 0 : 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              // Fully opaque 8px shy of the right edge
                              // (0.875 of the 64px width), so the chips are
                              // completely gone a beat before the caret.
                              stops: const [0, 0.875],
                              colors: [theme.colorScheme.tertiaryContainer.withValues(alpha: 0), theme.colorScheme.tertiaryContainer],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: HaLoColors.of(context).tertiaryLight.withValues(alpha: 0.5)),
              icon: AnimatedRotation(
                turns: _gridExpanded ? 0.5 : 0,
                duration: _duration,
                curve: Curves.easeInOut,
                child: Icon(MdiIcons.chevronDown, semanticLabel: _gridExpanded ? t.common.collapse : t.common.expand),
              ),
              onPressed: () => setState(() => _gridExpanded = !_gridExpanded),
            ),
          ],
        ),
      ],
    );
  }
}

/// Fades a chip in when it's newly added to the strip, and back out when
/// [exiting] flips true — calling [onExited] once that fade-out actually
/// finishes, which is the parent's cue to drop the chip for good. Opacity-
/// only (rather than also shrinking its width via `SizeTransition`) so the
/// chip's laid-out size — and so its tap target and its contribution to
/// `_measure`'s zone math — stays stable across the fade instead of
/// animating through partial sizes.
class _AnimatedChip extends StatefulWidget {
  final Widget child;
  final bool exiting;
  final Duration duration;
  final VoidCallback onExited;

  const _AnimatedChip({super.key, required this.child, required this.exiting, required this.duration, required this.onExited});

  @override
  State<_AnimatedChip> createState() => _AnimatedChipState();
}

class _AnimatedChipState extends State<_AnimatedChip> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration)
    ..addStatusListener(_handleStatusChanged)
    ..forward();

  void _handleStatusChanged(AnimationStatus status) {
    // Only reachable by actually finishing a reverse (never interrupted by
    // a forward() call in between — see didUpdateWidget), so there's no
    // stale-callback risk equivalent to a fixed-delay Timer: if `exiting`
    // flips back to false first, forward() takes over and dismissed is
    // never reached for this reverse.
    if (status == AnimationStatus.dismissed && widget.exiting) widget.onExited();
  }

  @override
  void didUpdateWidget(covariant _AnimatedChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exiting != oldWidget.exiting) {
      widget.exiting ? _controller.reverse() : _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // A chip mid-exit is no longer part of widget.controls, so tapping it
      // shouldn't be able to call onSelect with a key the caller no longer
      // recognizes.
      ignoring: widget.exiting,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        child: widget.child,
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  final SecondaryControlSpec control;
  final bool selected;
  final VoidCallback onTap;

  const _ControlChip({super.key, required this.control, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);

    // Matches app-polo's LoggerChip: unselected = tertiaryLight fill with
    // onTertiaryContainer text/icon; selected = solid tertiary fill with
    // onTertiary (near-white) text/icon. A rounded-rectangle shape, not
    // Flutter's default full-pill chip — app-polo's chips (react-native-paper
    // Chip, flat mode) are boxy with a modest corner radius.
    var foreground = selected ? theme.colorScheme.onTertiary : theme.colorScheme.onTertiaryContainer;
    var background = poloColors.tertiaryLight;
    var selectedColor = theme.colorScheme.tertiary;
    // The error pair keeps the same selected/unselected contrast the
    // tertiary one has — container fill closed, solid fill open — so an
    // alerting chip still reads as open or shut.
    if (control.alert) {
      foreground = selected ? theme.colorScheme.onError : theme.colorScheme.onErrorContainer;
      background = theme.colorScheme.errorContainer;
      selectedColor = theme.colorScheme.error;
    } else if (control.fill case final fill?) {
      foreground = Colors.white;
      background = fill;
      selectedColor = Color.lerp(fill, Colors.black, 0.35)!;
    }
    // Every color here is pinned explicitly (below), which bypasses
    // ChoiceChip's own built-in disabled treatment — fade everything by
    // hand instead, or a disabled pill (editing an event — see
    // `SecondaryControlSpec.enabled`) would look indistinguishable from a
    // live one.
    if (!control.enabled) {
      foreground = foreground.withValues(alpha: 0.5);
      background = background.withValues(alpha: 0.5);
      selectedColor = selectedColor.withValues(alpha: 0.5);
    }

    final painted = control.alert || control.fill != null;
    final liveColor = control.enabled && !painted ? control.liveIconColor : null;
    final tint = control.enabled && !painted ? control.liveTint : null;
    Color tinted(Color color) => tint == null ? color : Color.lerp(color, tint.color, tint.strength().clamp(0.0, 1.0))!;
    Widget icon({List<Shadow>? shadows}) {
      final base = control.enabled && !painted ? (control.iconColor ?? foreground) : foreground;
      return Icon(
        control.icon,
        size: 16 * MediaQuery.textScalerOf(context).scale(1.0),
        // The accent shows whenever the field holds a reference — open
        // (selected, solid tertiary fill) or closed (tertiaryLight fill).
        // Holding one is all it means: a reference the control's pattern
        // rejects is kept like any other, and says so through [alert] below
        // rather than by withholding the accent. Contrast against the selected fill isn't
        // guaranteed for an arbitrary extension color, but that's on the
        // extension to pick a color that works — same as the unselected case.
        // An alerting chip drops the accent entirely (see [alert]).
        color: tint != null ? tinted(base) : (liveColor == null ? base : liveColor(base)),
        shadows: shadows,
      );
    }

    Widget glowingIcon() {
      final glow = (control.liveIconGlow?.call() ?? 0).clamp(0.0, 1.0);
      return icon(
        shadows: glow == 0
            ? null
            : [
                Shadow(
                  // Up to twice a static glyph's halo: a glow
                  // that only matched it would not read as rising.
                  color: glyphGlowColor(Theme.of(context)).withValues(alpha: glyphGlowColor(Theme.of(context)).a * 2 * glow),
                  blurRadius: 4 + 8 * glow,
                ),
              ],
      );
    }

    return ChoiceChip(
      focusNode: control.focusNode,
      avatar: tint != null
          ? _EveryFrame(builder: (_) => glowingIcon())
          : control.liveIconGlow != null || liveColor != null
          ? OncePerSecond(builder: (_, _) => glowingIcon())
          : icon(),
      label: tint != null
          ? _EveryFrame(
              builder: (_) => Text(control.liveSummary?.call() ?? control.summary, style: TextStyle(color: tinted(foreground))),
            )
          : control.liveSummary != null
          ? OncePerSecond(
              builder: (_, _) => Text(control.liveSummary!(), style: TextStyle(color: foreground)),
            )
          : control.summaryParts != null
          ? Text.rich(
              TextSpan(
                children: [
                  for (final part in control.summaryParts!)
                    TextSpan(
                      text: part.text,
                      // A run's own color takes the same fade a disabled
                      // chip gives the foreground, or the one colored run
                      // would be the only thing on a dimmed chip at full
                      // strength.
                      style: TextStyle(
                        color: part.color == null ? foreground : (control.enabled ? part.color! : part.color!.withValues(alpha: part.color!.a * 0.5)),
                      ),
                    ),
                ],
              ),
            )
          : Text(control.summary, style: TextStyle(color: foreground)),
      selected: selected,
      showCheckmark: false,
      visualDensity: LayoutDensity.of(context).chipVisualDensity,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: background,
      selectedColor: selectedColor,
      // Material3's ChoiceChip draws a default outline when side is null;
      // app-polo's LoggerChip has none.
      side: BorderSide.none,
      onSelected: control.enabled ? (_) => onTap() : null,
      mouseCursor: control.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
    );
  }
}

/// Rebuilds [builder] every frame while mounted — for a chip's
/// [SecondaryControlSpec.liveTint], which has to move smoothly. Only ever in
/// the tree for the few seconds a tint is set.
class _EveryFrame extends StatefulWidget {
  const _EveryFrame({required this.builder});

  final WidgetBuilder builder;

  @override
  State<_EveryFrame> createState() => _EveryFrameState();
}

class _EveryFrameState extends State<_EveryFrame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => setState(() {}))..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Opens the show/hide + reorder settings dialog. Same pill shape/fill as
/// an unselected control chip (it's never "selected" — it opens a dialog
/// rather than expanding inline), icon-only. Built directly on Material
/// rather than ChoiceChip/ActionChip — Chip's built-in label padding keeps
/// some horizontal space reserved even for an empty label, which fights
/// against staying narrow; a square Material+InkWell has no such minimum.
class _SettingsPill extends StatelessWidget {
  final double height;
  final VoidCallback onTap;

  const _SettingsPill({required this.height, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);
    final borderRadius = BorderRadius.circular(8);

    return SizedBox(
      width: height,
      height: height,
      child: Material(
        color: poloColors.tertiaryLight,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          mouseCursor: SystemMouseCursors.click,
          onTap: onTap,
          child: Center(
            child: Icon(MdiIcons.cog, size: 16 * MediaQuery.textScalerOf(context).scale(1.0), color: theme.colorScheme.onTertiaryContainer),
          ),
        ),
      ),
    );
  }
}
