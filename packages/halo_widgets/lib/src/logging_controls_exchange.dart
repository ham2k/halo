// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The contest exchange fields: the typed-exchange activity controls (`text`,
// `serial` and `options` inputs) that render as PRIMARY fields, inline after
// Sent/Rcvd. [ExchangeFieldsModel] holds their state on behalf of
// `LoggingControls` — the per-field controllers, focus nodes and layer links,
// the typed values and which of them the operator actually keyed in, the
// `options` suggestion menu's matching and highlight, and the serial numbers
// previewed for `serial` fields (docs/design/contests.md §5.3, §5.8). The
// panel still decides WHICH controls are exchange fields (the operation's
// active ref types gate that), when the draft is cleared, restored or logged,
// and where focus goes next. [ExchangeField] draws one field from the model;
// [ExchangeSuggestionsMenu] draws the floating menu.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:halo_core/halo_core.dart';

import 'keyboard_accessory.dart';
import 'logging_controls_metrics.dart';
import 'option_matching.dart';
import 'panel_model.dart';
import 'ref_text_input.dart';
import 'spacing.dart';
import 'text_formatters.dart';
import 'theme.dart';

/// The `options` suggestion menu's own key — a focused TextField has a
/// follower of its own (selection handles), so this one is named, for tests.
const exchangeSuggestionsKey = ValueKey('exchange.suggestions');

/// What the model reads from the panel's live configuration — re-read on
/// every use rather than copied in, because each of these can change under a
/// mounted panel, and a copy would go stale with nothing to refresh it.
typedef ExchangeFieldsConfig = ({
  /// Every typed-exchange control currently in the entry row, in row order.
  /// The panel resolves this: which controls are exchange fields depends on
  /// the operation's active ref types, which the panel owns. A function, not
  /// a value: resolving it walks the whole log, and a method whose guard
  /// answers first — no sequences, an existing QSO open — must not pay for
  /// it on every keystroke.
  Iterable<Map<String, dynamic>> Function() textControls,
  Qso? editingQso,
  String operationUuid,
  SerialNumberSource? serialNumbers,
  SequencesRepository? sequences,

  /// The call as typed, trimmed and uppercased — what decides whether the
  /// draft has content.
  String call,

  /// Whether the suggestions menu opens BELOW its field rather than above
  /// it — a panel drawn above its QSO list has the information area under
  /// the fields, not over them. The menu keeps its best match against the
  /// field either way, so the arrows trade meanings with it.
  bool menuBelow,
});

/// An open suggestions menu: the focused `options` control and what it
/// offers. Resolved once per panel build, for the menu.
typedef ExchangeMenu = ({Map<String, dynamic> control, List<ExchangeOption> suggestions});

/// The exchange fields' state. See the file comment.
class ExchangeFieldsModel extends ChangeNotifier with PanelModel {
  ExchangeFieldsModel({
    required this.config,
    required this.draftQsoData,
    required this.onPrimaryFieldKeyEvent,
    required this.onFocusChanged,
    required this.onEdited,
  });

  /// The panel's configuration as it stands right now.
  final ExchangeFieldsConfig Function() config;

  /// The draft as the panel would log it right now — what a scoped sequence's
  /// request keys off (the band or mode a per-band serial counts under).
  final Map<String, dynamic> Function() draftQsoData;

  /// The panel's key handler for every main logging field — Tab's walk and
  /// arrow traversal. An exchange field is a main logging field too, so each
  /// of its focus nodes hands over what [_onKeyEvent] declines.
  final KeyEventResult Function(FocusNode node, KeyEvent event) onPrimaryFieldKeyEvent;

  /// Called whenever a field's focus node fires, before the model's own
  /// bookkeeping. The panel's focus ladder notes the node and, on a gain of
  /// focus, places the caret — the same cursor-at-end-on-focus rule the fixed
  /// primary fields get.
  final void Function(FocusNode node, TextEditingController controller) onFocusChanged;

  /// The operator changed a value — typed it, or took a suggestion. The live
  /// score reads the exchange, so the panel re-scores. A lookup's prefill
  /// ([applySuggestedValues]) does not call this: nobody is typing, and the
  /// panel re-scores on what that returns.
  final VoidCallback onEdited;

  /// Values typed into the exchange controls, keyed by control key. Several
  /// controls can share one `refType` while writing different `field`s of it
  /// — they're merged back into one ref per type on save
  /// ([refsWithTextValues]).
  final Map<String, String> _values = {};

  /// Controls the operator has actually typed into. A `suggestedValue` from a
  /// callsign lookup fills a field only while it is untouched, so a lookup
  /// resolving late can never clobber what someone already keyed in
  /// (docs/design/contests.md §5.3).
  final Set<String> _touched = {};

  /// Per control, the value [applySuggestedValues] last wrote and the callsign
  /// it was written for — so that only a value this put there is ever taken
  /// away (a serial preview lands in an untouched field too,
  /// `refreshSerialPreviews`), and only once that callsign has left the field
  /// ([withdrawSuggestionsExcept]).
  final Map<String, ({String value, String call})> _suggestedValues = {};

  /// One controller per control, created on demand and disposed with the
  /// model.
  final Map<String, TextEditingController> _controllers = {};

  /// One focus node per control, so Space and Tab cycle through the exchange
  /// fields the same way they cycle Call → Sent → Rcvd.
  final Map<String, FocusNode> _focus = {};

  /// One per field, so the `options` suggestion menu can be anchored to the
  /// field it belongs to rather than to the panel. Keyed the same way as the
  /// controllers and focus nodes, and just as long-lived.
  final Map<String, LayerLink> _links = {};

  /// Set by Escape and cleared by the next keystroke, a focus change or an
  /// accept: "I've seen the offer, get it out of the way".
  ///
  /// Not a per-value memory on purpose. The operator dismissed THIS offer, and
  /// typing another character is a new question — anything longer-lived would
  /// have them wondering why the menu stopped coming back.
  bool _menuDismissed = false;

  /// Which suggestion the operator has walked to with the arrow keys, or null
  /// while they haven't touched the selection.
  ///
  /// Null is not the same as 0. An untouched selection means Space is still
  /// just "next field" and the accept is a GUESS on the app's part, so it is
  /// held to the prefix rule in [acceptSuggestion]; once the operator has
  /// moved the highlight, or tapped a row, they have chosen, and what they
  /// chose is taken as-is.
  int? _selection;

