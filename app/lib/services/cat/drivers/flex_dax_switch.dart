// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio's transmit audio switched to DAX for the computer's voice keyer
// and back again after — docs/design/cat.md § The computer's voice keyer.
//
// With `dax=0` the radio transmits its mic input and drops the DAX audio,
// and a mic nobody is speaking into goes out as the speech processor's
// hiss; left on after the message, the operator's mic is dead.

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../error_reporting_service.dart';

class FlexDaxSwitch {
  FlexDaxSwitch({required this.host, required this.send, required this.transmitting, required this.keyedByUs, required this.diagnose});

  /// The radio's address, which a DAX still owed is kept by; null when the
  /// session has none.
  final String? Function() host;
  final void Function(String command) send;

  /// The interlock as last reported: null for a radio that has not said.
  final bool? Function() transmitting;

  /// Whether the session holds the key itself.
  final bool Function() keyedByUs;
  final void Function(String what) diagnose;

  /// The transmit object's `dax=` as last pushed: whether the radio takes its
  /// transmit audio from DAX (the computer) rather than its mic input. Null
  /// before the first `transmit` status.
  bool? _dax;

  /// DAX this app turned on for a message and has not yet seen the radio
  /// report off again — owed back off, by the switch that turned it on, or
  /// by nobody once that session has closed. Kept by the radio's address for
  /// the whole launch, not by the session: a link that drops mid-message
  /// hands the restore to the next session, rather than leaving DAX on, and
  /// with it the operator's mic dead, for good. Owned while that session
  /// lives: two slices of one radio are two sessions on one transmitter, and
  /// one settling the other's DAX turns it off under the other's message.
  static final _owedByHost = <String, FlexDaxSwitch?>{};
  bool _owedHere = false;

  /// Forgets every DAX owed: the tests' way to start each from a radio the
  /// app never keyed.
  @visibleForTesting
  static void forgetOwed() => _owedByHost.clear();

  /// Whether DAX is owed back off by this switch: it turned DAX on, or the
  /// session that did has closed.
  bool get _owed {
    final at = host();
    if (at == null) return _owedHere;
    if (!_owedByHost.containsKey(at)) return false;
    final owner = _owedByHost[at];
    return owner == null || identical(owner, this);
  }

  set _owed(bool owed) {
    final at = host();
    if (at == null) {
      _owedHere = owed;
    } else if (owed) {
      _owedByHost[at] = this;
    } else {
      _owedByHost.remove(at);
    }
  }

  /// Whether DAX is owed by another session on this radio that is still open.
  bool get _owedElsewhere {
    final at = host();
    if (at == null) return false;
    final owner = _owedByHost[at];
    return owner != null && !identical(owner, this);
  }

  /// Whether the DAX owed is a closed session's, for this one to settle.
  bool get _inherited {
    final at = host();
    return at == null ? !_keyedThisSession : _owedByHost.containsKey(at) && _owedByHost[at] == null;
  }

  /// Whether the restore waits on the radio saying it is back to receive
  /// after the last message's unkey.
  bool _armed = false;

  /// Whether the radio has reported itself keyed since the app last keyed it.
  /// An unkey that comes before it — Escape during the lead — must still wait
  /// for the radio to go through its keying and come back to receive.
  bool _keyedSinceKey = false;

  /// Whether this session has keyed at all: a DAX owed from an earlier one
  /// is settled as soon as the radio is known to be receiving.
  bool _keyedThisSession = false;

  /// `transmit set dax=0` sent and not yet seen to take, and how many times.
  bool _restoreSent = false;
  int _tries = 0;

  /// For a radio whose unkey is never followed by a receive report (a refused
  /// key, a radio that stopped saying): the restore goes anyway.
  Timer? _fallback;

  static const _fallbackAfter = Duration(seconds: 2);
  static const _maxTries = 3;

  /// The `transmit` status's `dax=`.
  void daxReported(bool dax) {
    _dax = dax;
    // Off under a message this switch keyed: a restore sent before the key,
    // this session's or the other slice's on its own connection, landed
    // after this message's `dax=1`, and the message goes out as mic hiss.
    if (!dax && _owed && !_restoreSent && keyedByUs()) return send('transmit set dax=1');
    _settle();
  }

