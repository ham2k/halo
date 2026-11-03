// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's fixed dimensions, and the vocabulary its main field row
// is laid out in.
//
// Their own file because they are read from every corner of the panel and
// changed almost never — and because the row's sizing rules only make sense
// read together, which they cannot be while they sit a thousand lines apart
// from each other inside the widget that uses them.
//
// Plain logical pixels throughout: the Font Scale setting scales the whole
// interface from one root wrapper (ui-scaling.md), so nothing here is
// multiplied by it.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'theme.dart';

/// Horizontal padding around the panel's fields — also handed to
/// `SecondaryControlRow` so its expanded control panel can bleed past it
/// and reach the view's true edges.
const secondaryPanelHorizontalInset = 12.0;

/// How wide a main logging field is, in characters of its own monospace
/// value: never narrower than [min] unless the row runs out of room, [ideal]
/// whenever the row has the room, and no wider than [max] — null for no limit,
/// which only the callsign has. [resolveMainFieldLayout] turns them into
/// pixels; every field states them in characters so that they follow OS text
/// scaling together.
typedef FieldChars = ({int min, int ideal, int? max});

/// A field's [FieldChars] from what it declares, any part of it missing: [min]
/// [defaultFieldMinChars], [ideal] its min, [max] its ideal — and put in order,
/// so a max under the ideal is not a field that shrinks as the row grows.
FieldChars fieldChars({int? min, int? ideal, int? max}) {
  final lo = min ?? defaultFieldMinChars;
  final mid = ideal == null || ideal < lo ? lo : ideal;
  return (min: lo, ideal: mid, max: max == null || max < mid ? mid : max);
}

/// A main field's floor when it declares none. Three characters reads a
/// filled field from an empty one and takes an RST whole — and focusing a
/// field brings it straight back to its ideal, so this is only ever what a
/// field the operator isn't in looks like.
const defaultFieldMinChars = 3;

/// How far under its min a field goes when the row has nothing else left to
/// give: two characters still tell a filled field from an empty one and take
/// a tap.
const fieldFloorChars = 2;

/// The callsign: a full call with a portable suffix (`W1AW/4`) at the least,
/// room for `VP2V/W1AW/P` when there is some, and no limit — past every
/// other field's max, the rest of the row is the callsign's.
const FieldChars callFieldChars = (min: 6, ideal: 10, max: null);

/// The built-in fields after the callsign.
const FieldChars rstFieldChars = (min: 3, ideal: 4, max: 6);
const FieldChars stateFieldChars = (min: 3, ideal: 3, max: 3);
const FieldChars gridFieldChars = (min: 4, ideal: 6, max: 6);

/// The most characters an extension's field may ask for, in any of its
/// counts. Without a ceiling a width written in pixels — `min: 60` — would
/// take a phone's whole row, push the log button off it and look fine on the
/// desktop it was tried on.
const maxFieldChars = 20;

/// An extension's `text`, `options` or `serial` control, from its
/// `input.chars: { min, ideal, max }` (docs/extensions/activities.md). One that
/// declares none asks for six characters, enough for a zone, a serial or a
/// section name — or its `maxLength`, if that is fewer — and may grow to its
/// `maxLength`. Every count stops at [maxFieldChars].
///
/// A declaration the row cannot take as written — not a map, a part that is
/// no count, one past the ceiling, an ideal under the min — still sizes the
/// field from what it can use, and is named on the console once, for [key]:
/// the field comes out a character or two off what was asked, too little for
/// its author to notice on their own.
FieldChars exchangeFieldChars(Map<dynamic, dynamic>? input, {String? key}) {
  final maxLength = _chars(input?['maxLength']);
  final longest = maxLength == null ? 6 : math.min(maxLength, maxFieldChars);
  final fallback = fieldChars(min: math.min(defaultFieldMinChars, longest), ideal: math.min(6, longest), max: longest);
  final declared = input?['chars'];
  if (declared == null) return fallback;
  if (declared is! Map) {
    _reportChars(key, declared, fallback);
    return fallback;
  }

  var adjusted = false;
  int? count(String name) {
    final raw = declared[name];
    if (raw == null) return null;
    final chars = _chars(raw);
    if (chars == null || chars > maxFieldChars) adjusted = true;
    return chars == null ? null : math.min(chars, maxFieldChars);
  }

  final min = count('min');
  final ideal = count('ideal');
  final max = count('max');
  final result = fieldChars(min: min, ideal: ideal, max: max ?? (maxLength == null ? null : longest));
  if ((ideal != null && ideal != result.ideal) || (max != null && max != result.max)) adjusted = true;
  if (adjusted) _reportChars(key, declared, result);
  return result;
}