  /// The serial number each `kind: 'serial'` control will send, as last
  /// peeked from the sequence — shown so the operator can read it off while
  /// typing the callsign, but NOT written to the QSO: the number is allocated
  /// at commit (docs/design/contests.md §5.8), so a peek that goes stale
  /// (another window logged in between) costs nothing.
  final Map<String, int> _serialPreviews = {};

  /// What the previews were last computed against — which sequences exist,
  /// and the band/mode a scoped one keys off. The parent hands down a fresh
  /// controls list on most rebuilds, so without this the peek would re-query
  /// the log every frame.
  String? _serialPreviewSignature;

  /// The sequence labels the previews were last claimed under. A band or mode
  /// change moves a scoped sequence to another label; the label it left is
  /// released, the rest keep their numbers.
  Set<String> _serialPreviewLabels = const {};

  /// The claims still settling, by control key — what a commit waits on.
  final Map<String, Future<int>> _pendingSerialClaims = {};

  // ---- Values ----

  /// The value in [key]'s field, as typed ('' when nothing has been).
  String valueOf(String key) => _values[key] ?? '';

  /// Whether the operator has typed into [key]'s field (or a saved value was
  /// restored into it, which counts the same).
  bool isTouched(String key) => _touched.contains(key);

  /// Whether any exchange field holds a value — part of what makes the draft
  /// worth an undo offer.
  bool get hasTypedValues => _values.values.any((v) => v.trim().isNotEmpty);

  /// The first non-empty value among the controls that write [field] — a
  /// contest's own grid exchange, say — or '' when none does.
  String valueForField(String field) {
    for (final control in config().textControls()) {
      if ((control['input'] as Map?)?['field'] != field) continue;
      final value = valueOf(control['key'] as String).trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// The operator typed [text] into [key]'s field.
  void typed(String key, String text) {
    _values[key] = text;
    // Once typed, a later lookup-derived suggestion must not overwrite it
    // (docs/design/contests.md §5.3).
    _touched.add(key);
    // An exchange typed before the call starts the contact just as a call
    // would, and takes the serial number with it (§5.8.1).
    unawaited(refreshSerialPreviews());
    // A new character is a new question: the offer comes back even if the
    // last one was dismissed, and the highlight starts over at the best match
    // rather than pointing at a row that may no longer be in the list.
    _menuDismissed = false;
    _selection = null;
    notify();
    onEdited();
  }

  /// Puts a value loaded off a saved QSO into [key]'s field. It is what
  /// actually went over the air, so it counts as operator input: without the
  /// touched mark a lookup resolving after the record opens would overwrite
  /// it with a suggestion — or, for a serial, the sequence's NEXT number would
  /// overwrite the one that was really sent.
  void restore(String key, String value) {
    _values[key] = value;
    controllerFor(key).text = value;
    _touched.add(key);
  }

  TextEditingController controllerFor(String key) => _controllers[key] ??= TextEditingController(text: _values[key] ?? '');

  LayerLink linkFor(String key) => _links[key] ??= LayerLink();

  /// A node per exchange field, created on first build, listened to, and
  /// given a key handler for Tab.
  ///
  /// The listener is what makes the `options` suggestion menu appear: the
  /// menu is derived from which field has focus, and focus alone rebuilds
  /// nothing. On a new QSO the panel is repainting anyway (the callsign is
  /// being typed), which masks its absence — but on an existing QSO opened
  /// for editing, tabbing into a searchable exchange would show no offer at
  /// all while Space still rewrote the field.
  FocusNode focusFor(String key) => _focus[key] ??= (FocusNode(debugLabel: 'exchange:$key', onKeyEvent: _onKeyEvent)
    ..addListener(() {
      onFocusChanged(_focus[key]!, controllerFor(key));
      // A dismissal and a highlight both belong to the field that had
      // focus when they were made, so leaving or entering a field clears
      // them.
      _menuDismissed = false;
      _selection = null;
      notify();
    }));

  /// [key]'s focus node, but only once it is attached to a built field —
  /// creating one for a control whose widget hasn't been built leaves an
  /// orphan with no context, which Flutter's focus traversal null-checks
  /// while sorting — taking down the whole frame rather than just
  /// misordering focus.
  FocusNode? attachedFocusFor(String key) {
    final node = _focus[key];
    return node?.context == null ? null : node;
  }

  /// Tab out of an exchange field takes the offer on the way, exactly as
  /// Space does — leaving the field forward is the same statement either way,
  /// and an operator who tabs rather than spaces shouldn't lose the suggestion
  /// for it.
  ///
  /// Shift+Tab is going BACK, so it takes nothing: it isn't leaving the field
  /// behind, it is stepping away from a field the operator may be about to
  /// return to.
  ///
  /// On the node itself rather than as a panel-wide shortcut: binding Tab or
  /// the arrows in `CallbackShortcuts` would take them away from every field
  /// in the panel, secondary controls and caret movement included. This only ADDS the accept and,
  /// while the suggestion menu is showing, the highlight walk — the menu can
  /// only be open while one of these nodes has focus, so this is the one
  /// place its arrows can live — then hands the event to
  /// [onPrimaryFieldKeyEvent]: an exchange is a main logging field, so it
  /// gets the same Tab walk and arrow traversal as the rest, and everything
  /// those decline stays with the ordinary traversal.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;
      final keyboard = HardwareKeyboard.instance;
      // A bare arrow only, as every rung's handler: Shift/Cmd/Ctrl/Alt+arrow
      // are the field's own selection and caret moves and stay its. The key
      // is tested before the menu, which is resolved from the options on
      // every ask — a plain keystroke must not pay for that.
      final bare = !(keyboard.isShiftPressed || keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed);
      if (bare && (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) && menuOpen) {
        // The menu is drawn best-against-the-field, so the arrow pointing
        // away from the field walks down the ranking, which is +1.
        final away = config().menuBelow ? LogicalKeyboardKey.arrowDown : LogicalKeyboardKey.arrowUp;
        moveSelection(key == away ? 1 : -1);
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent && key == LogicalKeyboardKey.tab && !keyboard.isShiftPressed) {
        acceptOnLeave();
      }
    }
    return onPrimaryFieldKeyEvent(node, event);
  }

