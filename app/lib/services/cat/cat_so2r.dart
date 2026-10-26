// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SO2R's second radio (docs/design/cat.md § Radio B, for SO2R): the role
// that drives `vfoB`, and which of the two radios keying is for.

part of 'cat_service.dart';

mixin _So2r on ChangeNotifier {
  SettingsService get _settings;
  Map<String, _NodeRuntime> get _runtimes;
  String? get _localRadio1;
  Future<void> _save();
  bool stopKeying();
  void _withKeyInUseTidied(void Function() mutate);
  void tuneNode(String uuid, VfoReading requested);
  ValueNotifier<({bool on, bool running})> get enterSends;
  void _setEnterSendsOf(bool running);
  bool get _keyingBusy;
  bool get cwSending;
  ValueNotifier<VoiceActivity?> get voiceActivity;
  bool _nodeTransmitting(String? uuid);
  bool get _disposed;

  /// Brings Radio B up the way a reconnect brings up radio1.
  Future<void> _connectRadio2();

  /// Keying moved between the radios — see [CatKeying.followKeyingRadio].
  void _onKeyingRadioMoved();

  /// The SO2R experiment, as the service last applied it: a change goes
  /// through [_withKeyInUseTidied] like every other move of the key in use,
  /// so turning SO2R off mid-message stops Radio B's keyer rather than
  /// leaving it sending with nothing to show or stop it.
  bool _so2rOn = false;

  /// What keying is busy with — a message, voice play, repeat or held PTT —
  /// whose every change may let keying follow the operator.
  late final Listenable _keyingActivity;

  void _startSo2r(Listenable keyingActivity) {
    _so2rOn = _settings.experimentEnabled('so2r') /* stored key, see experiments.yaml */;
    _settings.addListener(_onSo2rSetting);
    _keyingActivity = keyingActivity..addListener(_followOperator);
  }

  void _stopSo2r() {
    _settings.removeListener(_onSo2rSetting);
    _keyingActivity.removeListener(_followOperator);
    runningB.dispose();
  }

  void _onSo2rSetting() {
    final on = _settings.experimentEnabled('so2r') /* stored key, see experiments.yaml */;
    if (on == _so2rOn) return;
    if (!on) _stopKeyingOnB();
    _withKeyInUseTidied(() {
      _so2rOn = on;
      if (!on) _keyingOnB = false;
    });
    _onKeyingRadioMoved();
    // Radio B is one of the radios kept connected, and nothing else would
    // bring it up until the next launch or a link drop.
    if (on) unawaited(_connectRadio2());
    notifyListeners();
  }

  /// SO2R's second radio — the local transceiver whose VFO is `vfoB`.
  /// Plain stored state, like [radio1], and only ever a local rig.
  String? _radio2;

  /// [_radio2] while the SO2R experiment is on, and null otherwise: a stored
  /// pick neither drives `vfoB` nor auto-connects for an operator who has
  /// turned SO2R off, and is back when they turn it on again.
  String? get radio2 => _so2rOn ? _radio2 : null;

  bool isRadio2(String uuid) => radio2 == uuid;

  /// Points `vfoB` at a local transceiver, or None. Radio1's own rig is
  /// refused rather than taken from it — the picker never offers it.
  Future<void> setRadio2(String? uuid) async {
    if (_radio2 == uuid || (uuid != null && uuid == _localRadio1)) return;
    // [setRadio1]'s echo-guard reasoning: neither radio was told anything
    // through `vfoB` while it was not Radio B.
    for (final id in [_radio2, uuid]) {
      if (id != null) _runtimes[id]?.lastSent = null;
    }
    _stopKeyingOnB();
    // The key in use is the radio's pick, so a new Radio B is a new key —
    // and with none, keying is radio1's again.
    _withKeyInUseTidied(() {
      _radio2 = uuid;
      if (uuid == null) _keyingOnB = false;
    });
    _onKeyingRadioMoved();
    _followOperator();
    await _save();
    notifyListeners();
  }

  /// Clears Radio B from inside another change of radio — radio1 taking its
  /// rig, or its node removed — stopping what it had going, as [setRadio2]
  /// does.
  void _forgetRadio2() {
    _stopKeyingOnB();
    _radio2 = null;
    _keyingOnB = false;
  }

  /// Keying is leaving Radio B for good — Radio B changed or gone, or SO2R
  /// turned off: everything it had going stops, as a key in the other set
  /// would stop it, rather than a repeat's next send or a message still
  /// rendering coming back on radio A.
  void _stopKeyingOnB() {
    if (!_keyingOnB) return;
    _dropHolds();
    stopKeying();
  }

  /// SO2R: radio2's uuid while keying is Radio B's — its key in use, its
  /// voice memories, its PTT — and null while it is radio1's. Keying follows
  /// the set the operator is in, except that a message, chain or repeat
  /// under way keeps its radio until it ends: a CQ goes on on one radio while
  /// the operator works the other, and keying something from the other set
  /// ([keyForOperator]) is what stops it.
  String? get _keyingRadio2 => _keyingOnB ? radio2 : null;
  bool _keyingOnB = false;

  /// The set the operator is in, `A` or `B` — told by the logging panel.
  String _operatorRadio = 'A';

  /// Which radio keying is for right now: `A` or `B`.
  String get keyingRadio => _keyingRadio2 == null ? 'A' : 'B';

  /// Notes which set the operator is in; keying moves with them unless
  /// something is going out. Stops nothing on the air.
  void noteOperatorRadio(String radio) {
    _operatorRadio = radio;
    _followOperator();
  }

  /// Moves keying to the operator's radio once nothing is going out — on a
  /// move between the sets, and when a message, chain, repeat or held PTT
  /// left behind on the other radio ends.
  void _followOperator() {
    if (!_disposed && !_keyingBusy) _keyFor(_operatorRadio);
  }

  /// The set the operator is in, `A` or `B` — always `A` outside SO2R.
  String get operatorRadio => _so2rOn ? _operatorRadio : 'A';

  /// Radio B's Run versus S&P, its set's ESM and pill read. Radio A's is
  /// [enterSends]' `running`, the only one there is outside SO2R.
  late final runningB = ValueNotifier<bool>(_settings.enterSendsRunningB);

  /// Whether [radio] (`A` or `B`) is running rather than searching and
  /// pouncing.
  bool isRunning(String radio) => radio == 'B' && _so2rOn ? runningB.value : enterSends.value.running;

  /// Enter Sends Messages as the operator's radio has it: the switch is the
  /// station's, Run or S&P that radio's — what a surface showing the switch
  /// shows, and hands back to [setEnterSends], which files the Run or S&P
  /// under the same radio.
  ({bool on, bool running}) get operatorEnterSends => (on: enterSends.value.on, running: isRunning(operatorRadio));

  void setRunning(String radio, bool running) {
    if (radio != 'B' || !_so2rOn) return _setEnterSendsOf(running);
    if (runningB.value == running) return;
    runningB.value = running;
    unawaited(_settings.setEnterSendsRunningB(running));
  }

  /// Whether [radio] (`A` or `B`) is on the air: its rig says so, its PTT
  /// is held, or a message or memory is being keyed through it.
  bool isTransmitting(String radio) {
    if (_nodeTransmitting(radio == 'B' ? radio2 : _localRadio1)) return true;
    if (radio != keyingRadio) return false;
    final voice = voiceActivity.value;
    return cwSending || (voice != null && !voice.recording);
  }

  /// Whether [can] — the operator's capability check, `canKeyCw` and the
  /// like — holds with keying on [radio] (`A` or `B`), moving nothing and
  /// stopping nothing. A set with no radio keys nothing at all: falling back
  /// to the other radio would put set B's message on the air on radio A.
  bool canKeyOn(String radio, bool Function() can) {
    final toB = radio == 'B' && _so2rOn;
    if (toB && radio2 == null) return false;
    if (toB == _keyingOnB) return can();
    // Asked of the other radio's key in use, then put back — no tidy, no
    // notification: nothing has moved.
    _keyingOnB = toB;
    try {
      return can();
    } finally {
      _keyingOnB = !toB;
    }
  }

  /// Points keying at the operator's radio, ahead of anything keying from
  /// their set — when it can do what [can] asks; false, with nothing moved
  /// and nothing stopped, when it cannot. Crossing to the other radio stops
  /// whatever is going out on the one being left, a message still rendering
  /// for it included ([KeyingHold]) — a message key on radio B is the
  /// operator moving on from radio A's CQ.
  bool keyForOperator(bool Function() can) {
    if (!canKeyOn(operatorRadio, can)) return false;
    if ((operatorRadio == 'B') == _keyingOnB) return true;
    _dropHolds();
    stopKeying();
    _keyFor(_operatorRadio);
    return true;
  }

  /// A key press's claim on the radio it keyed from, from the press until
  /// what it keys is handed to the radio: keying waits for a render or a
  /// log to finish before the message goes out, and without the claim a
  /// move to the other set in between would send it on the other radio.
  KeyingHold holdKeying() {
    final hold = KeyingHold._(keyingRadio);
    _holds.add(hold);
    return hold;
  }

  void releaseKeying(KeyingHold hold) {
    if (!_holds.remove(hold)) return;
    _followOperator();
  }

  final _holds = <KeyingHold>{};

  void _dropHolds() {
    for (final hold in _holds) {
      hold._live = false;
    }
    _holds.clear();
  }

  void _keyFor(String radio) {
    final toB = radio == 'B' && radio2 != null;
    if (toB == _keyingOnB) return;
    _withKeyInUseTidied(() => _keyingOnB = toB);
    _onKeyingRadioMoved();
    notifyListeners();
  }

  /// [_onVfoChanged] for `vfoB`: retunes Radio B. Smart VFO Snap and the
  /// idle retry's nudge stay radio1's.
  void _onVfoBChanged(RadioService radio) {
    if (radio.lastVfoOrigin == VfoOrigin.radio) return;
    final uuid = radio2;
    if (uuid == null) return;
    final vfo = radio.vfo('vfoB');
    tuneNode(
      uuid,
      VfoReading(
        freqKHz: vfo.freq,
        mode: resolveSideband(vfo.mode, vfo.freq, band: vfo.band),
      ),
    );
  }
}

/// [_So2r.holdKeying]'s claim. No longer [live] once the operator keyed
/// something from the other set, which stops what this one was to send.
class KeyingHold {
  KeyingHold._(this.radio);

  /// The radio it was taken on, `A` or `B`.
  final String radio;

  bool get live => _live;
  bool _live = true;
}