/// A character count from extension JSON, which arrives as `int` or `double`;
/// anything else, or under one, is not a count.
int? _chars(Object? value) => value is num && value >= 1 ? value.floor() : null;

/// Once per control and declaration, since the row sizes its fields on every
/// layout.
void _reportChars(String? key, Object? declared, FieldChars used) {
  if (_reportedChars.add('$key $declared')) {
    debugPrint('[extensions] logging field ${key ?? '(no key)'}: chars $declared adjusted to min ${used.min}, ideal ${used.ideal}, max ${used.max}');
  }
}

final Set<String> _reportedChars = {};

/// The gap that precedes a main field: [mainFieldGap] between two of a kind
/// (the two RSTs, consecutive exchanges), [mainFieldGroupGap] where a new
/// kind starts, and [logButtonGap] before the log button itself.
const mainFieldGap = 8.0;
const mainFieldGroupGap = 10.0;
const logButtonGap = 12.0;

/// The Radio control's Station Configuration icon — plain [Icon], not
/// [IconButton], so this is its actual glyph size rather than a tap target.
/// The radio name beside it is capped at 3x this, ellipsized past that.
const stationConfigIconSize = 24.0;

/// Strips Material 3's default toggle-button fill from the Band/Mode
/// dropdowns' trailing arrow — see the wrapping `IconButtonTheme` at each
/// `DropdownMenu` for why one exists at all. Shared so the two can't drift.
const dropdownArrowTheme = IconButtonThemeData(
  style: ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(Colors.transparent),
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
    minimumSize: WidgetStatePropertyAll(Size.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),
);

/// The left+right `contentPadding` `poloFieldDecoration` (theme.dart) gives a
/// main field, before the text scaler is applied to it.
const mainFieldContentPadding = 8.0;

/// The left+right padding Material adds to every `filled` field **on top of**
/// `contentPadding`, of its own accord: `input_decorator.dart`'s
/// `_kInputExtraPadding`, 4 a side, not text-scaled and not exposed by any
/// `InputDecoration` field.
///
/// The row can still have it back. A **negative** content padding cancels it
/// exactly — nothing in `InputDecorator` requires a positive one — which is
/// what lets a fully squeezed field run its value right to its own edge
/// instead of stopping 8pt short with no way to say otherwise.
const materialFilledInputGap = 8.0;

/// The strip `RenderEditable` keeps clear for the caret — its 1pt gap plus
/// the 2pt cursor. Without it a value that exactly fills its field has its
/// last character scrolled out from under the cursor.
const caretAllowance = 3.0;

/// How long a main field takes to reach a new width. Deliberately brief: once
/// the row is squeezed it reflows on every focus move, and anything slower
/// reads as the layout lagging behind the keyboard rather than following it.
const fieldWidthDuration = Duration(milliseconds: 100);

/// One of the main logging fields that follow the callsign, as the row needs
/// it: the gap before it, its width in characters, the node whose focus
/// exempts it from being squeezed, and how to build it at whatever width and
/// inner padding it ends up with.
typedef MainField = ({double gapBefore, FieldChars chars, FocusNode focusNode, Widget Function(double width, double padding, Duration duration) build});

/// One main logging field as everything OUTSIDE the row needs it: what it is
/// called, what the operator has typed into it, and the hint standing in while
/// they have not.
///
/// [hint] is what lets a peer's block tell the operator's own answers from the
/// app's without a second channel saying so: an untouched field carries an
/// empty controller and its suggestion here. A report is the case that needs
/// it — `_rstOrDefault` folds the placeholder into the DRAFT, where a default
/// `59` and a typed `59` become the same three characters.
///
/// [skipFocus] takes the field out of the Space and Tab cycle while leaving it
/// on the row and within reach of the arrow keys — for a field the operator
/// only visits to correct, like the serial number we send
/// (docs/design/logging-fields.md, "Moving between the main fields").
typedef PrimaryField = ({String key, String label, FocusNode focus, TextEditingController controller, String? hint, bool skipFocus});

/// What [resolveMainFieldLayout] settles on for the
/// row: a width for each trailing field, and — once even the floors don't fit
/// — how much of the declared gaps survives and how much horizontal padding is
/// left inside every field, callsign included.
typedef MainFieldLayout = ({List<double> widths, double gapScale, double fieldPadding});