  /// Empties every field and forgets what was typed. The held serial number
  /// is deliberately NOT released here: an undo-wipe and an edit opening over
  /// the draft pass through this too, and both put the draft back. Only a
  /// wipe and a commit let a number go — the panel does that.
  void clear() {
    _values.clear();
    _touched.clear();
    _suggestedValues.clear();
    // Dropped, not kept: a wipe must let the next refresh re-fill the serial
    // fields, and the change-detection in `refreshSerialPreviews` would
    // otherwise see the same declarations and leave them blank.
    forgetSerialState();
    for (final controller in _controllers.values) {
      controller.clear();
    }
    unawaited(refreshSerialPreviews());
  }

  /// Applies each control's `suggestedValue` — a callsign-lookup-derived
  /// prefill — to fields the operator hasn't touched. Called when the controls
  /// are re-fetched after a lookup resolves, with the one [call] they were
  /// fetched for.
  ///
  /// Only ever writes. Taking a prefill back is [withdrawSuggestionsExcept]'s,
  /// driven by the call field itself: a refresh that fails, or is dropped,
  /// never reaches here, and a prefill left for a callsign that has since
  /// changed is a legal option code in an untouched field, which nothing
  /// tints and `refsWithTextValues` files as the new station's exchange.
  ///
  /// In a comma list or a `//` stack, [call] is the call under the cursor —
  /// the one the lookup ran for. A list logs every call with this one field,
  /// so its prefill goes out for all of them unless the operator changes it.
  ///
  /// Returns whether any field's value changed. The refresh that brings the
  /// suggestion lands after the lookup's own rescore may already have read
  /// the exchange, so a changed value needs scoring again.
  bool applySuggestedValues({required String call}) {
    if (call.isEmpty) return false;
    var changed = false;
    for (final control in config().textControls()) {
      final key = control['key'] as String;
      if (_touched.contains(key)) continue;
      final suggested = (control['input'] as Map)['suggestedValue'] as String? ?? '';
      if (suggested.isEmpty) continue;
      final held = _suggestedValues[key];
      final current = _values[key] ?? '';
      // Not ours to overwrite: either something else wrote it (a serial
      // preview, a value restored off a saved QSO) or it moved without being
      // marked typed. Either way the field wins over a guess.
      if (held == null ? current.isNotEmpty : current != held.value) continue;
      _suggestedValues[key] = (value: suggested, call: call);
      if (suggested == current) continue;
      _values[key] = suggested;
      controllerFor(key).text = suggested;
      changed = true;
    }
    return changed;
  }

  /// Takes back every prefill made for a callsign other than [call] — the
  /// call under the cursor, or empty when there is none.
  ///
  /// Called on every edit of the call field and every caret move in it, so it
  /// holds whether or not the new callsign's refresh ever succeeds:
  /// correcting `W6ABC` to a station the lookup has nothing for, clearing the
  /// field, or moving to another call in a list or stack all leave no
  /// earlier station's exchange behind. A value the operator has
  /// typed over, or anything this did not write, is left alone.
  void withdrawSuggestionsExcept({required String call}) {
    for (final entry in _suggestedValues.entries.toList()) {
      final key = entry.key;
      final held = entry.value;
      if (held.call == call && call.isNotEmpty) continue;
      _suggestedValues.remove(key);
      if (_touched.contains(key) || (_values[key] ?? '') != held.value) continue;
      _values[key] = '';
      controllerFor(key).text = '';
    }
  }

  /// Merges the fields' values into one ref per `refType`, folded in with any
  /// ref of that type already held by a refList control — so a contest's
  /// exchange and its refList-entered references coexist.
  List<Map<String, dynamic>> refsWithTextValues(List<Map<String, dynamic>> refs) {
    final controls = config().textControls();
    if (controls.isEmpty) return refs;

    // Values to write, and — separately — fields to REMOVE. An emptied field
    // has to be an active removal, not just an absent value: skipping it would
    // leave the old exchange on the ref, so clearing one while editing a QSO
    // wouldn't stick. Same reasoning as the unconditional `refs`/`freq` writes
    // in the panel's draft data.
    final byType = <String, Map<String, dynamic>>{};
    final clearedByType = <String, Set<String>>{};
    for (final control in controls) {
      final input = control['input'] as Map;
      final refType = input['refType'] as String?;
      final field = input['field'] as String?;
      if (refType == null || field == null) continue;
      final key = control['key'] as String;
      // A serial's displayed number is NOT a suggestion — it is what the
      // operator read off the screen and sent on the air, so it is written to
      // the ref exactly like something typed. Nobody re-keys it, and the log
      // must agree with what went out. (The sequence is what guarantees the
      // number was theirs to send; see `SequencesRepository`.)
      final value = (_values[key] ?? '').trim();
      if (value.isEmpty) {
        // An empty field means one of two different things, and a contest has
        // to be able to tell them apart: it either was never filled in, or the
        // operator deliberately emptied it. Only the operator touching it
        // distinguishes the two.
        //
        // A DELIBERATE blank is recorded as `field: ''` rather than dropped, so
        // it survives as a decision — `processQsoBeforeSave` stamps a guessed
        // exchange onto an ABSENT field, and would otherwise put back the value
        // the operator just removed (docs/design/contests.md §8).
        //
        // Serials are exempt: the sequence owns the number, "no serial" isn't a
        // thing an operator records, and an empty string on the field would
        // confuse the allocator that reads it at commit.
        if (_touched.contains(key) && input['kind'] != 'serial') {
          (byType[refType] ??= {'type': refType})[field] = '';
        } else {
          (clearedByType[refType] ??= {}).add(field);
        }
      } else {
        // A serial is stored as an int, matching what `_withAllocatedSerial`
        // writes — normalized HERE so the edit path agrees, since
        // `QsosRepository.update` deliberately never allocates and so never
        // passes through that method.
        (byType[refType] ??= {'type': refType})[field] = input['kind'] == 'serial' ? (int.tryParse(value) ?? value) : value;
      }
    }
    if (byType.isEmpty && clearedByType.isEmpty) return refs;

    final merged = <Map<String, dynamic>>[];
    for (final ref in refs) {
      final type = ref['type'];
      final extra = byType.remove(type);
      final cleared = clearedByType[type];
      if (extra == null && cleared == null) {
        merged.add(ref);
        continue;
      }
      final next = {...ref, ...?extra};
      for (final field in cleared ?? const <String>{}) {
        next.remove(field);
      }
      // A ref left with nothing but its type carried no information to begin
      // with — drop it rather than persisting an empty shell.
      if (next.length > 1 || next['ref'] != null) merged.add(next);
    }
    merged.addAll(byType.values);
    return merged;
  }

