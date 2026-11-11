// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The frame around the logging panel's information area: the room it
// reserves, how its content grows and cross-fades, where the host's footer
// goes, and where the panel's second action button sits. The panel
// decides WHAT the area shows and WHICH action the button is; this widget
// only decides where they go and how they get there.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'semantic_id.dart';
import 'spacing.dart';
import 'ui_scale.dart';

/// The information area's frame. See the file comment.
///
/// A min-height container: at least the action button's own diameter so a
/// one-line info area can't leave the button overflowing upward into the
/// secondary control chips above, but free to grow as tall as the call-info
/// lines and their wrapped pills need. It grows away from the entry row,
/// which never moves (docs/design/logging-fields.md, "The three parts"), and
/// it grows at once but shrinks late: what it pushed aside stays put for
/// five seconds after the area gets shorter, then follows over ten.
class LoggingInfoFrame extends StatefulWidget {
  const LoggingInfoFrame({
    super.key,
    required this.buttonDiameter,
    this.actionWidth,
    required this.leftieMode,
    required this.signature,
    this.footer,
    required this.actionButton,
    required this.child,
    this.entryRowAbove = false,
  });

  /// The log button's diameter (measured, or the first-frame fallback): the
  /// action button matches it, the area is at least that tall, and both the
  /// content and the strip keep clear of the column it sits in.
  final double buttonDiameter;

  /// How wide [actionButton] is when it is wider than one button — the
  /// operation lifecycle's labelled START, or its pair of controls. The
  /// content and the strip keep clear of this much; the area's minimum height
  /// stays [buttonDiameter]. Null is one button's width.
  final double? actionWidth;

  /// Action button on the left, for a left-handed operator.
  final bool leftieMode;

  /// What the area is showing, as a string that changes when the DISPLAYED
  /// content changes and stays put across in-place updates (the stats line's
  /// 1 Hz tick). Only a change here cross-fades — see [_LoggingInfoFrameState].
  final String signature;

  /// Whatever the host wants under the content, at the bottom of the area's
  /// own room — the app's FYI area. Outside the cross-fade: a change of
  /// content is not a change of what the host shows, and a footer remounted
  /// with every call-field keystroke would lose its state each time. It pads
  /// itself inside its own slide, so nothing is spent while it is not
  /// showing.
  final Widget? footer;

  /// The panel's second action button, pinned to the bottom of the area —
  /// directly over the log button.
  final Widget actionButton;

  /// The area's content.
  final Widget child;

  /// The entry row is ABOVE this frame rather than below it — a panel drawn
  /// above its QSO list. The action button pins to the top edge, still
  /// directly beside the log button; the footer stays under the content.
  final bool entryRowAbove;

  @override
  State<LoggingInfoFrame> createState() => _LoggingInfoFrameState();
}

/// How long the frame keeps its height after its content gets shorter, and
/// how long it then takes to come down: the controls around it stay put
/// while the content comes and goes — an FYI message, a call's details —
/// and drift back rather than jump once it has settled.
const _holdFor = Duration(seconds: 5);
const _releaseOver = Duration(seconds: 10);

/// The release's shortest step: a tall shrink comes down several device
/// pixels a step rather than stepping at the frame rate.
const _stepAtLeast = Duration(milliseconds: 50);

class _LoggingInfoFrameState extends State<LoggingInfoFrame> {
  /// A monotonic generation, bumped whenever [LoggingInfoFrame.signature]
  /// changes, which keys the AnimatedSwitcher below. A content-derived key
  /// that can repeat (stats → call → stats) would collide with a still-fading
  /// outgoing child of the same key and crash the switcher's Stack; a
  /// never-repeating generation can't. An unchanged signature leaves the key
  /// alone, so the content updates in place.
  int _generation = 0;

  /// The most the frame may keep of the height it had: unbounded while it
  /// holds, then lowered a device pixel at a time while it releases.
  double _ceiling = double.infinity;

  /// Device pixels per logical pixel here, the UI scale included
  /// (ui-scaling.md): what a release step is a whole number of.
  double _grid = 1;

  /// The hold, and then the release.
  Timer? _timer;

  /// The content's own height as last laid out: a change to it while held
  /// starts the hold over, a step of the release does not.
  double? _natural;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// After every layout that moved either height.
  void _laidOut(double natural, double shown) {
    if (!mounted) return;
    final changed = natural != _natural;
    _natural = natural;
    if (shown <= natural) {
      // Not holding: done releasing, or grown past the hold.
      _timer?.cancel();
      _timer = null;
      if (_ceiling != double.infinity) setState(() => _ceiling = double.infinity);
      return;
    }
    if (!changed) return;
    _timer?.cancel();
    if (_ceiling != double.infinity) setState(() => _ceiling = double.infinity);
    _timer = Timer(_holdFor, () => _release(from: shown, to: natural));
  }