/// Shared look for the main logging row (Their call/Sent/Rcvd and the rest) —
/// same font size across all of them, built on the app-wide field styling
/// (theme.dart), tinted to read against the panel's tertiaryContainer
/// background.
TextStyle mainFieldStyle(BuildContext context, {required FontWeight fontWeight}) => haloMonoStyle(context, fontSize: 15, fontWeight: fontWeight);

/// The main fields' caret height on iOS and macOS: 4pt under what those draw
/// by default, which is the line height plus 2 (`RenderEditable`) and stands
/// well above the mono digits beside it. Null — Flutter's own — elsewhere,
/// where the default is already 4pt under the line. Branched on
/// `defaultTargetPlatform`, the same switch `RenderEditable` draws by.
///
/// Cached per style and text scaler: every main field asks on every build,
/// which is every keystroke.
double? mainFieldCursorHeight(BuildContext context) {
  if (defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.macOS) return null;
  final style = Theme.of(context).textTheme.bodyLarge?.merge(mainFieldStyle(context, fontWeight: FontWeight.w500));
  final scaler = MediaQuery.textScalerOf(context);
  return _cursorHeights.putIfAbsent((style, scaler), () {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    );
    try {
      return painter.preferredLineHeight - 4;
    } finally {
      painter.dispose();
    }
  });
}

final _cursorHeights = <(TextStyle?, TextScaler), double>{};

/// A main field's decoration, with the label always pinned to the top-left
/// corner (not the "large placeholder until focused" default) so the row's
/// shape doesn't shift as you type.
///
/// [horizontalPadding] is the field's **total** effective left+right inset,
/// the last thing the row gives up when the fields won't fit at their floors
/// (see [resolveMainFieldLayout]). Effective, so [materialFilledInputGap]
/// comes out of it here: at full padding that leaves exactly the content
/// padding the theme asks for, and at zero it leaves a negative one that
/// cancels Material's own.
///
/// The vertical padding is left alone: it sets the row's height, and
/// squeezing that would move every control and the submit button as the
/// panel narrowed.
InputDecoration mainFieldDecoration(BuildContext context, String label, {String? hintText, required double horizontalPadding}) {
  final base = poloFieldDecoration(
    context,
    label,
    labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
    hintText: hintText,
    // A squeezed field is narrower than its own label ("Their call" over 6
    // characters, "State" over 2), and a label left to wrap makes the
    // decorator taller — which through the row's IntrinsicHeight widens the
    // submit button, taking back more room than the squeeze just found.
    labelMaxLines: 1,
  );
  final side = (horizontalPadding - materialFilledInputGap) / 2;
  final padding = base.contentPadding! as EdgeInsets;
  return base.copyWith(
    contentPadding: padding.copyWith(left: side, right: side),
  );
}

/// Which of a control's two labels a field [width] wide can actually show.
///
/// A main field is routinely narrower than its own label — that is what
/// [mainFieldDecoration]'s `labelMaxLines: 1` exists for, and an ellipsized
/// "QP Loca…" names the field no better than nothing does. An extension that
/// declares a `shortLabel` gets it used instead, at the width where the full
/// one stops fitting; the ellipsis stays the last resort for a field too narrow
/// for either.
///
/// [horizontalPadding] is the field's FULL inset — the same number
/// [mainFieldDecoration] is given.
///
/// Two corrections stand between that and what the label may paint in, and
/// getting either wrong shows the short label at every width:
///
///  * a FLOATING label is painted at [floatingLabelScale], and `InputDecorator`
///    lays it out at full size and then shrinks it — so it is given
///    `1 / floatingLabelScale` of the room it will occupy, and the measurement
///    here, which is also at full size, is compared against that;
///  * Material's own [materialFilledInputGap] is added to the CONTENT, not to
///    the label, so the label keeps the part of it that
///    [mainFieldDecoration] gave back as negative content padding.
///
/// [mainFieldLabelWidth] is the arithmetic, kept apart because the only honest
/// test of it renders a real field and compares the two.
String mainFieldLabel(BuildContext context, {required String label, String? shortLabel, required double width, required double horizontalPadding}) {
  if (shortLabel == null || shortLabel.isEmpty || shortLabel == label) return label;
  final available = mainFieldLabelWidth(width: width, horizontalPadding: horizontalPadding);
  return textWidth(context, label, poloFieldLabelStyle(context)) <= available ? label : shortLabel;
}

/// What `InputDecorator` gives a [mainFieldDecoration] label to lay out in,
/// measured at the label's own font size rather than the size it paints at.
double mainFieldLabelWidth({required double width, required double horizontalPadding}) =>
    (width - horizontalPadding + materialFilledInputGap) / floatingLabelScale;