  // ---- Options ----

  /// The exchange options a `kind: 'options'` control declares, parsed once
  /// per build from the descriptor. Malformed entries are dropped rather than
  /// crashing the entry row — options cross the bridge from third-party code.
  List<ExchangeOption> optionsFor(Map<dynamic, dynamic> control) => [
    for (final raw in ((control['input'] as Map?)?['options'] as List?) ?? const [])
      if (raw is Map) ?ExchangeOption.fromMap(raw.cast<String, dynamic>()),
  ];

  /// The separator a `kind: 'options'` control accepts several values with —
  /// a QSO party's county line, `ORDES/JEF` — or `''` for the single-value
  /// fields every other contest declares.
  String separatorFor(Map<dynamic, dynamic> control) {
    final separator = ((control['input'] as Map?)?['multiValue'] as Map?)?['separator'];
    return separator is String ? separator : '';
  }

  /// How many of the first value's characters a later one may borrow — the
  /// multi-state QSO parties' county-line shorthand, 0 everywhere else.
  int inheritPrefixFor(Map<dynamic, dynamic> control) {
    final value = ((control['input'] as Map?)?['multiValue'] as Map?)?['inheritPrefix'];
    return value is int ? value : 0;
  }

  /// What the operator is typing RIGHT NOW in [control] — the whole field for
  /// a single-value one, and the value the cursor is in for a multi-value one.
  ///
  /// The cursor comes from the controller rather than being tracked in state,
  /// so the SPACE handler and the accept read it at the moment they act and
  /// cannot disagree about which county the operator is in.
  ///
  /// The suggestion LINE is repainted by the ordinary rebuilds — a keystroke,
  /// a focus change — and nothing listens to the caret on its own, so moving
  /// it back into an earlier value leaves the offers showing for the value
  /// just left until the next keystroke. Accepting one is still correct,
  /// because the accept recomputes; the alternative is a listener that
  /// rebuilds the whole panel on every caret move, mid-QSO, for a line the
  /// operator is not reading.
  String _typedValue(Map<dynamic, dynamic> control) {
    final key = control['key'] as String;
    final text = _values[key] ?? '';
    final separator = separatorFor(control);
    if (separator.isEmpty) return text;
    final controller = controllerFor(key);
    final cursor = controller.selection.baseOffset;
    return exchangeValueAt(text, cursor < 0 ? text.length : cursor, separator);
  }

  /// What the value being typed might be SHORT for, where a control lets a
  /// later value borrow the first one's prefix — `JEF` after `ORDES/` may mean
  /// `ORJEF`. Null when there is no such reading.
  ///
  /// Offered ALONGSIDE the literal reading, never instead of it: the
  /// suggestion line searches for what was typed first and falls back to this
  /// only when that finds nothing, so typing a code out in full suggests as it
  /// always did.
  String? _inheritedValue(Map<dynamic, dynamic> control) {
    final inherit = inheritPrefixFor(control);
    final separator = separatorFor(control);
    if (inherit <= 0 || separator.isEmpty) return null;
    final key = control['key'] as String;
    final text = _values[key] ?? '';
    final typed = _typedValue(control);
    final values = splitExchangeValues(text, separator);
    if (values.length < 2 || typed.isEmpty || values.first == typed) return null;
    return inheritedCandidate(values.first, typed, inherit);
  }

  /// The fields a match is judged on. The offer and the accept ask this same
  /// question, so they read one answer: a menu that offered rows Space
  /// refused, or the reverse, would follow from two.
  Set<String> _matchOnFor(Map<dynamic, dynamic> input) {
    final matchOn = {
      for (final m in (input['matchOn'] as List?) ?? const ['code', 'name'])
        if (m is String) m,
    };
    return matchOn.isEmpty ? const {'code', 'name'} : matchOn;
  }

  /// The `kind: 'options'` control that currently has focus, if any.
  ///
  /// Read straight from the focus map rather than tracked in state: the
  /// suggestion line and the SPACE handler then compute from the same inputs
  /// at the same moment, so neither can act on a stale copy of the other's
  /// idea of what the operator is looking at. The node is read without
  /// creating one, so this never conjures one for a field that hasn't built.
  Map<String, dynamic>? get focusedOptionsControl {
    for (final control in config().textControls()) {
      if ((control['input'] as Map?)?['kind'] != 'options') continue;
      if (_focus[control['key']]?.hasFocus == true) return control;
    }
    return null;
  }

  /// Suggestions for the focused options field, best first — empty when no
  /// options field has focus, the set is empty, it declares a
  /// `minCharsForSuggestions` the operator hasn't reached, or the offer was
  /// dismissed with Escape.
  ///
  /// Cheap by construction: the set is inline in the descriptor (§5.3's
  /// `optionSet` was deferred for want of a consumer big enough to need it),
  /// so this is a list scan and not a query.
  List<ExchangeOption> get suggestions {
    final control = focusedOptionsControl;
    return control == null ? const [] : _suggestionsFor(control);
  }

  /// [suggestions] and the control they belong to, or null while no menu is
  /// open.
  ExchangeMenu? get openMenu {
    final control = focusedOptionsControl;
    if (control == null) return null;
    final suggestions = _suggestionsFor(control);
    return suggestions.isEmpty ? null : (control: control, suggestions: suggestions);
  }

  List<ExchangeOption> _suggestionsFor(Map<String, dynamic> control) {
    if (_menuDismissed) return const [];
    final input = control['input'] as Map;
    final options = optionsFor(control);
    if (options.isEmpty) return const [];

    final typed = _typedValue(control);
    final minChars = input['minCharsForSuggestions'];
    if (minChars is int && typed.trim().length < minChars) return const [];

    final on = _matchOnFor(input);
    final preferred = [
      for (final c in (input['preferredCodes'] as List?) ?? const [])
        if (c is String) c,
    ];
    return matchExchangeOptionsInheriting(typed, _inheritedValue(control), options, matchOn: on, preferred: preferred);
  }

