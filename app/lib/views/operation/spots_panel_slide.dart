// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'spots_panel.dart';

/// One of the two actions a spot row slides to reveal.
class _SlideAction {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  /// Fired once when this side first comes into view during a drag — before
  /// anything is committed. What separates "showing you what this would do"
  /// from doing it.
  final VoidCallback? onRevealed;

  /// The counterpart to [onRevealed]: the peek was given up without this
  /// action ever firing — dragged back, closed by another row, scrolled away.
  /// Whatever [onRevealed] put on screen belongs to the open row and may not
  /// outlive it.
  final VoidCallback? onWithdrawn;

  /// The row has come to rest open on this side and the finger is off it.
  /// Anything that has to face the operator waits for this: a dialog raised
  /// mid-drag takes the pointer while the drag runs on underneath it, and the
  /// release still commits.
  final VoidCallback? onSettled;

  const _SlideAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.onRevealed,
    this.onWithdrawn,
    this.onSettled,
  });
}

/// How much of a row an action panel occupies when the row rests open. Sized
/// for a tap target around a bare icon — the actions carry no label, so this
/// is a button's width rather than a word's, and the row's own height (which
/// shrinks with the density) never enters into it.
const _slideActionWidth = 72.0;

/// How far a drag must travel before the row will rest open on release —
/// and, on the way past it, the point at which the spot becomes the suggested
/// QSO. Both meanings are the same moment on purpose: it is where the gesture
/// stops being a twitch and starts being a choice of station.
const _slidePeekThreshold = _slideActionWidth / 2;

/// The share of the row's WIDTH a drag must pass for release to fire the
/// action outright rather than resting open. Two fifths is the point where
/// the gesture stops reading as "show me the button" and starts reading as
/// "do it" — and it is far enough from [_slidePeekThreshold] that settling
/// open is never a near-miss of firing.
const _slideCommitFraction = 0.4;

/// How much more horizontal than vertical a touch must be before it is taken
/// as a slide rather than a scroll — see
/// [_AxisLockedHorizontalDragGestureRecognizer].
const _slideAxisDominance = 1.0;

/// Wins the arena only for a drag that is going SIDEWAYS, not merely one that
/// has drifted the touch slop sideways on its way down the list.
///
/// A plain horizontal recognizer accumulates the horizontal component alone
/// and claims the pointer the moment it passes the slop, no matter how much
/// further the finger travelled vertically in the same span: a thumb scroll
/// arcs, so the arc opens a row. It bites hardest where the slop is widest —
/// iOS reports no device slop and so uses the 18px default, roughly twice
/// what Android's devices report, which leaves the arena unresolved over more
/// of the arc.
class _AxisLockedHorizontalDragGestureRecognizer extends HorizontalDragGestureRecognizer {
  _AxisLockedHorizontalDragGestureRecognizer({super.debugOwner});

  /// Where each tracked finger landed. Per pointer, because a drag can be
  /// tracking several: a palm or a second thumb landing across the row would
  /// otherwise become the origin the FIRST finger's travel is measured from,
  /// which reads as a long sideways move and lets through exactly the scroll
  /// this class exists to refuse.
  final Map<int, Offset> _origins = <int, Offset>{};

  /// How far the finger being judged has travelled since it landed, or null
  /// when there is nothing to judge by — a trackpad pan, which arrives with no
  /// down event and so no origin, leaves the base recognizer's own test to
  /// decide rather than being measured against a touch that has since lifted.
  Offset? _travel;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _origins[event.pointer] = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    // BEFORE super, which is what asks the question below — and about THIS
    // event's pointer, not whichever one moved last.
    final origin = event is PointerMoveEvent ? _origins[event.pointer] : null;
    _travel = origin == null ? null : event.position - origin;
    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) _origins.remove(event.pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _origins.clear();
    _travel = null;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    if (!super.hasSufficientGlobalDistanceToAccept(pointerDeviceKind, deviceTouchSlop)) return false;
    final travel = _travel;
    if (travel == null) return true;
    // Measured from where the finger landed rather than from the recognizer's
    // own signed accumulation, so a there-and-back wobble counts as the small
    // horizontal travel it is. Losing here is not final: the finger can turn
    // and win later, for as long as the list has not claimed the pointer.
    return travel.dx.abs() > travel.dy.abs() * _slideAxisDominance;
  }
}

