// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The activity references on the QSO being composed: the refs entered
// through `refList` controls (a park, a summit), the ones a saved QSO carries
// that no control claims, and the ones a callsign lookup guessed — plus the
// activity controls themselves, as re-fetched for the QSO in progress once
// its lookup resolves. [ActivityRefsModel] holds that state on behalf of
// `LoggingControls`; [activityControlSpec] draws a refList control's chip
// and its expanded field from it. The panel still decides which controls are
// PRIMARY fields (its `_textControls`, gated on the operation's active ref
// types), and when the draft is cleared, restored or logged.

import 'package:flutter/material.dart';

import 'package:halo_core/halo_core.dart';

import 'icon_resolver.dart';
import 'logging_controls_draft.dart';
import 'panel_model.dart';
import 'ref_text_input.dart';
import 'secondary_control_row.dart';

/// What the model reads from the panel's live configuration — re-read on
/// every use rather than copied in, because each of these can change under a
/// mounted panel, and a copy would go stale with nothing to refresh it.
typedef ActivityRefsConfig = ({
  /// The operation-level activity controls, as the app handed them over.
  List<Map<String, dynamic>> activityControls,

  /// Re-fetches the controls scoped to the QSO in progress; null when the
  /// app offers no per-QSO refresh.
  Future<List<Map<String, dynamic>>?> Function(Map<String, dynamic> qso)? refreshActivityControls,
  Qso? editingQso,

  /// Whether the form refuses writes right now — a staged delete, a deleted
  /// QSO, a write refusal. A function: the panel derives it.
  bool Function() fieldsLocked,

  /// The call the operator is on right now, for a refresh that resumes after
  /// the field moved on. A function: reading it parses the field.
  String Function() callAtCursor,
});

/// Which refs a lookup guessed, and for which call. Parked alongside a
/// parked draft — see [ActivityRefsModel.takeGuessSnapshot].
typedef GuessProvenance = ({String? forCall, List<Map<String, dynamic>> guessed});

/// The activity refs' state. See the file comment.
class ActivityRefsModel extends ChangeNotifier with PanelModel {
  ActivityRefsModel({
    required this.config,
    required this.draft,
    required this.draftQsoData,
    required this.onControlsRefreshed,
  });

  /// The panel's configuration as it stands right now.
  final ActivityRefsConfig Function() config;

  /// The draft the panel composes — read for [QsoDraft.isPopulating]: a
  /// guess must not land on a draft mid-population.
  final QsoDraft draft;

  /// The draft as the panel would log it for [call] — what the per-QSO
  /// refresh is asked against.
  final Map<String, dynamic> Function(String call) draftQsoData;

  /// Called once a per-QSO refresh has installed its controls, before the
  /// panel repaints: the panel's other models react to the new descriptors
  /// (a suggested exchange value, a serial field that just appeared).
  final VoidCallback onControlsRefreshed;

  /// The operation-level controls, re-fetched for the current QSO once its
  /// callsign lookup resolves — see [refreshControlsFor]. Reset to null
  /// (falling back to the operation's own) whenever the call field is
  /// cleared, so a stale QSO-scoped placeholder/transform doesn't linger
  /// onto the next entry.
  List<Map<String, dynamic>>? _refreshedControls;

  /// Bumped whenever the operation's controls or refs change
  /// ([controlsChanged]) — a per-QSO refresh in flight from BEFORE that
  /// change captures the generation it started against, and drops its own
  /// result on return if the generation has since moved on. A callsign
  /// lookup that started before a ref was added and resolves after must not
  /// overwrite the fresh operation-level controls with its own stale
  /// snapshot.
  int _generation = 0;

  /// Issued to each [refreshControlsFor] as it starts, in order; a result may
  /// apply only if no LATER-issued one has been applied already.
  ///
  /// A callsign is refreshed twice — once off the offline lookup, again off the
  /// online one — and the two are unawaited with no ordering between them. The
  /// later one knows more (the online pass is where a caller's STATE comes
  /// from), so it has to win however the two finish: without this, a slow
  /// offline refresh returning after a fast online one overwrites the fresher
  /// controls with a snapshot taken before the state was known. It is the
  /// APPLIED one that is compared, not the latest issued: an offline refresh
  /// that lands first is still applied, so an online one that then fails
  /// leaves the offline answer in place rather than nothing at all.
  int _refreshTicket = 0;
  int _appliedTicket = 0;

