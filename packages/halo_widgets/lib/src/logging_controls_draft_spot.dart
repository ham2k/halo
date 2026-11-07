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

  /// Enter on one entry ending in `!` that no command took: the rest of it,
  /// any text at all, marks the band at the radio's frequency as a band tag —
  /// "QRM!", "NET!", "CONTEST!" — and a lone `!` clears the local spots and
  /// tags there. Either way the call field empties for the next call. A
  /// stack or a call list is the logging path's: taken whole, the calls
  /// queued in it would go on the board as one tag and leave the field.
  ///
  /// When no spot can be made the text stays and the message slot says why;
  /// emptied, it would read as done. True when Enter was the tag's, and logs
  /// nothing.
  bool _postBandTag() {
    final text = _callController.text.trim();
    if (widget.session.editingQso != null || !text.endsWith('!') || text.contains(',') || text.contains('//')) return false;
    final tag = text.substring(0, text.length - 1).trim();
    final at = {'freq': _radio.freq, 'band': _radio.band, 'mode': _radio.mode};
    // A frequency off every band has no band either, and the host makes no
    // spot of it; asked anyway, its refusal would read as local spots off.
    if (_radio.freq == null || _radio.band == null) {
      _command.showError(t.loggingControls.localSpotNeedsFrequency);
      return true;
    }
    if (tag.isEmpty) {
      widget.session.onClearLocalSpots?.call(at);
      // The clear may take this entry's own spot down too; remembered as
      // sent, the same call left again would be deduped and never come back.
      _lastSpotQso = null;
    } else if (!_spotsNow) {
      _command.showError(t.loggingControls.localSpotNeedsLiveTime);
      return true;
    } else if (!(widget.session.onBandTag?.call(tag, at) ?? false)) {
      _command.showError(t.loggingControls.localSpotsOff);
      return true;
    }
    _callController.clear();
    return true;
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