/// Declares the row's slide to assistive technology, which a `RawGestureDetector`
/// otherwise cannot here: the default delegate finds the drag by looking the
/// EXACT [HorizontalDragGestureRecognizer] type up in the gesture map, and this
/// row registers a subclass under its own type — a map that cannot be keyed by
/// the base type either, since `RawGestureDetector` asserts the two match. With
/// no delegate the scroll-left/right actions disappear, and with them the only
/// route a screen-reader user has to the actions: the buttons exist on screen
/// only while the row is displaced.
///
/// One synthesised drag, start to end, exactly as the default delegate makes
/// one — a whole gesture rather than a fragment, because the row acts on
/// release and would otherwise be left sitting open.
class _SlideSemanticsDelegate extends SemanticsGestureDelegate {
  const _SlideSemanticsDelegate({required this.onStart, required this.onUpdate, required this.onEnd});

  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;

  @override
  void assignSemantics(RenderSemanticsGestureHandler renderObject) {
    renderObject.onHorizontalDragUpdate = (details) {
      onStart(DragStartDetails(globalPosition: details.globalPosition, localPosition: details.localPosition));
      onUpdate(details);
      onEnd(DragEndDetails(globalPosition: details.globalPosition, localPosition: details.localPosition));
    };
  }
}

/// Which rows are open, so only ever one is. A row registers itself as it
/// opens and the previous one closes; a tap on any row, and any edit to the
/// call being logged, clear the group outright. Scrolling deliberately does
/// not — see the list in `_SpotsPanelState.build`.
class _SlideGroup extends ChangeNotifier {
  /// Every row that is open, not just the latest one — because a row can
  /// REFUSE to close, which it does while a finger is still on it (see
  /// [_SlidableSpotRowState.close]). A group that tracked one row would have
  /// to forget a refuser to make room for the next, and a forgotten row is
  /// open with nothing able to close it: every later slide then leaves another
  /// beside it, until the list is a column of open rows. The refusal is not a
  /// rare path — crossing the peek suggests the QSO, which edits the call being
  /// logged, whose `closeSlidesSerial` lands here mid-drag.
  ///
  /// One row is still all the operator ever sees open: every row opening
  /// closes the others, and a refuser is closed at the next opportunity
  /// instead of being abandoned.
  final _open = <_SlidableSpotRowState>{};

  void opened(_SlidableSpotRowState row) {
    _closeAllExcept(row);
    _open.add(row);
  }

  void closed(_SlidableSpotRowState row) => _open.remove(row);

  void closeAll() => _closeAllExcept(null);

  void _closeAllExcept(_SlidableSpotRowState? keep) {
    for (final row in _open.toList()) {
      if (identical(row, keep)) continue;
      // A row that actually moves deregisters through [closed] on its way to
      // rest. The other two answers leave it here, and both are fine: a
      // refusal (a finger still on it) is closed the next time something asks,
      // and a row already at zero displacement — registered on drag start,
      // not yet moved — is deregistered by its own drag ending.
      row.close();
    }
  }
}

/// A spot row that slides horizontally to reveal one action on each side.
///
/// Wraps only the row's CONTENT: the divider and the row's outer box stay
/// still, so a sliding row moves within a list whose ruling does not. The
/// action layer is `Positioned.fill` inside a `Stack` sized by the content,
/// and the content moves by a `Transform` — neither changes the row's height,
/// which `spotRowHeightFor` declares and the reveal's scroll arithmetic sums
/// for rows it cannot see.
///
/// The content carries its own opaque background because the actions sit
/// BEHIND it; a transparent row would show the action it has not uncovered.
class _SlidableSpotRow extends StatefulWidget {
  /// Revealed by dragging right (sits against the leading edge), and by
  /// dragging left respectively. A null side does not drag.
  final _SlideAction? leading;
  final _SlideAction? trailing;

  /// Painted behind the row's content WHILE IT IS DISPLACED, so the action
  /// layer only shows where the content has actually moved off it. A row at
  /// rest paints no fill of its own, exactly as it did before it could slide.
  final Color background;

