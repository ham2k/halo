// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The "More" full-edit pane: the one surface that shows everything a contact
// can hold, including the fields no primary or secondary control exposes.
//
// It is a secondary control that bypasses the usual inline-expand behavior
// (special-cased in LoggingControls' _onSelectControl) to open a Modal Pane,
// reusing the FormRenderer engine via showFormPane (see form_pane.dart)
// rather than a new navigation route. Fields are `uppercase: true` per the
// logging-wide rule — uppercase unless explicitly mixed-case: Name and Notes
// are free prose, and Band's canonical names are lowercase ("20m", matching
// the `bands` table, which is compared by exact equality).
//
// The form's SHAPE lives here; applying what comes back stays in
// LoggingControls, where the controllers and the override maps are. The two
// meet on the field keys below, so a key renamed on one side fails to
// compile on the other.
//
// The Notes secondary control lives here too, for the same reason it is a
// pane concern at all: it is a second view onto the one value the pane's
// Notes field edits, and the two have to agree about width, casing and the
// check mark. Keeping them apart is what would let them drift.

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'form_pane.dart';
import 'mdi_icons.g.dart';
import 'secondary_control_row.dart';
import 'text_formatters.dart';
import 'theme.dart';

/// The `their` keys the pane owns outright — everything about the other
/// station that no logging control has a field for. Never `call`, `sent`,
/// `name`, `grid` or `state`: those have their own fields in the row, and
/// their own touched-tracking there.
const theirPaneKeys = ['city', 'county', 'cqZone', 'ituZone', 'arrlSection', 'lat', 'lon', 'power'];

/// The pane's field names for those keys. The pane prefixes them `their` so
/// `power` and `theirPower` — ours and theirs — stay two different fields in
/// one flat form state.
const theirPaneFormKeys = {
  'theirCity': 'city',
  'theirCounty': 'county',
  'theirCqZone': 'cqZone',
  'theirItuZone': 'ituZone',
  'theirArrlSection': 'arrlSection',
  'theirLat': 'lat',
  'theirLon': 'lon',
  'theirPower': 'power',
};

const _theirPaneNumericKeys = {'theirCqZone', 'theirItuZone', 'theirLat', 'theirLon', 'theirPower'};

/// One of the pane's `their` values in the shape both the form and the record
/// use, so "what it opened with" and "what came back" are comparable without
/// a per-field branch at either end. Text is trimmed (and the section
/// uppercased, as everything typed in the logging controls is unless it is
/// prose); numbers stay numbers, and an empty field of either kind comes back
/// as null — the pane offering no answer and the operator erasing one are the
/// same absence.
Object? theirPaneValue(String formKey, Object? raw) {
  if (raw == null) return null;
  if (_theirPaneNumericKeys.contains(formKey)) return asQsonNum(raw);
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  return formKey == 'theirArrlSection' ? text.toUpperCase() : text;
}

/// The pane's `their` values as they stood when it opened, keyed by form
/// field — the baseline every override below is measured against.
Map<String, Object?> theirPaneValues(Map<String, dynamic> their) => {
  for (final entry in theirPaneFormKeys.entries) entry.key: theirPaneValue(entry.key, their[entry.value]),
};

/// The `their` keys the operator actually CHANGED in the pane, keyed by
/// record field, ready to merge into the override map.
///
/// Only what changed, for the same reason the operator/position pair is: a
/// lookup's guess must not become an entered value from a contact merely
/// being opened and saved. `containsKey` first — a field the form dropped
/// (County over a DX contact, ARRL Section likewise) leaves a null in
/// [result] that would otherwise read as the operator clearing something they
/// were never shown.
Map<String, Object?> theirPaneOverrides(Map<String, dynamic> result, Map<String, Object?> before) => {
  for (final entry in theirPaneFormKeys.entries)
    if (result.containsKey(entry.key) && theirPaneValue(entry.key, result[entry.key]) != before[entry.key])
      entry.value: theirPaneValue(entry.key, result[entry.key]),
};

/// The instant the pane's Date and Time fields name, or null where they were
/// left exactly as they were shown.
///
/// The displayed-vs-edited distinction is the whole point: while composing,
/// the pane shows the live clock, and saving an untouched value must not turn
/// it into a manual override that freezes auto-timestamping. A half-parsed
/// pair is left alone rather than stamped — a date without a time is not an
/// instant.
int? paneStartAtMillis(Map<String, dynamic> result, String dateBefore, String timeBefore) {
  if (result['date'] == dateBefore && result['time'] == timeBefore) return null;
  final date = ((result['date'] as String?) ?? '').split('-');
  final time = ((result['time'] as String?) ?? '').split(':');
  if (date.length != 3 || time.length != 2) return null;
  final parts = [...date, ...time].map(int.tryParse).toList();
  if (parts.any((part) => part == null)) return null;
  return DateTime.utc(parts[0]!, parts[1]!, parts[2]!, parts[3]!, parts[4]!).millisecondsSinceEpoch;
}

