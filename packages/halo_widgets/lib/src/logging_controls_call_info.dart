// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The call-info: what a resolved lookup does to the entry, what the info
// area shows in place of it or beside it, and what the host hears about the
// call and the draft. Its own file for size alone; it is part of the panel's
// library and reaches its state directly.

part of 'logging_controls.dart';

extension _CallInfo on _LoggingControlsState {
  /// A per-QSO refresh just installed its controls: any `suggestedValue` a
  /// lookup produced can now fill fields the operator hasn't typed into, and
  /// the refreshed controls may have introduced a serial field, or changed
  /// the band a per-band sequence keys off.
  void _onActivityControlsRefreshed() {
    if (_exchange.applySuggestedValues(call: _callAtCursor)) _lookup.exchangePrefilled();
    unawaited(_exchange.refreshSerialPreviews());
  }

  /// Alphanumeric length of the call about to be logged — the call-info panel
  /// and its live scoring switch on at ≥3 characters (issue #40).
  int get _callInfoAlnumLength => _callAtCursor.replaceAll(RegExp('[^A-Z0-9]'), '').length;
  bool get _callInfoActive => _callInfoAlnumLength >= 3;

  /// Schedules the lookup for the call at the cursor, first taking back the
  /// references a previous call's guess put on the entry.
  ///
  /// A guessed ref belongs to the call it was resolved for, and is taken
  /// back once the field no longer holds that call — including mid-edit,
  /// with what's left not yet a valid callsign. Waiting for a replacement
  /// lookup would leave it standing through the intervening keystrokes, and
  /// a lookup that resolves nothing would never clear it at all. Correcting
  /// KI2D to KI2E must not log KI2E at KI2D's park.
  ///
  /// Keyed on the whole field, NOT on the call at the cursor: adding a
  /// second call to a stack moves the cursor off the first without
  /// correcting it, and a reference one stacked call earned is kept for the
  /// whole stack (refs are shared across the stack anyway — two operators
  /// at one park is exactly the case that produces a stack in the first
  /// place).
  void _scheduleLookup() {
    _refs.takeBackGuessUnlessIn(_callsInField);
    _lookup.scheduleLookup();
  }

  /// What a resolved lookup does to the entry, per pass.
  ///
  /// Spot-derived refs land off the OFFLINE pass deliberately without a
  /// re-lookup: the online pass rebuilds its `qso` argument from scratch, so
  /// the POTA/SOTA hooks see the just-added park/summit on that pass and
  /// resolve its grid — a re-lookup here would instead race the online pass
  /// already in flight. Anything the online pass proposes that the offline
  /// one didn't (a spot fetched in between) has had no chance to reach the
  /// activity hooks, so that one does re-look-up. It cannot cycle: the refs
  /// it just applied are filtered out as already-claimed on the next pass,
  /// which then applies nothing and re-triggers nothing.
  ///
  /// QSO-scoped activity controls are refreshed off BOTH passes. The offline
  /// pass resolves the DXCC entity (POTA's prefix placeholder needs only
  /// that), but a caller's STATE arrives only with the online pass — and a
  /// QSO party's suggestion is the state: refreshed off the offline pass alone,
  /// the field stays blank until the call is retyped and hits the cache. The
  /// two refreshes are unawaited with no ordering between
  /// them; [ActivityRefsModel]'s refresh ticket makes the later-issued one win
  /// however they finish, so a slow offline refresh cannot overwrite a fast
  /// online one. A cache hit refreshes too: typing back to a call reaches the
  /// lookup only through the cache, and its guessed refs were just cleared.
  void _onLookupResolved(String call, Map<String, dynamic>? result, LookupPhase phase) {
    switch (phase) {
      case LookupPhase.cached:
      case LookupPhase.offline:
        _refs.applyGuessRefs(result, call);
        unawaited(_refs.refreshControlsFor(call));
      case LookupPhase.online:
        if (_refs.applyGuessRefs(result, call)) _relookupForRefsChanged();
        unawaited(_refs.refreshControlsFor(call));
    }
  }

  /// [CallLookupModel.relookupForRefsChanged], gated on this panel not being
  /// in the middle of writing the fields itself.
  void _relookupForRefsChanged() {
    if (_draft.isPopulating) return;
    _lookup.relookupForRefsChanged();
  }

