// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO being composed — or the saved one being edited — as the logging
// panel holds it between the fields: what the More pane overrode, which of
// Grid and State the operator actually touched, the note and the other
// top-level keys, the draft parked while an earlier contact is looked at,
// and the wiped draft the undo button can bring back. [QsoDraft] turns all
// of that plus the fields and the sibling models into the record to log
// ([toData]) and back again ([applyData]), and owns the ONE way to tell the
// panel that a write is programmatic rather than the operator typing
// ([populate]). The fields' controllers stay the panel's; the draft reads and
// writes them through its configuration.

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:halo_core/halo_core.dart';

import 'logging_controls_exchange.dart';
import 'logging_controls_lookup.dart';
import 'logging_controls_radio.dart';
import 'logging_controls_refs.dart';
import 'logging_controls_time.dart';
import 'panel_model.dart';
import 'qso_edit_pane.dart' show theirPaneKeys;
import 'timed_undo_slot.dart';

/// What the draft reads from the panel — the fields, the sibling models and
/// the live configuration — re-read on every use rather than copied in,
/// because each of these can change under a mounted panel.
typedef QsoDraftConfig = ({
  Operation operation,
  Qso? editingQso,
  TextEditingController callController,
  TextEditingController sentController,
  TextEditingController rcvdController,
  TextEditingController gridController,
  TextEditingController stateController,
  TextEditingController notesController,
  RadioControlModel radio,
  TimeControlModel time,
  ExchangeFieldsModel exchange,
  ActivityRefsModel refs,
  CallLookupModel lookup,

  /// The call as the field reads it right now — trimmed, uppercased, and the
  /// cursor's segment of a list or a stack.
  String call,

  /// Where a report becomes what actually gets stored: the placeholder if
  /// the field is blank, otherwise the operator's own shorthand completed.
  String Function(String text) rstOrDefault,

  /// Whether a freq/band mirrors the operation's VFO: then freq and band are
  /// not something the operator composed for this QSO.
  bool hasRadioService,
});

/// The draft. See the file comment.
///
/// Never notifies: every change to it is made by the panel, inside its own
/// `setState`, so the panel's rebuild is the repaint. The mixin is here for
/// the disposal contract the panel's models share.
class QsoDraft extends ChangeNotifier with PanelModel {
  QsoDraft({required this.config});

  /// The panel as it stands right now.
  final QsoDraftConfig Function() config;

  /// Top-level keys of the contact that no field owns — the note, and
  /// whatever a command's `updateQso` put there. Never `refs`, `our`,
  /// `their`, `freq`, `band`, `mode`, `power` or `startAtMillis`: those have
  /// fields or models of their own.
  final Map<String, dynamic> extra = {};

  /// Fields of the contact's `our` block the full-edit pane overrides — who
  /// was at the key, and which position logged it. Kept apart from [extra],
  /// which carries only TOP-LEVEL keys: these two live inside `our`, beside
  /// the station call the controls own.
  ///
  /// An override is written only when the pane's field was actually edited,
  /// so a contact left alone still takes the stamp the save path applies
  /// (`qsoWithOperator`), and an emptied field stays empty rather than being
  /// re-stamped — the stamp fills what is ABSENT, and this key is present.
  final Map<String, dynamic> ourExtra = {};

  /// Fields of the contact's `their` block the full-edit pane overrides —
  /// everything about the other station that no primary or secondary control
  /// owns: city, county, the zones, the ARRL section, a coordinate, and the
  /// power they were running. Same shape and same rule as [ourExtra]: a key
  /// lands here only where the pane actually CHANGED it, so opening a
  /// contact and saving it never promotes a lookup guess into an entered
  /// value the way `their.grid` would (see [gridTouched]).
  ///
  /// Never `call`, `sent`, `name`, `grid` or `state` — those have their own
  /// fields in the row, and their own touched-tracking.
  final Map<String, dynamic> theirExtra = {};

  /// Their name override, settable only via the "More" edit pane —
  /// deliberately not a full inline field, to avoid growing the primary
  /// controls' footprint for rarely-edited data. Grid/State have their own
  /// controllers instead, since they can also appear as optional primary
  /// fields.
  String? theirNameOverride;

