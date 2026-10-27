// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What reaches the logging panel from outside while it is up — an edit
// opening and closing, a suggestion arriving, held or withdrawn, a log
// request, a swapped controller or notifier — and the fields written from
// a record. Its own file for size alone; it is part of the panel's library
// and reaches its state directly.

part of 'logging_controls.dart';

extension _WidgetUpdates on _LoggingControlsState {
  /// Sets a primary field as if typed — the controller listeners fire, so the
  /// debounced lookup/scoring run just like user input. `call` only for now.
  void _devSetField(String field, String value) {
    switch (field) {
      case 'call':
        // Same single-assignment idiom as the `setCallField` command path
        // (text + end cursor in one write, then focus) so `_onCallChanged`
        // reacts exactly as if typed.
        _callController.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
        _callFocus.requestFocus();
    }
  }

  /// A log request landed with this update — see [_handleLogRequest]. Runs
  /// before the editing guards in [didUpdateWidget] can return; says so,
  /// because a suggestion arriving on the same frame reads differently.
  bool _syncLogRequest(LoggingControls oldWidget) {
    final request = widget.session.logRequest;
    final logRequested = request != null && request.serial != oldWidget.session.logRequest?.serial;
    if (logRequested) {
      // The commit asks its own question, about the same gesture — so a peek
      // held from the way in has nothing left to say.
      _heldSuggestion = null;
      unawaited(_handleLogRequest(request.qso));
    }
    return logRequested;
  }

  void _syncPowerInPlay(LoggingControls oldWidget) {
    // Power may have just come into play — the operator added the control to
    // the row, or switched station-info tracking on. The field is seeded from
    // the VFO only while power IS in play, so without this it stays empty
    // until the next VFO notification, and a QSO logged in between carries
    // none. Decided from the inputs rather than a remembered flag: a `late`
    // field's initializer runs on its first READ, which is here, and would
    // simply record the new state and see no change.
    final controlsChanged =
        oldWidget.radio.trackingPower != widget.radio.trackingPower ||
        !const ListEquality<String>().equals(oldWidget.strip.controlOrder, widget.strip.controlOrder) ||
        !const SetEquality<String>().equals(oldWidget.strip.hiddenControlKeys, widget.strip.hiddenControlKeys);
    if (controlsChanged) _radio.seedPowerFromVfo();
  }

  /// A slid spot row's suggestion: withdrawn, held, or confirmed. Runs before
  /// the editing guards in [didUpdateWidget]: an edit in progress is exactly
  /// when a tentative suggestion has something to say, and those guards
  /// would swallow all three of these.
  void _syncSuggestionLifecycle(LoggingControls oldWidget, {required bool logRequested}) {
    if (oldWidget.session.suggestedQso != null && widget.session.suggestedQso == null) _withdrawTentativeSuggestion();
    if (!logRequested &&
        widget.session.suggestedQsoIsTentative &&
        widget.session.suggestedQso != null &&
        !identical(oldWidget.session.suggestedQso, widget.session.suggestedQso) &&
        (widget.session.editingQso != null || _hasComposedCall)) {
      // Held rather than applied — and rather than dropped: the operator gets
      // it back the moment the gesture settles.
      //
      // Never on the frame a log request lands. A commit carries a fresh
      // suggestion of its own alongside the request, and holding THAT arms a
      // question about a gesture that has already finished: it survives the
      // log, and the next row to settle raises a prompt about a station the
      // operator dealt with long ago — which, accepted, replaces the one they
      // are working and retunes the radio to it.
      _heldSuggestion = widget.session.suggestedQso;
    }
    if (widget.session.suggestionSettledSerial != oldWidget.session.suggestionSettledSerial) {
      final held = _heldSuggestion;
      if (held != null) {
        _heldSuggestion = null;
        unawaited(_confirmHeldSuggestion(held));
      }
    }
  }

  void _syncKeyboardAccessory(LoggingControls oldWidget) {
    // Withdraw from the controller we actually published to. `deactivate` only
    // ever sees the CURRENT one, so without this a swapped controller keeps a
    // row nothing can ever take back.
    if (!identical(oldWidget.prefs.keyboardAccessory, widget.prefs.keyboardAccessory)) {
      oldWidget.prefs.keyboardAccessory?.clearIfOwner(this);
    }
  }