  final _SlideGroup group;
  final Widget child;

  const _SlidableSpotRow({super.key, required this.group, required this.background, required this.child, this.leading, this.trailing});

  @override
  State<_SlidableSpotRow> createState() => _SlidableSpotRowState();
}

class _SlidableSpotRowState extends State<_SlidableSpotRow> {
  /// How far the content is currently displaced. Positive reveals [leading].
  double _dx = 0;

  /// Whether the drag is currently past the commit threshold. Kept so the
  /// haptic fires on the CROSSING rather than per drag frame, in both
  /// directions: reversing back under the threshold is a promise that release
  /// will no longer fire, and it deserves the same tick that promised it would.
  bool _pastCommit = false;

  /// Which side has passed the peek threshold, so [_SlideAction.onRevealed]
  /// and its tick fire once per open rather than on every drag frame.
  int _revealedSign = 0;

  /// Whether a finger is down. The displacement follows the finger exactly
  /// while it is, and eases to its resting place once it lifts — one value,
  /// two durations, rather than a controller this row would have to own and
  /// tear down as the list recycles it.
  bool _dragging = false;

  /// The pointers currently down on this row, and whether the one that ended
  /// the gesture was taken away rather than lifted. Both are written from the
  /// `Listener` below, which sees each event BEFORE the gesture recognizer
  /// does: render objects on the hit-test path are dispatched to ahead of
  /// `GestureBinding`, which is what routes the event on to the recognizer
  /// that then reports the end.
  ///
  /// Counted rather than a bare flag because a cancel is only this gesture's
  /// end when it is the LAST pointer to go: a palm or second thumb the system
  /// takes away mid-drag must not disarm the release the operator still
  /// makes, which would swallow the contact with no trace anywhere.
  final Set<int> _downPointers = <int>{};
  bool _cancelled = false;