  /// Whether the suggestion menu is showing — what arms the arrow keys and
  /// gives Escape its first meaning.
  bool get menuOpen => suggestions.isNotEmpty;

  /// Index into [suggestions] of the highlighted row.
  int highlightedIndex(int length) => length == 0 ? 0 : (_selection ?? 0).clamp(0, length - 1);

  void moveSelection(int delta) {
    final current = suggestions;
    if (current.isEmpty) return;
    final index = highlightedIndex(current.length);
    final next = (index + delta).clamp(0, current.length - 1);
    // An arrow that CANNOT move the highlight is not a choice. The menu is
    // drawn best-at-the-bottom, so ↓ from an untouched selection is already at
    // the end of the list (as is either arrow on a one-row menu): nothing
    // moves on screen. Arming "the operator chose this" on a keystroke with no
    // visible effect would let the next Space rewrite what they typed with a
    // match the prefix rule exists to refuse: type `SH`, press ↓, press Space,
    // and the field reads `ASD`, a county nobody worked.
    if (next == index && _selection == null) return;
    _selection = next;
    notify();
  }

  /// Escape: the offer is seen and declined, highlight and all.
  void dismissMenu() {
    _menuDismissed = true;
    _selection = null;
    notify();
  }

  /// Leaving the field forward — Space, Tab — takes the offer on the way.
  /// Having walked the highlight with the arrow keys IS a choice, so that row
  /// is taken as-is; an untouched highlight is still the app guessing, and
  /// stays held to the prefix rule.
  bool acceptOnLeave() => acceptSuggestion(explicit: _selection != null);

  /// Enter with a highlight the operator walked to: a PENDING CHOICE, taken
  /// instead of logging. False when there is no such choice, and Enter is just
  /// Enter.
  bool acceptPendingChoice() => _selection != null && acceptSuggestion(explicit: true);

  /// Writes a suggestion into the focused options field, as though it had
  /// been typed. Returns false when there was nothing to accept.
  ///
  /// [index] names the row (a tap); otherwise the highlighted one. [explicit]
  /// marks a choice the operator made — a tap, or Space after arrowing —
  /// which skips the prefix guard that keeps a plain Space from swapping in a
  /// substring match.
  ///
  /// Two traps this has to cover. A controller write does NOT fire
  /// `onChanged`, so the value and the touched set are updated by hand — the
  /// same trap the numbers row documents. And on mobile the space arrives
  /// through `VirtualSpaceFormatter`, which rejects the edit and schedules
  /// this in a microtask, so it must be safe to run when the field already
  /// holds the value: accepting the same code twice is a no-op rather than a
  /// second write.
  bool acceptSuggestion({int? index, bool explicit = false}) {
    final control = focusedOptionsControl;
    if (control == null) return false;
    final current = suggestions;
    if (current.isEmpty) return false;

    final key = control['key'] as String;
    final typed = _typedValue(control);
    final chosen = current[(index ?? highlightedIndex(current.length)).clamp(0, current.length - 1)];

    if (!explicit) {
      // Nothing typed, nothing to accept. An empty field's suggestion list is
      // the whole SET (`matchExchangeOptions` answers an empty query with
      // everything in declaration order), so without this, Space in an empty
      // exchange field — which is just how an operator skips past one they
      // haven't been given yet — logs whichever park happens to be declared
      // first.
      if (typed.trim().isEmpty) return false;
      // And only a suggestion the typed text is the START of: accepting a
      // substring hit replaces what they typed with something it isn't a
      // prefix of. See `isAcceptableExchangeMatch`.
      final on = _matchOnFor(control['input'] as Map);
      // The typed text, or what it may be short for: the suggestion line
      // offers `ORJEF` for a typed `JEF` (a borrowed county-line prefix), and
      // testing only the literal text would refuse every one of those — a
      // menu showing a row Space can never take.
      final inherited = _inheritedValue(control);
      final acceptable =
          isAcceptableExchangeMatch(typed, chosen, matchOn: on) || (inherited != null && isAcceptableExchangeMatch(inherited, chosen, matchOn: on));
      if (!acceptable) return false;
    }

    if (typed == chosen.code) return false;

    // A multi-value field keeps the values the operator has already entered:
    // only the one the cursor is in is replaced, and the cursor lands at the
    // end of it so typing the separator carries straight on to the next.
    final separator = separatorFor(control);
    final controller = controllerFor(key);
    if (separator.isEmpty) {
      _values[key] = chosen.code;
      controller.text = chosen.code;
    } else {
      final text = _values[key] ?? '';
      final cursor = controller.selection.baseOffset;
      final replaced = replaceExchangeValueAt(text, cursor < 0 ? text.length : cursor, separator, chosen.code);
      _values[key] = replaced.text;
      controller.value = TextEditingValue(
        text: replaced.text,
        selection: TextSelection.collapsed(offset: replaced.cursor),
      );
    }
    _touched.add(key);
    // The menu closes on the accepted value, so the highlight it belonged to
    // goes with it.
    _selection = null;
    notify();
    onEdited();
    return true;
  }

  // ---- Serial numbers ----

  SequenceDescriptor? serialDescriptorFor(Map<String, dynamic> control) {
    final key = control['key'] as String? ?? '';
    final slash = key.indexOf('/');
    return SequenceDescriptor.fromInput(
      (control['input'] as Map).cast<String, dynamic>(),
      // Control keys are `<extensionKey>/<name>` by convention; the prefix is
      // what keeps two contests' counters apart.
      extensionKey: slash > 0 ? key.substring(0, slash) : key,
    );
  }

  /// The sequences this operation's contests declared, resolved from the
  /// current controls. Passed to `add` so the repository can allocate against
  /// the QSO as committed — and so a number the operator was shown raises the
  /// counter past itself rather than being handed out twice.
  List<SequenceDescriptor> get serialSequences => [for (final control in config().textControls()) ?serialDescriptorFor(control)];

