// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// When each serial port first appeared, so the picker can say which one the
// operator has just plugged in. No platform exposes a plug-in timestamp —
// libserialport has no such field anywhere — so the only cross-platform
// answer is what this app has watched happen.

import 'package:halo_core/halo_core.dart';

/// First-seen stamps for serial port names, one set for the whole process:
/// there is one machine's worth of USB below us, same reasoning as the
/// transports' own static port caches.
///
/// [realNowMillis] and not the app clock: this measures real elapsed time
/// against the operator's own sense of "I just plugged that in", so a
/// developer travelling three days forward must not turn a cable they are
/// holding into an old one (see docs/design/time.md §1).
class SerialPortSightings {
  SerialPortSightings._();

  /// How long a port stays "just now" after it first appears.
  static const recentWindow = Duration(minutes: 5);

  static final Map<String, int> _firstSeenMillis = {};

  /// Whether the first enumeration has happened. What that one found is the
  /// BASELINE — ports that were already there — and no baseline port is ever
  /// "just now", however recent its stamp. Without this the whole feature
  /// stays silent for five minutes after launch: every port is stamped at
  /// the same instant, so a cable plugged in a minute later is no more
  /// recent than the ones that were already in.
  static var _baselineTaken = false;

  /// Records an enumeration: names not seen before are stamped now, and
  /// names that have gone are FORGOTTEN rather than kept. Forgetting is what
  /// makes an unplug-and-replug read as new — a remembered stamp would age
  /// out and the port would come back silently, which is exactly the moment
  /// the operator most wants pointed out.
  static void observe(Iterable<String> names) {
    final present = names.toSet();
    // An empty enumeration is IGNORED, never read as "everything was
    // unplugged". `availableSerialPorts()` answers with an empty list when
    // libserialport throws, and the Android path does the same when
    // `listDevices()` fails — so treating it as truth would forget every
    // port, and the next successful look, three seconds later, would stamp
    // the whole list as new and light every row up with "Recently connected"
    // for five minutes. The cost is that unplugging a machine's ONLY port
    // and plugging it back does not read as new; a machine with two ports
    // still reports each correctly.
    if (present.isEmpty) return;

    final now = realNowMillis();
    _firstSeenMillis.removeWhere((name, _) => !present.contains(name));
    for (final name in present) {
      _firstSeenMillis.putIfAbsent(name, () => _baselineTaken ? now : _baselineMillis);
    }
    _baselineTaken = true;
  }

  /// The stamp a baseline port carries: never within [recentWindow] of any
  /// real clock reading, so [isRecent] answers no without a second map to
  /// consult.
  static const _baselineMillis = 0;

  /// Whether [name] appeared within [recentWindow], after the baseline.
  /// False for a name never passed to [observe] — an unseen port is not a
  /// new one — and for one that was there from the start.
  static bool isRecent(String name) {
    final seen = _firstSeenMillis[name];
    if (seen == null || seen == _baselineMillis) return false;
    return realNowMillis() - seen < recentWindow.inMilliseconds;
  }

  /// Tests only. Nothing in the app forgets a machine's ports wholesale.
  static void resetForTest() {
    _firstSeenMillis.clear();
    _baselineTaken = false;
  }
}