  /// Refs entered via activity controls for the QSO being composed, keyed by
  /// control key.
  final Map<String, List<Map<String, dynamic>>> _controlRefs = {};

  /// Refs from a saved QSO whose `type` matched no currently registered
  /// activity control — round-tripped back into `refs` on save rather than
  /// silently dropped, even though no UI can show them.
  List<Map<String, dynamic>> _unmatched = const [];

  /// References put on the QSO by a lookup guess rather than by the
  /// operator, and the callsign they were resolved for.
  ///
  /// A guessed ref answers "where is THIS station right now", so it must not
  /// outlive the call that was asked about: correcting KI2D to KI2E would
  /// otherwise log the second station at the first one's park. Only refs
  /// this model actually inserted are tracked, and [clearGuessedRefs]
  /// removes them BY IDENTITY — an operator-typed ref that happens to equal
  /// one of these is not ours to take back. One exception follows from the
  /// field keeping the maps it is handed: a code the guess supplied, deleted
  /// from the field and typed back in, comes back as the guess's own map, and
  /// goes with the guess — it was the old call's park either way.
  String? _guessedFor;
  List<Map<String, dynamic>> _guessed = const [];

  /// One focus node per refList control, owned here rather than inside
  /// [RefTextInput] so expanding the control can move the cursor into it —
  /// the field itself is rebuilt on every expand, the node outlives it.
  final Map<String, FocusNode> _focus = {};

  /// One text controller per refList control, same reasoning as [_focus] —
  /// owned here so cursor-key field-hopping can read the caret position
  /// without reaching into [RefTextInput]'s own State.
  final Map<String, TextEditingController> _controllers = {};

  // ---- Controls ----

  /// The activity controls in force: the per-QSO refresh's answer while one
  /// stands, else the operation's own.
  List<Map<String, dynamic>> get controls => _refreshedControls ?? config().activityControls;

  /// Whether [key] names a refList control — the one kind that builds a
  /// field to focus, the same condition that gives it a chip.
  bool isRefListControl(String key) =>
      controls.any((c) => c['key'] == key && (c['input'] as Map?)?['kind'] == 'refList');

  /// The activity control that would own a ref of [type] — the refList
  /// control whose `refType` matches. Primary fields (`text`/`serial`/
  /// `options`) read one field out of a ref rather than owning it and
  /// several may share a type, so they never claim one; a ref they match
  /// still has to reach a refList control or fall through to the unmatched
  /// refs (the same rule the panel follows when loading a saved QSO).
  String? refListControlKeyForType(String type) {
    for (final control in controls) {
      final input = control['input'] as Map?;
      if (input?['refType'] != type) continue;
      final kind = input?['kind'];
      if (kind == 'text' || kind == 'serial' || kind == 'options') continue;
      return control['key'] as String?;
    }
    return null;
  }

  /// The controls in force start over: the operation's controls or refs
  /// changed under the panel, or the call field was cleared. A per-QSO
  /// refresh can have cached a snapshot from BEFORE the change — [controls]
  /// prefers that cache — so without this a contest's exchange field would
  /// stay invisible for the rest of the composing session even after the
  /// operation-level change landed, until something else (a wipe, an edit
  /// ending) happened to clear it; and a stale QSO-scoped placeholder or
  /// transform would linger onto the next entry. The generation bump
  /// additionally catches a refresh that was ALREADY IN FLIGHT when this
  /// happened.
  void controlsChanged() {
    _refreshedControls = null;
    _generation++;
  }

