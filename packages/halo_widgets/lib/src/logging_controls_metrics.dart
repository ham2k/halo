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

import 'package:flutter/material.dart';

import 'theme.dart';

/// Horizontal padding around the panel's fields — also handed to
/// `SecondaryControlRow` so its expanded control panel can bleed past it
/// and reach the view's true edges.
const secondaryPanelHorizontalInset = 12.0;

/// What a main logging field asks for when the row has the room: an RST, a
/// state or a grid at [fixedFieldMinWidth]; a contest exchange a little
/// wider, since it can be a zone, a serial or a section name.
///
/// **Minimums, not fixed sizes.** When the enabled fields don't all fit, they
/// render narrower than this — see [resolveMainFieldLayout].
const fixedFieldMinWidth = 64.0;
const exchangeFieldMinWidth = 76.0;

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

/// The callsign field's floor, in characters of its own value: a full call
/// with a portable suffix (`W1AW/4`).
const callFieldMinChars = 6;

/// Every other main field's floor. Two characters is enough to tell a filled
/// field from an empty one and to aim a click at it — and focusing it brings
/// it straight back to the width it asked for, so this is only ever what a
/// field the operator isn't in looks like.
const mainFieldMinChars = 2;

/// How long a main field takes to reach a new width. Deliberately brief: once
/// the row is squeezed it reflows on every focus move, and anything slower
/// reads as the layout lagging behind the keyboard rather than following it.
const fieldWidthDuration = Duration(milliseconds: 100);

/// One of the main logging fields that follow the callsign, as the row needs
/// it: the gap before it, the width it asks for, the node whose focus exempts
/// it from being squeezed, and how to build it at whatever width and inner
/// padding it ends up with.
typedef MainField = ({double gapBefore, double minWidth, FocusNode focusNode, Widget Function(double width, double padding, Duration duration) build});

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

/// The width [chars] characters of a main field's monospace value paint at,
/// plus the caret's reserved strip — everything a field needs EXCEPT its own
/// horizontal padding, which the caller adds because the row can take that
/// padding away again.
///
/// Every width this row states in characters goes through here, so they all
/// track OS/accessibility text scaling together — a 6-character minimum
/// measured at one scale and hardcoded would be five characters at the next.
double mainFieldValueWidth(BuildContext context, int chars) =>
    textWidth(context, 'W' * chars, mainFieldStyle(context, fontWeight: FontWeight.w500)) + caretAllowance;

/// What the row's arithmetic measures once per layout: the callsign's and
/// the other fields' character floors as widths, and the full padding a
/// field carries — the theme's own content padding, which scales with OS text
/// size, plus Material's fixed extra, which doesn't. Both are the row's to
/// give away.
typedef MainFieldFloors = ({double callValue, double fieldValue, double fullPadding});

MainFieldFloors mainFieldFloors(BuildContext context) => (
  callValue: mainFieldValueWidth(context, callFieldMinChars),
  fieldValue: mainFieldValueWidth(context, mainFieldMinChars),
  fullPadding: mainFieldContentPadding * MediaQuery.textScalerOf(context).scale(1.0) + materialFilledInputGap,
);

/// Resolves how the main logging row fills [maxWidth], and whether it had to
/// squeeze anything to do it.
///
/// Concessions, in the order the row makes them:
///
/// 1. **Everything fits.** Each of [fields] renders at its declared minimum
///    and the callsign takes whatever is left.
/// 2. **They don't.** The shortfall is split **evenly** across them — the
///    same number of pixels off each, not the same share of each — down to
///    [mainFieldMinChars] characters, with whatever a floored field can't
///    give up re-spread over the ones that still have room. The **focused
///    field is left out of the split entirely**: it renders at its full
///    declared minimum and its neighbours carry its share, which is what
///    keeps a squeezed row usable to type in.
/// 3. **Not even at their floors.** The gaps between the fields and the
///    padding inside them go next, together and *gradually* — a single
///    fraction of both, falling with the width rather than snapping off at
///    some breakpoint. Note this shrinks the floors too: two characters
///    without padding is narrower than two with.
/// 4. **Still not.** The callsign gives up its own [callFieldMinChars] — it
///    is the last thing left to give, and a callsign field too narrow reads
///    better than a row of overflow stripes.
///
/// The callsign is never in [fields]: it is `Expanded` over what they leave,
/// and this arithmetic only reserves its minimum before dividing up the rest.
///
/// `squeezed` says the row couldn't give every field its declared minimum.
/// The row's own focus listener reads it: the focused field renders at full
/// width, which only happens if a focus change rebuilds — and off a squeezed
/// row it would be a rebuild that changes nothing.
({MainFieldLayout layout, bool squeezed}) resolveMainFieldLayout({
  required List<MainField> fields,
  required double maxWidth,
  required double buttonWidth,
  required MainFieldFloors floors,
}) {
  final fullPadding = floors.fullPadding;
  var fullGaps = logButtonGap;
  for (final field in fields) {
    fullGaps += field.gapBefore;
  }

  // Concession 3, solved rather than iterated: the narrowest this row can be
  // is linear in how much gap and padding it keeps, so the largest fraction
  // that still fits is one division. 1 — nothing given up — whenever
  // squeezing the fields alone is enough, which is almost always.
  final incompressible = buttonWidth + floors.callValue + fields.length * floors.fieldValue;
  final compressible = fullGaps + (fields.length + 1) * fullPadding;
  final scale = compressible <= 0 ? 1.0 : ((maxWidth - incompressible) / compressible).clamp(0.0, 1.0);

  final padding = fullPadding * scale;
  final widths = [for (final field in fields) field.minWidth];
  final reserved = buttonWidth + fullGaps * scale + floors.callValue + padding;
  var deficit = widths.fold(0.0, (sum, w) => sum + w) - (maxWidth - reserved);
  final squeezed = deficit > 0;
  if (deficit <= 0) return (layout: (widths: widths, gapScale: scale, fieldPadding: padding), squeezed: squeezed);

  final floor = floors.fieldValue + padding;
  final open = {
    for (var i = 0; i < fields.length; i++)
      if (!fields[i].focusNode.hasFocus) i,
  };
  // Water-filling: an even share each pass, and anything a field that hit
  // its floor couldn't absorb goes back into the pot for the next one.
  // Terminates because every pass either clears the deficit or drops a field
  // out of `open`. A sub-pixel remainder isn't worth another pass.
  while (deficit > 0.5 && open.isNotEmpty) {
    final share = deficit / open.length;
    deficit = 0;
    for (final i in open.toList()) {
      // Never above what the field asked for: at a large enough OS text
      // scale two characters are wider than the declared minimum, and a
      // "floor" over the ceiling would quietly widen the field instead.
      final limit = floor < fields[i].minWidth ? floor : fields[i].minWidth;
      final shrunk = widths[i] - share;
      if (shrunk <= limit) {
        deficit += limit - shrunk;
        widths[i] = limit;
        open.remove(i);
      } else {
        widths[i] = shrunk;
      }
    }
  }
  return (layout: (widths: widths, gapScale: scale, fieldPadding: padding), squeezed: squeezed);
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
