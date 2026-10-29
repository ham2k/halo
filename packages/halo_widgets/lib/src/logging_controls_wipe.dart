// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Escape, the panel's chords, and the info row's second button: wipe and
// its undo, a staged delete and its undo, revert, and restoring a deleted
// QSO. Its own file for size alone; it is part of the panel's library and
// reaches its state directly.

part of 'logging_controls.dart';

extension _WipeAndUndo on _LoggingControlsState {
  /// Escape backs out of the innermost thing that's open, one layer per
  /// press: an options menu, then an expanded secondary control, then the
  /// editing session. It stops there: a QSO being composed is never wiped by
  /// Escape — that is Alt+W ([_handleChord]) or the wipe button.
  ///
  /// It must not blank the read-only view of a staged-delete or deleted QSO —
  /// the fields are the record's only display and can't be repopulated
  /// without reselecting it. When editing an existing QSO it discards any
  /// unsaved changes and ends the editing session entirely
  /// (ham2k/halo-dist#199), unlike Revert, which discards changes and
  /// stays in edit mode.
  void _handleEscape() {
    if (_fieldsLocked) return;
    if (widget.session.escapeClaimed?.call() ?? false) return;
    // An open exchange menu takes the first Escape, and takes it whether or not
    // the operator has touched the highlight: with a menu up, Escape means "not
    // that" — and what Escape does below throws away work (a discarded edit, a
    // deselected QSO). Losing a half-made correction to a keystroke aimed at a
    // dropdown is not a recoverable mistake.
    if (_exchange.menuOpen) {
      _exchange.dismissMenu();
      return;
    }
    // An open secondary control takes the next one, and goes all the way back
    // to the main fields — where Down and Enter stop at the pill, Escape is
    // the "out of here entirely" gesture. Nothing is thrown away by closing a
    // control (its value is already committed), so this is safe to take
    // priority over the destructive layers below.
    if (_selectedControlKey != null) {
      _onSelectControl(null);
      return;
    }
    if (widget.session.editingQso != null) widget.session.onEditCanceled?.call();
  }