  /// Whether the user has actually edited Grid/State (inline field or the
  /// "More" pane) for the QSO currently being composed/edited — as opposed
  /// to the controllers merely displaying a value populated from
  /// `editingQso.theirGrid`/`theirState` on load. Only a deliberate edit is
  /// sticky across a comma-separated call list (the panel's per-call data);
  /// an untouched, merely-displayed value must not clobber a fresh per-call
  /// lookup's own grid/state.
  bool gridTouched = false;
  bool stateTouched = false;

  /// The record being edited arrived carrying a power. Read from the record,
  /// never from the field: with the field as the test, emptying it would take
  /// the power OUT of the entry — and the write would then omit the key and
  /// leave the old value standing, so a wrong power could never be cleared.
  /// It also survives past the record, so it is cleared with the rest of the
  /// entry — otherwise a value left over from an edit goes on stamping every
  /// QSO logged afterwards.
  bool powerOnRecord = false;

  /// A wiped-but-not-yet-lost new QSO, stashed by the wipe button so the
  /// same button can flip to "undo" for a few seconds afterward. Only
  /// meaningful while composing a new QSO (`editingQso == null`).
  final undoSlot = TimedUndoSlot<Map<String, dynamic>>();

  /// The new QSO being composed, captured the instant the operator steps
  /// away to browse/edit an earlier one (`editingQso` going null → non-null)
  /// — restored when they come back (non-null → null), whether that's
  /// Escape, Down off the list, or saving the edit. Unlike [undoSlot] this
  /// never expires: it's not a "did you mean to lose this" offer, it's the
  /// draft's own state while attention is elsewhere.
  Map<String, dynamic>? _composingSnapshot;

  /// True while the panel is writing the fields itself — a selected QSO
  /// being loaded, a spot applied, a wipe undone, a command's setVfo — so a
  /// field listener can tell that write from the operator typing: the call
  /// field's lookup and command side effects, the frequency field's
  /// push-back to the radio, the Time control's manual override, a lookup's
  /// guessed refs, and any callback that would reach the parent from inside
  /// a build all stand down for it.
  bool _populating = false;

  bool get isPopulating => _populating;

  /// Runs [body] as a programmatic write. Nests: the flag goes back to what
  /// it was, not to false, so a seed inside a populate stays one. Restored
  /// on every exit, a throw included — a flag left standing would silence
  /// the operator's own typing for the rest of the session.
  T populate<T>(T Function() body) {
    final was = _populating;
    _populating = true;
    try {
      return body();
    } finally {
      _populating = was;
    }
  }

  /// Whether power is part of THIS entry — in play, or already on the record
  /// being edited. A QSO that carries a power keeps showing it after the
  /// control is switched back off: it went out on the air that way, and a
  /// value nothing displays is a value nothing can correct.
  bool get powerShown => _powerShownIn(config());

  /// The watts in the Power field, or null when it is empty (or holds
  /// nothing parseable — a lone "." mid-typing).
  num? get powerWatts => _powerWattsIn(config());

  bool _powerShownIn(QsoDraftConfig config) => config.radio.powerInPlay || powerOnRecord;

  num? _powerWattsIn(QsoDraftConfig config) => config.radio.powerWatts;

  /// The operator edited the Grid field — the inline field, a numbers-row
  /// key, or the More pane. Every one of them goes through here rather than
  /// setting the flag itself, because a typed grid also takes the contact's
  /// coordinate out of the entry: a pair the pane recorded earlier in this
  /// visit would otherwise survive and outrank the grid everywhere it is
  /// read (docs/design/locations.md), silently discarding the correction
  /// just made. A coordinate the operator types AFTER this, in the same pane
  /// visit, is recorded after it and still wins — that is the intended
  /// precedence.
  void markGridTouched() {
    gridTouched = true;
    theirExtra
      ..remove('lat')
      ..remove('lon');
  }

