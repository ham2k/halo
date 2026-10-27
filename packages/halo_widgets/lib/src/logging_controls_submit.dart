// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What Enter and the log button do: Enter Sends Messages, a stacked note
// expanded, a staged delete committed, an event saved, and the contact
// written — one QSO per call of a list or a stack. Its own file for size
// alone; it is part of the panel's library and reaches its state directly.

part of 'logging_controls.dart';

extension _Submit on _LoggingControlsState {
  /// Enter, which means two different things depending on whether the operator
  /// has a suggestion picked out.
  ///
  /// A highlight they walked to with the arrow keys is a PENDING CHOICE, so Enter
  /// takes it and stops there: logging a QSO whose exchange they were still
  /// choosing is the worst available reading of that keystroke, and unlike a
  /// wrong exchange it cannot be undone by pressing Enter again. With the
  /// highlight untouched there is no pending choice and Enter is just Enter — it
  /// logs, exactly as it does from every other field.
  ///
  /// The second Enter therefore logs, because accepting clears the highlight,
  /// which is the sequence the operator's hands were making anyway: pick, send.
  void _handleEnter() {
    if (_exchange.acceptPendingChoice()) return;
    _log(fromEnter: true);
  }

  /// The exchange fields ESM waits on: the contest's own, not the reports
  /// (which carry defaults) nor the serial we send (which is allocated).
  List<PrimaryField> get _esmExchangeFields {
    final keys = {
      for (final control in _textControls)
        if ((control['input'] as Map?)?['kind'] != 'serial') control['key'] as String,
    };
    return [
      for (final field in _primaryFields)
        if (keys.contains(field.key)) field,
    ];
  }

  /// What [esmStep] reads off the entry as it stands — one reading for the
  /// Enter and for [_publishEsmFacts], so what the app shows is what the
  /// Enter does.
  EsmFacts get _esmFacts {
    final exchange = _esmExchangeFields;
    // The call the messages key, not the field: on a stack, answering NK2Y
    // and then moving to KI2D is a new station to answer, not KI2D's thanks.
    final call = _callText.templateCalls.call;
    return (
      callEmpty: _callController.text.trim().isEmpty,
      canLog: _canLog,
      answered: call.isNotEmpty && _esmAnsweredCall == call,
      hasExchange: exchange.isNotEmpty,
      exchangeCopied: exchange.any((field) => _exchange.valueOf(field.key).trim().isNotEmpty),
      callFocused: _callFocus.hasFocus,
      incompleteCall: isIncompleteCall(call),
    );
  }

  /// Enter Sends Messages: keys what [esmStep] picks and answers whether this
  /// Enter ends here. False means go on and log.
  bool _enterSendsMessages(EnterSends esm) {
    final exchange = _esmExchangeFields;
    final calls = _callText.templateCalls;
    final call = calls.call;
    final step = esmStepFor(_esmFacts, running: esm.running);
    if (step == null) return false;
    // A step that logs hands over the contact as saved and the entry the log
    // left too, for the thanks — which may name the next stacked call.
    if (step.send.isNotEmpty && step.then == EsmThen.log) {
      final logged = _esmLogged = Completer<EsmLogged?>();
      esm.send(step.send, _withCallField(_draft.toData(), calls), logged: logged.future);
    } else if (step.send.isNotEmpty) {
      esm.send(step.send, _withCallField(_draft.toData(), calls));
    }
    switch (step.then) {
      case EsmThen.stay:
        return true;
      case EsmThen.toExchange:
        _esmAnsweredCall = call;
        _publishEsmFacts();
        final empty = exchange.where((field) => _exchange.valueOf(field.key).trim().isEmpty);
        // Reports only: Rcvd, for the report they give us; with the reports
        // hidden, State or Grid — never our own serial — else the call field
        // keeps focus, and [_esmAnsweredCall] makes the next Enter the second.
        final target = empty.isNotEmpty
            ? empty.first.focus
            : exchange.isNotEmpty
            ? exchange.first.focus
            : widget.prefs.showRSTFields
            ? _rcvdFocus
            : _primaryFields.where((field) => field.key == 'state' || field.key == 'grid').firstOrNull?.focus;
        target?.requestFocus();
        return true;
      case EsmThen.log:
        return false;
    }
  }