  /// The lookup `guess` for the call about to be logged. Prefers a live lookup
  /// result; when editing an existing QSO, uses the guess saved on the QSO at
  /// log time (`their.guess`) so its call-info shows without refetching — and
  /// while a fresh lookup for that same call is in flight (e.g. re-focusing the
  /// field), the saved fields fill any gaps the partial live result hasn't
  /// filled yet, so the panel updates in place instead of flashing to blank and
  /// back. The saved guess is only used while the call field still matches the
  /// QSO's own call. Empty map means "call known, nothing resolved yet."
  Map<String, dynamic>? get _currentGuess {
    final result = _lookup.resultForActiveCall;
    final liveGuess = result == null ? null : (asQsonMap(result['guess']) ?? const {});

    Map<String, dynamic>? savedGuess;
    final editing = widget.session.editingQso;
    if (editing != null) {
      final their = asQsonMap(editing.data['their']);
      final savedCall = (their?['call'] as String?)?.toUpperCase();
      if (savedCall != null && savedCall == _callAtCursor && their?['guess'] is Map) {
        savedGuess = (their!['guess'] as Map).cast<String, dynamic>();
      }
    }

    if (liveGuess != null && savedGuess != null) return {...savedGuess, ...liveGuess};
    return liveGuess ?? savedGuess;
  }

  /// The call-info the area shows — null while the call-info panel is not
  /// showing: fewer than three characters typed, or an event row, whose
  /// `their.call` (e.g. "NOTE") is a sentinel rather than a real callsign —
  /// the operation stats are the only sensible default there, same as with
  /// nothing typed yet.
  ///
  /// When editing an existing QSO, the data is held until scoring has run
  /// (`_lookup.scoreFor == _callAtCursor`), so the saved lookup and the pills
  /// appear together in one update — otherwise the lookup text renders first
  /// and the pills pop in a moment later. Composing streams in as the user
  /// types, the pills behind [CallLookupModel.currentAlertKeys]' holds.
  CallInfoData? get _callInfoForArea {
    if (!_callInfoActive || _editingEvent) return null;
    final ready = widget.session.editingQso == null || widget.lookups.scoreQso == null || _lookup.scoreIsCurrent;
    final guess = ready ? _currentGuess : null;
    return CallInfoData(
      call: _callAtCursor,
      guess: guess,
      lookups: _currentLookups,
      alertKeys: ready ? _lookup.currentAlertKeys : const [],
      noticeKeys: ready ? _lookup.currentNoticeKeys : const [],
      scoreSources: ready ? _lookup.currentScoreSources : const {},
      isEditing: widget.session.editingQso != null,
      workedBefore: _lookup.workedBefore,
    );
  }

  /// The info area (issue #40): [LoggingInfoArea] says what it shows and in
  /// what order; this is where the panel's state becomes its inputs. The
  /// distance line and the notice labels come from the app layer — only it
  /// knows the operation's own location and the current locale — and this
  /// panel is where they arrive.
  Widget _buildInfoArea(ThemeData theme) {
    final callInfo = _callInfoForArea;
    final guess = callInfo?.guess;
    final message = _command.message;
    return LoggingInfoArea(
      theme: theme,
      warnings: _missingRadioWarnings,
      message: message,
      callInfo: callInfo,
      locationLine: guess == null ? null : widget.lookups.callLocationLine?.call(guess),
      // Asked only when it would show: it walks the exchange fields.
      gridOnlyLine: message == null && callInfo == null ? _gridOnlyLine : null,
      statsLines: () => widget.lookups.operationStatsLines?.call(widget.log.qsos) ?? const <String>[],
      noticeLabel: widget.lookups.scoreNoticeLabel,
      workedBeforeLabel: widget.lookups.workedBeforeLabel,
      onCallInfoTap: widget.lookups.onCallInfoTap,
      onFindCall: widget.lookups.onFindCall,
      onOperationInfoTap: widget.lookups.onOperationInfoTap,
      onOpenLink: widget.lookups.onOpenLink,
    );
  }

  /// What the locked form says in place of the info area (ham2k/halo-dist#59).
  /// The write refusal is checked first: a staged delete on a QSO whose
  /// operation is also unwritable would otherwise promise a deletion that
  /// cannot be saved.
  String _lockedWarningText(bool deletedQso) {
    final refusal = _writeRefusal;
    // Worded for the event row when there is one (`kind` is its uppercased
    // eventKind, e.g. "NOTE"/"BREAK") — "QSO" is wrong for a row that isn't one.
    final kind = widget.session.editingQso?.eventKind?.toUpperCase();
    return (refusal != null)
        ? refusal.reason
        : (kind != null)
        ? (deletedQso
              ? t.loggingControls.deletedEventWarning(kind: kind)
              : isMobilePlatform
              ? t.loggingControls.pendingDeleteEventTapWarning(kind: kind)
              : t.loggingControls.pendingDeleteEventClickWarning(kind: kind))
        : (deletedQso
              ? t.loggingControls.deletedQsoWarning
              : isMobilePlatform
              ? t.loggingControls.pendingDeleteTapWarning
              : t.loggingControls.pendingDeleteClickWarning);
  }

