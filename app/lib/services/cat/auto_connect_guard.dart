// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The mark an automatic connect leaves behind while it is in flight, and the
// rule the NEXT launch applies when it finds one still there.
//
// A connect the app starts on its own is the only part of boot that reaches
// hardware, and the reach is not bounded: the serial open is synchronous FFI
// on the isolate that also pumps the UI, and on Windows `CreateFile` against a
// wedged COM port blocks with no timeout at all (HALO-456). A launch that dies
// there never produces a frame — and on Windows never shows its window, which
// leaves the single-instance guard handing every later launch to a corpse. The
// launch after it then makes the same call for the same reason, which is how
// one stuck port turns into an app that will not start at all (HALO-525).
//
// So the attempt is written down before it is made and erased when it returns.
// Whatever kills the process in between, the next launch can see which node the
// last one was holding when it went, and leave that one alone.
//
// Only a deliberate Connect clears a mark. A launch that cleared its own would
// merely take turns — hang, start, hang, start — and an operator cannot tell
// that from a random fault. The Connect button is the way back, and it is also
// the proof the guard wants: a port the operator can open by hand is a port
// worth opening automatically again.

import 'package:shared_preferences/shared_preferences.dart';

/// Namespaced like `db:uncleanQuit`, the other breadcrumb written for a
/// process that may not survive to describe itself.
const autoConnectInFlightKey = 'cat:autoConnectInFlight';

/// The nodes an automatic connect was started for and never finished.
///
/// Read ONCE per launch, before this process writes any mark of its own — see
/// [CatService.autoConnectHeldNodes]. Read live, it would answer "held" for a
/// connect that is merely in progress right now.
List<String> autoConnectMarks(SharedPreferences prefs) => prefs.getStringList(autoConnectInFlightKey) ?? const [];

/// Awaited by every caller, unlike most preference writes: a mark still
/// sitting in a buffer when the open wedges is not a mark at all.
Future<void> markAutoConnectStarted(SharedPreferences prefs, String uuid) async {
  final marks = autoConnectMarks(prefs);
  if (marks.contains(uuid)) return;
  await prefs.setStringList(autoConnectInFlightKey, [...marks, uuid]);
}

/// Removes [uuid]'s mark, if it has one.
///
/// The key is removed outright once nothing is marked, rather than left as an
/// empty list: an absent key is what a first launch has, and the two should not
/// be distinguishable by anything that reads this.
Future<void> clearAutoConnectMark(SharedPreferences prefs, String uuid) async {
  final marks = autoConnectMarks(prefs);
  if (!marks.contains(uuid)) return;
  final rest = [
    for (final mark in marks)
      if (mark != uuid) mark,
  ];
  if (rest.isEmpty) {
    await prefs.remove(autoConnectInFlightKey);
  } else {
    await prefs.setStringList(autoConnectInFlightKey, rest);
  }
}
