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

  /// Wired by [LoggingControls] on mount/unmount — not meant for callers.
  void attach({
    required void Function(String field, String value) setField,
    required Future<void> Function() submit,
    required void Function() wipe,
  }) {
    _setField = setField;
    _submit = submit;
    _wipe = wipe;
  }

  /// Wired by [LoggingControls] on unmount — not meant for callers.
  void detach() {
    _setField = null;
    _submit = null;
    _wipe = null;
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
}
