// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's secondary control strip: what each control opens
// into, opening and closing one, the specs the row is built from, and the
// More pane and the strip's settings. Its own file for size alone; it is
// part of the panel's library and reaches its state directly.

part of 'logging_controls.dart';

/// SO2R's strip: Time, the two radios, Spotting and the keyer, and nothing
/// else.
const _so2rStripKeys = {'time', 'radio', 'spotting', 'keyer'};

extension _ControlStrip on _LoggingControlsState {
  /// The field a control expands *into* — what the operator opened it to type
  /// in. Null for a control with nothing to type (Spotting with its comment
  /// hidden is just a button; `more` opens a pane instead of expanding), which
  /// leaves focus alone rather than yanking it somewhere useless.
  FocusNode? _expandedFocusFor(String? key) {
    if (key == null) return null;
    switch (key) {
      case 'time':
        return _time.timeFocus;
      // Frequency, not the Band dropdown: it is the field you actually type
      // into, and on touch platforms the dropdowns refuse focus outright.
      case 'radio':
        return _radio.freqFocus;
      case 'radioB':
        return widget.so2r?.link.radioB?.freqFocus;
      case 'power':
        return _radio.powerFocus;
      case 'spotting':
        return _spotting.state.showComment ? _spotting.commentFocus : null;
      case 'notes':
        return _notesFocus;
      default:
        // Every remaining control is an extension's. Only `refList` builds a
        // field to focus — the same condition that gave it a chip.
        return _refs.isRefListControl(key) ? _refs.focusFor(key) : null;
    }
  }

  /// Every focusable field inside [key]'s expanded content that Tab/Shift-Tab
  /// step through before moving on to a neighbouring control, in the same
  /// left-to-right order they're laid out on screen. Distinct from
  /// [_expandedFocusFor]: that one is the SINGLE field opening the control
  /// focuses (Radio's is Frequency, not first here — landing there on the
  /// way in from Tab would skip Band entirely).
  ///
  /// Cursor keys do NOT walk this list field by field — see
  /// the ladder's cursor-key crossing — so Band and Mode being here only matters for
  /// Tab/Shift-Tab, which do still visit them.
  List<(FocusNode, TextEditingController)> _expandedFieldOrderFor(String key) {
    switch (key) {
      case 'time':
        return [(_time.timeFocus, _time.timeController), (_time.dateFocus, _time.dateController)];
      case 'radio':
        return [(_radio.bandFocus, _radio.bandController), (_radio.freqFocus, _radio.freqController), (_radio.modeFocus, _radio.modeController)];
      case 'radioB':
        final radioB = widget.so2r?.link.radioB;
        return radioB == null
            ? const []
            : [(radioB.bandFocus, radioB.bandController), (radioB.freqFocus, radioB.freqController), (radioB.modeFocus, radioB.modeController)];
      case 'power':
        return [(_radio.powerFocus, _radio.powerController)];
      case 'spotting':
        return _spotting.state.showComment ? [(_spotting.commentFocus, _spotting.commentController)] : const [];
      case 'notes':
        return [(_notesFocus, _notesController)];
      default:
        return _refs.isRefListControl(key) ? [(_refs.focusFor(key), _refs.controllerFor(key))] : const [];
    }
  }

  // ── The focus ladder: [LoggingFocusLadder] (logging_controls_ladder.dart).
  // What stays with the panel is what the ladder cannot know: which fields
  // are on the row (logging_controls_fields.dart), and, here, what each
  // control opens into and opening a control.

  /// Shows (or, with null, hides) a control without moving focus — the
  /// ladder's crossings land on the field they chose; [LoggingFocusLadder
  /// .openControl] focuses after this. An event row refuses every control but
  /// Time here as well as on a tap: a Tab across the strip must not expand a
  /// control whose chip is disabled.
  void _showControl(String? key) {
    if (key != null && _controlDisabled(key)) return;
    _setStateFromPart(() {
      if (key == 'time' && _selectedControlKey != 'time') _time.seedFields();
      _selectedControlKey = key;
    });
  }

  /// Whether [key]'s chip is disabled: every control but Time on an event
  /// row, and a host control that says so of itself (the keyer in a Digital
  /// mode). The one rule for it: the chip is drawn disabled from this, the
  /// keyboard's walk leaves it out, and the keyboard and the host's open
  /// requests are refused by it, as a tap on the chip is.
  bool _controlDisabled(String key) => (_editingEvent && key != 'time') || widget.strip.hostControls.any((host) => host.key == key && !host.spec().enabled);

  /// The one thing that closes a control the operator did not: its chip
  /// turning disabled under it, which leaves nothing open to type into.
  void _closeDisabledControl() {
    if (_selectedControlKey case final key? when _controlDisabled(key)) _selectedControlKey = null;
  }