/// Material's `_kFinalLabelScale` — private, and the reason
/// [mainFieldLabelWidth] is pinned by a test against a rendered field rather
/// than trusted.
const floatingLabelScale = 0.75;

/// What the row's arithmetic measures once per layout: one character of the
/// main fields' monospace value, and the full padding a field carries — the
/// theme's own content padding, which scales with OS text size, plus
/// Material's fixed extra, which doesn't. The padding is the row's to give
/// away; the characters are not.
///
/// Measured, so every width stated in characters tracks OS/accessibility text
/// scaling together — a 6-character width measured at one scale and
/// hardcoded would be five characters at the next.
typedef MainFieldMetrics = ({double charWidth, double fullPadding});

MainFieldMetrics mainFieldMetrics(BuildContext context) => (
  charWidth: textWidth(context, 'W' * 10, mainFieldStyle(context, fontWeight: FontWeight.w500)) / 10,
  fullPadding: mainFieldContentPadding * MediaQuery.textScalerOf(context).scale(1.0) + materialFilledInputGap,
);

/// The width [chars] characters of value paint at, plus the caret's reserved
/// strip — everything a field needs EXCEPT its own horizontal padding, which
/// the row adds because it can take that padding away again.
double mainFieldValueWidth(MainFieldMetrics metrics, int chars) => chars * metrics.charWidth + caretAllowance;

/// Resolves how the main logging row fills [maxWidth], and whether it had to
/// squeeze anything to do it. Every field's [FieldChars] become pixels through
/// [metrics].
///
/// The row is filled in this order:
///
/// 1. **Every field at its min**, the callsign ([call]) included — and the
///    **focused field at its ideal**, so a squeezed row stays usable to type
///    in. That ideal counts as the focused field's min everywhere below: the
///    others wait short of their ideals for it, and short of even that the
///    gaps and padding give way before the callsign's own min does.
/// 2. **The callsign to its ideal.**
/// 3. **The other fields to their ideals**, the room shared in proportion to
///    what each still needs, so they all arrive together.
/// 4. **Every field toward its max**, the callsign included, the room shared
///    in proportion to the width each already has: the wider field gets more
///    of it. A field at its max drops out; the callsign has none, so past
///    every other max the rest of the row is its.
///
/// When even the mins don't fit, the gaps between the fields and the padding
/// inside them go first, together and *gradually* — a single fraction of both,
/// falling with the width rather than snapping off at some breakpoint. With
/// those gone the fields go under their mins, down to [fieldFloorChars], each
/// in proportion to what it has above that so they reach it together; the
/// focused field keeps its ideal. Past that the callsign gives up its own min
/// — the last thing left to give, and a callsign field too narrow reads better
/// than a row of overflow stripes.
///
/// The callsign is never in [fields]: it is `Expanded` over what they leave,
/// so its share here is only reserved, never returned.
///
/// `squeezed` says something besides the focused field is under its ideal —
/// another field, the callsign, or the gaps and padding. The row's own focus
/// listener reads it: the focused field renders at its ideal, which only
/// happens if a focus change rebuilds — and off a row where everything has its
/// ideal it would be a rebuild that changes nothing.
({MainFieldLayout layout, bool squeezed}) resolveMainFieldLayout({
  required List<MainField> fields,
  required double maxWidth,
  required double buttonWidth,
  required MainFieldMetrics metrics,
  FieldChars call = callFieldChars,
}) {
  double px(int chars) => mainFieldValueWidth(metrics, chars);
  final fullPadding = metrics.fullPadding;
  var fullGaps = logButtonGap;
  for (final field in fields) {
    fullGaps += field.gapBefore;
  }

  // The gaps and padding, solved rather than iterated: the narrowest this row
  // can be is linear in how much of them it keeps, so the largest fraction
  // that still fits is one division. 1 — nothing given up — whenever the mins
  // fit, which is almost always.
  var incompressible = buttonWidth + px(call.min);
  for (final field in fields) {
    incompressible += px(field.focusNode.hasFocus ? field.chars.ideal : field.chars.min);
  }
  final compressible = fullGaps + (fields.length + 1) * fullPadding;
  final scale = compressible <= 0 ? 1.0 : ((maxWidth - incompressible) / compressible).clamp(0.0, 1.0);
  final padding = fullPadding * scale;

  // Index 0 is the callsign, the fields follow. Value widths, no padding.
  final focused = [false, for (final field in fields) field.focusNode.hasFocus];
  final specs = [call, for (final field in fields) field.chars];
  final ideals = [for (final spec in specs) px(spec.ideal)];
  final caps = [for (final spec in specs) spec.max == null ? double.infinity : px(spec.max!)];
  final widths = [for (var i = 0; i < specs.length; i++) focused[i] ? ideals[i] : px(specs[i].min)];
  var rest = maxWidth - buttonWidth - fullGaps * scale - specs.length * padding - widths.fold(0.0, (sum, w) => sum + w);

  // Short even with the gaps and padding gone: the fields under their mins,
  // toward the floor, in proportion to what each has above it.
  if (rest < 0) {
    final floor = px(fieldFloorChars);
    var givable = 0.0;
    for (var i = 1; i < specs.length; i++) {
      if (!focused[i]) givable += math.max(0.0, widths[i] - floor);
    }
    if (givable > 0) {
      final share = math.min(1.0, -rest / givable);
      for (var i = 1; i < specs.length; i++) {
        if (!focused[i]) widths[i] -= math.max(0.0, widths[i] - floor) * share;
      }
      rest += givable * share;
    }
  }

  // 2. The callsign to its ideal.
  if (rest > 0) {
    final grow = math.min(rest, ideals[0] - widths[0]);
    widths[0] += grow;
    rest -= grow;
  }

  // 3. The fields to their ideals, in proportion to what each still needs.
  if (rest > 0) {
    var needed = 0.0;
    for (var i = 1; i < specs.length; i++) {
      needed += ideals[i] - widths[i];
    }
    if (needed > 0) {
      final share = math.min(1.0, rest / needed);
      for (var i = 1; i < specs.length; i++) {
        widths[i] += (ideals[i] - widths[i]) * share;
      }
      rest -= needed * share;
    }
  }

  // 4. Toward the maxes, in proportion to width. Water-filling: a field that
  // reaches its max gives what it couldn't take back to the next pass. Ends
  // because every pass either places all of it or caps another field; a
  // sub-pixel remainder isn't worth another.
  while (rest > 0.5) {
    final open = [
      for (var i = 0; i < specs.length; i++)
        if (widths[i] < caps[i]) i,
    ];
    if (open.isEmpty) break;
    final total = open.fold(0.0, (sum, i) => sum + widths[i]);
    var placed = 0.0;
    var capped = false;
    for (final i in open) {
      final grant = rest * widths[i] / total;
      final take = math.min(grant, caps[i] - widths[i]);
      if (take < grant) capped = true;
      widths[i] += take;
      placed += take;
    }
    rest -= placed;
    if (!capped) break;
  }

  final squeezed =
      scale < 1 ||
      rest < -0.5 ||
      widths[0] < ideals[0] - 0.5 ||
      [for (var i = 1; i < specs.length; i++) !focused[i] && widths[i] < ideals[i] - 0.5].any((under) => under);
  return (layout: (widths: [for (var i = 1; i < specs.length; i++) widths[i] + padding], gapScale: scale, fieldPadding: padding), squeezed: squeezed);
}

