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
//
// A key has an owner: null for the operator, and a CAT server client for a
// key that client asked for (cat_server_rig.dart). A client neither keys
// while anyone else holds the key nor drops a key it does not hold, so it
// never ends the operator's over, nor one another client started. Escape
// drops any key; ['] keys and unkeys where it is the PTT key, whoever holds
// it, and drops only the operator's own from anywhere else.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:halo_widgets/halo_widgets.dart' show keyBindings, pttCommandId;

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
  Object? _owner;
  bool _confirmed = false;
  Timer? _timeout;

  /// Whether the app's key is on [session].
  bool heldOn(EquipmentSession? session) => session != null && identical(_keyed, session);

  /// Who holds the key: null for the operator, and for no key at all.
  Object? get owner => _keyed == null ? null : _owner;

  /// Whether [owner] may key: the operator always may, and a client only
  /// while no one else holds the key.
  bool mayKey(Object? owner) => owner == null || _keyed == null || identical(_owner, owner);

  /// Keys [target] for [owner] (null: the operator) for at most [timeout],
  /// dropping a key held on any other radio first. False when the key did
  /// not go out — refused ([mayKey]), or failed.
  ///
  /// A key already on [target] is not sent again. Its owner asking again
  /// does not extend it; the operator keying over a client's key takes it,
  /// with [timeout] from now.
  bool key(PttSession target, {Duration timeout = pttTimeout, Object? owner}) {
    if (!mayKey(owner)) return false;
    if (heldOn(target)) {
      if (identical(_owner, owner)) return true;
      _owner = owner;
      _timeout?.cancel();
      _timeout = Timer(timeout, release);
      return true;
    }
    release();
    // Held before the command goes: a radio that reports TX as it keys
    // answers from inside setPtt, and a key not yet held would not hear it.
    _keyed = target;
    _owner = owner;
    _confirmed = false;
    held.value = true;
    try {
      target.setPtt(true);
    } catch (e, st) {
      _clear();
      ErrorReportingService.report(e, st, context: 'cat:ptt');
      return false;
    }
    _timeout = Timer(timeout, release);
    return true;
  }

  /// Unkeys, when the app holds a key — only [owner]'s key, when one is
  /// named. False when nothing was released, so Escape keeps its usual
  /// meaning.
  bool release({Object? owner}) {
    final target = _keyed;
    if (target == null) return false;
    if (owner != null && !identical(_owner, owner)) return false;
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
    _timeout = _keyed = _owner = null;
    held.value = false;
  }

  void dispose() {
    _clear();
    held.dispose();
  }
}

/// Which radio the PTT key keys from where the operator is — asked of each
/// surface that can key (today, an operation view), and null from all but
/// the one in front.
typedef PttKeyTarget = String? Function();

/// The station's PTT key (['] unless rebound — `radio.ptt`,
/// docs/design/keyboard-shortcuts.md) and Escape for PTT: one handler,
/// however many surfaces can key, so two of them never disagree about
/// whether the key is held.
///
/// While a key is held, Escape drops it from anywhere — another field, a
/// dialog, Settings — because the transmitter is on and has to come off. The
/// PTT key does too while the OPERATOR holds the key, being the key that put
/// it there. A CAT server client's key it drops only where it is the PTT key:
/// a client running FT8 transmits half of every minute, and would otherwise
/// take every apostrophe typed into a note. Only keying asks the surfaces.
class PttKeyboard {
  PttKeyboard({required this.held, required this.release, required this.escape, required this.toggle});

  /// Whether a key is held, on any radio.
  final ValueListenable<bool> held;

  /// Drops the operator's own key; false when they hold none.
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
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (keyboard.isMetaPressed || keyboard.isControlPressed || keyboard.isAltPressed) return false;
      return held.value && escape();
    }
    // A key that types a character is matched by the character typed, not
    // the key's name (KeyChord.matches): US Shift+['] types ["], and a German
    // or Swiss layout types ['] with Shift — the platforms disagree about
    // which key name either one reports.
    final bindings = keyBindings.value;
    final chord = bindings.match(pttCommandId, event);
    if (chord == null) return false;
    if (!release()) {
      // Where a field takes the character, the key types it instead.
      if (bindings.yieldsToField(pttCommandId, chord, event)) return false;
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