  /// An open Time control's fields are written when it opens, so one that
  /// stays open while the entry is wiped, replaced or loaded is written
  /// again here — after the entry's own time has been set — or it shows the
  /// time of the contact that just left.
  void _reseedOpenTime() {
    if (_selectedControlKey == 'time') _time.seedFields();
  }

  /// A tap on a chip, or the keyboard arriving on one: what a tap means is
  /// the panel's — `more` pops the full-edit pane instead of expanding, and
  /// the chip itself already refuses a tap on an event row
  /// (ChoiceChip.onSelected: null, see _ControlChip), which this repeats for
  /// the keyboard paths. Everything else is the ladder's open and close.
  void _onSelectControl(String? key) {
    if (key != null && _controlDisabled(key)) return;
    if (key == 'more') {
      _openMoreEditor();
      return;
    }
    if (key == null) {
      _ladder.closeControl();
    } else {
      _ladder.openControl(key);
    }
  }

  /// Something is logging power for this QSO: the operator put the control
  /// in the row, or the app is capturing it with the rest of the station
  /// info. This is what lets a composed QSO carry a power at all — without
  /// it the field stays empty and nothing is stamped.
  bool get _powerInPlay => _catalog.powerVisible || widget.radio.trackingPower;

  /// The strip's specs, in row order, each carrying the panel's keyboard
  /// policy. Which controls appear is [_catalog]'s call; what each one shows
  /// is its model's.
  List<SecondaryControlSpec> _buildSecondaryControls(ThemeData theme, HaLoColors poloColors) {
    final specs = <SecondaryControlSpec>[];
    final so2r = widget.so2r;
    for (final descriptor in _catalog.visibleControls()) {
      if (so2r != null && !_so2rStripKeys.contains(descriptor.key)) continue;
      switch (descriptor.key) {
        case 'time':
          specs.add(timeControlSpec(_time));
        case 'radio':
          specs.add(
            radioControlSpec(
              _radio,
              theme,
              selected: _selectedControlKey == 'radio',
              freqInputFormatters: [_virtualSpace],
              freqKeyboardType: _decimalKeyboardType,
              onFreqSubmitted: () => _ladder.closeExpandedControl('radio'),
              onPicked: _callFocus.requestFocus,
            ),
          );
          if (so2r?.link.radioB case final radioB?) {
            specs.last = so2rRadioSpec('A', specs.last);
            specs.add(
              so2rRadioSpec(
                'B',
                radioControlSpec(
                  radioB,
                  theme,
                  selected: _selectedControlKey == 'radioB',
                  freqInputFormatters: [_virtualSpace],
                  freqKeyboardType: _decimalKeyboardType,
                  onFreqSubmitted: () => _ladder.closeExpandedControl('radioB'),
                  onPicked: () => so2r!.link.focusSet('B'),
                ),
              ),
            );
          }
        case 'power':
          specs.add(powerControlSpec(_radio, keyboardType: _decimalKeyboardType));
        case 'spotting':
          specs.add(spottingControlSpec(_spotting, theme, selected: _selectedControlKey == 'spotting', onPressed: _focusCallAfterSpotPress));
        case 'notes':
          specs.add(notesControlSpec(theme, controller: _notesController, focusNode: _notesFocus, onChanged: _onNotesChanged));
        case 'more':
          specs.add(moreControlSpec());
        default:
          if (widget.strip.hostControls.where((host) => host.key == descriptor.key).firstOrNull case final host?) {
            specs.add(host.spec());
          } else if (descriptor.activityControl case final control?) {
            specs.add(activityControlSpec(_refs, control, onRefsChanged: _relookupForRefsChanged, decorate: widget.activities.decorateRef));
          }
      }
    }
    final enabled = {for (final spec in specs) spec.key: !_controlDisabled(spec.key)};
    // The strip's keys, for the arrow keys to walk. Recorded from the list
    // actually handed to the row, so the two can't drift apart — and only the
    // enabled ones: a disabled chip takes no focus, and a walk onto one stops
    // dead there.
    _ladder.pillOrder = [
      for (final spec in specs)
        if (enabled[spec.key]!) spec.key,
    ];
    return [for (final spec in specs) _ladder.withKeyboardNavigation(spec, enabled: enabled[spec.key]!)];
  }

  /// The contact's own note. Wider than the other controls' fields — a note
  /// is a sentence, not a value — and explicitly mixed-case, like Name and
  /// the spot comment: free prose, not logging data.
  /// Keeps the QSO's `notes` in step with the field ([QsoDraft.setNote]),
  /// and the chip's check mark in step with both. The `setState` is also
  /// what pushes the draft up to the host: the post-frame notify in [build]
  /// runs on every rebuild.
  void _onNotesChanged(String value) => _setStateFromPart(() => _draft.setNote(value));

