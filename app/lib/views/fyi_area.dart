// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The FYI area (docs/design/logging-fields.md § The FYI area): the line at
// the bottom of a set's info area, under the stats or the call info and
// above its entry row, where the app's components — and, through them, the
// radio — leave a glance's worth of news for the operator: the keyer's
// message going out, an SWR the antenna should not be giving, a storm
// nearby. One area per set, each showing its radio's messages and the
// station's (FyiService), hosted through ControlStripSettings.infoAreaFooter
// so it is exactly as wide as the main logging fields and sits outside the
// info area's cross-fade.
//
// Driven by AnimationControllers rather than a clock: the slide, the
// messages' resizing and the hold of one tapped open are frame-paced UI,
// and nothing time travel should move.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:halo_widgets/halo_widgets.dart';

import '../services/fyi_service.dart';
import '../services/halo_services.dart';
import 'keyer_area.dart';

/// The slide in and out.
const _revealDuration = Duration(milliseconds: 250);

/// A message growing into its room as it arrives, and shrinking out of it
/// as it goes, the rest of the line following.
const _resizeDuration = Duration(milliseconds: 200);

/// How long a message tapped open holds the line before it folds back.
const _expandedFor = Duration(seconds: 5);

const _iconSize = 16.0;

/// The least an item lays out at, whatever the line has left for it: a
/// pill's insets, its icon, the gap after the icon and the gap after the
/// item. Squeezed past that it runs off the line's end, clipped, rather
/// than overflowing its own box.
const _itemMinWidth = Space.sm + _iconSize + Space.sm + Space.sm + Space.sm;

/// The gap between the content above and the line, and the inset above and
/// below every message's text, which is the pill's around its own. The gap,
/// the inset and the text are together what the frame has to spare under a
/// line of stats: a pixel more and the stats move when the area appears.
const _gapAbove = 3.0;
const _textInset = 1.0;

/// The line's one height, whatever it shows: the text and its inset above
/// and below. Every message's text starts at the same inset, so their
/// baselines meet the pill's, and a message replacing another never moves
/// the fields or the content above. The keyer's bar runs [lineBarBelowText]
/// under its text, so it hangs [_hangBelow] out of the box, into the gap
/// before the fields — the clips let it.
double _lineHeight(double textHeight) => _textInset + textHeight + _textInset;

const _hangBelow = lineBarBelowText - _textInset;

/// The keyer line's slot among the messages' keys — one no poster can use.
const _keyerKey = '\u0000keyer';

/// A warning's icon: an amber apart from the theme's tertiary, which is the
/// operational colour on the same line, and legible on either surface.
const _warningLight = Color(0xFF9A7B00);
const _warningDark = Color(0xFFFFC107);

/// One set's FYI area. See the file comment and [FyiService].
///
/// [keyer] hosts the radio's keyer line as its operational item (the Keying
/// experiment); [phone], [digital] and [suppressed] are the keyer line's —
/// see [KeyerLineModel].
class FyiArea extends StatefulWidget {
  final HaLoServices services;

  /// The SO2R radio whose set this is — `A` alone outside SO2R.
  final String radio;

  final bool keyer;

  /// Whether the keyer line is the voice keyer's: the draft contact's mode
  /// is Phone. Decided by the operation view, which routes F1-F8 by the
  /// same answer — decided ONCE, so the keys and the line never disagree
  /// about which keyer this is. The draft's mode, not the radio's: the
  /// messages are for the contact being logged, and a rig sitting in USB
  /// while the operator logs CW keys CW.
  final bool phone;

  /// Whether the draft contact's mode is Digital, where nothing keys — read
  /// only to end keyboard mode when the draft turns Digital.
  final bool digital;

  /// True while the logging panel is editing a logged QSO: the keyer line
  /// goes and stays away until editing ends. The other messages stay — a
  /// warning about the antenna is as true while a contact is corrected.
  final bool suppressed;

  const FyiArea({super.key, required this.services, this.radio = 'A', this.keyer = false, this.phone = false, this.digital = false, this.suppressed = false});

  @override
  State<FyiArea> createState() => _FyiAreaState();
}

class _FyiAreaState extends State<FyiArea> with TickerProviderStateMixin {
  // Created in initState, never lazily: a `late` controller first touched
  // by dispose() would look TickerMode up on a context that is already gone.
  late final AnimationController _reveal;

