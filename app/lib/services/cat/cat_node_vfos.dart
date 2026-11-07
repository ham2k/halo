// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which VFO in RadioService each radio has, and what the app shows it tuned
// to (docs/design/cat.md § The VFO the app shows): radio1 and Radio B drive
// the app's `vfoA` and `vfoB`, and every other radio has one of its own under
// its node id, fed its reports and forwarded an operator's tune as they are.

part of 'cat_service.dart';

mixin _NodeVfos on ChangeNotifier {
  RadioService? get _radio;
  Map<String, _NodeRuntime> get _runtimes;
  String? get _localRadio1;
  String? get radio2;
  EquipmentState stateFor(String uuid);
  void tuneNode(String uuid, VfoReading requested);

  /// Whether [uuid] is the local node filling the radio1 role — a peer pick is no node of this
  /// station's, so it answers false for every uuid.
  bool isRadio1(String uuid) => _localRadio1 == uuid;

  /// The app VFO [uuid] drives: `vfoA` for radio1, `vfoB` for SO2R's Radio
  /// B, null for any other node. [vfoKeyFor] is the key for any radio.
  String? _vfoKeyOf(String uuid) => uuid == _localRadio1
      ? 'vfoA'
      : uuid == radio2
      ? 'vfoB'
      : null;

  /// Where RadioService keeps [uuid]'s VFO: the app VFO it drives, or its own under its node id.
  String vfoKeyFor(String uuid) => _vfoKeyOf(uuid) ?? uuid;

  /// The frequency the app shows [uuid] on: while it is live (`isLiveRadio`) and an operator's
  /// tune of it is unconfirmed, the tune; otherwise the radio's last report. A tune typed while the
  /// radio is away never reached it, and a radio's own VFO is not fed its reports while it fills a
  /// role, so outside a tune it can be wherever the radio was before.
  double? vfoFreqKHzFor(String uuid) {
    final reported = stateFor(uuid);
    final live = reported.status == EquipmentStatus.connected && !reported.stale && reported.problem == null;
    final key = vfoKeyFor(uuid);
    if (!live || !(_radio?.unconfirmed(key).freq ?? false)) return reported.vfo.freqKHz;
    return _radio?.vfo(key).freq ?? reported.vfo.freqKHz;
  }

  /// What moves [vfoFreqKHzFor] besides a report: an operator's tune, and a hold running out.
  Listenable get vfoChanges => _radio ?? _noVfoChanges;
  static final _noVfoChanges = ChangeNotifier();

  /// A hold of [key] that ran out shows the radio's report ([RadioService.realVfo]), and the
  /// echo guard goes back to it: it kept the tune while the radio had not reported it
  /// (`_keepUnconfirmedSent`), and a radio that refused the tune must still be sent it again if
  /// asked again. Every other `radio` notification follows a report that already set it.
  void _sentFollowsRelease(RadioService radio, String key) {
    final runtime =
        _runtimes[key == 'vfoA'
            ? _localRadio1
            : key == 'vfoB'
            ? radio2
            : key];
    final open = radio.unconfirmed(key);
    if (runtime == null || open.freq || open.mode) return;
    runtime.lastSent = runtime.state.vfo;
  }

  /// The VFO of a radio no app VFO is driven by moved — a panel tuned it. Its own reports come back
  /// here too, as `radio`, and go no further.
  void _onNodeVfoChanged(RadioService radio, String uuid) {
    if (radio.lastVfoOrigin == VfoOrigin.radio || !_runtimes.containsKey(uuid)) return;
    final vfo = radio.vfo(uuid);
    tuneNode(uuid, VfoReading(freqKHz: vfo.freq, mode: vfo.mode));
  }
}