  /// Re-fetches the activity controls for [activeCall]'s QSO, discarding the
  /// result if the active call moved on (or the panel was disposed) while
  /// awaiting — the same staleness guard the lookup itself uses.
  Future<void> refreshControlsFor(String activeCall) async {
    final refresh = config().refreshActivityControls;
    if (refresh == null) return;
    final requestGeneration = _generation;
    final ticket = ++_refreshTicket;
    final fetched = await refresh(draftQsoData(activeCall));
    if (isDisposed || config().callAtCursor() != activeCall) return;
    // A later-issued refresh has already been applied — see [_refreshTicket].
    if (ticket < _appliedTicket) return;
    // The operation's own activity/ref set changed while this was in
    // flight — that fetch was issued against the OLD set, and applying it
    // now would silently reshadow the fresh operation-level controls the
    // panel already installed (see [controlsChanged]).
    if (requestGeneration != _generation) return;
    // Null is "the fetch failed", so the panel keeps the controls it is
    // already showing rather than blanking the QSO in progress.
    if (fetched == null) return;
    _appliedTicket = ticket;
    _refreshedControls = fetched;
    onControlsRefreshed();
    notify();
  }

  // ---- Refs ----

  /// The refs [key]'s control holds.
  List<Map<String, dynamic>> refsFor(String key) => _controlRefs[key] ?? const [];

  /// Every ref on the draft: the controls' own, then the unmatched ones.
  List<Map<String, dynamic>> get allRefs => [
        for (final list in _controlRefs.values) ...list,
        ..._unmatched,
      ];

  /// Whether the draft carries any ref at all — part of what makes it worth
  /// an undo offer.
  bool get hasRefs => _controlRefs.values.any((refs) => refs.isNotEmpty) || _unmatched.isNotEmpty;

  /// The operator edited [key]'s field: [refs] replaces what it held.
  void setRefs(String key, List<Map<String, dynamic>> refs) {
    _controlRefs[key] = refs;
    notify();
  }

  /// A ref restored off a saved QSO: onto [controlKey]'s control, or among
  /// the unmatched refs when no control claims it.
  void restore(Map<String, dynamic> ref, {required String? controlKey}) {
    if (controlKey != null) {
      // Replaced, never mutated in place — see [applyGuessRefs].
      _controlRefs[controlKey] = [...?_controlRefs[controlKey], ref];
    } else {
      _unmatched = [..._unmatched, ref];
    }
  }

  /// Forgets every ref and every guess — the draft is gone, or a saved QSO is
  /// about to be loaded over it.
  void clear() {
    _controlRefs.clear();
    _guessed = const [];
    _guessedFor = null;
    _unmatched = const [];
  }

  /// Applies references a `lookup` hook proposed for this call — the park or
  /// summit `spot-history` mined out of a recent spot — onto the QSO being
  /// composed. Returns whether anything actually landed.
  ///
  /// A proposed ref is only ever ADDED, never allowed to replace a ref whose
  /// type the QSO already carries: the operator's own entry outranks a
  /// guess, and re-proposing an existing type on every pass is exactly what
  /// would make the ref-change re-lookup cycle forever.
  ///
  /// Skipped entirely while editing a saved QSO — refs describe where the
  /// station is *now*, which says nothing about where it was when a contact
  /// already in the log was made.
  bool applyGuessRefs(Map<String, dynamic>? result, String forCall) {
    final config = this.config();
    if (config.editingQso != null || config.fieldsLocked() || draft.isPopulating) return false;
    final guess = result?['guess'];
    if (guess is! Map) return false;
    final proposed = asQsonList(guess['refs'])?.whereType<Map<dynamic, dynamic>>().map((r) => r.cast<String, dynamic>()) ?? const [];
    if (proposed.isEmpty) return false;

    final claimedTypes = <Object?>{
      for (final list in _controlRefs.values)
        for (final ref in list) ref['type'],
      for (final ref in _unmatched) ref['type'],
    };
    final added = <String, List<Map<String, dynamic>>>{};
    final addedUnmatched = <Map<String, dynamic>>[];
    // Given once per call: a guess the operator deleted from the field frees
    // its type, and the re-lookup that deletion triggers proposes the same
    // park again — which would put it straight back into the field they
    // just emptied.
    bool alreadyGiven(Map<String, dynamic> ref) =>
        _guessedFor == forCall && _guessed.any((g) => g['type'] == ref['type'] && g['ref'] == ref['ref']);
    for (final ref in proposed) {
      final type = ref['type'];
      if (type is! String || type.isEmpty || ref['ref'] == null) continue;
      if (alreadyGiven(ref)) continue;
      if (!claimedTypes.add(type)) continue;
      final key = refListControlKeyForType(type);
      if (key != null) {
        (added[key] ??= []).add(ref);
      } else {
        addedUnmatched.add(ref);
      }
    }
    if (added.isEmpty && addedUnmatched.isEmpty) return false;

    // Replaced, never mutated in place: the field holding this list resyncs
    // only when it is handed a DIFFERENT list, so an in-place add would show
    // "✓ POTA" on the chip over a field still reading blank.
    added.forEach((key, refs) => _controlRefs[key] = [...?_controlRefs[key], ...refs]);
    // Rebuilt as well — and it must be: the unmatched list starts life as a
    // const literal, which cannot be added to.
    if (addedUnmatched.isNotEmpty) _unmatched = [..._unmatched, ...addedUnmatched];
    // Remembered so they can be taken back when the call changes — see
    // [_guessed]. Appended, not replaced: the offline pass and the online
    // pass both contribute for the same call.
    _guessedFor = forCall;
    _guessed = [
      ..._guessed,
      for (final refs in added.values) ...refs,
      ...addedUnmatched,
    ];
    notify();
    return true;
  }