  void _syncActivityControls(LoggingControls oldWidget) {
    // The controls a contest contributes arrive asynchronously, after this
    // widget first builds — so a serial field is typically declared here
    // rather than in initState, and this is where its first preview comes
    // from. The operation's own refs matter just as much, since they decide
    // which primary controls survive `_textControls` at all: adding the
    // activity is what makes the serial field appear. Deliberately before the
    // editing guards in [didUpdateWidget]: showing the right number never
    // depends on what is being composed.
    if (!identical(oldWidget.activities.activityControls, widget.activities.activityControls) ||
        !identical(oldWidget.log.operation.data['refs'], widget.log.operation.data['refs'])) {
      // A per-QSO refresh cached before this change must not shadow it —
      // see [ActivityRefsModel.controlsChanged].
      _refs.controlsChanged();
      // `_scheduleLookup` only re-fetches per-QSO controls when the active
      // call CHANGES (`_lookup.lookupFor == activeCall` short-circuits it) — so
      // clearing the cache here would otherwise silently drop an
      // already-resolved lookup's guessed field (a suggested grid, say)
      // for the rest of the composing session, with nothing left to bring
      // it back except retyping the callsign.
      if (_lookup.lookupFor != null) unawaited(_refs.refreshControlsFor(_lookup.lookupFor!));
      unawaited(_exchange.refreshSerialPreviews());
    }
  }

  void _syncSerialSource(LoggingControls oldWidget) {
    // The source is the panel's only handle on its held number: a source
    // swapped out (sharing switched off) or an operation swapped under the
    // panel would otherwise leave that number held with nothing left to
    // release it — and served again the moment the source came back.
    if (widget.session.editingQso == null &&
        (oldWidget.log.serialNumbers != widget.log.serialNumbers || oldWidget.log.operation.uuid != widget.log.operation.uuid)) {
      oldWidget.log.serialNumbers?.release(oldWidget.log.operation.uuid);
      _exchange.forgetSerialState();
      unawaited(_exchange.refreshSerialPreviews());
    }
  }

  void _attachController(LoggingControlsController? controller) => controller?.attach(
    setField: _devSetField,
    submit: _log,
    wipe: _wipe,
    isFieldsLocked: () => _fieldsLocked,
    handleChord: _handleChord,
    focusCall: _callFocus.requestFocus,
    focusSecondaryControls: _ladder.focusPillAndOpen,
    focusLastPrimaryField: _ladder.focusLastPrimaryField,
  );

  void _syncController(LoggingControls oldWidget) {
    if (oldWidget.session.controller != widget.session.controller) {
      oldWidget.session.controller?.detach();
      _attachController(widget.session.controller);
    }
  }

  void _syncRadioUpdates(LoggingControls oldWidget) {
    // The VFO notifier can be swapped with the widget (a different
    // HaLoServices in a harness, a future per-profile RadioService). Without
    // this the listener stays on the OLD notifier and `dispose` removes it
    // from the new one, so following dies and the old notifier keeps this
    // State alive.
    //
    // Before the editing guards in [didUpdateWidget], like [_syncController]
    // and for the same reason: re-subscribing is bookkeeping about which
    // notifier this State is attached to, not something a QSO being edited
    // gets a say in.
    // Below them it simply never ran while an edit was open.
    if (!identical(oldWidget.radio.radioUpdates, widget.radio.radioUpdates)) {
      oldWidget.radio.radioUpdates?.removeListener(_onRadioVfoChanged);
      widget.radio.radioUpdates?.addListener(_onRadioVfoChanged);
    }
    // A rig coming on line reports wherever its knob was left, which is the
    // station an entry typed meanwhile is for.
    if (widget.radio.radioConnected && !oldWidget.radio.radioConnected) _radio.settle();
  }