  /// Steps the ceiling from [from] down to [to] in whole device pixels,
  /// one a step and never a step under [_stepAtLeast], spread over
  /// [_releaseOver]: a redraw per step, not per frame. Steps counted from
  /// the timer's ticks, so a throttled timer (a background tab) catches up
  /// rather than stretching the release.
  void _release({required double from, required double to}) {
    final grid = _grid;
    final top = (from * grid).floor();
    final pixels = top - (to * grid).ceil();
    if (pixels <= 0) {
      setState(() => _ceiling = to);
      return;
    }
    final steps = math.min(pixels, _releaseOver.inMicroseconds ~/ _stepAtLeast.inMicroseconds);
    _timer = Timer.periodic(_releaseOver ~/ steps, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final step = math.min(timer.tick, steps);
      if (step == steps) timer.cancel();
      setState(() => _ceiling = step == steps ? to : (top - (pixels * step / steps).round()) / grid);
    });
  }

  @override
  void didUpdateWidget(LoggingInfoFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.signature != oldWidget.signature) _generation++;
  }

  @override
  Widget build(BuildContext context) {
    _grid = PixelGrid.of(context).devicePixelsPerLogical;
    final reserve = widget.actionWidth ?? widget.buttonDiameter;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          verticalDirection: widget.entryRowAbove ? VerticalDirection.up : VerticalDirection.down,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.buttonDiameter),
              child: SizedBox(
                width: double.infinity,
                // Reserves room for the button positioned on top of this box
                // (below), so text truncates before it rather than rendering
                // underneath.
                child: Padding(
                  padding: widget.leftieMode ? EdgeInsets.only(left: reserve + Space.md) : EdgeInsets.only(right: reserve + Space.md),
                  // Top-aligned, with the height animating as the content
                  // grows and content swaps cross-fading. AnimatedSize
                  // drives the growth; the hold keeps the height as the
                  // content shrinks and steps it down while it releases,
                  // each step whole in the frame after its own: a
                  // microsecond, not zero, which completes the size's
                  // controller inside layout and re-dirties the box
                  // mid-layout. In that frame the column is already a step
                  // shorter than the box, so the box holds it against the
                  // fields' edge, where the footer is. AnimatedSwitcher fades
                  // between distinct states, keyed by the generation.
                  child: AnimatedSize(
                    duration: _ceiling.isFinite ? const Duration(microseconds: 1) : const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    alignment: _ceiling.isFinite && !widget.entryRowAbove ? Alignment.bottomLeft : Alignment.topLeft,
                    child: _HeightHold(
                      ceiling: _ceiling,
                      onLayout: _laidOut,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        // The footer at the bottom of the room the area
                        // reserves or holds, the slack between it and the
                        // content: it rises out of the fields' edge into that
                        // slack, not down from under the content. With the
                        // entry row above, it stays under the content, nearer
                        // the row.
                        mainAxisAlignment: widget.entryRowAbove ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 120),
                            layoutBuilder: (currentChild, previousChildren) =>
                                Stack(alignment: Alignment.topLeft, children: [...previousChildren, ?currentChild]),
                            child: KeyedSubtree(key: ValueKey(_generation), child: widget.child),
                          ),
                          ?widget.footer,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: widget.leftieMode ? 0 : null,
          right: widget.leftieMode ? null : 0,
          top: widget.entryRowAbove ? 0 : null,
          bottom: widget.entryRowAbove ? null : 0,
          child: widget.actionButton,
        ),
      ],
    );
  }
}

/// The info row's second (no-background) button — the one secondary action
/// slot, serving Wipe, Undo, Delete, Restore or Revert as the panel decides.
///
/// Same footprint as the submit button (whose size is layout-derived and
/// measured post-frame, hence [diameter] rather than a constant), no
/// background of its own, and its icon tinted with the colour the submit
/// button uses as its *background*, tying the two together visually.
class LoggingActionButton extends StatelessWidget {
  const LoggingActionButton({super.key, required this.diameter, required this.icon, required this.label, required this.onPressed, required this.color});

  final double diameter;
  final IconData icon;

  /// Screen-reader name only — no hover tooltip (user-interface.md).
  final String? label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // #236: stable id for agent/browser tooling. Named for its default role
    // (Wipe) even though it also serves Undo/Delete/Restore/Revert — it's the
    // one secondary action slot, and the dev bridge drives it as `wipe`.
    return semanticId(
      'action.wipe',
      SizedBox(
        width: diameter,
        height: diameter,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, semanticLabel: label),
          color: color,
          padding: EdgeInsets.zero,
          iconSize: diameter * 0.5 * 1.2,
        ),
      ),
    );
  }
}

/// Never shorter than its child, nor shorter than it was itself unless
/// [ceiling] says so: the larger of the child's height and the least of its
/// own last height and [ceiling]. A child shorter than that is laid out
/// again at least that tall, so the child's own alignment says where the
/// held room goes — the frame's column puts it between the content and the
/// footer, which stays at the fields' edge. At least, never exactly: a
/// tight height makes the child a relayout boundary, and a change inside it
/// would never reach the hold.
class _HeightHold extends SingleChildRenderObjectWidget {
  const _HeightHold({required this.ceiling, required this.onLayout, required super.child});

  final double ceiling;

  /// The child's height and the height shown, after a layout that changed
  /// either — in the frame's post-frame phase, when state may change.
  final void Function(double natural, double shown) onLayout;

  @override
  _RenderHeightHold createRenderObject(BuildContext context) => _RenderHeightHold(ceiling, onLayout);

  @override
  void updateRenderObject(BuildContext context, _RenderHeightHold renderObject) => renderObject
    ..ceiling = ceiling
    ..onLayout = onLayout;
}

class _RenderHeightHold extends RenderProxyBox {
  _RenderHeightHold(this._ceiling, this.onLayout);

  double _ceiling;
  set ceiling(double value) {
    if (value == _ceiling) return;
    _ceiling = value;
    markNeedsLayout();
  }

  void Function(double natural, double shown) onLayout;

  double? _shown;
  double? _reportedNatural;
  double? _reportedShown;

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints, parentUsesSize: true);
    final natural = child.size.height;
    final held = math.min(_shown ?? natural, _ceiling);
    final shown = _shown = constraints.constrainHeight(math.max(natural, held));
    if (shown > natural) child.layout(constraints.copyWith(minHeight: shown), parentUsesSize: true);
    size = constraints.constrain(Size(child.size.width, shown));
    if (natural != _reportedNatural || shown != _reportedShown) {
      _reportedNatural = natural;
      _reportedShown = shown;
      SchedulerBinding.instance.addPostFrameCallback((_) => onLayout(natural, shown));
    }
  }
}