  /// [refs] with every declared serial field removed, so the sequence issues
  /// a fresh number at commit instead of the one already on the ref. Only for
  /// the second and later calls of a call list.
  List<Map<String, dynamic>> refsWithoutSerials(Object? refs) {
    final descriptors = serialSequences;
    final list = [
      for (final ref in (refs as List?) ?? const [])
        if (ref is Map) ref.cast<String, dynamic>(),
    ];
    if (descriptors.isEmpty) return list;
    return [
      for (final ref in list) {...ref}..removeWhere((field, _) => descriptors.any((d) => d.refType == ref['type'] && d.field == field)),
    ];
  }

  /// Refreshes the previewed next number for each serial control — one query
  /// per sequence, and only when the declarations or their scope changed.
  ///
  /// Never while editing an existing QSO. That record's number was sent long
  /// ago and is restored from the ref by the panel; the sequence's *next*
  /// number has nothing to do with it. Filling it here would overwrite a
  /// logged serial on a record that merely had its RST corrected, or invent
  /// one for a QSO that never carried a contest ref at all.
  ///
  /// Nor before the operator has put anything into the draft. A number is
  /// held against the other positions from the moment it is shown
  /// (docs/design/contests.md §5.8.1), so an idle panel holds nothing and
  /// shows nothing — a blank, never a tentative number that might move. The
  /// first edit — a typed call, a tapped spot, an exchange field touched —
  /// is what takes the number; a band or mode change from the radio is not
  /// an edit, and only moves a claim already held to its new label.
  Future<void> refreshSerialPreviews() async {
    final config = this.config();
    final sequences = config.sequences;
    if (sequences == null || config.editingQso != null) return;

    final descriptors = <String, SequenceDescriptor>{};
    for (final control in config.textControls()) {
      final descriptor = serialDescriptorFor(control);
      if (descriptor != null) descriptors[control['key'] as String] = descriptor;
    }
    if (descriptors.isEmpty) return;

    final hasContent = config.call.trim().isNotEmpty || _touched.isNotEmpty;
    if (!hasContent) {
      // Nothing composed — never started, or backspaced to nothing. An idle
      // panel holds nothing, so a number taken earlier goes back, and off the
      // screen with it.
      if (_serialPreviews.isEmpty && _serialPreviewLabels.isEmpty) return;
      forgetSerialState();
      config.serialNumbers?.release(config.operationUuid);
      for (final key in descriptors.keys) {
        if (_touched.contains(key)) continue;
        _values.remove(key);
        controllerFor(key).clear();
      }
      notify();
      return;
    }

    final qso = Qso(uuid: '', operationUuid: config.operationUuid, data: draftQsoData());
    final requests = {for (final entry in descriptors.entries) entry.key: entry.value.requestFor(qso)};
    final labels = {for (final request in requests.values) request.label};
    final signature = '${descriptors.keys.join(',')}|${labels.join(',')}';
    if (signature == _serialPreviewSignature && _serialPreviews.isNotEmpty) return;
    _serialPreviewSignature = signature;

    final source = config.serialNumbers ?? LocalSerialNumberSource(sequences);
    // A scoped sequence keys off the band or mode: a label the draft has moved
    // off is let go — and only that one. An unscoped sequence beside it keeps
    // the number the operator may already have read.
    final moved = _serialPreviewLabels.difference(labels);
    if (moved.isNotEmpty) source.release(config.operationUuid, labels: moved);
    _serialPreviewLabels = labels;

    var changed = false;
    for (final entry in requests.entries) {
      // Read again past each await: a claim made after the operation moved
      // under the panel must not be held under the one that was released.
      final pending = source.claim(this.config().operationUuid, entry.value);
      _pendingSerialClaims[entry.key] = pending;
      final next = await pending;
      // A wipe or a scope change while the claim was settling: that answer is
      // for a draft that no longer exists, and the refresh it triggered fills
      // the field for the current one.
      if (isDisposed || _serialPreviewSignature != signature) return;
      if (_serialPreviews[entry.key] == next) continue;
      _serialPreviews[entry.key] = next;
      changed = true;
      // The preview fills the field itself so the number is readable at a
      // glance, but the control stays untouched — only a number the operator
      // actually edits overrides the commit-time allocation.
      if (!_touched.contains(entry.key)) {
        _values[entry.key] = '$next';
        controllerFor(entry.key).text = '$next';
      }
    }
    if (changed) notify();
  }

  /// Forgets the previews and the claims behind them without touching the
  /// fields, so the next [refreshSerialPreviews] starts from nothing. Never
  /// releases anything: whether the held number goes back is the caller's
  /// question — a wipe lets it go, an undo-wipe or an edit opening keeps it,
  /// and a source swapped under the panel has already been released by the
  /// panel.
  void forgetSerialState() {
    _serialPreviews.clear();
    _serialPreviewSignature = null;
    _serialPreviewLabels = const {};
    _pendingSerialClaims.clear();
  }

  /// Waits for every serial claim still settling, so a commit never runs
  /// ahead of the number it is about to write. Needing the number is what
  /// settles it (docs/design/contests.md §5.8.1); the wait is bounded by the
  /// source's own cap. False when a claim failed and the commit must not go
  /// ahead.
  Future<bool> settleSerialClaims() async {
    final pending = _pendingSerialClaims.values.toList();
    if (pending.isEmpty) return true;
    try {
      await Future.wait(pending);
      return true;
    } on Exception {
      // Already reported by the refresh that owns the claim (it awaits the
      // same future unguarded). Here it means the number never settled, and
      // a commit without it would be allocated blind to the peers — refused,
      // like a locked form: the fields keep everything typed.
      return false;
    }
  }

  /// [data] with the duplicate-serial mark set wherever the number on a ref
  /// is one another position is known to have shown too
  /// (docs/design/contests.md §5.8.1). The number is written regardless —
  /// it went on the air — and the record says so.
  Map<String, dynamic> withSerialConflicts(Map<String, dynamic> data) {
    final config = this.config();
    final source = config.serialNumbers;
    if (source == null) return data;
    final qso = Qso(uuid: '', operationUuid: config.operationUuid, data: data);
    for (final descriptor in serialSequences) {
      final request = descriptor.requestFor(qso);
      final number = request.serialOn(qso);
      if (number != null && source.isConflicted(config.operationUuid, request, number)) {
        return {...data, Qso.serialConflictKey: true};
      }
    }
    return data;
  }

