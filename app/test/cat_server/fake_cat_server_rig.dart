// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/foundation.dart';
import 'package:ham2k_logger/services/cat_server/cat_server_rig.dart';

/// A rig that records what it was asked to do and moves where it was told,
/// as `vfoA` does when a radio follows it.
class FakeCatServerRig extends ChangeNotifier implements CatServerRig {
  @override
  bool available;

  @override
  double? freqKHz;

  @override
  String? mode;

  @override
  bool transmitting = false;

  @override
  bool transmitAllowed = false;

  /// Unless set, follows [transmitAllowed]: a radio that can be keyed.
  bool? radioCanKey;

  @override
  bool get canTransmit => transmitAllowed && (radioCanKey ?? true);

  final tunes = <({double? freqKHz, String? mode})>[];

  /// Every key that went out and every unkey, in order.
  final ptts = <bool>[];

  /// Who holds the key, as CatPtt keeps it: a client's unkey drops only its
  /// own.
  Object? pttOwner;

  var clientPttReleases = 0;

  FakeCatServerRig({this.available = true, this.freqKHz = 14074, this.mode = 'USB'});

  @override
  void tune({double? freqKHz, String? mode}) {
    tunes.add((freqKHz: freqKHz, mode: mode));
    if (freqKHz != null) this.freqKHz = freqKHz;
    if (mode != null) this.mode = mode;
    notifyListeners();
  }

  @override
  bool keyPtt(Object owner) {
    if (!canTransmit) return false;
    if (pttOwner == null) ptts.add(true);
    pttOwner = owner;
    return true;
  }

  @override
  void releasePtt(Object owner) {
    if (!identical(pttOwner, owner)) return;
    pttOwner = null;
    ptts.add(false);
  }

  @override
  void releaseClientPtt() => clientPttReleases++;

  /// Moves as a radio's own knob would: without a tune.
  void move({double? freqKHz, String? mode}) {
    if (freqKHz != null) this.freqKHz = freqKHz;
    if (mode != null) this.mode = mode;
    notifyListeners();
  }

  @override
  Listenable get changes => this;
}
