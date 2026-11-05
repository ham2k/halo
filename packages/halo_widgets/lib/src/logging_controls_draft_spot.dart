// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The station being worked, as a local spot ([LoggingSession.onDraftSpot]):
// when it starts, what it follows, what logging the contact sends, and which
// wipes take it back
// (docs/design/logging-fields.md § Local spots). Part of the panel's library;
// it reaches the panel's state directly.

part of 'logging_controls.dart';

extension _DraftSpot on _LoggingControlsState {
  /// The call field lost focus — by Space, Tab, an arrow, a tap anywhere
  /// else. A call left behind in a new contact starts its spot, or moves
  /// the one it already has.
  ///
  /// Not an untouched tentative suggestion: that fill is a spot row being
  /// peeked at, already on the board, and it goes when the row closes.
  void _onCallFieldLeft() {
    if (widget.session.onDraftSpot == null || widget.session.editingQso != null || _fieldsLocked) return;
    if (_suggestionWasTentative && _callIsUntouchedSuggestion) return;
    if (_spotKey == null && _call.isEmpty) return;
    _spotKey ??= uuidGenerator.v4();
    _emitDraftSpot();
  }

  /// After a build: the spot follows the draft as the operator fills it in.
  /// Never while the call field has focus — a call being retyped is half a
  /// callsign at every keystroke, and the board would show each one.
  void _followDraftSpot() {
    if (_spotKey == null || widget.session.editingQso != null || _callFocus.hasFocus) return;
    _emitDraftSpot();
  }

  /// Sends the draft as it stands, or a retraction once its call is gone
  /// or its time is no longer now ([_spotsNow]). Deduped: a build that
  /// changed nothing in the draft sends nothing.
  void _emitDraftSpot() {
    final key = _spotKey;
    final onDraftSpot = widget.session.onDraftSpot;
    if (key == null || onDraftSpot == null) return;
    final qso = _call.isEmpty || !_spotsNow ? null : _draft.toData();
    if (const DeepCollectionEquality().equals(qso, _lastSpotQso)) return;
    _lastSpotQso = qso;
    onDraftSpot(key, qso);
  }

  /// The operator's own wipe (the button, Alt+W): the call was wrong, or the
  /// station gone, and the spot goes with the entry. Its undo brings both
  /// back ([_restoreDraftSpot]).
  void _retractDraftSpot() {
    final key = _spotKey;
    if (key == null) return;
    if (_lastSpotQso != null) widget.session.onDraftSpot?.call(key, null);
    _lastSpotQso = null;
  }

  /// A new contact logged: the station really is there, and its spot takes
  /// the record as logged — under the key it was followed under, or a fresh
  /// one when the call field was never left (Enter straight from it). The
  /// last of a call list is the one spotted: they share one frequency, and
  /// each would replace the one before it. The wipe after the log ends the
  /// follow.
  void _spotLogged(List<Qso> logged) {
    final onDraftSpot = widget.session.onDraftSpot;
    if (onDraftSpot == null || logged.isEmpty || !_spotsNow) return;
    onDraftSpot(_spotKey ?? uuidGenerator.v4(), logged.last.data);
  }

  /// Whether the entry's time is now. A spot says who is on the air at the
  /// moment it is posted; a paper log typed in under manual time entry, or a
  /// contact with a start time of its own, would put every station in it on
  /// the board as live.
  bool get _spotsNow => _time.isLive;

  /// Every wipe ends the follow; the spot stays where it was last sent. A
  /// logged contact ([_spotLogged]) or a QSY leaves a station that was really
  /// there.
  void _releaseDraftSpot() {
    _spotKey = null;
    _lastSpotQso = null;
  }

  /// A wipe undone: the restored entry takes back the spot it had. Sent now,
  /// not on the next leave of the call field, which undo may have focused.
  ///
  /// The entry the undo replaces is gone as a wiped one is, and its spot with
  /// it — under its key the restored entry would move it, and with no key
  /// nothing would ever take it down.
  void _restoreDraftSpot(String? key) {
    _retractDraftSpot();
    _releaseDraftSpot();
    if (key == null) return;
    _spotKey = key;
    _lastSpotQso = null;
    _emitDraftSpot();
  }
}