  /// Keeps the QSO's `notes` in step with what was typed. An empty note is
  /// REMOVED rather than stored as an empty string: [extra] being non-empty
  /// is one of the signals that says a draft is worth keeping
  /// ([hasComposedValues]), so a note typed and then deleted would otherwise
  /// leave an empty entry looking like a started one. What the SAVE writes
  /// for an empty note is a separate question — see [toData].
  void setNote(String value) {
    final notes = value.trim();
    if (notes.isEmpty) {
      extra.remove('notes');
    } else {
      extra['notes'] = notes;
    }
  }

  /// Parks the draft being composed while an earlier contact is looked at.
  void snapshotComposing() => _composingSnapshot = toData(composing: true);

  /// The parked draft, if one is waiting — and it stops waiting.
  Map<String, dynamic>? takeComposingSnapshot() {
    final snapshot = _composingSnapshot;
    _composingSnapshot = null;
    return snapshot;
  }

  /// Editing-session bookkeeping that must never leak from one QSO context
  /// into the next.
  void resetSession() {
    theirNameOverride = null;
    gridTouched = false;
    stateTouched = false;
    undoSlot.clear();
  }

  /// Forgets everything the draft holds beyond the fields — a wipe, or an
  /// editing session ending.
  void clear() {
    theirNameOverride = null;
    gridTouched = false;
    stateTouched = false;
    extra.clear();
    ourExtra.clear();
    theirExtra.clear();
  }

  /// Whether the in-progress new QSO has anything actually worth wiping —
  /// the wipe button stays visible but disabled when this is false. With a
  /// radio service, freq/band merely mirror the operation's VFO (seeded on
  /// entry, not something the operator composed for this specific QSO) and
  /// don't count; without one, they fall back to the pre-VFO behavior.
  bool get hasComposedValues {
    final config = this.config();
    return config.call.isNotEmpty ||
        (!config.hasRadioService && (config.radio.freqController.text.trim().isNotEmpty || config.radio.manualBand != null)) ||
        config.time.manualStartAtMillis != null ||
        theirNameOverride != null ||
        config.refs.hasRefs ||
        config.exchange.hasTypedValues ||
        extra.isNotEmpty ||
        ourExtra.isNotEmpty ||
        // A VALUE, not merely a key: a draft restored after a field was cleared
        // in the More pane carries that field's null in the snapshot, and
        // counting those would leave a visibly empty row guarding itself
        // against a wipe and asking before a spot overwrites it.
        theirExtra.values.any((value) => value != null) ||
        config.gridController.text.trim().isNotEmpty ||
        config.stateController.text.trim().isNotEmpty;
  }

  /// Whether the fields being edited differ from [editingQso]'s stored
  /// record.
  bool differsFrom(Qso editingQso) => !qsoDataEquivalent(toData(), editingQso.data);