  /// What the contact in hand is missing from the radio state that every QSO
  /// needs: a band (or a frequency to derive one from) and a mode. Empty —
  /// the normal state — paints nothing.
  ///
  /// Never while editing an event row. A NOTE is not a contact and needs no
  /// band, and the `event` band sentinel it carries does not survive into
  /// `_radio.band`: the record's zero frequency sends [QsoDraft.applyData] down
  /// its frequency branch, which drops `_radio.manualBand`. On a tuned rig
  /// `_seedFromRadioService` then fills it from the VFO and the question never
  /// arises; on the untuned one these warnings exist for, this guard is all
  /// that stops an annotation being nagged about a field it will never have.
  List<String> get _missingRadioWarnings {
    if (_editingEvent) return const [];
    return [
      // The same condition [_log] refuses a submit on, so the two can never
      // name different things as missing. They are not the same test, though:
      // this one is additionally suppressed on an event row and wherever
      // `fieldsLocked` swaps the whole area for its own warning. Neither is
      // reachable with something loggable in hand today — an event's `NOTE`
      // is not a callsign, and a locked form cannot log — so nothing is lost
      // by staying quiet there.
      if (_radio.freq == null && _radio.band == null) t.loggingControls.missingBand,
      if (_radio.mode.trim().isEmpty) t.loggingControls.missingMode,
    ];
  }

  /// What the info area is showing, as the signature [LoggingInfoFrame] keys
  /// its cross-fade on — changes when the DISPLAYED content changes (mode,
  /// lookup result, notices), but is stable across the stats line's 1 Hz
  /// clock tick, so only real content changes cross-fade.
  ///
  /// The missing-band/mode warnings are deliberately outside it: they are a
  /// state of the radio, not of the area, and they come and go while the area
  /// is showing the same thing. They update in place, as lookup and score
  /// results do.
  String _infoAreaSignature({required bool fieldsLocked, required bool deletedQso}) {
    // The refusal is part of the signature because it can clear while the
    // form stays locked for another reason — travel ending over a staged
    // delete — and the warning text changes without `fieldsLocked` moving.
    if (fieldsLocked) return 'locked:$deletedQso:${_writeRefusal != null}';
    if (_command.message != null) return 'message'; // message text updates in place
    // Coarse on purpose: only the call itself keys the cross-fade. Lookup and
    // score results stream in as in-place updates (no switch), so the panel
    // fills smoothly instead of flashing empty between passes.
    if (_callInfoActive) return 'call:$_callAtCursor';
    if (_gridOnlyLine case final line?) return 'grid:$line';
    return 'stats'; // stable across the ticker
  }

  /// A complete Maidenhead locator (4, 6 or 8 characters) — the shortest
  /// form a distance can be taken from.
  static final _completeGrid = RegExp(r'^[A-R]{2}[0-9]{2}([A-X]{2}([0-9]{2})?)?$', caseSensitive: false);

  /// With no callsign in the field but a grid typed — a microwave operator
  /// lining up a dish on a square before the other station is even named —
  /// the grid alone is enough to show the distance and bearing to it. A
  /// contest's own grid exchange (`field: 'grid'`) counts, and so does the
  /// core Grid field. Null when there is nothing to point at, or nothing to
  /// say about it: the app composes the line, and answers null when the
  /// operation has no location of its own — then the stats stay, rather than
  /// a person icon over a blank line hiding that "set our grid" is what's
  /// missing.
  String? get _gridOnlyLine {
    final guess = _gridOnlyGuess;
    if (guess == null) return null;
    final line = widget.lookups.callLocationLine?.call(guess);
    return (line == null || line.isEmpty) ? null : line;
  }

  Map<String, dynamic>? get _gridOnlyGuess {
    if (_callInfoActive || _editingEvent) return null;
    var grid = _exchange.valueForField('grid');
    if (grid.isEmpty && widget.prefs.showGridField) grid = _gridController.text.trim();
    if (!_completeGrid.hasMatch(grid)) return null;
    // The fields uppercase as typed; the line reads better as FN20aa.
    return {'grid': normalizeGrid(grid)};
  }

  /// The lookup entries backing the current call-info — live results when
  /// available, else the entries saved on the QSO being edited (`their.lookups`,
  /// which carry the call-notes `notes` array the merge doesn't fold into
  /// `guess`).
  List<Map<String, dynamic>> get _currentLookups {
    final live = asQsonList(_lookup.resultForActiveCall?['lookups'])?.whereType<Map<String, dynamic>>().toList();
    if (live != null) return live;
    final their = asQsonMap(widget.session.editingQso?.data['their']);
    return asQsonList(their?['lookups'])?.whereType<Map<String, dynamic>>().toList() ?? const [];
  }