  /// A QSO opened for editing, or the edit ended. True when that was the
  /// update: the fields are a new context's, and nothing below applies.
  bool _syncEditingQso(LoggingControls oldWidget) {
    if (oldWidget.session.editingQso?.uuid != widget.session.editingQso?.uuid) {
      // Captured before _resetEditingSessionState() below, which clears
      // _draft.theirNameOverride — a snapshot taken after that would silently drop
      // a name entered via the More pane.
      if (oldWidget.session.editingQso == null && widget.session.editingQso != null) {
        _draft.snapshotComposing();
        // Parked with it, for the reason given at [_handleWipeTap]: the
        // reset below forgets which refs were a lookup's.
        _composingGuesses = _refs.takeGuessSnapshot();
        _composingStart = _radio.startedOn;
      }
      _resetEditingSessionState();
      if (widget.session.editingQso != null) {
        _populateFromEditingQso(widget.session.editingQso!);
      } else {
        final composingSnapshot = _draft.takeComposingSnapshot();
        final composingGuesses = _composingGuesses;
        _composingGuesses = null;
        final composingStart = _composingStart;
        _composingStart = null;
        _resetLocalFields();
        // Overlaid back on top of the blank fields _resetLocalFields just
        // seeded.
        if (composingSnapshot != null) {
          _restoreDraft(composingSnapshot, guesses: composingGuesses);
          // Measured from where it was parked: the radio was not followed
          // while the earlier contact was open, and the seed above took
          // wherever it went as the start.
          _radio.startOn(composingStart);
          _onRadioVfoChanged();
        }
      }
      // Self- vs other-spot eligibility can differ per extension (e.g. only
      // self-spotting an operation with an activation ref) — re-fetch
      // whenever what's being spotted changes.
      _spotting.forgetSources();
      _spotting.refreshSources();
      // The fields are this panel's own again, which is exactly what anything
      // parked was waiting for — and [didUpdateWidget] stops here, so the
      // drain is this method's, not the end of the update's.
      _drainPending();
      return true;
    }
    return false;
  }

  /// While composing: the operation's refs changed, or a new suggestion
  /// arrived — and then whatever was parked waiting for the fields is
  /// applied, unless a tentative suggestion was left held.
  void _syncComposingInputs(LoggingControls oldWidget) {
    // While composing a new QSO, self-spot eligibility depends on the
    // operation's own activation refs (not editingQso, which stays null
    // throughout) — refresh when those refs change too.
    if (!identical(oldWidget.log.operation.data['refs'], widget.log.operation.data['refs'])) {
      _spotting.refreshSources();
    }

    // A new suggestion (e.g. tapping a different spot) — same reset scope
    // as [_syncEditingQso], applied for it instead. Deliberately independent
    // from the refs check just above (not `else if`),
    // so both can fire in the same call — e.g. an operation-refs change and
    // a spot tap landing in the same frame would otherwise let one silently
    // suppress the other.
    if (widget.session.suggestedQso != null && !identical(oldWidget.session.suggestedQso, widget.session.suggestedQso)) {
      // A gesture the operator can still drag back may not take the fields or
      // the VFO from work already in progress — [_syncSuggestionLifecycle]
      // held it instead, and anything parked stays parked with it.
      if (widget.session.suggestedQsoIsTentative && _hasComposedCall) return;
      _resetEditingSessionState();
      _applySuggestedQso(widget.session.suggestedQso!);
      _rememberSuggestedCall(tentative: widget.session.suggestedQsoIsTentative);
      _spotting.forgetSources();
      _spotting.refreshSources();
      // A suggestion means "work THIS station", so Enter must be able to log
      // it right away — the tap that produced it landed outside the logging
      // fields, leaving nothing focused for Enter to reach. Focus the
      // callsign field (cursor-at-end comes from its focus listener). Not on
      // mobile without a physical keyboard: there an uninvited virtual
      // keyboard would cover the call info the tap just surfaced
      // (docs/design/logging-fields.md's mobile carve-out).
      if (!isMobilePlatform || hardwareKeyboardAttached.value) _callFocus.requestFocus();
    }

    // A request held back until the edit it had to clear is gone — see
    // [_handleLogRequest]. By here `editingQso` is null, so the fields are
    // this panel's own again and the spot can take them.
    _drainPending();
  }

