// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'activities_view.dart';

mixin _ActivitiesRefs on State<OperationSheet> {
  abstract Operation _operation;
  List<Map<String, dynamic>> get _controls;
  abstract ControlsLoadState _controlsState;
  bool get _showResultsMap;
  ActivitySearchState get _searchState;
  Future<void> _loadControls();
  void _reloadControlsIfRefsChanged(Operation before, Operation after);
  void _researchIfLocationChanged(Operation before, Operation after);

  static const _flashDuration = Duration(milliseconds: 900);

  /// The Current Activities row currently flashing (see [_flashExistingRef]),
  /// as `type/ref`; null when nothing is. [_flashToken] only exists to make
  /// each flash a distinct animation.
  String? _flashingRefRowId;
  int _flashToken = 0;
  Timer? _flashTimer;
  final Map<String, GlobalKey> _refRowKeys = {};

  bool _isDuplicateRef(String type, String code) => _operation.refs.any((ref) => ref['type'] == type && ref['ref'] == code);

  void _saveOperationData(Map<String, dynamic> patch) {
    final data = {..._operation.data, ...patch};
    // On the draft rather than at save, so the nearby search recentres on the
    // park just added while the sheet is still open — and [saveAndClose]
    // tells the repository not to decide it again.
    locationFollowsRefs(_operation.data, data);
    final updated = Operation(
      uuid: _operation.uuid,
      data: data,
      qsoCount: _operation.qsoCount,
      startAtMillisMin: _operation.startAtMillisMin,
      startAtMillisMax: _operation.startAtMillisMax,
      localData: _operation.localData,
    );
    if (mounted) {
      final before = _operation;
      setState(() => _operation = updated);
      widget.onOperationChanged?.call(updated);
      _reloadControlsIfRefsChanged(before, updated);
      // The other path that replaces `_operation` — a location placed by the
      // refs comes through here, not through [updateOperation].
      _researchIfLocationChanged(before, updated);
    }
  }

  void _saveRefs(List<Map<String, dynamic>> refs) => _saveOperationData({'refs': refs});

  /// Opens an `input.kind == 'form'` control's setup form (a contest's
  /// identifier, sent exchange, mode…), pre-filled from [existing] if this ref
  /// is already on the operation. Returns the ref to save, or null if the
  /// operator cancelled.
  ///
  /// The form's values live directly on the ref, so they persist through the
  /// same `_saveRefs` path every other activity ref uses — no separate
  /// operation write-path is involved.
  Future<Map<String, dynamic>?> _runSetupForm(Map<String, dynamic> control, {Map<String, dynamic>? existing}) async {
    final input = (control['input'] as Map?) ?? const {};
    final refType = input['refType'] as String?;
    final form = (input['form'] as Map?)?.cast<String, dynamic>();
    if (refType == null || form == null) return null;

    // Seed from the ref itself: every field key is a key on the ref.
    final initialState = <String, dynamic>{
      for (final entry in (existing ?? const <String, dynamic>{}).entries)
        if (entry.key != 'type') entry.key: entry.value,
    };

    final result = await showFormDialog(context, formDefinition: form, initialState: initialState, developerMode: widget.services.settings.developerMode);
    if (result == null || !mounted) return null;

    return refWithFormResult(existing, result, refType: refType);
  }

  /// Only reachable for a ref type that declares `editable` (see
  /// [refTypeIsEditable]).
  Future<void> _editRef(Map<String, dynamic> ref) async {
    final t = context.t.activitiesView;

    // A form-configured activity (a contest) edits through its own setup form
    // rather than the single reference-code field below — it has no code.
    final formControl = controlForRef(_controls, type: ref['type'] as String?, code: refCodeOf(ref));
    if ((formControl?['input'] as Map?)?['kind'] == 'form') {
      final updated = await _runSetupForm(formControl!, existing: ref);
      if (updated == null || !mounted) return;
      final decorated = await widget.services.extensions.decorateRef(updated);
      if (!mounted) return;
      // Read the refs AFTER every await, never across one — see
      // [_configureNewRef], which reaches the same place by the other path.
      // The dialog is gone while `decorateRef` runs to its hook timeout, so a
      // list captured earlier silently undoes whatever the operator did in
      // between.
      final refs = _operation.refs;
      final index = refs.indexWhere((r) => r['type'] == ref['type'] && r['ref'] == ref['ref']);
      if (index < 0) return;
      _saveRefs([...refs]..[index] = decorated);
      return;
    }

    final code = await editOneFieldDialog(
      context,
      title: t.editActivity,
      fieldLabel: t.reference,
      fieldInitial: (ref['ref'] as String?) ?? '',
      fieldCapitalization: TextCapitalization.characters,
      saveLabel: context.t.common.save,
    );
    if (code == null || !mounted) return;

    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return;

    final type = ref['type'] as String?;

    final refs = _operation.refs;
    final index = refs.indexWhere((r) => r['type'] == ref['type'] && r['ref'] == ref['ref']);
    if (index < 0) return;

    // The ref being edited is not its own duplicate.
    if (refs.indexWhere((r) => r['type'] == type && r['ref'] == trimmed) case final existing when existing >= 0 && existing != index) {
      widget.services.statusBar.setMessage(key: 'activities:duplicate', text: t.duplicateReference);
      return;
    }

    final decorated = await widget.services.extensions.decorateRef({...ref, 'ref': trimmed});
    _saveRefs([...refs]..[index] = decorated);
  }

  Future<void> _deleteRef(Map<String, dynamic> ref) async {
    final refs = _operation.refs.where((r) => !(r['type'] == ref['type'] && r['ref'] == ref['ref'])).toList();
    _saveRefs(refs);
    widget.services.track('activity_removed', {'activity': ref['type']});
    if (!mounted) return;
    // Removing an activity is often a mistake to undo, so surface it back as
    // a suggestion — but only until the next search resolves (or this view
    // closes), rather than sticking around as stale state.
    _searchState.reoffer(ref);
  }

  /// The operation's refs minus the ones a new ref of [type] displaces (see
  /// [refsKeptWhenAdding]), reading the type's multiplicity off the
  /// suggestion being added or, for a hand-typed ref, its control descriptor.
  List<Map<String, dynamic>> _refsKeeping(String? type, {Map<String, dynamic>? suggestion}) => refsKeptWhenAdding(
    refs: _operation.refs,
    type: type,
    allowsMultiple: allowsMultipleRefsOfType(type, suggestion: suggestion, control: controlForRefType(_controls, type)),
  );

  Future<void> _addSuggestion(Map<String, dynamic> suggestion) async {
    final type = suggestion['type'] as String?;
    final code = suggestion['ref'] as String?;
    if (type != null && code != null && _isDuplicateRef(type, code)) {
      await _flashExistingRef(type, code);
      return;
    }
    _saveRefs([..._refsKeeping(type, suggestion: suggestion), suggestion]);
    widget.services.track('activity_added', {'activity': type});

    // SAVE FIRST, then configure — the opposite order from [_addFormActivity],
    // and deliberately so. That path runs the form as the act of adding, with
    // nothing on the operation until it is submitted; here the tap on a
    // suggestion IS the add, so backing out of the form leaves the activity in
    // place, unconfigured. A tap that can end with nothing added reads as a tap
    // that didn't work.
    await _configureNewRef(suggestion);
  }

  /// Opens a freshly-added ref's setup form, for a type that has one.
  ///
  /// A contest added from the search is unusable until its exchange is set, and
  /// nothing on the row says so — the operator has to know it is tappable. Only
  /// form-configured types prompt: a reference type's suggestion already
  /// carries the code that identifies it, so the only thing an editor could ask
  /// is that they retype what they just picked.
  Future<void> _configureNewRef(Map<String, dynamic> ref) async {
    // Descriptors FIRST, and freshly: a form is allowed to depend on the refs
    // the operation carries (see [_reloadControlsIfRefsChanged]), and the ref
    // this is about to configure was saved a moment ago. State Parks asks Ohio
    // for its park, power class and entry category only once its own ref is on
    // the operation — read before the reload lands, its descriptor offers the
    // event select alone and the operator saves a setup missing everything the
    // scorer and the Cabrillo export need.
    //
    // This also settles the cold-boot case: `_controls` starts empty while
    // suggestion rows are already tappable, and an absent control is
    // indistinguishable from a type that has no form.
    await _loadControls();
    if (!mounted) return;

    final control = controlForRef(_controls, type: ref['type'] as String?, code: refCodeOf(ref));
    // Which of the two absences this is, is now answerable, and they call for
    // opposite things. A type with no form is done here; a form that could
    // not be FETCHED leaves the operator with an unconfigured contest, a row
    // that renders non-editable because `refTypeIsEditable(null)` is false,
    // and — silently — no way back to the setup they were about to be shown.
    if (control == null && _controlsState == ControlsLoadState.failed) {
      widget.services.statusBar.setMessage(key: 'activities:setup-unavailable', text: context.t.activitiesView.setupUnavailable);
      return;
    }
    if (!refTypeIsForm(control)) return;

    final updated = await _runSetupForm(control!, existing: ref);
    if (!mounted) return;
    // Decorate even on a CANCEL — that is the whole point of decorating here.
    // A suggestion is persisted verbatim, and its `name` describes the event
    // for the search list it was written for ("the ARRL's June operating
    // event"). Left at that, a contest the operator backed out of reads like a
    // configured activity. Running the hook over the ref as it stands lets the
    // extension say what is actually true of it — that it is not set up.
    final decorated = await widget.services.extensions.decorateRef(updated ?? ref);
    if (!mounted) return;
    // Read the refs AFTER every await, never across one. The dialog is gone by
    // now and the sheet is live, while `decorateRef` can run to its 10s hook
    // timeout — a list captured earlier and written here silently undoes an
    // activity the operator added or deleted in between. Identity, not a
    // remembered index, for the same reason.
    final refs = _operation.refs;
    final index = refs.indexWhere((r) => r['type'] == ref['type'] && r['ref'] == ref['ref']);
    if (index < 0) return;
    _saveRefs([...refs]..[index] = decorated);
  }

  /// Adds a form-configured activity by running its setup form. One per
  /// operation: a second CQ WW ref would be meaningless, unlike a second park,
  /// so tapping an already-added contest edits it instead.
  Future<void> _addFormActivity(Map<String, dynamic> control) async {
    final refType = ((control['input'] as Map?) ?? const {})['refType'] as String?;
    if (refType == null) return;

    final existing = _operation.refs.where((r) => r['type'] == refType).firstOrNull;
    if (existing != null) {
      await _editRef(existing);
      return;
    }

    final ref = await _runSetupForm(control);
    if (ref == null) return;
    final decorated = await widget.services.extensions.decorateRef(ref);
    _saveRefs([..._operation.refs, decorated]);
    widget.services.track('activity_added', {'activity': refType});
  }

  String _refRowId(String? type, String? code) => '$type/$code';

  /// Points at the ref the user just tried to add again. Rather than telling
  /// them it's a duplicate, we show them: the Current Activities row for it
  /// is scrolled into view and flashes once, which also answers the question
  /// behind the mistake ("is this one already on the list?").
  Future<void> _flashExistingRef(String type, String code) async {
    final id = _refRowId(type, code);
    setState(() {
      _flashingRefRowId = id;
      _flashToken++;
    });
    _flashTimer?.cancel();

    // The row may have only just been built (this can be the first frame it
    // exists on), so wait for it to be laid out before asking the list to
    // bring it into view.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _flashingRefRowId != id) return;
    final rowContext = _refRowKeys[_refRowKeyId(id)]?.currentContext;
    if (rowContext != null && rowContext.mounted) {
      await Scrollable.ensureVisible(rowContext, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut, alignment: 0.5);
    }
    if (!mounted) return;
    _flashTimer = Timer(_flashDuration, () {
      if (mounted && _flashingRefRowId == id) setState(() => _flashingRefRowId = null);
    });
  }

  /// A row's GlobalKey is scoped to the mode that built it: the list and the
  /// map put the Current Activities rows under different parents, and one
  /// GlobalKey spanning both migrates its elements — and their semantics
  /// nodes — to the new parent while the old parent is torn down in the same
  /// frame. Flutter's semantics update can't express that pairing (the child
  /// is re-parented, the old parent never dropped), and the web engine
  /// rejects the whole update with "Semantics node map was inconsistent".
  /// Nothing needs the key across a toggle — [_flashExistingRef] only ever
  /// looks up a row in the mode currently on screen.
  String _refRowKeyId(String id) => '${_showResultsMap ? 'map' : 'list'}/$id';

  /// Tags a Current Activities row so [_flashExistingRef] can find it, and
  /// paints the fading highlight over it while it's the flashing one.
  Widget _flashableRow(Map<String, dynamic> ref, Widget row) {
    final id = _refRowId(ref['type'] as String?, ref['ref'] as String?);
    final rowKey = _refRowKeys.putIfAbsent(_refRowKeyId(id), () => GlobalKey());
    if (id != _flashingRefRowId) return KeyedSubtree(key: rowKey, child: row);
    return KeyedSubtree(
      key: rowKey,
      child: TweenAnimationBuilder<double>(
        // Re-keyed per flash so selecting the same duplicate twice replays
        // the animation instead of sitting at its finished value.
        key: ValueKey(_flashToken),
        tween: Tween(begin: 1, end: 0),
        duration: _flashDuration,
        curve: Curves.easeOut,
        builder: (context, value, child) => Stack(
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  // onSurfaceAccent: a flash has to be a change the eye
                  // catches, which means lightening a dark row rather than
                  // washing it with the near-invisible dark teal primary is.
                  color: HaLoColors.of(context).onSurfaceAccent.withValues(alpha: 0.35 * value),
                ),
              ),
            ),
          ],
        ),
        child: row,
      ),
    );
  }

  /// Persists [_operation], refreshing `data['title']` from a FRESH
  /// suggestion first — the sheet's own live-preview title (driven by
  /// OperationView's `_draftTitleFragments`) never lands in `_operation`
  /// itself, only in the header's ephemeral preview, so without this an
  /// explicit save could commit a stale generated title for refs edited
  /// just now. Left untouched when the extension runtime isn't up
  /// (suggestFragments returns null) — same "degrade silently" rule as
  /// OperationTitleService's own live retitles, so a host hiccup at save
  /// time doesn't wipe out a previously generated title.
  ///
  /// The save itself must run regardless of `mounted` — this widget can be
  /// disposed while `suggestFragments` is still awaiting the extension host
  /// (up to its own 10s-per-ref timeout), and skipping the write in that case
  /// would silently drop the whole edit (refs, notes, callsign, everything),
  /// not just the title. Uses the module-level `t`, not `context.t`, so the
  /// title can still be assembled after unmount; only the navigation pop is
  /// gated on `mounted`.
  Future<void> saveAndClose() async {
    final fragments = await widget.services.operationTitles.suggestFragments(_operation);
    final data = fragments == null ? _operation.data : {..._operation.data, 'title': buildGeneratedTitle(t, fragments)};
    await widget.services.operations.saveData(
      Operation(
        uuid: _operation.uuid,
        data: data,
        qsoCount: _operation.qsoCount,
        startAtMillisMin: _operation.startAtMillisMin,
        startAtMillisMax: _operation.startAtMillisMax,
        localData: _operation.localData,
      ),
      // Every refs edit already ran the rule on the draft. Run again against
      // the stored row, it would put back a location the operator cleared on
      // the Location screen after adding the park.
      followRefs: false,
    );
    if (mounted) Navigator.of(context).pop();
  }
}