  /// Runs `widget.log.decorateQsoBeforeSave` if wired, so an activity can project
  /// its ref data into generic QSON fields. Identity when no callback is
  /// supplied, which is every test and tooling path.
  Future<Map<String, dynamic>> _decorated(Map<String, dynamic> data) async {
    final decorate = widget.log.decorateQsoBeforeSave;
    if (decorate == null) return data;
    // A new contact has no `startAtMillis` yet (its time is automatic) and
    // belongs to the CURRENT segment — not the base, which is what
    // `effectiveAt(null)` answers.
    final at = data['startAtMillis'] as int?;
    return decorate(data, at == null ? _segmented.current : _segmented.effectiveAt(at));
  }

  void _scheduleSubmitButtonMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = _submitButtonKey.currentContext?.size;
      if (size != null && (_editButtonDiameter == null || (size.height - _editButtonDiameter!).abs() > 0.5)) {
        _setStateFromPart(() => _editButtonDiameter = size.height);
      }
    });
  }

  /// Note expansion inside a stack (issue #17 × issue #7): asks the command
  /// hooks to expand the segment under the cursor, and splices the result
  /// back into just that segment — "KI2D//1AB" becomes "KI2D//W1AB,W1AC",
  /// which the NEXT Enter logs as a stacked call list. Returns whether it
  /// expanded anything, in which case this Enter logs nothing at all.
  ///
  /// This exists because the ordinary command path ([CommandInterpretationModel.runOnEnter]) only ever sees the
  /// WHOLE field, so a key stacked alongside other calls would never be
  /// offered for expansion at all. A whole-field "//KEY" that path already
  /// expanded never arrives here — it returned. One it could not expand does
  /// arrive, asks the identical question, and gets the identical no.
  Future<bool> _expandStackedNote() async {
    if (widget.session.editingQso != null || widget.commands.interpretCommand == null || !_isCallStackField) return false;
    // Captured BEFORE the round trips below and reused for the splice, never
    // recomputed after them: the cursor can move without the text changing
    // (a click, an arrow key), and offsets taken afterwards would splice the
    // answer for the segment the hook was asked about into whichever segment
    // the cursor had since wandered into — destroying a call that was never
    // part of this expansion.
    final stack = _callText.stackSegments();
    final input = _command.expansionInputFor(stack);
    if (input == null) return false;
    final before = _callController.text;

    // Preview first (`execute: false`), same discipline as the whole-field
    // command path: this probe runs on EVERY stacked Enter, the ordinary
    // "K1ABC//W1AW" that expands nothing included, and an execute-time
    // interpretation is allowed side effects of its own — a network fetch, a
    // batch of generated QSOs (see CommandHook.interpret's `execute` doc).
    // Only once the preview says this really is an expansion is it worth
    // asking for the executable one, whose `commands` are the real ones.
    final preview = await _command.interpret(input);
    if (!mounted || _callController.text != before) return false;
    if (CommandInterpretationModel.expandedCallText(preview) == null) return false;

    final executable = await _command.interpret(input, execute: true);
    // Stale — the field changed while awaiting a JS runtime round trip, so
    // the captured segment offsets no longer describe this text.
    if (!mounted || _callController.text != before) return false;
    final text = CommandInterpretationModel.expandedCallText(executable);
    if (text == null) return false;

    final segments = [...stack.segments];
    segments[stack.cursorIndex] = text;
    // The cursor stays on the segment it expanded, at its end — that's the
    // segment the next Enter has to pick, and [CallFieldText.pickStackedCall] reads the
    // cursor to decide. Focus goes with it for the same reason: an unfocused
    // field reports no selection at all, and the fallback there is the LAST
    // segment, which in a three-segment stack is a different call entirely.
    _callController.value = TextEditingValue(
      text: segments.join('//'),
      selection: TextSelection.collapsed(offset: stack.starts[stack.cursorIndex] + text.length),
    );
    _callFocus.requestFocus();
    _command.markExpanded(input);
    return true;
  }

  /// HaLo's big light-blue log button — a circle as tall as the text fields
  /// beside it, which [LoggingEntryRow] places at either end of the row and
  /// keys there, since it is that row that moves it. (A LayoutBuilder here to
  /// size the icon off the button's resolved constraints would seem natural,
  /// but the row's IntrinsicHeight needs to query this subtree's intrinsic
  /// dimensions, which LayoutBuilder explicitly doesn't support — so the icon
  /// just uses a fixed, comfortable size.) #236: stable id for agent/browser
  /// tooling. [_submitButtonKey] is for the post-frame measurement.
  Widget _buildSubmitButton(ThemeData accentTheme, {required bool editing, required bool deletedQso}) => semanticId(
    'action.log',
    AspectRatio(
      key: _submitButtonKey,
      aspectRatio: 1,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: FilledButton(
          // Disabled while viewing a deleted QSO — there's nothing to
          // save; restore first. `_command.hasExecutableCommand` lets
          // the button accept a command too, matching Enter (a command
          // isn't a callsign, so `_canLog` alone would leave it
          // disabled — see that getter). `_editingEvent` skips both: an
          // event row has neither a callsign nor a command to accept.
          onPressed: (!deletedQso && (_pendingDelete || _canLog || _command.hasExecutableCommand || _editingEvent)) ? _log : null,
          style: FilledButton.styleFrom(
            backgroundColor: accentTheme.colorScheme.tertiary,
            foregroundColor: accentTheme.colorScheme.onTertiary,
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
          child: Icon(
            _pendingDelete ? MdiIcons.trashCan : (editing ? MdiIcons.contentSave : MdiIcons.upload),
            size: 24 * 1.2 * MediaQuery.textScalerOf(context).scale(1.0),
          ),
        ),
      ),
    ),
  );

  /// A QSO write threw: surface it in the info area (the same channel a
  /// command error uses — never a toast over the logging UI) and hand it to
  /// the host to report. The caller decides what field bookkeeping
  /// accompanies it; the fields themselves are never wiped on failure.
  ///
  /// The in-panel message is load-bearing, not a courtesy: the host's own
  /// notice for a write error shows at most once per session, so without it
  /// an operator on a full disk loses every QSO after the first in silence.
  void _reportWriteFailure(Object e, StackTrace stack, {bool delete = false}) {
    widget.log.onWriteError?.call(e, stack);
    if (!mounted) return;
    // A confirm-clear timer from an earlier command would wipe this message
    // moments after it appears — the failure owns the slot now.
    _command.showError(delete ? t.loggingControls.deleteFailed(error: e) : t.loggingControls.saveFailed(error: e));
  }

  /// [focusCall] false leaves the focus alone when the entry is wiped after
  /// logging — for a contact logged by a gesture made somewhere else (a spot
  /// row slid past the commit point). The operator is working the spots list,
  /// and taking focus here pops the on-screen keyboard up over it.
  ///
  /// [fromEnter] marks the keyboard's Enter, the only submit Enter Sends
  /// Messages speaks for.
  Future<void> _log({bool focusCall = true, bool fromEnter = false}) async {
    // The outermost Enter holds it: a repeat inside its awaits must not let
    // go while the first is still logging.
    if (_logPending) return _logEntry(focusCall: focusCall, fromEnter: fromEnter);
    _logPending = true;
    try {
      await _logEntry(focusCall: focusCall, fromEnter: fromEnter);
    } finally {
      _logPending = false;
      // What the radio did meanwhile, now: followed, or a QSY of an entry
      // the Enter left standing.
      if (_vfoMovedWhileLogging && mounted) _onRadioVfoChanged();
      _vfoMovedWhileLogging = false;
    }
  }

  Future<void> _logEntry({required bool focusCall, required bool fromEnter}) async {
    if (_isLogging) return; // already logging this entry; ignore the repeat
    // The write policy specifically, NOT `_fieldsLocked`: this method is also
    // how a staged delete is committed and a deleted QSO saved, both of which
    // lock the form on purpose and are handled by their own branches below.
    //
    // Fields being disabled is not enough on its own — the panel binds Enter
    // at its own level (`CallbackShortcuts`), so a contact still sitting in
    // the controllers can be submitted from anywhere in the subtree after the
    // form locks under the operator, which running DEVTT from the command bar
    // does exactly.
    if (_writeRefusal != null) return;

    // Check command — shortcuts (band/freq/mode, etc.) only apply while
    // composing a new QSO. A real callsign is exceedingly unlikely to
    // parse as one, but editing an existing entry shouldn't run it through
    // command interpretation at all, least of all while confirming a
    // staged delete.
    final call = _call;
    if (widget.session.editingQso == null) {
      // Enter inside the claim window would otherwise commit a blank serial
      // field, and the allocator's fallback knows nothing of the peers' holds.
      final settled = await _exchange.settleSerialClaims();
      if (!settled || !mounted || _call != call || _isLogging) return;
    }
    // The command line's own decision: whether the typed text is a command
    // at all, what it interprets to, and whether Enter ran it, showed why it
    // cannot, or falls through to logging. The panel supplies what is its own
    // — the double-log guard, the field, the actions.
    final consumed = await _command.runOnEnter(
      alreadyLogging: () => _isLogging,
      whileLogging: (body) async {
        _isLogging = true;
        try {
          await body();
        } finally {
          _isLogging = false;
        }
      },
      clearField: _callController.clear,
      dispatch: (commands, {required skipOnlineLookup}) async {
        try {
          await _dispatchActions(commands, skipOnlineLookup: skipOnlineLookup);
        } catch (e, stack) {
          // A command's actions can write QSOs (e.g. a SEED batch) — a
          // throw mid-dispatch must not vanish into the zone handler
          // while the panel looks like the command ran.
          _reportWriteFailure(e, stack);
        }
      },
    );
    if (consumed) return;

    // Note expansion inside a stack (see [_expandStackedNote]): "KI2D//1AB"
    // becomes "KI2D//W1AB,W1AC" and logs NOTHING this time round. Placed
    // above every gate below, including the band/frequency one, because an
    // expansion writes no QSO — there is nothing yet for a missing band to
    // spoil, and refusing here would leave the operator unable to even see
    // what the key expands to.
    if (await _expandStackedNote()) return;
    // That probe is a real suspension point (a JS runtime round trip) sitting
    // between the entry guard and `_isLogging = true` below — so a repeated
    // Enter that cleared the entry guard before it can now be inside the very
    // same window, and both would go on to log the same QSO. Exactly the race
    // the command path above re-checks for, for exactly the same reason: key
    // auto-repeat fires well inside an extension round trip.
    if (!mounted || _isLogging || _call != call) return;

    final editingQso = widget.session.editingQso;

    // Viewing a deleted QSO: the save button is disabled, but Enter is
    // also bound to _log — nothing to save until it's restored.
    if (editingQso != null && editingQso.deleted) return;

    if (editingQso != null && _pendingDelete) {
      await _commitStagedDelete(editingQso);
      return;
    }

    // Events have none of the callsign/band/mode fields the checks below
    // exist for — save them straight from the inline editor's state.
    if (editingQso != null && editingQso.isEvent) {
      await _saveEvent(editingQso);
      return;
    }

    // A contact needs a band or a frequency (HALO-24). On a fresh install
    // nothing has ever set either — `RadioService` has no stored VFO, so
    // `vfoA` is empty — and every gate below looks only at the callsign, so
    // the QSO would be written with both null. That is worse than an
    // incomplete record: the ADIF exporter emits BAND only when there is one
    // and FREQ only when it's non-zero, so the contact leaves carrying
    // neither, and LoTW, QRZ and POTA all reject it — which the operator
    // discovers long after the station is gone. The `Band???` pill summary is
    // the only existing signal, and it's passive.
    //
    // So refuse, say so, and open the Radio control, which focuses its
    // frequency field (`_expandedFocusFor`) — the answer is one number away,
    // and the focus ladder is unchanged. The message rides the same
    // `_command.message` channel a command's error does, so it renders in the
    // information area right above the fields (`_buildInfoArea`), never as a
    // toast over the logging UI (docs/design/user-interface.md).
    //
    // Placed here deliberately: below the delete branches, so a QSO already
    // logged without a band can still be deleted without first being
    // repaired; above the stacked-call branch, so that path is covered too;
    // and gated on `_canLog` so it only speaks up when there was actually
    // something to log rather than shouting at an empty or half-typed field.
    // Editing an existing QSO is covered on purpose — an edit is exactly the
    // moment to repair one of the bandless records this bug already created.
    if (_canLog && _radio.freq == null && _radio.band == null) {
      // A confirm-clear timer from an earlier command would wipe this moments
      // after it appears — same reasoning as the command error branches.
      _command.showError(t.loggingControls.bandOrFreqRequired);
      _onSelectControl('radio');
      return;
    }

    // Enter Sends Messages, after every gate a plain Enter would stop at —
    // so a thanks is never keyed for a contact the band check then refuses —
    // and only while composing: an edit is a correction, not an exchange.
    if (fromEnter && editingQso == null) {
      if (widget.session.enterSends?.call() case final esm? when _enterSendsMessages(esm)) return;
    }
    final logged = _esmLogged;
    _esmLogged = null;

    if (!_canLog) {
      logged?.complete(null);
      // Pointing the operator at the field they have to fix — but only when
      // they are here to see it. A spot that cannot be logged (no usable
      // callsign) must not answer a gesture made on the spots list by raising
      // a keyboard over it.
      if (focusCall) _callFocus.requestFocus();
      return;
    }
    List<Qso>? added;
    try {
      added = await _saveContact(editingQso, focusCall: focusCall);
    } finally {
      // What an ESM thanks renders against: the first contact as saved, and
      // the entry as the save left it — wiped, and the rest of a stack back
      // in the field. Completed whatever happens, or the thanks waits on it
      // forever. A throw building it still goes up from here, after the
      // completion.
      if (logged != null) {
        EsmLogged? after;
        try {
          if (added != null && added.isNotEmpty && mounted) {
            after = (qso: added.first.data, next: _withCallField(_draft.toData(), _callText.templateCalls));
          }
        } finally {
          logged.complete(after);
        }
      }
    }
  }

  Future<void> _commitStagedDelete(Qso editingQso) async {
    _isLogging = true;
    try {
      await widget.log.qsosRepository.softDelete(editingQso);
    } catch (e, stack) {
      // The row is untouched and the delete stays staged — say so and let
      // the operator retry or cancel, instead of the editor silently
      // closing over a QSO that never actually deleted.
      _reportWriteFailure(e, stack, delete: true);
      return;
    } finally {
      _isLogging = false;
    }
    widget.log.onQsoDeleted?.call(editingQso);
    widget.session.onEditCanceled?.call();
  }

  /// An event row saved straight from the inline editor's state — events
  /// have none of the callsign/band/mode fields the contact path checks.
  Future<void> _saveEvent(Qso editingQso) async {
    _isLogging = true;
    try {
      await widget.log.qsosRepository.update(
        Qso(uuid: editingQso.uuid, operationUuid: widget.log.operation.uuid, data: _eventDataForSave(editingQso)),
        basedOn: editingQso,
      );
    } catch (e, stack) {
      // Editor stays open with the typed values — nothing committed.
      _reportWriteFailure(e, stack);
      return;
    } finally {
      _isLogging = false;
    }
    widget.session.onEditCanceled?.call();
  }

  /// The contact — one QSO per call of a list or a stack segment, or the
  /// edited record updated in place with any calls added to it logged
  /// fresh. Everything up to here has already refused what cannot log.
  /// The contacts added, as saved and in order — null when a write failed and
  /// the entry was left for the operator to retry. An edited record is
  /// updated, not added, so it is not among them.
  Future<List<Qso>?> _saveContact(Qso? editingQso, {required bool focusCall}) async {
    _isLogging = true;
    try {
      // A comma-separated call list logs one QSO per call, all sharing the
      // same other attributes, with each successive one's time 5 seconds
      // after the last (issue #7) — a single call is just a one-item list,
      // so `baseData`'s own startAtMillis/editingQso.startAtMillis is
      // preserved exactly for that common case.
      //
      // Call stacking (issue #7) feeds the same path: "//" picks ONE segment
      // out of the stack (which may itself be a comma list) and logs only
      // its calls, then leaves the rest of the stack in the field below.
      // Everything else is identical to a typed list, deliberately — no
      // information carries over between stacked calls either way.
      final added = <Qso>[];
      final stacked = editingQso == null ? _callText.pickStackedCall() : null;
      final calls = stacked?.calls ?? _callList;
      final isList = calls.length > 1;
      // `their.call` for the whole batch comes from `dataFor` below, but the
      // cached lookup only rides along when [QsoDraft.toData] is asked
      // about the call it was made for — the raw stacked field text never
      // matches it.
      final baseData = _draft.toData(callOverride: stacked?.calls.first);
      final baseStartAtMillis = (baseData['startAtMillis'] as int?) ?? nowMillis();

      // The record being edited (index 0, when editing) survives untouched
      // even once more calls are added to its list — same as an ordinary
      // single-call edit, no fresh lookup, nothing suppressed. Every other,
      // newly-added entry in a multi-call list is saved bare and handed to
      // `enqueueLookup` (below) for its own fresh, independent background
      // lookup, instead of inheriting whatever single guessed/looked-up
      // name/grid was cached for a different call — and instead of blocking
      // the save on N sequential network lookups (a stall with no network).
      // A manually entered grid override is more often a station-wide
      // correction, so it's fine for that to still apply to every new
      // entry — but a manually entered name is specific to whoever the
      // override was actually typed for, so it isn't duplicated onto a
      // different, newly-added call.
      Map<String, dynamic> dataFor(String call, int index) {
        final keepOriginal = !isList || (editingQso != null && index == 0);
        return {
          ...baseData,
          // The displayed serial belongs to the FIRST call only — that is the
          // one number the operator actually read out. Everyone after it in the
          // list got the next numbers in the series, so strip the field and let
          // the sequence issue them at commit; without this the whole list logs
          // under one serial.
          if (index > 0) 'refs': _exchange.refsWithoutSerials(baseData['refs']),
          'their': {
            if (keepOriginal) ...?(baseData['their'] as Map<String, dynamic>?),
            'call': call,
            'sent': _rstOrDefault(_rcvdController.text.trim()),
            if (keepOriginal && _draft.theirNameOverride != null) 'name': _draft.theirNameOverride,
            // Same normalization as [QsoDraft.toData]: canonical Maidenhead
            // casing for grids, uppercase for states.
            if (_draft.gridTouched) 'grid': normalizeGrid(_gridController.text.trim()),
            if (_draft.stateTouched) 'state': _stateController.text.trim().toUpperCase(),
          },
          'startAtMillis': baseStartAtMillis + index * 5000,
        };
      }

      if (editingQso != null) {
        try {
          // `basedOn` is the snapshot this edit was composed from: if a sync
          // pull moved the row while the editor sat open, only the fields
          // actually edited here overwrite it (see mergeConcurrentEdit).
          await widget.log.qsosRepository.update(
            Qso(uuid: editingQso.uuid, operationUuid: widget.log.operation.uuid, data: await _decorated(dataFor(calls.first, 0))),
            basedOn: editingQso,
          );
        } catch (e, stack) {
          // Nothing committed — the editor stays open with every typed value.
          _reportWriteFailure(e, stack);
          return null;
        }
        for (var i = 1; i < calls.length; i++) {
          // The base data carries the edited QSO's own uuid (baseData came
          // from its record) — strip it so add() generates a fresh one for
          // this new QSO instead of colliding with the original.
          final data = dataFor(calls[i], i)..remove('uuid');
          final Qso qso;
          try {
            qso = await widget.log.qsosRepository.add(
              widget.log.operation.uuid,
              await _decorated(_exchange.withSerialConflicts(data)),
              serialSequences: _exchange.serialSequences,
            );
          } catch (e, stack) {
            // Calls before [i] are already committed: keep the edited
            // record's own call plus only the still-unlogged ones in the
            // field, so retrying the Enter can't log the committed ones
            // twice.
            _callController.text = [calls.first, ...calls.sublist(i)].join(',');
            _reportWriteFailure(e, stack);
            return null;
          }
          _exchange.releaseCommittedSerials(qso);
          added.add(qso);
          widget.log.onLogged?.call(qso);
          widget.lookups.enqueueLookup?.call(qso);
        }
        widget.session.onEditCanceled?.call();
      } else {
        // Flush any pending debounced frequency push first, so a value
        // typed just before hitting Enter/Log is reflected in both the VFO
        // and this QSO, rather than only landing after the fact.
        _radio.flushPendingPush();
        for (var i = 0; i < calls.length; i++) {
          final Qso qso;
          try {
            qso = await widget.log.qsosRepository.add(
              widget.log.operation.uuid,
              await _decorated(_exchange.withSerialConflicts(dataFor(calls[i], i))),
              serialSequences: _exchange.serialSequences,
            );
          } catch (e, stack) {
            // Nothing is wiped on failure — the fields keep every typed
            // value. With calls already committed (i > 0), the field is
            // rewritten to only the unlogged ones (plus the untouched rest
            // of a stack), cursor on them, so retrying the Enter can't log
            // the committed calls twice.
            if (i > 0) {
              final unlogged = calls.sublist(i).join(',');
              final text = stacked == null || stacked.remainder.isEmpty ? unlogged : '$unlogged//${stacked.remainder}';
              _callController.value = TextEditingValue(
                text: text,
                selection: TextSelection.collapsed(offset: unlogged.length),
              );
            }
            _reportWriteFailure(e, stack);
            return null;
          }
          _exchange.releaseCommittedSerials(qso);
          added.add(qso);
          widget.log.onLogged?.call(qso);
          widget.lookups.enqueueLookup?.call(qso);
        }
        _time.advancePast(baseStartAtMillis);
        _wipe(focusCall: focusCall);
        // The un-logged rest of the stack goes straight back into the
        // now-empty field — whole, so its pills are not held as being typed.
        if (stacked != null) _callController.text = _lastCallText = stacked.remainder;
      }

      // A single rescoring pass after the whole batch, not a score check per
      // call — the on-screen scoring pills already only ever reflect the
      // cursor's own call (see `CallLookupModel.scheduleScore`/`_callAtCursor`).
      if (isList) widget.log.onCallListLogged?.call();
      return added;
    } finally {
      _isLogging = false;
    }
  }
}

/// [qso] as a template reads it: plus `callField`, the calls
/// [CallFieldText.templateCalls] names, which `qso.call` / `qso.nextCall` /
/// `qso.nextPartial` render from — and `call` split by whether it reads as a
/// callsign yet, into `fullCall` and `partial`, so a message can answer a
/// station and ask a partial back ("KR?") without keying one as the other.
/// Only for a draft leaving the panel to be rendered — `callField` is not
/// QSON, and a record never carries it.
Map<String, dynamic> _withCallField(Map<String, dynamic> qso, TemplateCalls calls) {
  final full = calls.call.isNotEmpty && looksLikeCallsign(calls.call);
  return {
    ...qso,
    'callField': {
      'call': calls.call,
      'fullCall': full ? calls.call : '',
      'partial': full ? '' : calls.call,
      'nextCall': calls.nextCall,
      'nextPartial': calls.nextPartial,
    },
  };
}
