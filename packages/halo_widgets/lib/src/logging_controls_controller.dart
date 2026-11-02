// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Imperative handle for driving a LoggingControls from outside it (set a field,
// log, wipe) — used by the app's dev bridge (window.__halo) so agents can drive
// the logging loop without pixel-hunting the canvas. Create one, pass it to
// LoggingControls (which attaches itself on mount), and call its methods.

import 'package:flutter/widgets.dart';

import 'logging_controls_refs.dart' show GuessProvenance;

/// An entry taken out of a set ([LoggingControlsController.takeEntry]) for
/// another to take in ([LoggingControlsController.putEntry]): the record,
/// with the frequency, band and mode it is on, and which of its refs a
/// lookup proposed. Never a power: that is the rig's, and each set keeps
/// its own.
class LoggingEntry {
  const LoggingEntry({required this.data, required this.guesses, this.answered = false});

  final Map<String, dynamic> data;
  final GuessProvenance guesses;

  /// Enter Sends Messages has already answered the call: the next Enter
  /// sends the thanks and logs, in whichever set the entry lands.
  final bool answered;
}

/// A handle a [LoggingControls] attaches itself to, exposing a few imperative
/// actions. Inert (all methods no-op) while nothing is attached.
class LoggingControlsController {
  void Function(String field, String value)? _setField;
  Future<void> Function()? _submit;
  void Function()? _wipe;
  bool Function()? _isFieldsLocked;
  KeyEventResult Function(KeyEvent event)? _handleChord;
  void Function()? _focusCall;
  void Function()? _focusSecondaryControls;
  void Function()? _focusLastPrimaryField;
  void Function(String key)? _openControl;
  LoggingEntry? Function()? _takeEntry;
  void Function(LoggingEntry entry)? _putEntry;

  /// Wired by [LoggingControls] on mount/unmount — not meant for callers.
  void attach({
    required void Function(String field, String value) setField,
    required Future<void> Function() submit,
    required void Function() wipe,
    required bool Function() isFieldsLocked,
    required KeyEventResult Function(KeyEvent event) handleChord,
    required void Function() focusCall,
    required void Function() focusSecondaryControls,
    required void Function() focusLastPrimaryField,
    required void Function(String key) openControl,
    required LoggingEntry? Function() takeEntry,
    required void Function(LoggingEntry entry) putEntry,
  }) {
    _setField = setField;
    _submit = submit;
    _wipe = wipe;
    _isFieldsLocked = isFieldsLocked;
    _handleChord = handleChord;
    _focusCall = focusCall;
    _focusSecondaryControls = focusSecondaryControls;
    _focusLastPrimaryField = focusLastPrimaryField;
    _openControl = openControl;
    _takeEntry = takeEntry;
    _putEntry = putEntry;
  }

  /// Wired by [LoggingControls] on unmount — not meant for callers.
  void detach() {
    _setField = null;
    _submit = null;
    _wipe = null;
    _isFieldsLocked = null;
    _handleChord = null;
    _focusCall = null;
    _focusSecondaryControls = null;
    _focusLastPrimaryField = null;
    _openControl = null;
    _takeEntry = null;
    _putEntry = null;
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

  /// Offers a key event to the attached [LoggingControls]' modifier chords
  /// (Alt+W, Cmd/Ctrl+Z — see `LoggingControls._handleChord`). For the host
  /// to call from a handler above the controls: a staged delete disables
  /// every field, so the keyboard is never inside the controls at the one
  /// moment Cmd/Ctrl+Z has a delete to take back.
  KeyEventResult handleChord(KeyEvent event) => _handleChord?.call(event) ?? KeyEventResult.ignored;

  /// Puts the keyboard back on the callsign field — the bottom rung of the
  /// focus ladder (docs/design/logging-fields.md), used when Escape ends an
  /// edit from the list: a
  /// fresh start for composing the next contact, not a return to wherever
  /// the operator happened to be before arrowing up into the list.
  void focusCall() => _focusCall?.call();

  /// Puts the keyboard on the secondary control strip, opening the pill the
  /// operator last used (or the first one) — same as arriving there via Up
  /// from a main field.
  void focusSecondaryControls() => _focusSecondaryControls?.call();

  /// Puts the keyboard back on the main field the operator was last typing
  /// in (Call, if none is remembered) — used when Up off the pills loads a
  /// row: the operator is picking up an edit, not starting a fresh QSO, so
  /// the field they left keeps making more sense than always landing on Call.
  void focusLastPrimaryField() => _focusLastPrimaryField?.call();

  /// Opens the secondary control under [key] — `radio`, or `radioB` for set
  /// B's Radio control in set A's strip under SO2R — as a tap on its pill
  /// does, the keyboard landing in the field it opens into. For a host
  /// answering a tap of its own with the control: the FYI area's No Band.
  void openControl(String key) => _openControl?.call(key);

  /// Takes the entry being composed out of the set, leaving the set as a
  /// wipe does but with no undo offer: the entry is not gone, it is on its
  /// way to [putEntry]. Null — and nothing taken — while the set shows a
  /// logged contact, while its fields are locked ([isFieldsLocked]), or
  /// while nothing is attached.
  LoggingEntry? takeEntry() => _takeEntry?.call();

  /// Puts [entry] into the set in place of whatever it holds, and tunes the
  /// set's VFO to the entry's frequency, band and mode as the entry's own
  /// move — so the set takes the radio's arrival there as no QSY.
  void putEntry(LoggingEntry entry) => _putEntry?.call(entry);
}