  /// Applies whatever was parked waiting for an edit to be gone — see
  /// [_handleLogRequest] and [_confirmHeldSuggestion].
  ///
  /// Called from BOTH [_syncEditingQso] and [_syncComposingInputs], because
  /// the update that clears the edit is the former, and `didUpdateWidget`
  /// stops there. Draining only at the end of an update leaves the work parked until some unrelated rebuild — a spot poll, a
  /// clock tick — picks it up seconds later, on top of whatever the operator
  /// has typed since, moving the VFO with it.
  void _drainPending() {
    if (widget.session.editingQso != null) return;
    final pending = _pendingLogRequest;
    if (pending != null) {
      _pendingLogRequest = null;
      unawaited(_applyAndLog(pending));
    }
    final pendingSuggestion = _pendingSuggestion;
    if (pendingSuggestion != null) {
      _pendingSuggestion = null;
      _applyTentativeSuggestion(pendingSuggestion);
    }
  }

  /// Whether the call in the field is still exactly what a suggestion put
  /// there — nothing typed over it, nothing typed after it.
  bool get _callIsUntouchedSuggestion => _suggestedCall != null && _call == _suggestedCall;

  /// The row that made the tentative suggestion has closed. Its fill goes with
  /// it: leaving it there makes the next Log a contact with whoever was slid
  /// last.
  void _withdrawTentativeSuggestion() {
    _heldSuggestion = null;
    _pendingSuggestion = null;
    // Only a peek's own fill, and only while it is still exactly what the peek
    // put there: an entry the operator has typed over is theirs, and the row
    // that started it closing may not take it away.
    if (!_suggestionWasTentative || !_callIsUntouchedSuggestion) return;
    _suggestionWasTentative = false;
    // Focus stays where it is: pulling it here would raise the mobile keyboard
    // over the list the operator is still working. And behind [QsoDraft.populate],
    // which is what stops the clear from reaching `onCallEdited`: this runs
    // from didUpdateWidget, so the listener would report the operator editing
    // the field — from inside a build, to a view that has already built. Any
    // OTHER callback this wipe fires is under the same constraint.
    _draft.populate(() {
      _wipe(focusCall: false);
    });
  }

  /// Puts a held suggestion to the operator, and applies it if they clear the
  /// way. Declining keeps their work — [LoggingSession.confirmLogOverwrite] surfaces this
  /// panel so they land on it — and leaves the row to ask again if the
  /// gesture is carried through to a commit.
  Future<void> _confirmHeldSuggestion(Map<String, dynamic> qso) async {
    final editing = widget.session.editingQso != null;
    // The conflict is re-read here, not trusted from when the suggestion was
    // held: the operator may have logged, wiped or cancelled the edit in
    // between, and a prompt offering to clear an empty panel teaches them the
    // prompt means nothing.
    if (!editing && !_hasComposedCall) {
      _applyTentativeSuggestion(qso);
      return;
    }
    final clear = await _askOverwrite(editing: editing);
    if (!mounted || !clear) return;
    // Re-read AFTER the wait, because the wait is the point: the row that
    // raised this dialog can be closed or discarded while it is up, which
    // takes the suggestion back. Applying it anyway fills the fields and
    // retunes the radio for a row that no longer exists — and the withdrawal
    // has already been and gone, so nothing is left that could undo it.
    if (!identical(widget.session.suggestedQso, qso)) return;
    if (editing) {
      // Comes back as a widget update with `editingQso` null; the suggestion
      // waits for it rather than filling fields that still belong to the edit.
      widget.session.onEditCanceled?.call();
      _pendingSuggestion = qso;
      return;
    }
    _applyTentativeSuggestion(qso);
  }