  // ---- "More" full-edit pane ----
  //
  // The form's shape — its sections, its fields and the rules about which of
  // them appear — lives in qso_edit_pane.dart. What is left here is applying
  // what comes back, which is the half that needs the controllers and the
  // override maps.

  Future<void> _openMoreEditor() async {
    // Captured so the Save handler below can tell "the user actually edited
    // Grid/State in this pane" from "the pane merely displayed whatever
    // was already there" — the latter must not turn a passive lookup guess
    // into a deliberately-touched, sticky value (see _draft.gridTouched's doc).
    final gridBeforePane = _gridController.text.trim();
    final stateBeforePane = _stateController.text.trim();
    // Same for date/time: saving the live clock the pane merely showed must
    // not stop it in manual time entry.
    final (dateBeforePane, timeBeforePane) = _time.shownFields;
    // What the contact itself says, override included — never the operation's
    // stand-in, which is only ever a placeholder here.
    final ourBeforePane = {...?asQsonMap(widget.session.editingQso?.data['our']), ..._draft.ourExtra};
    final operatorBeforePane = (asQsonString(ourBeforePane['operatorCall']) ?? '').trim();
    final positionBeforePane = (asQsonString(ourBeforePane['multiIdentifier']) ?? '').trim();
    // The same displayed-vs-edited distinction once more, for every `their`
    // field the pane owns outright: a value merely shown must not be recorded
    // as an override, or a contact opened and saved would take its lookup's
    // guesses as entered values and stop tracking the lookup.
    final theirBeforePane = {...?asQsonMap(widget.session.editingQso?.data['their']), ..._draft.theirExtra};
    final theirValuesBeforePane = theirPaneValues(theirBeforePane);

    _editPaneOpen = true;
    final pane = showQsoEditPane(
      context,
      gridBeforePane: gridBeforePane,
      formDefinition: buildQsoEditFormDefinition(
        defaultOperatorCall: widget.prefs.defaultOperatorCall,
        defaultPosition: widget.prefs.defaultPosition,
        showPositionField: widget.prefs.showPositionField,
        their: asQsonMap(widget.session.editingQso?.data['their']),
        guess: _currentGuess,
        rstPaneKeyOrder: _rstPaneKeyOrder,
        rstPlaceholder: _rstPlaceholder,
        powerShown: _draft.powerShown,
        composing: widget.session.editingQso == null,
        currentMode: _radio.modeForEditing,
      ),
      initialState: {
        'theirCall': _call,
        // Entered name only (not the `theirName` getter, which coalesces in the
        // guess) so a guessed-only name shows as the placeholder above instead
        // of being pre-filled — and merely viewing the pane never promotes a
        // passive guess to a sticky entered value.
        'theirName': _draft.theirNameOverride ?? asQsonString(asQsonMap(widget.session.editingQso?.data['their'])?['name']) ?? '',
        'theirGrid': gridBeforePane,
        'theirState': stateBeforePane,
        'sent': _sentController.text.trim(),
        'rcvd': _rcvdController.text.trim(),
        'freq': _radio.freq,
        'band': _radio.band ?? '',
        'mode': _radio.modeForEditing,
        'power': _draft.powerWatts,
        'date': dateBeforePane,
        'time': timeBeforePane,
        'notes': (_draft.extra['notes'] as String?) ?? '',
        'operatorCall': operatorBeforePane,
        if (widget.prefs.showPositionField) 'multiIdentifier': positionBeforePane,
        ...theirValuesBeforePane,
        // Shown, never taken: `theirEntity` is `disabled`, and the save
        // handler below reads nothing back out of it.
        'theirEntity': theirEntityDisplay(asQsonMap(widget.session.editingQso?.data['their']), _currentGuess) ?? '',
      },
    );
    final result = await pane.whenComplete(() {
      _editPaneOpen = false;
      _rebuildForNumbersRow();
    });
    if (result == null || !mounted) return;

    // Same as the setVfo command dispatch: a deliberate pane Save, not
    // raw typing — push immediately rather than via the frequency field's
    // debounce, and only while composing (rule: editing an existing QSO
    // applies changes to the QSO, never the VFO).
    _draft.populate(() {
      _setStateFromPart(() {
        _callController.text = ((result['theirCall'] as String?) ?? '').toUpperCase();
        final name = (result['theirName'] as String?)?.trim();
        _draft.theirNameOverride = (name == null || name.isEmpty) ? null : name;
        final grid = normalizeGrid(((result['theirGrid'] as String?) ?? '').trim());
        final state = ((result['theirState'] as String?) ?? '').trim().toUpperCase();
        // Normalized comparison, not raw string inequality: the pane's
        // uppercase formatter rewrites the WHOLE field on any keystroke, so
        // a net no-op edit over a lookup-guessed 'FN31pr' would come back
        // 'FN31PR' and a raw compare would falsely promote the passive guess
        // to a sticky touched override (see [QsoDraft.gridTouched]). Case is not
        // a deliberate edit; only a real value change is.
        // Through [QsoDraft.markGridTouched], not a bare flag: the pane's on-screen
        // coordinate clear runs on BLUR (`FormRenderer` hangs `onChange` off the
        // focus node), and `submit()` snapshots its values before the unfocus it
        // triggers has been delivered — so a grid typed and then saved with
        // Enter, or with the field still focused, reaches here with the
        // coordinate fields never blanked and no override recorded to blank
        // them. The drop has to happen on the value that was actually saved.
        if (grid != normalizeGrid(gridBeforePane)) _draft.markGridTouched();
        _draft.stateTouched = _draft.stateTouched || state != stateBeforePane.toUpperCase();
        _gridController.text = grid;
        _stateController.text = state;
        _lookup.entriesEdited();
        _sentController.text = (result['sent'] as String?) ?? '';
        _rcvdController.text = (result['rcvd'] as String?) ?? '';

        final freq = result['freq'];
        if (freq is num) {
          _radio.setFrequency(freq.toDouble());
        } else {
          final band = (result['band'] as String?)?.trim();
          _radio.setBand((band == null || band.isEmpty) ? null : band);
        }

        // Resolved against the freq/band the pane just wrote above, like every
        // other mode PICK, and never skipped for an untouched select: the pane
        // can move the frequency, and an untouched `SSB` has to re-derive
        // against where the contact now is. Lossless because the rule is total
        // — see docs/design/cat.md's "Showing it back".
        final panedMode = result['mode'] as String?;
        if (panedMode != null) _radio.mode = _radio.resolveMode(panedMode);

        // Written even when the pane didn't offer the field: absent means the
        // form dropped it, and `result` then carries a null this must not read
        // as the operator clearing a value they were never shown.
        if (result.containsKey('power')) {
          final power = result['power'];
          _radio.powerController.text = power is num ? '$power' : '';
        }

        final stamped = paneStartAtMillis(result, dateBeforePane, timeBeforePane);
        if (stamped != null) _time.takeTime(stamped);

        final notes = ((result['notes'] as String?) ?? '').trim();
        _draft.setNote(notes);
        // The Notes control shows the same value; without this it would go on
        // showing what the contact said before the pane was opened.
        _notesController.text = notes;

        _draft.theirExtra.addAll(theirPaneOverrides(result, theirValuesBeforePane));

        // Recorded only where the pane actually changed them, so a contact
        // merely opened and saved keeps taking the operation's stamp — and an
        // emptied field records the empty string, which the stamp then leaves
        // alone (it fills what is absent).
        // Compared uppercased on both sides, like the grid two blocks up: the
        // pane's callsign field rewrites the whole field in uppercase, so a
        // record whose stored operator came in lowercase (an ADIF import's
        // OPERATOR, a peer from another client) would otherwise record an
        // override — and read as composed — from merely being opened.
        final operatorCall = ((result['operatorCall'] as String?) ?? '').trim().toUpperCase();
        if (operatorCall != operatorBeforePane.toUpperCase()) _draft.ourExtra['operatorCall'] = operatorCall;
        if (widget.prefs.showPositionField) {
          final position = panePosition(result['multiIdentifier']);
          if (position != positionBeforePane) _draft.ourExtra['multiIdentifier'] = position;
        }

        _time.seedFields();
      });
    });
    if (widget.session.editingQso == null) {
      // Power first: the frequency push notifies, and the seed that follows
      // rewrites the power field from the VFO — which would put the value
      // the pane just returned back to whatever it was before the pane
      // opened, and then commit THAT.
      _radio.commitPower();
      _radio.pushVfo();
    }
  }

  // ---- Secondary control settings (show/hide + reorder) ----

  Future<void> _openControlSettingsDialog() async {
    final result = await showControlSettingsDialog(context, _catalog);
    if (result == null) return;
    widget.strip.onControlsSettingsChanged?.call(result.$1, result.$2);
  }

  /// The Spotting control's button — a spot, or starting or stopping
  /// auto-respotting: either way the next thing to type is a callsign, not
  /// more of a comment. Not on mobile without a
  /// physical keyboard unless the comment already had one up — a tap with
  /// nothing focused must not pop an uninvited one (logging-fields.md).
  void _focusCallAfterSpotPress() {
    if (!isMobilePlatform || hardwareKeyboardAttached.value || _spotting.commentFocus.hasFocus) _callFocus.requestFocus();
  }
}
