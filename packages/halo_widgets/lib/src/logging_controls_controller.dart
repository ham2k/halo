// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Imperative handle for driving a LoggingControls from outside it (set a field,
// log, wipe) — used by the app's dev bridge (window.__halo) so agents can drive
// the logging loop without pixel-hunting the canvas. Create one, pass it to
// LoggingControls (which attaches itself on mount), and call its methods.

/// A handle a [LoggingControls] attaches itself to, exposing a few imperative
/// actions. Inert (all methods no-op) while nothing is attached.
class LoggingControlsController {
  void Function(String field, String value)? _setField;
  Future<void> Function()? _submit;
  void Function()? _wipe;
  bool Function()? _isFieldsLocked;
  void Function()? _focusCall;
  void Function()? _focusSecondaryControls;
  void Function()? _focusLastPrimaryField;

  /// Wired by [LoggingControls] on mount/unmount — not meant for callers.
  void attach({
    required void Function(String field, String value) setField,
    required Future<void> Function() submit,
    required void Function() wipe,
    required bool Function() isFieldsLocked,
    required void Function() focusCall,
    required void Function() focusSecondaryControls,
    required void Function() focusLastPrimaryField,
  }) {
    _setField = setField;
    _submit = submit;
    _wipe = wipe;
    _isFieldsLocked = isFieldsLocked;
    _focusCall = focusCall;
    _focusSecondaryControls = focusSecondaryControls;
    _focusLastPrimaryField = focusLastPrimaryField;
  }

  /// Wired by [LoggingControls] on unmount — not meant for callers.
  void detach() {
    _setField = null;
    _submit = null;
    _wipe = null;
    _isFieldsLocked = null;
    _focusCall = null;
    _focusSecondaryControls = null;
    _focusLastPrimaryField = null;
  }

  /// Whether a LoggingControls is currently attached.
  bool get isAttached => _setField != null;

  /// Sets a primary field's text as if typed, so the debounced lookup and
  /// scoring run just like user input. Supported [field] today: `call`.
  /// Unknown fields are ignored.
  void setField(String field, String value) => _setField?.call(field, value);

  /// Logs the current QSO — the same path as tapping Log.
  Future<void> submit() => _submit?.call() ?? Future<void>.value();

  /// Clears the compose fields — the same as Wipe.
  void wipe() => _wipe?.call();

  /// Whether the attached [LoggingControls] is showing a read-only,
  /// staged-delete or deleted QSO — Escape must not close that view (see
  /// `LoggingControls._handleEscape`'s doc). False (never locked) while
  /// nothing is attached.
  bool get isFieldsLocked => _isFieldsLocked?.call() ?? false;

  /// Puts the keyboard back on the callsign field — the bottom rung of
  /// APP-19's focus ladder, used when Escape ends an edit from the list: a
  /// fresh start for composing the next contact, not a return to wherever
  /// the operator happened to be before arrowing up into the list.
  void focusCall() => _focusCall?.call();

  /// Puts the keyboard on the secondary control strip, opening the pill the
  /// operator last used (or the first one) — same as arriving there via Up
  /// from a main field. The rung between the main fields and the QSO list;
  /// the list calls this when Down walks off its newest row.
  void focusSecondaryControls() => _focusSecondaryControls?.call();

  /// Puts the keyboard back on the main field the operator was last typing
  /// in before they arrowed up into the QSO list (Call, if none is
  /// remembered) — used when Enter selects a row: the operator is picking up
  /// an edit, not starting a fresh QSO, so the field they left keeps making
  /// more sense than always landing on Call.
  void focusLastPrimaryField() => _focusLastPrimaryField?.call();
}