  /// The record as the fields and the models would log it right now.
  ///
  /// [callOverride] lets call stacking supply the one segment it picked out
  /// of the "//"-separated field, instead of the raw (still-stacked) field
  /// text.
  ///
  /// [composing] describes the new-QSO draft regardless of what
  /// `editingQso` currently is — needed to snapshot it from inside the
  /// panel's `didUpdateWidget`, where the configuration already reflects
  /// the QSO about to be edited by the time this runs, and `base`/the Time
  /// control's effective time would otherwise pull from THAT record instead
  /// of from the still-blank-base draft being stepped away from.
  Map<String, dynamic> toData({String? callOverride, bool composing = false}) {
    final config = this.config();
    final base = composing ? const <String, dynamic>{} : (config.editingQso?.data ?? const <String, dynamic>{});
    final call = callOverride ?? config.call;
    final startAtMillis = composing ? config.time.manualStartAtMillis : config.time.effectiveStartAtMillis;
    final refs = config.exchange.refsWithTextValues(config.refs.allRefs);
    return {
      ...base,
      // Unconditional (not `if (refs.isNotEmpty)`/`if (freq != null)`):
      // `base` may already carry a non-empty value for these from the
      // record being edited, and a merge-style `...base` above won't drop
      // a stale one just because the live value is now empty/null — these
      // have to actively overwrite every time, including with null/empty,
      // for clearing a ref/freq/band during an edit to actually stick.
      'refs': refs,
      'our': {
        ...?(base['our'] as Map<String, dynamic>?),
        // The FIRST of the operation's callsigns, not the field: several
        // callsigns live in it as one comma-separated string, and a contact
        // holds exactly one. Stamping the field puts "N0DEV,KI2D" — which is
        // not a callsign — on every contact and into the `our_call` column
        // the cross-operation Logs view groups by. Which of several calls
        // made a given contact is not recorded here (app-polo doesn't record
        // it either); the exports fan out per call and restamp each file's
        // records themselves (`ExportService._qsosAs`).
        'call': config.operation.stationCalls.first,
        'sent': config.rstOrDefault(config.sentController.text.trim()),
        ...ourExtra,
      },
      'their': {
        ...?(base['their'] as Map<String, dynamic>?),
        if (theirNameOverride != null) 'name': theirNameOverride,
        // Conditional on [gridTouched]/[stateTouched], not just "is the
        // controller non-empty": the controller may just be *displaying* a
        // value populated from `editingQso.theirGrid`/`theirState` on load,
        // which must NOT clobber `their.guess`'s fallback for a call this
        // record hasn't actually been edited for. Once touched, though, write
        // it unconditionally — including empty — so deliberately clearing
        // the field actually clears the stored value instead of leaving the
        // old one from `...?(base['their'])`. Grid input is uppercase-only
        // like every logging control, but the stored value gets the
        // conventional Maidenhead casing back (FN31pr) via normalizeGrid;
        // states are plain uppercase.
        if (gridTouched) 'grid': normalizeGrid(config.gridController.text.trim()),
        if (stateTouched) 'state': config.stateController.text.trim().toUpperCase(),
        ...theirExtra,
        // A typed locator replaces whatever coordinate the record arrived with
        // by its own square's center — a leftover pair outranks the grid
        // everywhere it is read. After [theirExtra], so a pair typed into the
        // More pane still wins, and tested AS a pair: the pane records its two
        // fields apart, and a typed latitude beside a center's longitude is a
        // point nobody stated. `locSource` goes too — app-polo sends it tagging
        // a pair a west-positive centroid, and it would tag this center.
        if (gridTouched && locationFromLatLon(theirExtra['lat'], theirExtra['lon']) == null) ...{
          'lat': locationForStatedGrid(config.gridController.text)?.latitude,
          'lon': locationForStatedGrid(config.gridController.text)?.longitude,
          'locSource': null,
        },
        'call': call,
        'sent': config.rstOrDefault(config.rcvdController.text.trim()),
        // Matches the `AnnotatedCallInfo` TS type (`CallInfo & {guess?:
        // CallInfo, lookups?: CallInfoLookup[]}`, @ham2k/lib-qson-tools) and
        // app-polo's convention: the merged lookup guess stays NESTED under
        // `guess`/`lookups`, never flattened onto `their`'s own fields —
        // readers fall back to `their.guess.x` when `their.x` isn't set.
        if (config.lookup.resultFor(call) case final result?) ...{'guess': result['guess'], 'lookups': result['lookups']},
      },
      'freq': config.radio.freq,
      'band': config.radio.band,
      'mode': config.radio.mode,
      // The field owns the QSO's power whenever power is part of the entry
      // at all ([powerShown]) — which is what keeps a record's own power
      // from being dropped by a save that only corrected its RST. Written
      // unconditionally then, INCLUDING null, exactly as refs/freq/band are
      // above: this map is merged over the record, so an omitted key leaves
      // the stored value standing and a wrong power could never be cleared.
      if (_powerShownIn(config)) 'power': _powerWattsIn(config),
      'startAtMillis': ?startAtMillis,
      ...extra,
      // The same active-overwrite rule as refs/freq/band/power above, and it
      // has to be stated separately because [extra] DROPS an empty note
      // rather than holding one: an entry carrying nothing but a note that
      // was typed and deleted again must not read as composed
      // ([hasComposedValues]). So the key is absent exactly when the note is
      // empty, and this map is merged over the record — leaving a note
      // deleted from a saved contact standing, with the field empty and the
      // save reporting success.
      //
      // Only where there is something to clear, though: `mergeConcurrentEdit`
      // reads what this map writes as an edit, so stamping an empty note on
      // every save would let a contact merely opened and re-saved overwrite
      // one another device added while the editor sat open. An empty string,
      // not null, because that is what a deliberate clear stores everywhere
      // else here — a stamp fills what is ABSENT, and this key is present.
      if (extra.containsKey('notes') || (asQsonString(base['notes']) ?? '').isNotEmpty) 'notes': (extra['notes'] as String?) ?? '',
    };
  }