/// What every main logging field does instead of `EditableText`'s default
/// end-of-editing behavior.
///
/// That default **unfocuses the field before it calls `onSubmitted`** — so
/// left alone, every Enter blurs the field that submitted it, and the entry
/// row only looked like it kept focus because the ordinary logging paths
/// happen to re-focus afterwards (the wipe after a logged QSO, the can't-log
/// guard otherwise). Any path that didn't — running a command, saving an
/// edit, a second Enter while one is still in flight — left the operator
/// with nothing focused at all.
///
/// Here Enter means "log", never "done editing": the entry row is a loop the
/// keyboard stays inside (docs/design/logging-fields.md § "Enter and focus"),
/// so the field that submitted keeps focus unless something downstream
/// deliberately moves it. Suppressing the blur at the three build sites fixes
/// every submit path at once, rather than making each new branch of the log
/// path remember to put focus back.
///
/// Supplying `onEditingComplete` replaces the branch that did BOTH of those,
/// so the composing-region cleanup is reinstated here by hand. It does not
/// replace everything: `_finalizeEditing`'s trailing
/// `if (shouldUnfocus) _scheduleRestartConnection()` still runs, and
/// actually restarts the platform input connection rather than finding it
/// already closed — which is what keeps the keyboard from blinking per QSO.
///
/// Secondary controls are deliberately not covered — they keep their widget
/// defaults (docs/design/logging-fields.md § "The three parts"), and the
/// radio control's field moves focus to its pill itself on submit.
void finishEditingWithoutBlur(TextEditingController controller) => controller.clearComposing();
