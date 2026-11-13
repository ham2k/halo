// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Picking a draft suggestion (docs/design/logging-fields.md § Draft
// suggestions): Alt-Y and Shift-Alt-Y walk the list, a tap on the FYI line
// picks out of turn, and walking past the last puts the contact back as it
// stood before the first pick. Its own file for size alone; it is part of
// the panel's library and reaches its state directly.

part of 'logging_controls.dart';

extension _DraftSuggestionPicks on _LoggingControlsState {
  /// What a pick sets, and the walk back puts as it was: all a draft may
  /// carry. Everything else of the contact — the radio, the time, our side —
  /// stays as it stands through the walk.
  static const _setByPicks = {'their', 'refs', 'notes'};

  /// Ties [model] to this set: its taps pick here, and it reads the call
  /// field as it stands.
  void _attachSuggestions(DraftSuggestions? model) {
    if (model == null) return;
    model
      ..onTap = _suggestionTap
      ..call = _callController.text;
  }

  void _detachSuggestions(DraftSuggestions? model) => model?.releaseTap(_suggestionTap);

  bool get _canPickSuggestion => widget.session.editingQso == null && !_fieldsLocked && (widget.session.draftSuggestions?.showing ?? false);

  /// Alt-Y ([step] 1) and Shift-Alt-Y (-1): the next suggestion the line
  /// shows, or the previous, the contact as it stood before the first pick
  /// sitting between the last and the first.
  void _cycleSuggestion(int step) {
    final model = widget.session.draftSuggestions;
    if (model == null || !_canPickSuggestion) return;
    _beginSuggestionCycle();
    final drafts = model.list!.drafts.length;
    final positions = (model.shownCount ?? drafts).clamp(0, drafts) + 1;
    final next = ((model.picked ?? -1) + 1 + step) % positions - 1;
    if (next < 0) {
      model.picked = null;
      _putSuggestionData(_suggestionBase!);
      _suggestionLeft = _suggestionTyped();
    } else {
      _applySuggestion(next);
    }
  }

  /// A tap on the FYI line's [index]th call.
  void _pickSuggestion(int index) {
    final model = widget.session.draftSuggestions;
    if (model == null || !_canPickSuggestion || index >= model.list!.drafts.length) return;
    _beginSuggestionCycle();
    _applySuggestion(index);
  }

  /// Starts a cycle from the contact as it stands — unless the operator has
  /// typed nothing since the last pick, when the cycle under way goes on.
  /// Anything they typed since makes the contact as it now is the one the
  /// cycle returns to, so walking past the last suggestion never takes away
  /// what they typed after a pick.
  void _beginSuggestionCycle() {
    if (_suggestionBase != null && const DeepCollectionEquality().equals(_suggestionTyped(), _suggestionLeft)) return;
    _suggestionBase = _suggestionSnapshot();
    _suggestionLeft = _suggestionTyped();
  }

  /// What the operator has typed into the contact: the call, the reports,
  /// the notes, and the grid, state and exchange fields they typed into.
  /// Not the whole record: a pick's lookup lands after it, with a guess, a
  /// prefill and its refs, and the radio moves on its own — none of that is
  /// the operator changing the contact. The reports as typed: as the record
  /// reads them, an empty one takes the mode's default, and a mode change
  /// would read as an edit.
  Map<String, Object?> _suggestionTyped() => {
    'call': _callController.text,
    'sent': _sentController.text.trim(),
    'rcvd': _rcvdController.text.trim(),
    'notes': _notesController.text,
    if (_draft.gridTouched) 'grid': _gridController.text,
    if (_draft.stateTouched) 'state': _stateController.text,
    'exchange': _exchange.typedValues,
  };

  void _applySuggestion(int index) {
    final model = widget.session.draftSuggestions!;
    final draft = model.list!.drafts[index];
    // Before the call changes: the field reading the picked call is then a
    // pick standing, whose list the app keeps, and not typing.
    model.picked = index;
    _putSuggestionData(mergeDraftPatch(_suggestionBase!, draft.qso));
    _suggestionLeft = _suggestionTyped();
  }

  /// The contact as the draft records it, with the reports as typed: the
  /// record fills an empty one with its default, which put back would turn
  /// the field's hint into text the operator never typed.
  Map<String, dynamic> _suggestionSnapshot() {
    final data = _draft.toData(composing: true);
    return {
      ...data,
      'our': {...?(data['our'] as Map<String, dynamic>?), 'sent': _sentController.text.trim()},
      'their': {...?(data['their'] as Map<String, dynamic>?), 'sent': _rcvdController.text.trim()},
    };
  }

  /// Puts [data]'s station, refs and notes in place of the contact's, and
  /// keeps the rest as it stands now: the radio may have moved since the
  /// cycle began, and a field no pick sets may have been changed.
  void _putSuggestionData(Map<String, dynamic> data) {
    final now = _suggestionSnapshot();
    _applyDraftPatch(
      const {},
      whole: {
        for (final MapEntry(:key, :value) in now.entries)
          if (!_setByPicks.contains(key)) key: value,
        for (final key in _setByPicks)
          if (data.containsKey(key)) key: data[key],
      },
    );
    if (_callFocus.hasFocus) _callController.selection = TextSelection.collapsed(offset: _callController.text.length);
  }
}