  /// Puts [LoggingSession.confirmLogOverwrite]'s question to the operator,
  /// from OUTSIDE the frame that decided to ask it.
  ///
  /// Both askers run from `didUpdateWidget` — deliberately, so neither is
  /// swallowed by the editing guards there — which is the build phase, with
  /// the Navigator mid-flush. A route pushed into it from there trips the
  /// Navigator's own `!_debugLocked` assertion when the push animation lands,
  /// and what reaches the operator is a crash where the question should be.
  Future<bool> _askOverwrite({required bool editing}) {
    final confirm = widget.session.confirmLogOverwrite;
    if (confirm == null) return Future.value(false);
    final asked = Completer<bool>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        asked.complete(false);
        return;
      }
      // `Future.sync`, so a caller that throws BEFORE returning its future
      // still reaches the awaiting side. Left bare, a synchronous throw
      // escapes this callback with the completer unfinished, and everything
      // waiting on it waits forever: the contact the operator committed to
      // with a full slide is never logged, and nothing retries it (the
      // request's serial only changes once).
      asked.complete(Future.sync(() => confirm(editing: editing)));
    });
    return asked.future;
  }

  void _applyTentativeSuggestion(Map<String, dynamic> qso) {
    _resetEditingSessionState();
    _applySuggestedQso(qso);
    _rememberSuggestedCall(tentative: true);
  }

  /// Records what the suggestion just applied put in the call field, so
  /// [_callIsUntouchedSuggestion] can tell it apart from an entry the operator
  /// composed. Read back off the field rather than out of the QSO map: the
  /// field is what every other reader of this panel sees.
  void _rememberSuggestedCall({required bool tentative}) {
    _suggestedCall = _call.isEmpty ? null : _call;
    _suggestionWasTentative = tentative;
  }

  /// Handles a log request from outside — the spots list's slide.
  ///
  /// Runs BEFORE `didUpdateWidget`'s editing guards, deliberately: those
  /// return early whenever a QSO is selected for editing, which is an ordinary
  /// two-pane state, and a request swallowed there is a contact the operator
  /// was told had been logged. The serial only changes once, so nothing
  /// retries it.
  Future<void> _handleLogRequest(Map<String, dynamic> qso) async {
    final editing = widget.session.editingQso != null;
    if (editing || _hasComposedCall) {
      // Something here would be destroyed. Never silently: the operator is
      // looking at the spots list, and the work at risk is on a surface they
      // cannot see from there.
      final clear = await _askOverwrite(editing: editing);
      if (!mounted || !clear) return;
      if (editing) {
        // Comes back as a widget update with `editingQso` null; the request
        // waits for it rather than filling fields that still belong to the edit.
        widget.session.onEditCanceled?.call();
        _pendingLogRequest = qso;
        return;
      }
      // Same reasoning as `_applyAndLog`'s own wipe: the operator answered a
      // dialog raised over another surface, and is still standing on it.
      _wipe(focusCall: false);
    }
    await _applyAndLog(qso);
  }

  /// Fills the fields from [qso] and submits them, in that order and with no
  /// frame between: `_log` reads the live field state, so anything that let a
  /// build in between would log what the fields held before the spot landed.
  Future<void> _applyAndLog(Map<String, dynamic> qso) async {
    _resetEditingSessionState();
    _applySuggestedQso(qso);
    await _log(focusCall: false);
  }

  /// Editing-session bookkeeping that must never leak from one QSO context
  /// into the next.
  ///
  /// Called wherever the fields are about to be written from a record: the
  /// editingQso and suggestedQso paths in `didUpdateWidget`, and Revert,
  /// which reloads the record the operator is already on. That last one is
  /// why anything cleared here has to be something `QsoDraft.applyData`
  /// puts back from the record — Revert is a reload, not a fresh start, and
  /// a field reset here and restored by nothing would go missing from the
  /// contact with nothing said.
  void _resetEditingSessionState() {
    _pendingDelete = false;
    // Dropped with the undo slot that `resetSession` clears, so the two
    // cannot drift apart: provenance outliving the draft it belongs to is
    // the shape of the bug this whole pairing exists to prevent.
    _undoGuesses = null;
    _time.forgetWipe();
    _draft.resetSession();
  }

  /// Populates controllers/state from an existing QSO selected for editing.
  /// Local-state only — never calls parent-notifying callbacks (this runs
  /// from `didUpdateWidget`, where a synchronous `setState` back up the
  /// tree could throw).
  void _populateFromEditingQso(Qso qso) {
    _suggestedCall = null;
    _suggestionWasTentative = false;
    _draft.populate(() {
      _applyFieldsFromData(qso.data);
      if (qso.isEvent) {
        _applyEventFieldsFromData(qso.data);
        // An event's own freq/band/mode are sentinels (freq 0, mode the event
        // kind) — showing them on the Radio control would be meaningless.
        // Feed it the radio's actual current conditions instead, same as
        // composing a new QSO; never saved either way (`_eventDataForSave`
        // never reads these controllers).
        _seedFromRadioService();
      }
      _time.manualStartAtMillis = null; // _time.effectiveStartAtMillis falls back to editingQso.startAtMillis
      _setStateFromPart(() {});
    });
    // Score the edited QSO (excluding itself) so its dupe/New-* pills show, the
    // same way they do while composing — populate suppressed _onCallChanged's
    // own trigger. The worked-before pill likewise: an edit runs no live
    // lookup (the saved guess stands), so the lookup path never fetches it.
    _lookup.scheduleScore();
    _lookup.refreshWorkedBefore();
    // A QSO logged before its online lookup ever ran (e.g. offline, or a
    // quick log with the runtime still booting) should get one now rather
    // than sit unenriched until the next background pass — `enqueueLookup`
    // already skips QSOs that already have real (non-annotation-only)
    // lookup data, so this is a no-op for anything already enriched.
    widget.lookups.enqueueLookup?.call(qso);
  }

  /// Populates controllers/state from a `suggestedQso` map (e.g. tapping a
  /// spot) — same wrapping as `_populateFromEditingQso`, for a QSO being
  /// composed rather than an existing one being edited.
  ///
  /// A suggestion that carries no RST (spots never do today) leaves the
  /// fields blank, which is the composing default — `_rstPlaceholder` shows
  /// through it. One that DOES carry RST (`our.sent`/`their.sent` — e.g. a
  /// deeplink) keeps it, matching `_applyFieldsFromData`'s own behavior for
  /// editingQso.
  ///
  /// A `startAtMillis` on the suggestion becomes the MANUAL time, exactly as
  /// if the operator had typed it: a `/qso` deep link reports when a contact
  /// actually happened (a WSJT-X bridge hands over a QSO already made), and
  /// composing it at "now" would file it minutes late. A suggestion without
  /// one still clears the manual time — a spot says nothing about when, and
  /// must not inherit the last link's timestamp.
  void _applySuggestedQso(Map<String, dynamic> data) {
    _draft.populate(() {
      _applyFieldsFromData(data);
      // Read from `data`, since `_applyFieldsFromData` strips the key rather
      // than carrying it into `_draft.extra`.
      final suggestedStart = data['startAtMillis'];
      _time.manualStartAtMillis = suggestedStart is int ? suggestedStart : null;
      _setStateFromPart(() {});
    });
    // A tapped spot starts a contact as surely as a typed call does, and it
    // bypasses `_onCallChanged` — so the serial number is taken here.
    unawaited(_exchange.refreshSerialPreviews());
    // Populating a suggestion sets the call without the user typing, so
    // [QsoDraft.populate] suppressed _onCallChanged's own lookup and score
    // scheduling. Any source that sets the current QSO's callsign must
    // still trigger a lookup — spots (#315) and a future deeplink both arrive
    // here — so run them explicitly, like `_restoreFromUndoSlot` does.
    // The lookup was reset above, so the "only when changed" guard won't
    // wrongly short-circuit. Guarded on
    // `_callInfoActive` (a real call is present) so both only schedule their
    // timers and never setState synchronously — this also runs from initState
    // for a deeplink cold-start (see the editingQso path in `initState`).
    if (_callInfoActive) {
      _scheduleLookup();
      _lookup.scheduleScore();
    }
    // A suggestion is specific operator intent — "work THIS station" — so
    // unlike the ambient VFO seed it overrides, it moves the VFO, and with
    // a radio connected (CAT) that retunes the radio itself. Tapping a
    // spot is the main way this happens.
    //
    // Only when the suggestion actually carried radio state: a bare
    // callsign (a deeplink, say) must not retune anything. And the push is
    // immediate rather than debounced — the operator picked a specific
    // station, there is nothing more to wait for.
    if (widget.session.editingQso == null && (data['freq'] != null || data['band'] != null || data['mode'] != null)) {
      _radio.cancelPendingPush();
      // AFTER the frame, not now. Both callers — initState and
      // didUpdateWidget — run inside the build phase, and `setVfo` notifies
      // its listeners synchronously; SpotsPanel listens and calls setState,
      // which Flutter refuses mid-build ("cannot be marked as needing to
      // build because the framework is already in the process of building
      // widgets"). ErrorPolicy classes that as logOnly, so it costs the
      // operator nothing visible and would have gone unnoticed — but the
      // panel can silently miss its rebuild for that frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _radio.pushVfo();
      });
    }
  }

  /// Shared by `_populateFromEditingQso` (loading an existing record for
  /// editing) and `_restoreFromUndoSlot` (undoing a wipe) — both need to
  /// push a `data` map from a `Qso`/[QsoDraft.toData] shape back into the
  /// live controllers/state. The draft does the fields and the models; what
  /// stays here is the panel's own context — the lookup, the open control,
  /// the command line.
  void _applyFieldsFromData(Map<String, dynamic> data, {bool restoringDraft = false}) {
    _draft.applyData(data, restoringDraft: restoringDraft);
    _lookup.reset();
    _selectedControlKey = null;
    // Command state must never survive into a freshly populated QSO
    // context: this runs under [QsoDraft.populate], so _onCallChanged's own
    // per-keystroke reset is suppressed. Without this, typing "NOTE hi",
    // then tapping a spot, would leave the call field showing a real
    // callsign while still in the note's mixed-case free-text mode — and a
    // stale complete interpretation would make Space insert a literal
    // space (or Enter execute the old command) instead of acting on the
    // callsign.
    _command.reset();
  }

  void _applyEventFieldsFromData(Map<String, dynamic> data) {
    final fields = eventFieldsFromData(data);
    _eventTextController.text = fields.text;
    _eventTodoDone = fields.done;
  }

  Map<String, dynamic> _eventDataForSave(Qso editingQso) =>
      eventDataForSave(editingQso, text: _eventTextController.text, done: _eventTodoDone, startAtMillis: _time.effectiveStartAtMillis);

  /// Clears local fields when an editing session ends (mirrors the
  /// local-state portion of `_wipe()`, without `_wipe()`'s parent callback —
  /// see `didUpdateWidget`).
  void _resetLocalFields() {
    // Guards _onCallChanged (fired synchronously by _callController.clear()
    // below) from calling widget.commands.onCommandMessageChanged — a parent-state
    // setState — while still inside didUpdateWidget.
    _draft.populate(() {
      _callController.clear();
      _clearRSTs();
      _gridController.clear();
      _stateController.clear();
      _draft.clear();
      _lookup.cancelLookup();
      // `_radio.freqTouched` outlives this reset otherwise, and live radio follow
      // stays switched off for the rest of the session.
      _radio.settlePendingFreqEdit(flush: false);
      _lookup.reset();
      _refs.clear();
      _exchange.clear();
      _notesController.clear();
      _time.manualStartAtMillis = null;
      _radio.manualBand = null;
      _selectedControlKey = null;
      _radio.clearPowerEntry();
      // Back to composing a new QSO — the Radio control goes back to
      // mirroring the operation's VFO, not whatever the just-edited QSO's
      // own freq/band/mode happened to be.
      _seedFromRadioService();
      _setStateFromPart(_command.reset);
    });
  }

  /// The part of [QsoDraft.hasComposedValues] a spot slide may not overwrite. The
  /// slide is made on another surface, so what it would destroy has to be
  /// worth a prompt from over there: a station being composed is, while a
  /// frequency, a reference or a stray field with no call attached is
  /// scaffolding the incoming spot replaces anyway.
  ///
  /// A call a SUGGESTION put there is not composed at all — the operator chose
  /// a station, they did not compose an entry (see [_suggestedCall]). So the
  /// next spot, slid or tapped, replaces it silently, and the log request that
  /// ends a slide never asks permission to overwrite what that same slide
  /// filled in a moment earlier.
  bool get _hasComposedCall => _call.isNotEmpty && !_callIsUntouchedSuggestion;
}