  /// Runs while a message tapped open holds the line, and folds it back
  /// when it runs out.
  late final AnimationController _expandedHold;

  /// The message tapped open — cut short for want of room, now in full with
  /// the rest of the line out of its way — until the second tap or the hold
  /// runs out.
  String? _expanded;

  /// [_expanded] as the line was last built — what the slots are drawn to,
  /// which [_expanded] runs ahead of between a tap or the hold's end and the
  /// next frame.
  String? _builtExpanded;

  /// The keyer line's presence, while [FyiArea.keyer] hosts it.
  KeyerLineModel? _keyer;

  /// Whether the area is (or is sliding) in — from the first message until
  /// the last is gone and it has slid away.
  bool _visible = false;

  /// The messages the last change left on the line, by key, and whether the
  /// keyer line was among them — what the next change is measured against
  /// to tell what left.
  Map<String, FyiMessage> _shown = const {};
  bool _shownKeyer = false;

  /// Messages gone from the service and still on the line, shrinking out of
  /// their room; and whether the keyer line is.
  final _leaving = <String, FyiMessage>{};
  bool _keyerLeaving = false;

  /// The slots in the order last laid out, the leaving ones included: a
  /// slot shrinks where it was, among the ones that were around it.
  List<String> _order = const [];

  FyiService get _fyi => widget.services.fyi;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, duration: _revealDuration);
    _expandedHold = AnimationController(vsync: this, duration: _expandedFor)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _collapse();
      });
    _fyi.addListener(_onChanged);
    _syncKeyer();
    _onChanged();
  }

  /// Keeps [_keyer] to [FyiArea.keyer] and the radio: a model per radio,
  /// disposed when keying goes off or the set changes radios.
  void _syncKeyer() {
    final keyer = _keyer;
    if (!widget.keyer) {
      if (keyer != null) {
        keyer.removeListener(_onChanged);
        keyer.dispose();
        _keyer = null;
      }
      return;
    }
    if (keyer == null || keyer.radio != widget.radio || keyer.cat != widget.services.cat) {
      keyer?.removeListener(_onChanged);
      keyer?.dispose();
      _keyer = KeyerLineModel(cat: widget.services.cat, radio: widget.radio, vsync: this)..addListener(_onChanged);
    }
    _keyer!.suppressed = widget.suppressed;
  }

  @override
  void didUpdateWidget(FyiArea old) {
    super.didUpdateWidget(old);
    if (old.services.fyi != _fyi) {
      old.services.fyi.removeListener(_onChanged);
      _fyi.addListener(_onChanged);
    }
    _syncKeyer();
    // Keyboard mode is the CW keyer's; the draft going to Phone or Digital
    // ends it the way Enter would.
    if ((widget.phone && !old.phone) || (widget.digital && !old.digital)) _keyer?.finishTyping();
    _onChanged();
  }

  @override
  void dispose() {
    _fyi.removeListener(_onChanged);
    _keyer?.removeListener(_onChanged);
    _keyer?.dispose();
    _expandedHold.dispose();
    _reveal.dispose();
    super.dispose();
  }

  List<FyiMessage> get _messages => _fyi.messagesFor(widget.radio);

  bool get _keyerActive => _keyer?.active ?? false;

  /// Slides the area in with its first message and away after its last;
  /// in between, every change redraws the line, what left shrinking away.
  void _onChanged() {
    if (!mounted) return;
    // The message open as the line was last built: everything else on it
    // has shrunk away behind that one, and what leaves from there has no
    // shrink left to end on — kept as leaving, it would never be let go, a
    // slot of nothing holding its place — so it goes at once. Read as built,
    // not as [_expanded] stands: a tap's action clearing another message
    // lands after the second tap has already cleared that.
    final open = _builtExpanded;
    if (_expanded case final expanded? when _fyi.messageFor(expanded) == null) {
      _expanded = null;
      _expandedHold.stop();
    }
    final current = {for (final m in _messages) m.key: m};
    for (final MapEntry(:key, :value) in _shown.entries) {
      if (!current.containsKey(key) && (open == null || open == key)) _leaving[key] = value;
    }
    _leaving.removeWhere((key, _) => current.containsKey(key));
    _shown = current;
    final keyerActive = _keyerActive;
    // The keyer's slot shrinks away like a message's while its model is
    // there to draw it; keying switched off takes the model, and the slot
    // with it at once.
    if (_shownKeyer && !keyerActive && _keyer != null && open == null) _keyerLeaving = true;
    if (keyerActive || _keyer == null) _keyerLeaving = false;
    _shownKeyer = keyerActive;
    if (current.isNotEmpty || keyerActive) {
      _visible = true;
      _reveal.forward();
    } else if (_visible) {
      _reveal.reverse().whenComplete(() {
        if (mounted && _reveal.isDismissed) {
          setState(() {
            _visible = false;
            _leaving.clear();
            _keyerLeaving = false;
            _order = const [];
          });
        }
      });
    }
    setState(() {});
  }

  /// A tap on a message cut short opens it: it takes the line, the rest
  /// making way, for [_expandedFor] or until the next tap. A tap on one
  /// shown in full — opened, or never cut — does what it asks and puts it
  /// away; one that opted out of dismissal is only folded back.
  void _tap(String key, BuildContext item) {
    // As last posted: a re-post that reads the same is not news to the
    // line, so the message this slot was built with may be an action behind.
    final message = _fyi.messageFor(key);
    if (message == null) return;
    if (_expanded != key && _textCut(item)) {
      setState(() => _expanded = message.key);
      _expandedHold.forward(from: 0);
      return;
    }
    _expandedHold.stop();
    _expanded = null;
    message.onTap?.call();
    if (message.dismissible) {
      _fyi.dismiss(message.key);
    } else {
      setState(() {});
    }
  }

  /// Whether the message's text, as laid out under [item], ran out of room
  /// — the one paragraph under it with lines to exceed; the icon's glyph
  /// has none.
  static bool _textCut(BuildContext item) {
    var cut = false;
    void visit(RenderObject object) {
      if (object is RenderParagraph) cut = cut || object.didExceedMaxLines;
      object.visitChildren(visit);
    }

    item.findRenderObject()?.visitChildren(visit);
    return cut;
  }

  void _collapse() {
    if (!mounted || _expanded == null) return;
    setState(() => _expanded = null);
  }

  /// A slot that has shrunk away.
  void _left(String key) {
    if (!mounted) return;
    setState(() {
      if (key == _keyerKey) {
        _keyerLeaving = false;
      } else {
        _leaving.remove(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    // Grows up from the fields' edge — the frame seats the area at the
    // bottom of the room it reserves — and the content rides up with it:
    // the box keeps its bottom and the content is pinned there, then slid
    // down by what the box lacks, so its top edge is the box's. The line
    // reads as rising out from under the entry row, and sinking back into
    // it, rather than fading in place. The fields never move. The clip is
    // the box while it slides, so nothing spills under the rising edge, and
    // the box with the bar's hang once it is up.
    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, child) => ClipRect(
        clipper: _LineClip(below: _reveal.isCompleted ? _hangBelow : 0),
        child: Align(alignment: AlignmentDirectional.bottomStart, heightFactor: _reveal.value, child: child),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(_reveal),
        child: Padding(
          // Inside the slide, so a hidden area costs nothing.
          padding: const EdgeInsets.only(top: _gapAbove),
          child: _line(context),
        ),
      ),
    );
  }

  /// The line (logging-fields.md § The FYI area): every message with its
  /// text, left to right — the high alerts, then what is under way with the
  /// keyer line after the high operational messages and before the rest,
  /// then the other alerts, the warnings and the info —
  /// and by priority within a group, each taking the room it needs from
  /// what the ones before it left.
  Widget _line(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium ?? const TextStyle();
    // As the messages draw it, emoji fallback included — the line's height
    // is the text's, not a guess at it.
    final textHeight = spansHeight(context, [const TextSpan(text: 'Xg')], style.copyWith(fontFamilyFallback: const [emojiFontFamily]));
    final messages = _messages;
    final keyer = _keyer;
    final keyerActive = _keyerActive;
    // While something is still on the line, what leaves shrinks out of its
    // room; after the last, the whole line sinks away with its content as
    // it was.
    final shrinking = messages.isNotEmpty || keyerActive;
    bool high(FyiMessage m, FyiCategory category) => m.category == category && m.priority == FyiPriority.high;
    final current = [
      for (final m in messages)
        if (high(m, FyiCategory.alert)) m.key,
      // A high operational message — the operating style — is how the
      // operator is working, which the keying it explains follows.
      for (final m in messages)
        if (high(m, FyiCategory.operational)) m.key,
      // What is under way outranks every warning and reading: a message
      // keying is read while it keys.
      if (keyer != null && keyerActive) _keyerKey,
      for (final m in messages)
        if (m.category == FyiCategory.operational && !high(m, FyiCategory.operational)) m.key,
      for (final m in messages)
        if (m.category == FyiCategory.alert && !high(m, FyiCategory.alert)) m.key,
      for (final category in [FyiCategory.warning, FyiCategory.info])
        for (final m in messages)
          if (m.category == category) m.key,
    ];
    // What was posted and gone between two frames was never on the line.
    _leaving.removeWhere((key, _) => !_order.contains(key));
    if (!_order.contains(_keyerKey)) _keyerLeaving = false;
    final leavingKeyer = _keyerLeaving && keyer != null;
    final order = _order = _placeLeaving(current, {..._leaving.keys, if (leavingKeyer) _keyerKey});
    // A message tapped open has the line to itself: the rest make way.
    final expanded = _builtExpanded = _expanded;
    final items = <String, Widget>{
      for (final m in messages) m.key: _item(context, m, leaving: false, hidden: expanded != null && expanded != m.key),
      for (final MapEntry(:key, :value) in _leaving.entries) key: _item(context, value, leaving: shrinking, hidden: expanded != null),
      if (keyer != null && (keyerActive || leavingKeyer)) _keyerKey: _keyerItem(theme, keyer, leaving: leavingKeyer && shrinking, hidden: expanded != null),
    };
    // Every slot hangs from the top of the one fixed height, its text at
    // the pill's inset — see [_lineHeight]. The clip is for what runs off
    // the end — see [_InOrder] — and lets the keyer's bar hang below.
    return ClipRect(
      clipper: const _LineClip(below: _hangBelow),
      child: SizedBox(
        height: _lineHeight(textHeight),
        child: CustomMultiChildLayout(
          delegate: _InOrder(order),
          children: [for (final key in order) LayoutId(key: ValueKey(key), id: key, child: items[key]!)],
        ),
      ),
    );
  }

  /// Where the leaving slots go among the current ones: each right after
  /// the slot that was before it when it was last laid out, so it shrinks
  /// in its place rather than jumping to one end.
  List<String> _placeLeaving(List<String> current, Set<String> leaving) {
    final placed = [...current];
    for (var i = 0; i < _order.length; i++) {
      final key = _order[i];
      if (!leaving.contains(key)) continue;
      var at = 0;
      for (var j = i - 1; j >= 0; j--) {
        final before = placed.indexOf(_order[j]);
        if (before >= 0) {
          at = before + 1;
          break;
        }
      }
      placed.insert(at, key);
    }
    return placed;
  }

  /// An item's room on the line: grown from nothing as it arrives, shrunk
  /// back to nothing as it leaves or makes way for a message tapped open,
  /// its trailing gap inside so that goes too. While the whole line is
  /// sliding in, an item arrives at its full width — the slide is animation
  /// enough. [onHidden] runs once it has shrunk away.
  Widget _slot(Widget child, {required bool shown, VoidCallback? onHidden}) => TweenAnimationBuilder<double>(
    tween: Tween(begin: _reveal.isCompleted ? 0 : 1, end: shown ? 1 : 0),
    duration: _resizeDuration,
    curve: Curves.easeOut,
    onEnd: shown ? null : onHidden,
    child: Padding(
      padding: const EdgeInsetsDirectional.only(end: Space.sm),
      child: child,
    ),
    builder: (context, factor, child) => ClipRect(
      child: Align(alignment: AlignmentDirectional.topStart, widthFactor: factor, child: child),
    ),
  );

  /// One message: its icon and its text, hung from the line's top with the
  /// text at the pill's inset ([_lineHeight]); [leaving] the service,
  /// [hidden] by another message tapped open.
  Widget _item(BuildContext context, FyiMessage m, {required bool leaving, required bool hidden}) {
    final theme = Theme.of(context);
    final colors = HaLoColors.of(context);
    final style = theme.textTheme.bodyMedium ?? const TextStyle();
    // A high alert is drawn as a filled pill — the alert red behind it, its
    // icon and text in the colour that reads on that — and so is a message
    // asking for a pill of its own colour.
    final fill = m.backgroundColor ?? (m.category == FyiCategory.alert && m.priority == FyiPriority.high ? colors.alert : null);
    final pill = fill != null;
    final onPill = pill ? colors.onAlert : null;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.sm,
      children: [
        Icon(m.icon, size: _iconSize, color: m.iconColor ?? onPill ?? _categoryColor(theme, colors, m.category)),
        Flexible(
          // The emoji font behind the text, so a flag or a pictograph in a
          // message draws on every platform.
          child: InlineMarkdownText(
            m.text,
            style: style.copyWith(color: m.textColor ?? onPill, fontFamilyFallback: const [emojiFontFamily]),
            maxLines: 1,
          ),
        ),
      ],
    );
    final shown = !leaving && !hidden;
    // The tap reads the text as laid out under this context.
    return _slot(
      Builder(
        builder: (item) {
          // A message on its way out, or out of the way, is past tapping.
          final tap = shown ? () => _tap(m.key, item) : null;
          return Semantics(
            label: m.text,
            button: true,
            // The one button assistive tech sees — the detector's own
            // semantics are excluded — so it carries the tap as well.
            onTap: tap,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: tap,
                child: pill
                    // The pill fills the line's height: the text's inset
                    // above and below it.
                    ? Container(
                        padding: const EdgeInsets.only(left: Space.sm, right: Space.sm, top: _textInset, bottom: _textInset),
                        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(3)),
                        child: content,
                      )
                    : Padding(
                        padding: const EdgeInsets.only(top: _textInset),
                        child: content,
                      ),
              ),
            ),
          );
        },
      ),
      shown: shown,
      onHidden: leaving ? () => _left(m.key) : null,
    );
  }

  /// The keyer line as its radio's operational item: its icon — the key for
  /// CW, the microphone for voice — level with the message's text, above
  /// its bar.
  Widget _keyerItem(ThemeData theme, KeyerLineModel keyer, {required bool leaving, required bool hidden}) => _slot(
    Padding(
      padding: const EdgeInsets.only(top: _textInset),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: Space.sm,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: lineBarBelowText),
            child: Icon(widget.phone ? MdiIcons.microphone : MdiIcons.key, size: _iconSize, color: theme.colorScheme.tertiary),
          ),
          Flexible(
            child: KeyerLineItem(model: keyer, services: widget.services),
          ),
        ],
      ),
    ),
    shown: !leaving && !hidden,
    onHidden: leaving ? () => _left(_keyerKey) : null,
  );

  /// The colour a category's icon takes when the message names none.
  static Color _categoryColor(ThemeData theme, HaLoColors colors, FyiCategory category) => switch (category) {
    FyiCategory.alert => colors.alert,
    FyiCategory.warning => theme.brightness == Brightness.dark ? _warningDark : _warningLight,
    FyiCategory.operational => theme.colorScheme.tertiary,
    FyiCategory.info => theme.colorScheme.onSurface.withValues(alpha: 0.6),
  };
}

/// Lays the line's slots out in order, each at its own width from what the
/// ones before it left — the first takes what it needs, the last what
/// remains — and never under [_itemMinWidth], past which a slot runs off
/// the end for the line's clip to cut. Each slot carries its trailing gap,
/// so the last one's room reaches one gap past the line.
class _InOrder extends MultiChildLayoutDelegate {
  _InOrder(this.ids);

  final List<String> ids;

  @override
  void performLayout(Size size) {
    var x = 0.0;
    for (final id in ids) {
      final room = math.max(size.width + Space.sm - x, _itemMinWidth);
      // Width alone: a slot takes its own height, the keyer's bar hanging
      // below the box.
      final width = layoutChild(id, BoxConstraints(maxWidth: room)).width;
      positionChild(id, Offset(x, 0));
      x += width;
    }
  }

  @override
  bool shouldRelayout(_InOrder old) => !listEquals(old.ids, ids);
}

/// The line's clip: its box and [below] it, for the keyer's bar's hang — so
/// what runs off the end is cut and the bar is not.
class _LineClip extends CustomClipper<Rect> {
  const _LineClip({required this.below});

  final double below;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, size.height + below);

  @override
  bool shouldReclip(_LineClip old) => old.below != below;
}