  @override
  void dispose() {
    widget.group.closed(this);
    // A row can be DISCARDED while open, without ever closing: its key carries
    // the spot's own timestamp, so an ordinary poll that re-spots the station
    // rebuilds it as a different row and this State goes away mid-peek. What
    // the peek filled would otherwise sit in the logging fields with no open
    // row left to take it back — the very leftover this whole gesture is
    // careful about everywhere else.
    //
    // After the frame: dispose runs inside `finalizeTree`, where reaching up
    // to set state on the operation view is illegal.
    final action = _revealedSign > 0 ? widget.leading : (_revealedSign < 0 ? widget.trailing : null);
    final withdrawn = action?.onWithdrawn;
    if (withdrawn != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => withdrawn());
    }
    super.dispose();
  }

  /// Slides shut without firing anything — what the group calls on the row
  /// that was open when another one opens. Returns whether it actually did:
  /// a row refuses while a finger is on it, and the group has to keep
  /// tracking one that refused.
  bool close() {
    if (!mounted) return true;
    if (_dx == 0) return true;
    // Never while the finger is down. Crossing the peek suggests the QSO,
    // which edits the call being logged, whose `closeSlidesSerial` closes open
    // rows — including this one. Zeroing the displacement there
    // would restart the drag from nothing under a finger that never lifted:
    // the row jumps back, can no longer reach the commit point, and re-crossing
    // the peek suggests a second time. It also deregisters the row, so it can
    // come to rest open with the group believing nothing is.
    if (_dragging) return false;
    _animateTo(0);
    return true;
  }

  void _animateTo(double target) {
    setState(() {
      _dragging = false;
      _dx = target;
    });
    if (target == 0) {
      widget.group.closed(this);
      _pastCommit = false;
      _withdraw();
    }
  }

  /// Gives up the peek without firing its action. Everything [_SlideAction
  /// .onRevealed] put on screen is undone here, so a spot's hold on the
  /// logging fields lasts exactly as long as its row stays open.
  void _withdraw() {
    final sign = _revealedSign;
    _revealedSign = 0;
    if (sign == 0) return;
    (sign > 0 ? widget.leading : widget.trailing)?.onWithdrawn?.call();
  }

  /// Runs an action and closes the row. The peek is SPENT rather than
  /// withdrawn: what it revealed is what the action is about to act on, and
  /// withdrawing it here would take the suggested QSO out of the logging
  /// fields the log is made from.
  void _fire(_SlideAction action) {
    _revealedSign = 0;
    _animateTo(0);
    action.onPressed();
  }

  void _onDragStart(DragStartDetails details) {
    _cancelled = false;

    setState(() => _dragging = true);
    widget.group.opened(this);
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    final max = widget.leading == null ? 0.0 : width;
    final min = widget.trailing == null ? 0.0 : -width;
    final next = (_dx + (details.primaryDelta ?? 0)).clamp(min, max);
    // Two thresholds, two different weights of feedback, so the hand can tell
    // them apart without looking: a medium tap where the station is picked up,
    // a heavier one where releasing would act on it. Both are impacts rather
    // than selection ticks — the gesture is made without looking, often on a
    // phone in a pocket-sized grip, so the feedback has to carry.
    final sign = next.abs() < _slidePeekThreshold ? 0 : (next > 0 ? 1 : -1);
    if (sign != _revealedSign) {
      // Withdraw first, then reveal: dragging back through the middle and out
      // the other side is one gesture, and the incoming side's suggestion must
      // land AFTER the outgoing side has taken its own back.
      _withdraw();
      if (sign != 0) {
        _revealedSign = sign;
        HapticFeedback.mediumImpact();
        (sign > 0 ? widget.leading : widget.trailing)?.onRevealed?.call();
      }
    }
    final past = next.abs() >= width * _slideCommitFraction;
    if (past != _pastCommit) {
      // On the way out this says "release now and it happens"; on the way back
      // it says it no longer will. Both deserve saying, and both are the
      // heavier of the two so neither is mistaken for the peek.
      HapticFeedback.heavyImpact();
      _pastCommit = past;
    }
    setState(() => _dx = next);
  }

  void _onDragEnd(DragEndDetails details, double width) {
    // Act only on evidence that the operator actually let go. An ACCEPTED drag
    // reports a cancelled pointer as an ordinary end — and `onHorizontalDrag
    // Cancel` only ever fires BEFORE acceptance, where no row has been touched
    // — so without this a system gesture claiming the touch, or the app going
    // to the background, LOGS A CONTACT nobody released. A pointer still down
    // at the end means the same thing by another route: the recognizer also
    // ends a drag whose buttons change mid-gesture, with no cancel to see.
    //
    // Shutting the row rather than resting it open takes the peek back with
    // it — [_animateTo] withdraws at zero — which is what keeps a station the
    // operator never chose out of the logging fields.
    if (_cancelled || _downPointers.isNotEmpty) {
      _animateTo(0);
      return;
    }
    final action = _dx > 0 ? widget.leading : widget.trailing;
    if (_pastCommit && action != null) {
      // Fire on release, then slide shut — the row has done its job and
      // leaving the button sitting there invites a second press.
      _fire(action);
      return;
    }
    // Far enough to mean it: rest open with the button exposed to tap.
    // Anything shorter was a stray horizontal wobble during a scroll.
    if (_dx.abs() >= _slidePeekThreshold) {
      _animateTo(_dx > 0 ? _slideActionWidth : -_slideActionWidth);
      action?.onSettled?.call();
    } else {
      _animateTo(0);
    }
  }

  Widget _actionPanel(_SlideAction action, {required bool leading, required double width, required double revealed}) {
    // Grows with the drag, so past the commit threshold the action fills the
    // row and reads as the thing about to happen rather than as a button
    // waiting to be pressed.
    revealed = revealed.clamp(0.0, width);
    final past = revealed >= width * _slideCommitFraction;
    // Past the commit point the icon crosses its well to sit against the row
    // it will act on — the same edge the row is being dragged by. Before it,
    // the icon centres in whatever width is revealed, so it arrives with the
    // well and sits centred in it once the row rests open, like the button it
    // still is. The move is the visible half of what the heavy tick says:
    // this is armed now.
    final alignment = past ? (leading ? Alignment.centerRight : Alignment.centerLeft) : Alignment.center;
    return Align(
      alignment: leading ? Alignment.centerLeft : Alignment.centerRight,
      child: SizedBox(
        width: revealed,
        child: Material(
          color: action.background,
          child: InkWell(
            onTap: () => _fire(action),
            // The label is a screen-reader one only: these are bare icons, and
            // this repo has no tooltips (a `tooltip:` anywhere in lib fails a
            // source-scanning test), so Semantics is where the word lives.
            child: Semantics(
              label: action.label,
              button: true,
              child: ClipRect(
                child: AnimatedAlign(
                  alignment: alignment,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Icon(action.icon, color: action.foreground, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A hairline divider between rows, painted over the row's bottom edge
    // (foreground) so it adds no height — lighter than the section header's
    // 3px rule so rows read as subdivisions within a group. OUTSIDE the
    // slide, so the ruling between rows stays put while a row moves under it.
    Widget ruled(Widget child) => DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: child,
    );

    if (widget.leading == null && widget.trailing == null) return ruled(widget.child);
    return ruled(
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Listener(
            // The only place a cancelled touch can be told apart from a lifted
            // one — see [_downPointers]. Behaviour left at the default,
            // `deferToChild`, so this listens over exactly the region the
            // gesture below it drags on, and widens nothing.
            onPointerDown: (event) => _downPointers.add(event.pointer),
            onPointerUp: (event) => _downPointers.remove(event.pointer),
            onPointerCancel: (event) {
              _downPointers.remove(event.pointer);
              if (_downPointers.isEmpty) _cancelled = true;
            },
            child: RawGestureDetector(
              // Horizontal only — the enclosing scroll view keeps the vertical
              // axis, and the narrow layout's TabBarView has page-swiping
              // disabled, so nothing else is competing for this drag. Raw rather
              // than a `GestureDetector` for the sake of the recognizer, which is
              // the one thing keeping a scroll from opening a row.
              gestures: <Type, GestureRecognizerFactory>{
                _AxisLockedHorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<_AxisLockedHorizontalDragGestureRecognizer>(
                  () => _AxisLockedHorizontalDragGestureRecognizer(debugOwner: this),
                  (instance) {
                    instance
                      ..onStart = _onDragStart
                      ..onUpdate = ((d) => _onDragUpdate(d, width))
                      ..onEnd = ((d) => _onDragEnd(d, width))
                      // The device's own slop, as a `GestureDetector` would have
                      // set it — the enclosing list reads the same one.
                      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
                  },
                ),
              },
              semantics: _SlideSemanticsDelegate(onStart: _onDragStart, onUpdate: (d) => _onDragUpdate(d, width), onEnd: (d) => _onDragEnd(d, width)),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: _dx),
                // Zero while the finger is down, so the row tracks it exactly
                // rather than lagging behind its own gesture.
                duration: _dragging ? Duration.zero : const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                // The panel behind is sized from the SAME animating value as the
                // row in front, so the two stay edge to edge through a snap
                // instead of the panel jumping to its target while the row eases.
                builder: (context, dx, child) {
                  final stack = Stack(
                    children: [
                      // Only while there is something to see: an idle row pays for
                      // no extra layer, which matters on a board scrolled fast.
                      if (dx != 0)
                        Positioned.fill(
                          child: dx > 0
                              ? _actionPanel(widget.leading!, leading: true, width: width, revealed: dx)
                              : _actionPanel(widget.trailing!, leading: false, width: width, revealed: -dx),
                        ),
                      Transform.translate(
                        offset: Offset(dx, 0),
                        // Opaque ONLY while displaced: the actions sit behind the
                        // row, so a transparent row would show the one it has not
                        // uncovered — but a row at rest must paint exactly what it
                        // painted before it could slide, down to having no fill.
                        child: dx == 0 ? child! : ColoredBox(color: widget.background, child: child!),
                      ),
                    ],
                  );
                  // The displaced content is clipped to the row's box — the width
                  // of the list itself — so a row dragged to the edge stops at it
                  // instead of painting over whatever sits beside the spot list.
                  // `Clip.none` rather than dropping the widget while the row
                  // rests: it allocates no layer either, and keeping the widget
                  // type stable across that boundary keeps the row's subtree —
                  // global keys, ink splashes and all — from being re-inflated at
                  // the frame a slide starts and again at the one it ends.
                  return ClipRect(clipBehavior: dx == 0 ? Clip.none : Clip.hardEdge, child: stack);
                },
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}