  /// Pushes a `data` map — a saved record, a suggestion, a parked or wiped
  /// draft — back into the fields and the models. Programmatic by nature,
  /// so the panel runs it under [populate].
  ///
  /// [restoringDraft] says [data] is one of this draft's own records
  /// ([toData]), coming back after a wipe or a detour: those carry
  /// `their.grid`/`their.state` only because the fields were touched, so
  /// their presence restores the flags. A suggestion — a spot, a deep link —
  /// is not: a grid it carries is displayed, never promoted to a touched
  /// value that would stick across a call list.
  void applyData(Map<String, dynamic> data, {bool restoringDraft = false}) {
    final config = this.config();
    final our = asQsonMap(data['our']) ?? const {};
    final their = asQsonMap(data['their']) ?? const {};
    config.callController.text = asQsonString(their['call']) ?? '';
    config.sentController.text = asQsonString(our['sent']) ?? '';
    config.rcvdController.text = asQsonString(their['sent']) ?? '';
    // Only the entered value fills the field; a guess (their.guess) stays a
    // faint placeholder (see the Grid/State decorations) instead of being
    // pre-filled as if it were a confirmed value.
    config.gridController.text = asQsonString(their['grid']) ?? '';
    config.stateController.text = asQsonString(their['state']) ?? '';
    // Restore the name override too, or wipe-then-undo would silently drop a
    // name set via the "More" pane (it round-trips as `their.name`).
    final theirName = asQsonString(their['name'])?.trim();
    theirNameOverride = (theirName == null || theirName.isEmpty) ? null : theirName;
    final freq = asQsonNum(data['freq'])?.toDouble();
    if (freq != null) {
      config.radio.setFrequency(freq);
    } else {
      config.radio.setBand(asQsonString(data['band']));
    }
    config.radio.mode = asQsonString(data['mode']) ?? config.radio.mode;
    final power = asQsonNum(data['power']);
    powerOnRecord = power != null;
    config.radio.powerController.text = power == null ? '' : '$power';
    // A wholesale repopulate — a spot tapped, a QSO opened for editing —
    // replaces every field, so nothing in a dropdown survives it either.
    config.radio.resyncDropdownFields();
    // Restore the More pane's operator/position overrides for the same reason
    // the name above is restored: wipe-then-undo, and stepping into an edit
    // and back out, both round-trip the draft through here, and a dropped
    // override would silently hand the contact back to the operation's stamp.
    //
    // Only for a DRAFT (no `uuid`). A record already in the log carries its
    // own `our` block, which [toData] reads straight from `editingQso` —
    // recording it as an override too would mark an untouched record as
    // composed.
    ourExtra.clear();
    theirExtra.clear();
    if (restoringDraft) {
      // Without this, a wipe undone or a detour returned from shows the grid
      // in the field and logs a record without it: [toData] gates the write
      // on the flag, not on the field.
      gridTouched = their.containsKey('grid');
      stateTouched = their.containsKey('state');
    }
    if ((asQsonString(data['uuid']) ?? '').isEmpty) {
      for (final key in const ['operatorCall', 'multiIdentifier']) {
        if (our.containsKey(key)) ourExtra[key] = asQsonString(our[key]) ?? '';
      }
      // Raw, not coerced: these are a mix of strings and numbers, and
      // `normalizeQsoQson` has already given each one the type its table
      // names. A null is kept as a null — that is a coordinate the pane
      // deliberately cleared, and dropping it would let the old one return.
      for (final key in theirPaneKeys) {
        if (their.containsKey(key)) theirExtra[key] = their[key];
      }
    }
    extra
      ..clear()
      ..addAll(data)
      ..remove('refs')
      ..remove('our')
      ..remove('their')
      ..remove('freq')
      ..remove('band')
      ..remove('mode')
      ..remove('power')
      ..remove('startAtMillis');
    // The Notes control's second view onto `notes`, re-seeded with it. Read
    // back out of the map rather than from `data`, so the two can only ever
    // show the same string.
    config.notesController.text = (extra['notes'] as String?) ?? '';
    config.refs.clear();
    config.exchange.clear();
    final refs = (asQsonList(data['refs']))?.whereType<Map<dynamic, dynamic>>().map((r) => r.cast<String, dynamic>()) ?? const [];
    for (final ref in refs) {
      String? key;
      for (final control in config.refs.controls) {
        final input = control['input'] as Map?;
        if (input?['refType'] != ref['type']) continue;
        // A primary field reads ONE field out of the ref rather than owning the
        // whole ref, and several may share a type — so it never claims the ref,
        // which must still round-trip through a refList control or the
        // unmatched refs. `serial` counts here exactly as `text` does: it is
        // one field of the ref, and skipping it would both leave the number
        // unrestored and `break` before any sibling field of the same ref
        // (cqwpx declares `ourSerial` before `theirSerial`), silently clearing
        // that sibling on the next save.
        if (input?['kind'] == 'text' || input?['kind'] == 'serial' || input?['kind'] == 'options') {
          final field = input?['field'] as String?;
          // Serials are stored as ints (see `_withAllocatedSerial`), exchanges
          // as strings — read either.
          final raw = field == null ? null : ref[field];
          final value = raw is num ? '$raw' : (raw is String ? raw : '');
          // PRESENT, not non-empty: an explicit `field: ''` is the operator
          // having emptied it on purpose (see [ExchangeFieldsModel.refsWithTextValues]), and
          // restoring it as touched-but-blank is what keeps a lookup from
          // helpfully filling it back in the moment the record opens.
          if (field != null && ref.containsKey(field)) {
            final controlKey = control['key'] as String;
            config.exchange.restore(controlKey, value);
          }
          continue;
        }
        key = control['key'] as String?;
        break;
      }
      config.refs.restore(ref, controlKey: key);
    }
  }