  /// The panel's modifier chords, which are the second button's gestures on
  /// the keyboard: Alt+W wipes the QSO being composed, and Cmd/Ctrl+Z takes
  /// back a wipe (while its undo offer lasts) or a staged delete.
  ///
  /// A key handler rather than a `CallbackShortcuts` entry because Cmd/Ctrl+Z
  /// must stay the focused field's own text undo whenever there is nothing
  /// here to take back, and a shortcut binding claims its key unconditionally.
  /// Revert-changes is deliberately not on it for the same reason: while
  /// editing, the operator reaching for Cmd/Ctrl+Z means the last keystroke,
  /// not the whole record.
  ///
  /// Alt+W (unless rebound — `logging.wipe`) resets the whole draft either
  /// way: with something composed it is the wipe button's path and its undo
  /// offer, and with nothing composed it
  /// still clears what [QsoDraft.hasComposedValues] does not count — a report,
  /// a power entry, a pending frequency edit — which no other gesture resets.
  /// It is claimed in every state, and on key repeat too: unclaimed, macOS
  /// types Option+W into the focused field as "∑".
  ///
  /// Cmd/Ctrl+Z restores a wipe only onto a form with nothing composed since.
  /// The undo offer outlives the operator starting the next contact, and a
  /// Cmd/Ctrl+Z aimed at a typo in it would otherwise replace that contact
  /// with the wiped one, with nothing left to take THAT back.
  ///
  /// Also reachable through [LoggingControlsController.handleChord]: a staged
  /// delete disables every field here, so the event cannot arrive by focus.
  KeyEventResult _handleChord(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (keyBindings.value.claim('logging.wipe', event) != null) {
      if (event is KeyDownEvent && widget.session.editingQso == null && !_fieldsLocked) {
        if (_draft.hasComposedValues) {
          _handleWipeTap();
        } else {
          _time.leaveForWipe();
          _wipe();
        }
      }
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    final command = keyboard.isMetaPressed || keyboard.isControlPressed;
    if (keyboard.isShiftPressed || keyboard.isAltPressed || !command) return KeyEventResult.ignored;
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyZ) {
      // Not while the staged delete is being committed: un-staging then would
      // show Delete again over a record that is already on its way out.
      if (_pendingDelete && !_isLogging) {
        _setStateFromPart(() => _pendingDelete = false);
        return KeyEventResult.handled;
      }
      if (widget.session.editingQso == null && _draft.undoSlot.value != null && !_draft.hasComposedValues) {
        _restoreFromUndoSlot();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// [focusCall] false leaves the focus where it is — for a wipe the operator
  /// did not ask for from this panel (a slid spot row closing, say), or one
  /// that ends a gesture made on another surface, where pulling focus here
  /// would raise the mobile keyboard over the list they are actually working.
  ///
  /// [inPlace] also leaves the command line's message standing — for a wipe
  /// nothing in this panel asked for (a QSY), which must not eat the
  /// confirmation of the command that moved the radio.
  ///
  /// No wipe closes an open control (docs/design/logging-fields.md § Focus
  /// and the secondary controls).
  void _wipe({bool focusCall = true, bool inPlace = false}) {
    // The draft is gone, and so is its hold on a number. After a commit this
    // is a no-op — the log path released with the committed numbers already.
    widget.log.serialNumbers?.release(widget.log.operation.uuid);
    _suggestedCall = null;
    _suggestionWasTentative = false;
    _esmAnsweredCall = null;
    _radio.settlePendingFreqEdit();
    _callController.clear();
    _clearRSTs();
    _gridController.clear();
    _stateController.clear();
    _draft.clear();
    _lookup.cancelLookup();
    _lookup.reset();
    _refs.clear();
    _exchange.clear();
    _notesController.clear();
    _time.manualStartAtMillis = null;
    _reseedOpenTime();
    _radio.clearPowerEntry();
    // The VFO's power is ambient, not composed — a wipe drops what the entry
    // stated and goes back to mirroring it, the way the Radio control does.
    _seedFromRadioService();
    if (focusCall) _callFocus.requestFocus();
    // Only the message stands: what the command line kept about the text
    // typed is the wiped entry's, as it is in every other wipe.
    if (inPlace) return _setStateFromPart(_command.forgetRetained);
    _setStateFromPart(_command.reset);
    _command.keystroke();
  }

  /// Stashes the in-progress new QSO into the undo slot (for 5 seconds,
  /// even if the user keeps typing — see `_buildWipeOrEditButton`), then
  /// wipes the form.
  void _handleWipeTap() {
    _stashForUndo(_draft.toData());
    _time.leaveForWipe();
    _wipe();
  }

  /// The VFO left the one the entry was started on
  /// ([RadioControlModel.qsyFromStart]) — at the radio, or from anything but
  /// the entry's own Radio control and More pane: a spot row, a program on
  /// the CAT server, a command. The entry was for the station back there, so
  /// it is wiped, with the wipe button's undo offer; the undo tunes back to
  /// [startedOn] with it.
  ///
  /// It leaves manual time entry as the operator's wipe does, and its undo
  /// goes back into it — but leaves focus alone: the gesture was made at the
  /// radio, not this panel.
  void _wipeOnQsy(Vfo startedOn) {
    // Dropped, not flushed: a frequency still being typed belongs to the
    // entry being wiped, and flushing it would tune the radio back off where
    // it was just taken.
    _radio.cancelPendingPush();
    // This stash replaces any earlier wipe's without expiring it, and undo
    // would otherwise resume that wipe's manual time on this entry.
    _time.forgetWipe();
    _time.leaveForWipe();
    _stashForUndo({..._draft.toData(), 'freq': startedOn.freq, 'band': startedOn.band, 'mode': startedOn.mode});
    // As a seed, not an edit: the wipe writes the VFO's new frequency into
    // the field, which read as typed stops the panel following the radio and
    // pushes that frequency back at it five seconds on.
    _draft.populate(() => _wipe(focusCall: false, inPlace: true));
  }

  void _stashForUndo(Map<String, dynamic> data) {
    // Beside the draft, never inside it: [QsoDraft.toData] writes the refs
    // and not which of them a lookup proposed, and the wipe after this is
    // what forgets that.
    _undoGuesses = _refs.takeGuessSnapshot();
    _draft.undoSlot.set(
      data,
      onExpire: () {
        _undoGuesses = null;
        _time.forgetWipe();
        if (mounted) _setStateFromPart(() {});
      },
    );
  }

  void _restoreFromUndoSlot() {
    final data = _draft.undoSlot.take();
    if (data == null) return;
    final guesses = _undoGuesses;
    _undoGuesses = null;
    _time.undoWipe();
    _restoreDraft(data, guesses: guesses);
    // The entry's frequency, band and mode come back with it, and the radio
    // is tuned back to them: an entry is for the station where it was
    // started, and one restored onto another frequency would be logged there.
    _radio.pushVfo();
  }

  /// Puts one of the draft's own records ([QsoDraft.toData]) back — a wipe
  /// undone, or a detour through an earlier contact returned from. One
  /// method for both, or the next rule added to one path is missed by the
  /// other.
  void _restoreDraft(Map<String, dynamic> data, {GuessProvenance? guesses}) {
    _draft.populate(() {
      _applyFieldsFromData(data, restoringDraft: true);
      // Before the lookup below, and before any correction to the callsign:
      // the refs are back but nothing yet says which of them a lookup put
      // there, and an unmarked guess is never taken back.
      if (guesses != null) _refs.restoreGuesses(guesses);
      _time.manualStartAtMillis = data['startAtMillis'] as int?;
      _reseedOpenTime();
      _setStateFromPart(() {});
    });
    // The populate bracket suppressed _onCallChanged's own _scheduleLookup()/
    // _lookup.scheduleScore() calls above (population isn't the user typing),
    // and the wipe or the reset before this cleared the lookup cache and score
    // notices — without these a restored call sits unlooked-up and without
    // its dupe/New-* pills until the operator edits the call field again.
    _scheduleLookup();
    _lookup.scheduleScore();
  }

  /// Restores (undeletes) the deleted QSO being viewed, then ends the
  /// editing session — the caller clears its selection and the list row
  /// loses its strikethrough via the repository watch.
  Future<void> _handleRestoreTap(Qso editingQso) async {
    // Restore sits OUTSIDE `_fieldsLocked` on purpose — a deleted QSO is
    // always locked, and undoing that is the button's whole job — so the
    // write policy has to be consulted here in its own right.
    final refusal = _writeRefusal;
    if (refusal != null) return;
    if (_isLogging) return;
    _isLogging = true;
    try {
      await widget.log.qsosRepository.undelete(editingQso);
      if (!mounted) return;
      widget.log.onQsoUndeleted?.call(editingQso);
      widget.session.onEditCanceled?.call();
    } finally {
      _isLogging = false;
    }
  }

  /// Whether the fields being edited differ from the stored record — drives
  /// the "revert changes" vs. "delete" state of the info row's second
  /// button while editing.
  bool _qsoDataChanged() {
    final editingQso = widget.session.editingQso;
    if (editingQso == null) return false;
    if (editingQso.isEvent) return !qsoDataEquivalent(_eventDataForSave(editingQso), editingQso.data);
    return _draft.differsFrom(editingQso);
  }

  /// Which action the info row's second button is right now, as a
  /// [LoggingActionButton] sized to the log button.
  Widget _buildWipeOrEditButton(ThemeData accentTheme) {
    final editingQso = widget.session.editingQso;
    final IconData icon;
    final String? actionLabel;
    final VoidCallback? onPressed;

    if (editingQso == null) {
      if (_draft.undoSlot.value != null) {
        icon = MdiIcons.undo;
        actionLabel = t.loggingControls.undo;
        onPressed = _restoreFromUndoSlot;
      } else {
        icon = MdiIcons.backspaceOutline;
        actionLabel = t.loggingControls.wipe;
        onPressed = _draft.hasComposedValues ? _handleWipeTap : null;
      }
    } else if (editingQso.deleted) {
      // An already-deleted QSO (selected via the "show deleted QSOs"
      // toggle) — one tap restores it immediately (ham2k/halo-dist#59);
      // no staged-until-save step, since restoring isn't destructive.
      icon = MdiIcons.deleteRestore;
      actionLabel = t.loggingControls.restore;
      // Disabled rather than merely refused: restore is the one action that
      // deliberately survives `_fieldsLocked` (a deleted QSO is always
      // locked), so without this it is the only enabled control on an
      // otherwise read-only form, and tapping it would do nothing.
      onPressed = _writeRefusal != null ? null : () => _handleRestoreTap(editingQso);
    } else if (_pendingDelete) {
      icon = MdiIcons.undo;
      actionLabel = t.loggingControls.undoDelete;
      onPressed = () => _setStateFromPart(() => _pendingDelete = false);
    } else if (_qsoDataChanged()) {
      icon = MdiIcons.undo;
      actionLabel = t.loggingControls.revert;
      // Reset THEN populate, the pairing every other load of a record uses:
      // the values alone are not the edit. A touched flag left standing is
      // still an edit as far as the record is concerned, so the button would
      // go on reading Revert and a save would write the field back — and for
      // the grid, the square's centre as a coordinate the operator never
      // entered.
      onPressed = () {
        _resetEditingSessionState();
        _populateFromEditingQso(editingQso);
      };
    } else {
      icon = MdiIcons.trashCanOutline;
      actionLabel = t.common.delete;
      onPressed = () => _setStateFromPart(() => _pendingDelete = true);
    }

    return LoggingActionButton(
      diameter: _editButtonDiameter ?? 44,
      icon: icon,
      label: actionLabel,
      onPressed: onPressed,
      color: accentTheme.colorScheme.tertiary,
    );
  }
}