  /// The call field changed: a guess made for a call no longer in the field
  /// is taken back. Keyed on the whole field, NOT on the call at the cursor:
  /// adding a second call to a stack moves the cursor off the first without
  /// correcting it, and a reference one stacked call earned is kept for the
  /// whole stack (refs are shared across the stack anyway — two operators at
  /// one park is exactly the case that produces a stack in the first place).
  void takeBackGuessUnlessIn(Iterable<String> callsInField) {
    final forCall = _guessedFor;
    if (forCall == null || callsInField.contains(forCall)) return;
    if (clearGuessedRefs()) notify();
  }

  /// Removes every ref a previous call's guess contributed, leaving the
  /// operator's own untouched. Returns whether anything was removed.
  bool clearGuessedRefs() {
    _guessedFor = null;
    if (_guessed.isEmpty) return false;
    final stale = _guessed;
    _guessed = const [];
    bool isStale(Map<String, dynamic> ref) => stale.any((s) => identical(s, ref));

    // [list] without the stale refs, or null when it held none — a list
    // nothing left is left alone, so the field holding it is not resynced.
    // Replaced, never mutated in place — see [applyGuessRefs]: a take-back
    // the field did not notice would keep showing the park, and the next
    // keystroke there would put it back on the QSO.
    List<Map<String, dynamic>>? without(List<Map<String, dynamic>> list) =>
        list.any(isStale) ? [for (final ref in list) if (!isStale(ref)) ref] : null;

    var removed = false;
    for (final key in _controlRefs.keys) {
      final kept = without(_controlRefs[key]!);
      if (kept == null) continue;
      _controlRefs[key] = kept;
      removed = true;
    }
    if (without(_unmatched) case final kept?) {
      _unmatched = kept;
      removed = true;
    }
    return removed;
  }

  /// Which refs a lookup put here, and for which call — the provenance a
  /// draft's own data cannot carry, because [toData] writes refs and not
  /// where they came from.
  ///
  /// Taken where the draft itself is parked (a wipe, a detour through an
  /// earlier contact) and handed back to [restoreGuesses] with it. Without
  /// the pair, a restored guess is indistinguishable from a ref the operator
  /// typed, and the next correction to the callsign leaves the old call's
  /// park on the contact.
  /// Copied, not aliased: the caller holds this across the [clear] that
  /// follows, and a snapshot sharing the model's own list would be one
  /// in-place append away from following it.
  GuessProvenance takeGuessSnapshot() => (forCall: _guessedFor, guessed: List.of(_guessed));

  /// Re-marks the refs a [takeGuessSnapshot] remembered, after a restore has
  /// put them back.
  ///
  /// The restore rebuilds every ref from plain data, so the maps now in the
  /// field are NEW instances and the identity [clearGuessedRefs] takes them
  /// back by would match nothing. Each remembered guess is therefore
  /// re-pointed at the live map carrying the same `(type, ref)`.
  ///
  /// A guess with no live match is one the operator deleted before the
  /// restore, and it stays in the list as its own map: `alreadyGiven`
  /// compares by value, so the re-lookup still declines to propose it a
  /// second time and the deletion sticks, while the identity take-back
  /// matches nothing and so removes nothing.
  void restoreGuesses(GuessProvenance snapshot) {
    _guessedFor = snapshot.forCall;
    _guessed = [
      for (final guess in snapshot.guessed) _liveRefMatching(guess) ?? guess,
    ];
  }