  @override
  void dispose() {
    undoSlot.dispose();
    super.dispose();
  }
}

/// Deep, order-insensitive-for-lists equality — used to detect whether the
/// fields being edited still match the stored record. Lists compare as
/// multisets (via sorted JSON) rather than element-by-element, since `refs`
/// is the only list-valued field here and its order is an artifact of how
/// the refs model iterates, not a meaningful edit. A key missing entirely,
/// an empty Map/List/String, and an explicit null all count as equivalent —
/// [QsoDraft.toData] always emits fields like `their.sent`/`mode`/`freq`/
/// `band`/`refs`, even when blank/null/empty, but a record with nothing
/// recorded there yet might simply lack the key, which isn't a meaningful
/// edit either.
bool qsoDataEquivalent(dynamic a, dynamic b) {
  if (_isEmptyish(a) && _isEmptyish(b)) return true;
  if (a is Map || b is Map) {
    final ma = a is Map ? a : const <dynamic, dynamic>{};
    final mb = b is Map ? b : const <dynamic, dynamic>{};
    for (final key in {...ma.keys, ...mb.keys}) {
      if (!qsoDataEquivalent(ma[key], mb[key])) return false;
    }
    return true;
  }
  if (a is List || b is List) {
    final la = a is List ? a : const <dynamic>[];
    final lb = b is List ? b : const <dynamic>[];
    if (la.length != lb.length) return false;
    final sa = la.map(jsonEncode).toList()..sort();
    final sb = lb.map(jsonEncode).toList()..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }
  return a == b;
}

bool _isEmptyish(dynamic v) => v == null || (v is String && v.isEmpty) || (v is Map && v.isEmpty) || (v is List && v.isEmpty);