  /// The interlock's report, after the session has taken it in.
  void interlock({required bool transmitting}) {
    if (transmitting) {
      _keyedSinceKey = true;
    } else {
      _settle(receiving: true);
    }
  }

  /// DAX on for a message, unless the operator had it on already; before the
  /// key.
  void beforeKey() {
    // A restore still waiting for the last message's unkey is for that
    // message: left armed, it would put DAX back off under this one, which
    // then goes out as mic hiss. DAX stays owed back after this one.
    _armed = false;
    _restoreSent = false;
    // A new message's restore is a new one: the tries left from the last are
    // not this one's, and kept, an SO2R run that hands the debt back and
    // forth between two slices runs out of them and leaves DAX on.
    _tries = 0;
    _fallback?.cancel();
    _keyedSinceKey = false;
    _keyedThisSession = true;
    // Owed by the other slice's session, DAX is the app's and not the
    // operator's: this message takes the debt over, and turns DAX on again
    // in case that session's restore is already on its way.
    final taken = _owedElsewhere;
    if (_dax != true || taken) {
      _owed = true;
      send('transmit set dax=1');
    }
  }

  /// DAX back off once the radio is receiving again; after the unkey.
  void afterUnkey() {
    if (!_owed) return;
    // Sent while the radio is still keying or unkeying, `transmit set dax=0`
    // is answered with success and not applied, leaving DAX on: it waits for
    // the radio to say it is back to receive — after saying it keyed, for an
    // unkey that came before that did. A radio that never reports its
    // interlock has nothing to wait for.
    _armed = true;
    if (transmitting() == null) return _restore();
    _fallback?.cancel();
    _fallback = Timer(_fallbackAfter, () {
      if (_armed && transmitting() != true) _restore();
    });
  }

  /// A closing connection cannot wait for the radio to be receiving: the
  /// restore goes now, after the session's unkey — DAX turned off first
  /// would put the mic on the air. Still owed if it does not take: the next
  /// session settles it.
  void teardown() {
    _fallback?.cancel();
    if (_owed) {
      _armed = false;
      send('transmit set dax=0');
      final at = host();
      if (at != null) _owedByHost[at] = null;
    }
  }

  /// Settles DAX against what the radio reports: the restore once it is
  /// receiving after the last message, again when a restore did not take,
  /// and a DAX owed from an earlier session as soon as this one knows the
  /// radio is receiving. [receiving] is an interlock report of it.
  void _settle({bool receiving = false}) {
    if (!_owed) return;
    // Off counts once a restore went out, or for a DAX owed from an earlier
    // session: a report of off before the radio has taken this message's
    // `dax=1` says nothing about the restore.
    if (_dax == false && (_restoreSent || _inherited)) {
      _owed = false;
      _restoreSent = false;
      _tries = 0;
      return;
    }
    if (keyedByUs() || transmitting() != false) return;
    if (_armed) {
      if (receiving && _keyedSinceKey) _restore();
    } else if (_restoreSent && _dax == true) {
      // The radio answered the restore and kept DAX on.
      _restore();
    } else if (_inherited && _dax == true) {
      _restore();
    }
  }

  void _restore() {
    _armed = false;
    _fallback?.cancel();
    // Taken over by the other slice's message since this was armed.
    if (!_owed) return;
    if (_tries >= _maxTries) {
      // Reported once, and not tried again: the operator has to turn it off.
      _owed = false;
      _restoreSent = false;
      diagnose('Flex DAX left on after $_tries restores');
      ErrorReportingService.report(FlexDaxLeftOn(host()), StackTrace.current, context: 'flex:dax-restore');
      return;
    }
    _tries++;
    _restoreSent = true;
    send('transmit set dax=0');
  }
}

/// DAX this app turned on for a message, still on after every restore it
/// sent: the radio transmits its DAX audio, and the operator's mic not at
/// all, until DAX is turned off on the radio or its client.
class FlexDaxLeftOn implements Exception {
  final String? host;

  const FlexDaxLeftOn(this.host);

  @override
  String toString() => 'FlexDaxLeftOn: DAX left on at ${host ?? 'the radio'} after the restores sent did not take';
}