  /// The ref currently in the field carrying the same `(type, ref)` as
  /// [guess], if any — identity, not equality, is what the caller needs.
  Map<String, dynamic>? _liveRefMatching(Map<String, dynamic> guess) {
    bool matches(Map<String, dynamic> ref) => ref['type'] == guess['type'] && ref['ref'] == guess['ref'];
    for (final list in _controlRefs.values) {
      for (final ref in list) {
        if (matches(ref)) return ref;
      }
    }
    for (final ref in _unmatched) {
      if (matches(ref)) return ref;
    }
    return null;
  }

  // ---- Fields ----

  FocusNode focusFor(String key) => _focus[key] ??= FocusNode(debugLabel: 'ref:$key');

  TextEditingController controllerFor(String key) => _controllers[key] ??= TextEditingController();

  @override
  void dispose() {
    for (final node in _focus.values) {
      node.dispose();
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// A refList activity control's chip and its expanded field, read from
/// [model]. [onRefsChanged] runs after an edit lands on the model — the
/// panel re-runs the lookup, so a park or summit ref added after the call
/// reaches the guess (POTA/SOTA lookup hooks key off the QSO's refs).
SecondaryControlSpec activityControlSpec(
  ActivityRefsModel model,
  Map<String, dynamic> control, {
  required VoidCallback onRefsChanged,
  required RefDecorator? decorate,
}) {
  final key = control['key'] as String;
  final refs = model.refsFor(key);
  final refCount = refs.length;
  final label = (control['label'] as String?) ?? key;
  return SecondaryControlSpec(
    key: key,
    icon: resolveIconName(control['icon'] as String?),
    // A check per reference marks a park-and-summit-style "twofer"; beyond
    // two, a single check plus the count keeps the label from running long
    // (e.g. a 5-park POTA rove would otherwise be "✓✓✓✓✓ POTA"). The plain
    // check mark (U+2713) has no emoji presentation, so it always renders
    // in the label's own text color instead of a fixed emoji color.
    summary: switch (refCount) {
      0 => label,
      1 => '✓ $label',
      2 => '✓✓ $label',
      _ => '✓×$refCount $label',
    },
    // Accent the icon (issue #187) only once the field actually holds a
    // reference — an active-but-empty control stays the default color.
    iconColor: refCount > 0 ? resolveExtensionColor(control['color'] as String?) : null,
    // A reference the pattern rejects is KEPT, so the chip counts it and reads
    // "✓ POTA" like any other — and the field's own tint is gone the moment
    // the control is shut, which is how it spends most of a QSO and all of
    // the instant the contact is logged. So the chip carries the mark too, in
    // the error pair the Radio chip wears with no band to log on and for the
    // same reason: what is wrong is only cheap to fix while the station is
    // still there. It outranks the extension's accent, which has no
    // guaranteed contrast against the error fill.
    alert: anyRefFailsPattern(refs, (control['input'] as Map?)?['pattern'] as String?),
    expandedBuilder: (context) => SizedBox(
      width: 160,
      child: RefTextInput(
        focusNode: model.focusFor(key),
        controller: model.controllerFor(key),
        refType: (control['input'] as Map)['refType'] as String,
        label: (control['label'] as String?) ?? '',
        placeholder: (control['input'] as Map)['placeholder'] as String?,
        pattern: (control['input'] as Map)['pattern'] as String?,
        transforms: [
          for (final t in ((control['input'] as Map)['transforms'] as List?) ?? const [])
            RefTransform.fromMap((t as Map).cast<String, dynamic>()),
        ],
        // Not the `refs` captured above for the chip: that one is spec-time,
        // and the row can build an expanded field from an earlier spec. A
        // snapshot would hand the field refs it has since moved past — which
        // it answers with a controller write in the middle of a build.
        refs: model.refsFor(key),
        onChanged: (refs) {
          model.setRefs(key, refs);
          onRefsChanged();
        },
        decorate: decorate,
        labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
      ),
    ),
  );
}
