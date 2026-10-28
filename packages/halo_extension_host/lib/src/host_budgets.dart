// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The budgets the host holds one bundle to beyond its grants: how much it may
// have outstanding or stored at once, so that one extension's volume cannot
// take the host, or the others, down with it. Each is refused at the call that
// would exceed it, never queued or quietly dropped: a runaway loop fails where
// it runs, and its author sees why. `host.fetch`'s own are in fetch_policy.dart,
// the sockets' in extension_sockets.dart, the timers' in extension_timers.dart.

import 'dart:collection';

import 'package:halo_core/halo_core.dart';

/// How many of one bundle's host calls may await an answer at once. A hook
/// makes a few, in sequence; a loop that fires `host.*` calls without awaiting
/// them would otherwise park a completer here, and one in the kernel, per call
/// for as long as the app takes to answer — or for the session, for a form
/// nobody closes.
const kMaxHostCallsPending = 32;

/// The same across every extension: the only bound on calls the kernel did not
/// attribute to a bundle (its public `hostCall` surface, and its own), and the
/// bound on the host's outstanding work in all.
const kMaxHostCallsPendingTotal = 256;

/// The most keys a bundle's extensions may store in `kv` themselves (what the
/// app seeds for them is outside it). It lives in the Dart heap, outside the
/// engine's memory ceiling — and in the UI isolate on web — so with
/// [kMaxKvEntryChars] this bounds what a bundle may have the host keep.
const kMaxKvKeysPerBundle = 10;

/// The most one `kv` entry, key and value together, may encode to, in
/// characters of JSON — the form it crossed the bridge in. The key counts so
/// that the entry's bound is one the name cannot slip past.
const kMaxKvEntryChars = 4096;

/// So many admissions within a sliding span, on the real clock: a rate an
/// extension is held to, where a count would only delay the same loop.
class RateWindow {
  final int limit;
  final Duration span;
  final int Function() _nowMillis;
  final Queue<int> _admitted = Queue();

  RateWindow(this.limit, this.span, {int Function()? nowMillis}) : _nowMillis = nowMillis ?? realNowMillis;

  /// Admits one more now, when fewer than [limit] were admitted within the
  /// last [span]. A refusal leaves no mark, so a caller refused is refused
  /// only for as long as its admitted ones stay recent.
  bool admit() {
    final now = _nowMillis();
    final before = now - span.inMilliseconds;
    while (_admitted.isNotEmpty && _admitted.first <= before) {
      _admitted.removeFirst();
    }
    if (_admitted.length >= limit) return false;
    _admitted.addLast(now);
    return true;
  }
}