/// The multi-station operating position the pane names: digits only, and no
/// leading zeros. `/OP` plus anything else is a callsign no hunter can use,
/// and `02` and `2` are the same seat. Empty for anything that names none.
String panePosition(Object? typed) {
  final digits = (typed as String? ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  final parsed = int.tryParse(digits);
  return parsed == null || parsed <= 0 ? '' : parsed.toString();
}

/// The country-file entity prefixes whose stations have a county and an ARRL
/// section. The same three the scorer uses (`extensions/core/scoring`'s
/// `US_ENTITIES`) — Alaska is `KL`, not `KL7`, and Hawaii and Alaska are their
/// own DXCC entities rather than part of `K`. A DIVERGENCE from app-polo,
/// which asks on the bare `K` prefix: that hides both fields from exactly the
/// stations whose section (`AK`, `PAC`) is the only record of where they are,
/// since neither carries a `state` of its own.
const _usEntities = {'K', 'KL', 'KH6'};

/// Whether County and ARRL Section belong in the pane for this contact: both
/// are US concepts, and offering them over a DX contact is offering a field
/// with no possible answer. Reads the entered entity first and the guess
/// second, the same precedence every other `their` field takes.
bool theirIsUS(Map<String, dynamic>? their, Map<String, dynamic>? guess) =>
    _usEntities.contains(asQsonString(their?['entityPrefix']) ?? asQsonString(guess?['entityPrefix']));

/// The entity, spelled the way the call-info area spells it — a value the pane
/// SHOWS and never takes, since it follows from the callsign and nothing here
/// could correct it. Null when the callsign hasn't resolved to one yet, which
/// drops the field rather than showing an empty one.
String? theirEntityDisplay(Map<String, dynamic>? their, Map<String, dynamic>? guess) {
  final name = asQsonString(their?['entityName']) ?? guess?['entityName'] as String?;
  final prefix = asQsonString(their?['entityPrefix']) ?? guess?['entityPrefix'] as String?;
  if (name == null || name.isEmpty) return null;
  return prefix == null || prefix.isEmpty ? name : '$name ($prefix)';
}

/// The locator a lookup's [guess] places the station in, as the operator's
/// Grid Precision renders it — the hint every Grid field shows while it is
/// empty, here and on the logging row.
///
/// Through [gridForDisplay], never the guess's stored `grid` alone. A lookup
/// that reported a coordinate has its square derived from that coordinate,
/// which is finer than the six characters the merge files beside it — and a
/// hint must show what would be stored if the operator left the field alone,
/// or the hint and the record disagree (docs/design/locations.md). One
/// function for both fields, because two Grid hints on one screen showing
/// different squares is the failure this is guarding against.
String? guessGridDisplay(Map<String, dynamic>? guess) {
  if (guess == null) return null;
  final exact = locationFromGuess(guess);
  return gridForDisplay(lat: exact?.latitude, lon: exact?.longitude, grid: asQsonString(guess['grid']));
}

/// A guessed number as a placeholder string — the zones, which arrive from a
/// lookup as ints but hint as text like every other field here.
String? _numericGuess(Map<String, dynamic>? guess, String key) {
  final value = guess?[key];
  return value == null ? null : '$value';
}

/// The pane's four sections, in the order app-polo's Edit QSO screen puts
/// them: what the contact was, who they were, who we were, and the rest.
///
/// [composing] means a new contact rather than one already in the log — see
/// the operator field. [rstPaneKeyOrder] is the panel's own resolved
/// Sent/Rcvd order; [powerShown] whether power is part of this entry at all.
Map<String, dynamic> buildQsoEditFormDefinition({
  required String defaultOperatorCall,
  required String defaultPosition,
  required bool showPositionField,
  required Map<String, dynamic>? their,
  required Map<String, dynamic>? guess,
  required List<String> rstPaneKeyOrder,
  required String? rstPlaceholder,
  required bool powerShown,
  required bool composing,
  required String currentMode,
}) {
  final entity = theirEntityDisplay(their, guess);
  final us = theirIsUS(their, guess);
  final tt = t.qsoEditForm;
  return {
    'title': tt.title,
    'elements': [
      {'type': 'header', 'title': tt.sectionQso},
      {'type': 'field', 'key': 'date', 'fieldType': 'text', 'label': t.loggingControls.date},
      {'type': 'field', 'key': 'time', 'fieldType': 'text', 'label': t.loggingControls.timeUtc},
      {'type': 'field', 'key': 'freq', 'fieldType': 'number', 'label': t.loggingControls.frequency},
      {'type': 'field', 'key': 'band', 'fieldType': 'text', 'label': tt.band},
      {
        'type': 'field',
        'key': 'mode',
        'fieldType': 'select',
        'label': t.loggingControls.mode,
        // [currentMode] is what the panel SHOWS ([displayMode]), and it is
        // appended when the option list has no entry for it — a select whose
        // value matches no option renders empty, and saving that pane would
        // then clear the mode the contact was worked on.
        'options': [
          for (final m in [...modes, if (!modes.contains(currentMode)) currentMode]) {'value': m, 'label': m},
        ],
      },
      // After the mode, with the rest of what describes the transmission
      // rather than the station. Only when power is part of this entry: an
      // operator who never states one has no use for the field.
      if (powerShown) {'type': 'field', 'key': 'power', 'fieldType': 'number', 'label': t.loggingControls.power},
      // Both reports, together, in this section — app-polo splits them
      // between its Their and Our sections, and here they cannot be split:
      // one place resolves which is drawn first (LoggingControls'
      // `_rstPaneKeyOrder`) and the row, the key cycle and the QSO list cell
      // all read it, so a pane that put them under two headings would be
      // contradicting the row that opened it. Same blank-means-the-default
      // rule as the Sent/Rcvd row, so the pane never shows a report the row
      // is only standing in for.
      for (final key in rstPaneKeyOrder)
        {
          'type': 'field',
          'key': key,
          'fieldType': 'text',
          'label': (key == 'sent' ? t.loggingControls.sent : t.loggingControls.rcvd),
          'uppercase': true,
          'placeholder': rstPlaceholder,
        },

      {'type': 'header', 'title': tt.sectionTheir},
      // Guessed values ride along as faint placeholders (the FormRenderer
      // maps a field's `placeholder` to poloFieldDecoration's hintText) —
      // same "guess as a hint, never a pre-filled value" behaviour as the
      // primary Grid/State.
      {'type': 'field', 'key': 'theirCall', 'fieldType': 'callsign', 'label': t.loggingControls.theirCall},
      {'type': 'field', 'key': 'theirName', 'fieldType': 'text', 'label': tt.theirName, 'placeholder': guess?['name'] as String?},
      // Their address, coarse to fine. `city` is what ADIF calls QTH and what
      // a lookup answers with.
      {'type': 'field', 'key': 'theirCity', 'fieldType': 'text', 'label': tt.theirCity, 'placeholder': guess?['city'] as String?},
      {'type': 'field', 'key': 'theirState', 'fieldType': 'text', 'label': tt.theirState, 'uppercase': true, 'placeholder': guess?['state'] as String?},
      if (us) {'type': 'field', 'key': 'theirCounty', 'fieldType': 'text', 'label': tt.theirCounty, 'placeholder': guess?['county'] as String?},
      if (entity != null) {'type': 'field', 'key': 'theirEntity', 'fieldType': 'text', 'label': tt.theirEntity, 'disabled': true},
      {'type': 'field', 'key': 'theirCqZone', 'fieldType': 'number', 'label': tt.theirCqZone, 'placeholder': _numericGuess(guess, 'cqZone')},
      {'type': 'field', 'key': 'theirItuZone', 'fieldType': 'number', 'label': tt.theirItuZone, 'placeholder': _numericGuess(guess, 'ituZone')},
      if (us)
        {
          'type': 'field',
          'key': 'theirArrlSection',
          'fieldType': 'text',
          'label': tt.theirArrlSection,
          'uppercase': true,
          'placeholder': guess?['arrlSection'] as String?,
        },
      {'type': 'field', 'key': 'theirGrid', 'fieldType': 'text', 'label': tt.theirGrid, 'uppercase': true, 'placeholder': guessGridDisplay(guess)},
      // Editable, and cleared by the grid above the moment it is edited (see
      // [showQsoEditPane]'s onChange): a coordinate outranks a grid wherever
      // one is read (docs/design/locations.md), so leaving a stale pair on
      // screen would show the operator a locator the app is about to ignore.
      // A coordinate typed here still wins — that is the operator stating
      // where the station is, to the precision they have.
      {'type': 'field', 'key': 'theirLat', 'fieldType': 'number', 'label': tt.theirLat},
      {'type': 'field', 'key': 'theirLon', 'fieldType': 'number', 'label': tt.theirLon},
      // What THEY were running, which is not the `power` above — that one is
      // ours. Always offered, unlike ours: there is no VFO carrying it and no
      // setting that captures it, so the pane is the only way it ever reaches
      // a contact.
      {'type': 'field', 'key': 'theirPower', 'fieldType': 'number', 'label': tt.theirPower},

      {'type': 'header', 'title': tt.sectionOur},
      // Who was at the key, and — only where the operation is run by
      // positions — which one logged this contact. The station callsign is
      // deliberately absent: the save path stamps the operation's own, and
      // which of several calls made a given contact is not recorded per QSO.
      //
      // The placeholder is the operation's own answer, and only while
      // COMPOSING: that is what the save path will stamp on a new contact, so
      // the pane is showing what is about to happen. An existing record takes
      // no stamp (`qsoWithOperator`), so the same hint over an old contact
      // would promise a callsign that will never be written, and a log made
      // before anyone was named would read as if it had been.
      {
        'type': 'field',
        'key': 'operatorCall',
        'fieldType': 'callsign',
        'label': tt.operatorCall,
        'placeholder': composing && defaultOperatorCall.isNotEmpty ? defaultOperatorCall : null,
      },
      if (showPositionField)
        {
          'type': 'field',
          'key': 'multiIdentifier',
          'fieldType': 'text',
          'label': tt.position,
          'placeholder': composing && defaultPosition.isNotEmpty ? defaultPosition : null,
        },

      {'type': 'header', 'title': tt.sectionNotes},
      // Capitalized, not uppercased — a note is prose. The Notes control in
      // the row applies the same rule to the same value.
      {'type': 'field', 'key': 'notes', 'fieldType': 'multiline', 'label': tt.notes, 'capitalize': true},
    ],
  };
}

/// Opens the pane and returns what the operator saved, or null if they didn't.
///
/// [gridBeforePane] is the locator the pane opened with, which the coordinate
/// rule below needs to tell a real edit from a re-render.
Future<Map<String, dynamic>?> showQsoEditPane(
  BuildContext context, {
  required Map<String, dynamic> formDefinition,
  required Map<String, dynamic> initialState,
  required String gridBeforePane,
}) => showFormPane(
  context,
  formDefinition: formDefinition,
  initialState: initialState,
  onChange: (key, value, state) async {
    // Freq wins over a manually-typed band, matching _onFreqChanged's
    // existing precedence for the inline Radio control.
    if (key == 'freq' && value is num) {
      final band = bandForFrequency(value.toDouble());
      if (band != null) return {'band': band};
    }
    // A typed locator replaces whatever coordinate the record arrived
    // with, and the save path clears the pair for exactly that reason
    // (`QsoDraft.toData`). Blanking the fields here is
    // what keeps the pane honest about it: locations.md's rule is that a
    // field the operator types into shows what would be stored if they
    // left it alone, and a coordinate left on screen beside a corrected
    // grid says the opposite of what the save will do.
    if (key == 'theirGrid' && normalizeGrid((value as String? ?? '').trim()) != normalizeGrid(gridBeforePane)) {
      return {'theirLat': null, 'theirLon': null};
    }
    return null;
  },
);

/// The Notes chip and its field — a free-prose note about this contact.
///
/// Wider than the other controls' fields, because a note is a sentence rather
/// than a value, and explicitly mixed-case like Name and the spot comment.
/// [onChanged] carries the value back to whatever owns it; the chip's summary
/// is read from [controller] on every build, so it follows the same string.
/// The More and Notes chips' glyphs — the settings dialog's entries read
/// these too.
const moreChipIcon = MdiIcons.pencil;
const notesChipIcon = MdiIcons.noteOutline;

/// The More chip. Never actually expanded — the logging panel special-cases
/// 'more' to open this pane instead of expanding inline.
SecondaryControlSpec moreControlSpec() =>
    SecondaryControlSpec(key: 'more', icon: moreChipIcon, summary: t.loggingControls.more, expandedBuilder: (context) => const SizedBox.shrink());

SecondaryControlSpec notesControlSpec(
  ThemeData theme, {
  required TextEditingController controller,
  required FocusNode focusNode,
  required ValueChanged<String> onChanged,
}) {
  final label = t.loggingControls.notesControl;
  return SecondaryControlSpec(
    key: 'notes',
    icon: notesChipIcon,
    // The same check mark the reference controls use to say a field is filled
    // in (U+2713, no emoji presentation, so it takes the label's own color).
    // A note is one thing or nothing, so there is no count.
    summary: controller.text.trim().isEmpty ? label : '✓ $label',
    expandedBuilder: (context) => SizedBox(
      width: 320,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        selectAllOnFocus: false,
        style: haloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500),
        decoration: poloFieldDecoration(context, label, labelColor: theme.colorScheme.onTertiaryContainer),
        // `textCapitalization` is only a hint to an on-screen keyboard — it
        // does nothing on a desktop or in a browser — so the formatter is what
        // actually delivers the capital, on every platform.
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: const [CapitalizeFirstLetterTextFormatter()],
        onChanged: onChanged,
      ),
    ),
  );
}