  /// Tells the number source the committed QSO's numbers are now in the log,
  /// so its hold on them ends without handing them out again meanwhile.
  void releaseCommittedSerials(Qso qso) {
    final config = this.config();
    final source = config.serialNumbers;
    if (source == null) return;
    final committed = <SequenceRequest, int>{};
    for (final descriptor in serialSequences) {
      final request = descriptor.requestFor(qso);
      final number = request.serialOn(qso);
      if (number != null) committed[request] = number;
    }
    source.release(config.operationUuid, committed: committed);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }
}

/// One exchange control rendered as a primary entry field — a contest
/// exchange, sitting inline with Call and the RSTs.
///
/// A `pattern` mismatch tints the field but never blocks the keystroke:
/// contest rules don't always anticipate what the other station actually
/// sends, and refusing input mid-QSO is worse than accepting an oddity.
class ExchangeField extends StatelessWidget {
  const ExchangeField({
    super.key,
    required this.model,
    required this.control,
    required this.enabled,
    required this.width,
    required this.padding,
    required this.duration,
    required this.virtualSpace,
    required this.numericKeyboardType,
    required this.onSubmitted,
  });

  final ExchangeFieldsModel model;

  /// The control's descriptor, as the extension declared it.
  final Map<String, dynamic> control;

  final bool enabled;

  /// Resolved by [resolveMainFieldLayout] — [exchangeFieldMinWidth] when the
  /// row has room, and less when it doesn't.
  final double width;
  final double padding;
  final Duration duration;

  /// The panel's on-screen-keyboard Space formatter, installed FIRST exactly
  /// as every other primary field installs it: on an on-screen keyboard there
  /// is no hardware Space to hit the panel shortcut, so without this the space
  /// is just swallowed by the formatters after it and the field becomes a
  /// dead end. Mobile is where most contest logging happens.
  final TextInputFormatter virtualSpace;

  /// The keyboard a numeric field (a serial, or `numeric: true`) asks for;
  /// null keeps the platform default.
  final TextInputType? numericKeyboardType;

  /// Enter — the panel's own handler, which picks a highlighted suggestion
  /// before it logs.
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final key = control['key'] as String;
    final input = control['input'] as Map;
    // The row squeezes this field well below its own label's width, so which
    // label it shows is a function of the width it was resolved to.
    final label = mainFieldLabel(
      context,
      label: (control['label'] as String?) ?? key,
      shortLabel: control['shortLabel'] as String?,
      width: width,
      horizontalPadding: padding,
    );
    final value = model.valueOf(key).trim();

    // A serial is digits, never uppercased. The number shown is the one the
    // sequence will issue; typing over it is an override, which the extension
    // can disallow with `editable: false`.
    final isSerial = input['kind'] == 'serial';
    final numeric = input['numeric'] == true || isSerial;
    // Both halves of a serial exchange step on a period or comma: the number
    // we send, and the one received (`theirSerial` is the SDK's name for it).
    // Only while it is digits-only — nrrl-nfd's received field also takes a
    // locator, whose letters a step would throw away.
    final steps = numeric && (isSerial || input['field'] == 'theirSerial');

    final regex = compileRefPattern(input['pattern'] as String?);
    var isInvalid = value.isNotEmpty && regex != null && !regex.hasMatch(value);

    // An `options` field validates against its SET as well as any pattern: a
    // county that isn't in the party's list is a lost multiplier, and the
    // operator can still fix it while the QSO is in front of them. A contest
    // whose exchange is genuinely open-ended says `allowFreeform: true`.
    final isOptions = input['kind'] == 'options';
    final options = isOptions ? model.optionsFor(control) : const <ExchangeOption>[];
    if (isOptions && value.isNotEmpty && input['allowFreeform'] != true && options.isNotEmpty) {
      // Every value, not just the last one: a county line whose second county
      // is a typo claims a multiplier that isn't there, and the field is the
      // only place that can say so while the QSO is still in front of the
      // operator.
      isInvalid = isInvalid || !areKnownExchangeOptions(value, options, separator: model.separatorFor(control), inheritPrefix: model.inheritPrefixFor(control));
    }
    final uppercase = !isSerial && input['uppercase'] != false;
    final transforms = [for (final t in (input['transforms'] as List?) ?? const []) RefTransform.fromMap((t as Map).cast<String, dynamic>())];

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      // Wider than an RST, narrower than the callsign: an exchange is usually
      // a zone, a serial or a state abbreviation.
      width: width,
      // Linked so the `options` suggestion menu can hang off this field's own
      // corner — right-aligned to the field, wherever the row happens to put
      // it (RSTs on or off, a state field, several exchanges).
      child: CompositedTransformTarget(
        link: model.linkFor(key),
        child: NumbersRowExtraKey(
          extraKey: NumbersRowExtraKey.declared(input['numbersRowKey']),
          child: TextField(
            controller: model.controllerFor(key),
            focusNode: model.focusFor(key),
            selectAllOnFocus: false,
            enabled: enabled,
            readOnly: isSerial && input['editable'] == false,
            style: mainFieldStyle(context, fontWeight: FontWeight.w500),
            keyboardType: numeric ? numericKeyboardType : null,
            textCapitalization: TextCapitalization.characters,
            // Codes, not prose — the same four refusals as every other main
            // field. `autocorrect: false` alone leaves Android's suggestion
            // strip over a county field and lets iOS turn a typed `-` into a
            // dash the formatters below never undo.
            autocorrect: false,
            enableSuggestions: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            inputFormatters: [
              // FIRST — see [virtualSpace].
              virtualSpace,
              // Ahead of the digits filter, which would drop the keystroke.
              if (steps) const SerialStepFormatter(),
              if (numeric) FilteringTextInputFormatter.digitsOnly,
              if (uppercase) const UpperCaseTextFormatter(),
              if (transforms.isNotEmpty) RefTransformFormatter(transforms),
              if (input['maxLength'] is int) LengthLimitingTextInputFormatter(input['maxLength'] as int),
            ],
            // An unrecognized value tints the field's own underline rather than
            // going through `errorText` — see [haloInvalidInputBorder] for why
            // the error slot is not an option in this row.
            decoration: mainFieldDecoration(context, label, horizontalPadding: padding).copyWith(
              hintText: input['placeholder'] as String?,
              enabledBorder: isInvalid ? haloInvalidInputBorder(context, width: 1) : null,
              focusedBorder: isInvalid ? haloInvalidInputBorder(context, width: 2) : null,
            ),
            onChanged: (text) => model.typed(key, text),
            onEditingComplete: () => finishEditingWithoutBlur(model.controllerFor(key)),
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
      ),
    );
  }
}