  /// The current call-info payload for the detail panel, or null when the
  /// call-info panel isn't showing.
  CallInfoData? get _currentCallInfoData {
    // Mirror the compact area's priority: a command message wins over call-info.
    if (!_callInfoActive || _command.message != null) return null;
    return CallInfoData(
      call: _callAtCursor,
      guess: _currentGuess,
      lookups: _currentLookups,
      alertKeys: _lookup.currentAlertKeys,
      noticeKeys: _lookup.currentNoticeKeys,
      scoreSources: _lookup.currentScoreSources,
      isEditing: widget.session.editingQso != null,
      workedBefore: _lookup.workedBefore,
    );
  }

  /// Pushes the current call-info up to the host (deduped) — the Info tab's
  /// detail panel mirrors it. Called post-build so it never setStates a parent
  /// mid-build.
  void _notifyCallInfo() {
    if (widget.lookups.onCallInfoChanged == null) return;
    final data = _currentCallInfoData;
    final g = data?.guess;
    final sig = data == null
        ? null
        : '${data.call}|${_lookup.lookupFor}|${data.isEditing}|${g?['name']}|${g?['grid']}|${g?['image']}|${g?['note']}'
              '|${data.alertKeys.join(",")}|${data.noticeKeys.join(",")}|${data.scoreSources}';
    if (sig == _lastCallInfoSig) return;
    _lastCallInfoSig = sig;
    widget.lookups.onCallInfoChanged!(data);
  }

  /// Pushes the QSO being composed up to the host (deduped), for consumers
  /// that need the whole draft rather than the call-info summary above —
  /// extension panels declaring the `qso` trigger.
  ///
  /// Deep-compared, not signature-compared like call-info: the draft's
  /// interesting parts are nested (`their`, `our`, `refs`) and a flat
  /// signature over them would be the same code as an equality check, only
  /// wrong whenever a field is added. The cost is bounded by the null check
  /// at the call site — a host with no such consumer never gets here.
  ///
  /// A published draft is READ-ONLY to everyone downstream. [QsoDraft.toData]
  /// shares nested references with the QSO being edited and with the lookup
  /// result, and every map handed out below shares those nested maps with
  /// the one kept here (the peer's IS it) — so mutating a published draft in
  /// place moves both sides of the comparison together, and the panel
  /// watching it silently stops updating.
  void _notifyQsoDraft() {
    final wantsDraft = widget.session.onQsoChanged != null;
    final wantsPeer = widget.session.onPeerDraftChanged != null;
    if (!wantsDraft && !wantsPeer) return;
    // Built once and handed to both — the deep compare below is the expensive
    // half, not this.
    final qso = _draft.toData();
    final unchanged = const DeepCollectionEquality().equals(qso, _lastPublishedQso);
    // Deduped separately, never on `unchanged` alone: a report the operator
    // types over its own placeholder leaves the draft identical and changes
    // only what [_peerDraftFields] answers (see `onPeerDraftChanged`).
    if (wantsPeer) {
      final fields = _peerDraftFields();
      if (!unchanged || !const DeepCollectionEquality().equals(fields, _lastPublishedFields)) {
        _lastPublishedFields = fields;
        widget.session.onPeerDraftChanged!(qso, fields);
      }
    }
    if (wantsDraft) {
      // Deduped on the calls too: moving the cursor between stacked segments
      // changes which call `qso.call` names while the draft stays the same.
      final calls = _callText.templateCalls;
      if (!unchanged || calls != _lastPublishedCalls) widget.session.onQsoChanged!(_withCallField(qso, calls));
      _lastPublishedCalls = calls;
    }
    _lastPublishedQso = qso;
  }

  /// The main logging row as a peer's panel renders it, in the order this
  /// operator sees it.
  ///
  /// Read straight off [_primaryFields], which IS the row — so a control an
  /// activity contributes or the operator switches on appears here with no
  /// second list to keep in step, and sent/rcvd come out whichever way this
  /// device draws them.
  ///
  /// The value is the CONTROLLER's, never the draft's. An untouched field is
  /// empty here and carries its suggestion in `hint`, which is the whole
  /// distinction the receiving panel draws; the draft cannot answer it,
  /// because a report reaches the draft with its placeholder already folded
  /// in by `_rstOrDefault`.
  List<PeerDraftField> _peerDraftFields() => [
    for (final field in _primaryFields) (key: field.key, label: field.label, value: field.controller.text.trim(), hint: field.hint?.trim()),
  ];
}
