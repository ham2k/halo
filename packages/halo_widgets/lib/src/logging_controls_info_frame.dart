// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The frame around the logging panel's information area: the room it
// reserves, how its content grows and cross-fades, where the strip above the
// entry row goes, and where the panel's second action button sits. The panel
// decides WHAT the area shows and WHICH action the button is; this widget
// only decides where they go and how they get there.

import 'package:flutter/material.dart';

import 'logging_controls_metrics.dart';
import 'semantic_id.dart';
import 'spacing.dart';

/// The information area's frame. See the file comment.
///
/// A min-height container: at least the action button's own diameter so a
/// one-line info area can't leave the button overflowing upward into the
/// secondary control chips above, but free to grow taller for the call-info
/// panel's up-to-three lines.
class LoggingInfoFrame extends StatefulWidget {
  const LoggingInfoFrame({
    super.key,
    required this.buttonDiameter,
    required this.leftieMode,
    required this.signature,
    required this.strip,
    required this.actionButton,
    required this.child,
  });

  /// The log button's diameter (measured, or the first-frame fallback): the
  /// action button matches it, the area is at least that tall, and both the
  /// content and the strip keep clear of the column it sits in.
  final double buttonDiameter;

  /// Action button on the left, for a left-handed operator.
  final bool leftieMode;

  /// What the area is showing, as a string that changes when the DISPLAYED
  /// content changes and stays put across in-place updates (the stats line's
  /// 1 Hz tick). Only a change here cross-fades — see [_LoggingInfoFrameState].
  final String signature;

  /// Whatever the host wants directly above the entry row, under the area —
  /// it pads itself inside its own slide, so nothing is spent while it is
  /// not showing.
  final Widget? strip;

  /// The panel's second action button, pinned to the bottom of the area AND
  /// the strip together — directly over the log button — rather than
  /// floating above the strip.
  final Widget actionButton;

  /// The area's content.
  final Widget child;

  @override
  State<LoggingInfoFrame> createState() => _LoggingInfoFrameState();
}

class _LoggingInfoFrameState extends State<LoggingInfoFrame> {
  /// A monotonic generation, bumped whenever [LoggingInfoFrame.signature]
  /// changes, which keys the AnimatedSwitcher below. A content-derived key
  /// that can repeat (stats → call → stats) would collide with a still-fading
  /// outgoing child of the same key and crash the switcher's Stack; a
  /// never-repeating generation can't. An unchanged signature leaves the key
  /// alone, so the content updates in place.
  int _generation = 0;

  @override
  void didUpdateWidget(LoggingInfoFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.signature != oldWidget.signature) _generation++;
  }

  @override
  Widget build(BuildContext context) {
    final reserve = widget.buttonDiameter;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: reserve),
              child: SizedBox(
                width: double.infinity,
                // Reserves room for the button positioned on top of this box
                // (below), so text truncates before it rather than rendering
                // underneath.
                child: Padding(
                  padding: widget.leftieMode
                      ? EdgeInsets.only(left: reserve + Space.md)
                      : EdgeInsets.only(right: reserve + Space.md),
                  // Top-aligned, with the height animating as the content
                  // grows/shrinks and content swaps cross-fading. AnimatedSize
                  // drives the height; AnimatedSwitcher fades between distinct
                  // states, keyed by the generation.
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    alignment: Alignment.topLeft,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.topLeft,
                        children: [
                          ...previousChildren,
                          ?currentChild,
                        ],
                      ),
                      child: KeyedSubtree(key: ValueKey(_generation), child: widget.child),
                    ),
                  ),
                ),
              ),
            ),
            // Kept off the log button's column: the strip ends over the
            // rightmost field (its close button sits there). Same reserve the
            // entry row makes — the button's diameter plus gap.
            if (widget.strip case final strip?)
              Padding(
                padding: EdgeInsets.only(
                  right: widget.leftieMode ? 0 : reserve + logButtonGap,
                  left: widget.leftieMode ? reserve + logButtonGap : 0,
                ),
                child: strip,
              ),
          ],
        ),
        Positioned(
          left: widget.leftieMode ? 0 : null,
          right: widget.leftieMode ? null : 0,
          bottom: 0,
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
  const LoggingActionButton({
    super.key,
    required this.diameter,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
  });

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