/// The `options` suggestion menu: a floating column of the focused exchange
/// field's matches, values on the right and names off to the left where there
/// is room for them. Hung off the field itself through a [LayerLink], so that
/// holds wherever the row puts the field: RSTs on or off, a state field, two
/// exchanges side by side.
///
/// Ordered BOTTOM-UP: the best match is the row nearest the field, and it is
/// the row Space takes. Rows are tappable and the arrow keys walk the
/// highlight ([ExchangeFieldsModel.moveSelection]); all three go through
/// [ExchangeFieldsModel.acceptSuggestion], so a tap, an arrow-then-Space and
/// a plain Space are one path.
///
/// Both columns are sized from the widest value measured in BOLD, so the menu
/// keeps its shape as the highlight moves — a menu that resized under the
/// arrow keys would jump under the operator's hands.
///
/// Colours are the dialog scheme, not the panel's: this is a surface floating
/// over the panel rather than part of it, so it reads like every other thing
/// the app puts on top — `surface` for the rows, the dialog band tone for the
/// value column, and a plain onSurface wash for the highlighted row.
///
/// Floating, not laid out, so nothing moves as the operator types: it paints
/// over the info area above rather than pushing the fields down under the
/// cursor. It is inside the panel's own subtree — not an `Overlay` — so it
/// rebuilds with the panel and needs no entry to insert, update or dispose.
/// Built as a [Positioned], so it sits directly in the panel's [Stack].
///
/// COVERING the info area while it is open — the DUPE warning and the rest of
/// the scoring notices with it — is a SETTLED decision rather than an
/// oversight: it is the price of not pushing the fields down under the
/// operator's hands mid-exchange, and polo made the opposite trade. It is not
/// a defect, however much it looks like one from the info area's side.
class ExchangeSuggestionsMenu extends StatelessWidget {
  const ExchangeSuggestionsMenu({super.key, required this.model, required this.menu, required this.theme});

  final ExchangeFieldsModel model;

  /// [ExchangeFieldsModel.openMenu], resolved once by the panel's build for
  /// this menu.
  final ExchangeMenu menu;

  /// The panel's accent theme — the menu's colours come from it, not from the
  /// ambient one.
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final (:control, :suggestions) = menu;
    final colors = theme.colorScheme;
    final selected = model.highlightedIndex(suggestions.length);

    // Monospace for the codes: they are log data, read as a column and compared
    // character by character against what is in the field — the same reason the
    // QSO list and the spots panel set callsigns in it.
    // Weights are explicit on both variants: the regular one has to SAY it is
    // regular, or a row inherits whatever weight the ambient text theme brought
    // and the highlight stops being the only difference between rows.
    final codeStyle = haloMonoStyle(context, color: colors.onSurface, fontWeight: FontWeight.w400);
    final boldCode = codeStyle.copyWith(fontWeight: FontWeight.w700);
    final nameStyle = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(color: colors.onSurface, fontWeight: FontWeight.w400);
    final boldName = nameStyle.copyWith(fontWeight: FontWeight.w700);

    // Measured in BOLD even for the rows that aren't: the highlight moves with
    // the arrow keys, and a column sized to the regular weight would have to
    // grow the moment its row became the selected one.
    var codeText = 0.0;
    var nameText = 0.0;
    for (final option in suggestions) {
      codeText = math.max(codeText, textWidth(context, option.code, boldCode));
      nameText = math.max(nameText, textWidth(context, option.name ?? option.code, boldName));
    }
    const namePadding = 10.0;
    const codePadding = 8.0;
    // A long name is ellipsized rather than allowed to push the menu off the
    // side of a narrow window; the code column, which is the point, is never cut.
    final nameWidth = math.min(nameText, 220.0) + namePadding * 2;
    final codeWidth = codeText + codePadding * 2;

    Widget row(int index, ExchangeOption option) {
      final isSelected = index == selected;
      return InkWell(
        // The field keeps focus: this is a value picker, not somewhere to land.
        // Without this, tapping a row moves focus out of the exchange field and
        // the menu it belongs to closes under the operator's finger.
        canRequestFocus: false,
        onTap: () => model.acceptSuggestion(index: index, explicit: true),
        child: DecoratedBox(
          // In FRONT, so the wash covers the value column too and the whole row
          // reads as one selected thing.
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(color: isSelected ? colors.onSurface.withValues(alpha: 0.10) : Colors.transparent),
          child: Row(
            children: [
              SizedBox(
                width: nameWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: namePadding, vertical: Space.xs),
                  child: Text(option.name ?? option.code, maxLines: 1, overflow: TextOverflow.ellipsis, style: isSelected ? boldName : nameStyle),
                ),
              ),
              Container(
                width: codeWidth,
                color: haloDialogBandColor(context),
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                alignment: Alignment.center,
                child: Text(option.code, maxLines: 1, style: isSelected ? boldCode : codeStyle),
              ),
            ],
          ),
        ),
      );
    }

    final below = model.config().menuBelow;
    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        key: exchangeSuggestionsKey,
        link: model.linkFor(control['key'] as String),
        // The menu's bottom-LEFT corner against the field's top-left (or its
        // top-left against the field's bottom-left, [below]), then shifted left
        // by exactly the name column: that puts the code column's left edge on
        // the field's own left edge.
        targetAnchor: below ? Alignment.bottomLeft : Alignment.topLeft,
        followerAnchor: below ? Alignment.topLeft : Alignment.bottomLeft,
        offset: Offset(-nameWidth, below ? 6 : -6),
        child: Material(
          // A menu, so it casts a shadow over what it covers rather than looking
          // like part of the panel underneath.
          elevation: 8,
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Best against the field: reversed above it, worst at the top.
              for (final entry in below ? suggestions.indexed.toList() : suggestions.indexed.toList().reversed) row(entry.$1, entry.$2),
            ],
          ),
        ),
      ),
    );
  }
}
