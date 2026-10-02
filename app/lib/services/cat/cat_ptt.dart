// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operator's ['] in a Phone mode: keys a radio over CAT, and ['] again,
// Escape or a minute unkeys it (docs/design/cat.md § PTT).
//
// The key belongs to the RADIO it went to, not to the Main VFO role: a key
// left behind when the role moved, or when another radio is added, is still
// this station's to drop. One key for the whole station, because one radio
// transmits at a time — CatService.yieldTransmitter is where keying another
// radio first quiets this one.
//
// What this holds is the APP's key, not whether the radio transmits — that
// is the radio's report. The two meet in one place: a radio that says it
// stopped transmitting after it said it started has dropped the key itself
// (its own time-out timer, the operator's mic switch), and the app's key goes
// with it, so the next ['] keys again rather than sending an unkey for a key
// nobody holds.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../error_reporting_service.dart';
import 'driver.dart';

/// The longest the app holds the transmitter keyed on the operator's behalf.
/// A key forgotten under a mic cable is a minute of dead carrier, not an
/// hour of it.
const pttTimeout = Duration(minutes: 1);

class CatPtt {
  /// Whether the app holds a key, on any radio.
  final held = ValueNotifier<bool>(false);

  /// The session the key went to. Always a live one: the service [forget]s
  /// a session as it closes.
  PttSession? _keyed;
  bool _confirmed = false;
  Timer? _timeout;

  /// Whether the app's key is on [session].
  bool heldOn(EquipmentSession? session) => session != null && identical(_keyed, session);

  /// ['] on [target]: unkeys it when the app holds its key, keys it
  /// otherwise — dropping a key held on any other radio first.
  void toggle(PttSession target) {
    if (heldOn(target)) {
      release();
      return;
    }
    release();
    // Held before the command goes: a radio that reports TX as it keys
    // answers from inside setPtt, and a key not yet held would not hear it.
    _keyed = target;
    _confirmed = false;
    held.value = true;
    try {
      target.setPtt(true);
    } catch (e, st) {
      _clear();
      return ErrorReportingService.report(e, st, context: 'cat:ptt');
    }
    _timeout = Timer(pttTimeout, release);
  }

  /// Unkeys, when the app holds a key. False when it did not, so Escape
  /// keeps its usual meaning.
  bool release() {
    final target = _keyed;
    if (target == null) return false;
    _clear();
    try {
      target.setPtt(false);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:ptt');
    }
    return true;
  }

  /// [closing] is going away. A key held on it is not held any more: the
  /// session's own teardown unkeys the radio, and an unkey sent after it
  /// would go to a closed connection.
  void forget(EquipmentSession closing) {
    if (heldOn(closing)) _clear();
  }

  /// [session] reported a change in its TX state. A "not transmitting"
  /// before the radio ever confirmed is the poll that was already on the
  /// wire when the key went out, and says nothing about the key. After it,
  /// the key is released — the unkey sent anyway: a CAT key is latched, and
  /// a report that was transient or misread would otherwise leave the radio
  /// keyed with no timeout left to drop it.
  void onTransmitting(EquipmentSession? session, bool transmitting) {
    if (!heldOn(session)) return;
    if (transmitting) {
      _confirmed = true;
    } else if (_confirmed) {
      release();
    }
  }

  void _clear() {
    _timeout?.cancel();
    _timeout = _keyed = null;
    held.value = false;
  }

  void dispose() {
    _clear();
    held.dispose();
  }
}

/// Which radio ['] keys from where the operator is — asked of each surface
/// that can key (today, an operation view), and null from all but the one in
/// front, and from it whenever ['] is not PTT there.
typedef PttKeyTarget = String? Function();

/// The station's ['] and Escape for PTT: one handler, however many surfaces
/// can key, so two of them never disagree about whether the key is held.
///
/// While a key is held, ['] or Escape drops it from anywhere — another
/// field, a dialog, Settings — because the transmitter is on and the key that
/// put it there has to take it off. Only keying asks the surfaces.
class PttKeyboard {
  PttKeyboard({required this.held, required this.release, required this.escape, required this.toggle});

  /// Whether a key is held, on any radio.
  final ValueListenable<bool> held;

  /// Drops the held key; false when nothing was held.
  final bool Function() release;

  /// Escape while a key is held: stops it the way Escape stops a message, so
  /// the logging fields hear it as stopped too.
  final bool Function() escape;

  /// Keys or unkeys the radio a surface named.
  final void Function(String radio) toggle;

  final _targets = <PttKeyTarget>[];
  bool _registered = false;

  /// The physical key whose press went to PTT. Its auto-repeats and its
  /// release are swallowed with it: left to the focused field, holding [']
  /// down would type a run of apostrophes into it while the radio transmits.
  PhysicalKeyboardKey? _down;

  /// Registered with the keyboard on the first surface, and kept until the
  /// service goes: a key held after the last surface closed is still one the
  /// operator must be able to drop.
  void addTarget(PttKeyTarget target) {
    _targets.add(target);
    if (_registered) return;
    _registered = true;
    HardwareKeyboard.instance.addHandler(handle);
  }

  void removeTarget(PttKeyTarget target) => _targets.remove(target);

  @visibleForTesting
  bool handle(KeyEvent event) {
    if (event is! KeyDownEvent) {
      if (event.physicalKey != _down) return false;
      if (event is KeyUpEvent) _down = null;
      return true;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isMetaPressed || keyboard.isControlPressed || keyboard.isAltPressed) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) return held.value && escape();
    // The character typed, not the key's name: US Shift+['] types ["], and
    // a German or Swiss layout types ['] with Shift — the platforms disagree
    // about which key name either one reports.
    if (event.character != "'") return false;
    if (!release()) {
      final radio = _targets.map((target) => target()).nonNulls.firstOrNull;
      if (radio == null) return false;
      toggle(radio);
    }
    _down = event.physicalKey;
    return true;
  }

  void dispose() {
    if (_registered) HardwareKeyboard.instance.removeHandler(handle);
    _targets.clear();
  }
}
