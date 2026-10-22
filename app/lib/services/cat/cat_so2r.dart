// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SO2R's second radio (docs/design/cat.md § Radio B, for SO2R): the role
// that drives `vfoB`, the set the operator is in, and the turns the two
// radios' keyers take on the air.

part of 'cat_service.dart';

mixin _So2r on _KeyingSurface {
  Map<String, _NodeRuntime> get _runtimes;
  Future<void> _save();
  void _withKeyInUseTidied(void Function() mutate);
  void _retune(String uuid, String vfoKey);
  void _setEnterSendsOf(bool running);
  bool _nodeTransmitting(String? uuid);
  bool get _disposed;

  /// Brings Radio B up the way a reconnect brings up radio1.
  Future<void> _connectRadio2();

  /// The SO2R experiment, as the service last applied it: a change goes
  /// through [_withKeyInUseTidied] like every other move of the key in use,
  /// so turning SO2R off mid-message stops Radio B's keyer rather than
  /// leaving it sending with nothing to show or stop it.
  bool _so2rOn = false;

  /// Everything whose change may give the other radio its turn on the air.
  late final Listenable _onAirChanges;

  void _startSo2r() {
    _so2rOn = _settings.experimentEnabled('so2r') /* stored key, see experiments.yaml */;
    _settings.addListener(_onSo2rSetting);
    _onAirChanges = Listenable.merge([
      for (final radio in ['A', 'B']) ...[_keyerOf(radio).cwProgress, _keyerOf(radio).voiceActivity, _keyerOf(radio).voiceStarting],
      _ptt.held,
    ])..addListener(_pump);
  }

  void _stopSo2r() {
    _settings.removeListener(_onSo2rSetting);
    _onAirChanges.removeListener(_pump);
    runningB.dispose();
  }

  void _onSo2rSetting() {
    final on = _settings.experimentEnabled('so2r') /* stored key, see experiments.yaml */;
    if (on == _so2rOn) return;
    if (!on) _stopRadioB();
    _withKeyInUseTidied(() => _so2rOn = on);
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
  @override
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
    _stopRadioB();
    // The key in use is the radio's pick, so a new Radio B is a new key.
    _withKeyInUseTidied(() => _radio2 = uuid);
    await _save();
    notifyListeners();
  }

  /// Clears Radio B from inside another change of radio — radio1 taking its
  /// rig, or its node removed — stopping what it had going, as [setRadio2]
  /// does.
  void _forgetRadio2() {
    _stopRadioB();
    _radio2 = null;
  }

  /// Radio B is going, or changing: everything its keyer had going stops,
  /// rather than a repeat's next send or a message waiting its turn going
  /// out on whatever fills the role next.
  void _stopRadioB() {
    _resume.remove('B');
    _keyerOf('B').stopAll();
    // What radio A held for Radio B goes once the role has changed, with
    // nothing left to wait for.
    scheduleMicrotask(_pump);
  }

  /// The set the operator is in, `A` or `B` — told by the logging panel.
  String _operatorRadio = 'A';

  /// Notes which set the operator is in. Stops and moves nothing: each
  /// radio keeps its own keyer, and what the operator keys next is keyed
  /// on this one.
  void noteOperatorRadio(String radio) {
    if (radio == _operatorRadio) return;
    _operatorRadio = radio;
    notifyListeners();
  }

  /// The set the operator is in, `A` or `B` — always `A` outside SO2R.
  @override
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

  @override
  void setRunning(String radio, bool running) {
    if (radio != 'B' || !_so2rOn) return _setEnterSendsOf(running);
    if (runningB.value == running) return;
    runningB.value = running;
    unawaited(_settings.setEnterSendsRunningB(running));
  }

  String? _radioUuid(String radio) => radio == 'B' ? radio2 : _localRadio1;

  /// Whether [radio] (`A` or `B`) is on the air: its rig says so, its PTT
  /// is held, or its keyer is keying a message or playing a memory.
  bool isTransmitting(String radio) => _nodeTransmitting(_radioUuid(radio)) || _keyerOf(radio).onAir;

  // ------------------------------------------------- the radios' turns

  /// Whether both radios key for the operator: SO2R on, with a Radio B.
  bool get _twoKeyers => radio2 != null;

  /// A CAT append is already ordered by the shared queue. An external keyer,
  /// voice playback or a held PTT is independent and still needs a turn.
  bool _canAppendSharedCw(String radio) {
    final other = _otherRadio(radio), keyer = _keyerOf(other);
    if (!keyer.cwSending || keyer.voiceStarting.value || keyer.voiceActivity.value != null || pttHeldOn(_radioUuid(other))) return false;
    final first = _keyerOf(radio).station.keyInUse, second = keyer.station.keyInUse;
    if (first == null || second == null || connectedSession(first) is! CwKeyerSession || connectedSession(second) is! CwKeyerSession) return false;
    final device = logicalDeviceIdFor(first);
    return device != null && device == logicalDeviceIdFor(second);
  }

  static String _otherRadio(String radio) => radio == 'A' ? 'B' : 'A';

  /// Whether the app has [radio] on the air: its keyer keying, or the app's
  /// PTT key held on it. What a turn waits on — the things the app hears
  /// end.
  bool _keyedOnAir(String radio) => _keyerOf(radio).onAir || pttHeldOn(_radioUuid(radio));

  /// The radios whose repeat sends message 1 again the moment the other
  /// radio is quiet, rather than at the end of its wait: the operator keyed
  /// the other radio over or during it, and the CQ picks up where they left
  /// it.
  final _resume = <String>{};

  /// Orders the operator's messages across both radios: bumped as each one
  /// asks for its turn ([_keyedAt]), and read at a keypress ([keyMark]).
  int _keySequence = 0;

  /// Each radio's last operator message to ask for its turn, on
  /// [_keySequence].
  final _keyedAt = <String, int>{'A': 0, 'B': 0};

  /// Where the operator's messages stand, taken at a keypress whose message
  /// reaches the keyer later — rendered, or behind a contact being logged —
  /// for [keyedOverSince].
  int get keyMark => _keySequence;

  /// Whether the operator keyed the radio other than [radio] after [mark],
  /// while a message keyed then for [radio] was still on its way. Had it
  /// gone at once, that later message would have stopped it; sent now, it
  /// would stop the later one instead, so it is not sent. Never with
  /// messages queued, where it waits its turn.
  bool keyedOverSince(String radio, int mark) => _twoKeyers && !_settings.so2rQueueMessages && _keyedAt[_otherRadio(radio)]! > mark;

  /// [KeyingStation.clearToSend] for [radio]'s keyer. One radio on the air
  /// at a time: a repeat's send waits for the other radio to be quiet,
  /// whatever its delay, and so does an operator's while
  /// [SettingsService.so2rQueueMessages] is on — otherwise it stops what the
  /// other radio is sending. Either way an operator's message on one radio
  /// sends the other's repeating CQ again as soon as it is done.
  bool _clearToSend(String radio, {required bool repeat, bool queuedCw = false}) {
    if (!_twoKeyers) return true;
    if (queuedCw && !repeat && _canAppendSharedCw(radio)) return true;
    final other = _otherRadio(radio);
    if (!repeat) {
      _keyedAt[radio] = ++_keySequence;
      // The operator keying this radio is a new start for it: a resume
      // still pending here belonged to a chain that message replaces.
      _resume.remove(radio);
      if (_keyerOf(other).chain.running) _resume.add(other);
    }
    if (!_keyedOnAir(other)) return true;
    if (repeat || _settings.so2rQueueMessages) return false;
    // No turns while the other radio comes off the air: it is quiet for this
    // send, which is about to take the air, and not for what waits.
    _holdingTurns(() {
      _keyerOf(other).interrupt();
      if (pttHeldOn(_radioUuid(other))) _ptt.release();
    });
    return true;
  }

  /// Runs [stop] with no turn given out while it does: a radio stopping is
  /// quiet, and without this what waits would take the air mid-stop.
  void _holdingTurns(void Function() stop) {
    final was = _pumping;
    _pumping = true;
    try {
      stop();
    } finally {
      _pumping = was;
    }
  }

  /// The app's PTT key going down on [radio]: the operator talking on it,
  /// which takes the other radio off the air through its own keyer — a
  /// sequence it is playing ends there rather than going on to its next
  /// memory over the operator — and which the other radio's repeat resumes
  /// after, as for a message.
  @override
  void togglePtt(String radio) {
    if (!_twoKeyers || pttHeldOn(radio)) return super.togglePtt(radio);
    final other = _otherRadio(radio == radio2 ? 'B' : 'A');
    if (_keyerOf(other).chain.running) _resume.add(other);
    _holdingTurns(() {
      _keyerOf(other).interrupt();
      super.togglePtt(radio);
    });
  }

  bool _pumping = false;

  /// Gives the air to what waits for it, once neither radio is on it: the
  /// oldest send held for the other radio first, then a repeat resuming.
  void _pump() {
    if (_pumping || _disposed) return;
    // Without a Radio B only what radio A held for it is left to go.
    final radios = _twoKeyers ? const ['A', 'B'] : const ['A'];
    if (!_twoKeyers) _resume.clear();
    if (radios.any(_keyedOnAir)) return;
    _pumping = true;
    try {
      final held = [
        for (final radio in radios)
          if (_keyerOf(radio).waiting.value.isNotEmpty) radio,
      ]..sort((a, b) => _keyerOf(a).waiting.value.first.sequence.compareTo(_keyerOf(b).waiting.value.first.sequence));
      if (held.isNotEmpty) {
        // Whatever it holds is its turn, a repeat's own send included.
        _resume.remove(held.first);
        _keyerOf(held.first).flushWaiting();
        return;
      }
      for (final radio in [..._resume]) {
        _resume.remove(radio);
        if (_keyerOf(radio).chain.running) {
          _keyerOf(radio).chain.sendNow();
          return;
        }
      }
    } finally {
      _pumping = false;
    }
  }

  /// Whether an Escape just stopped keying under SO2R — see
  /// [CatKeying.escapeStoppedKeying].
  bool _so2rEscapeStopped = false;

  @override
  bool get escapeStoppedKeying => super.escapeStoppedKeying || _so2rEscapeStopped;

  /// Escape with two keyers. With [SettingsService.so2rQueueMessages] on and
  /// messages waiting, only what is on the air stops: the waiting messages
  /// go next and a repeat stopped mid-CQ resumes after them. Otherwise
  /// everything stops, on both radios, repeats and waiting messages
  /// included. False when there was nothing to stop.
  @override
  bool stopKeying() {
    if (!_twoKeyers) return super.stopKeying();
    // Held: the PTT key coming up is a radio falling quiet, and what waits
    // would take the air before the stop below reaches it.
    var alsoStopped = false;
    _holdingTurns(() => alsoStopped = _ptt.release() | stopNodeTunes());
    final (a, b) = (_keyerOf('A'), _keyerOf('B'));
    if (!a.busy && !b.busy && !alsoStopped) return false;
    _so2rEscapeStopped = true;
    scheduleMicrotask(() => _so2rEscapeStopped = false);
    if (_settings.so2rQueueMessages && (a.hasQueued || b.hasQueued)) {
      _holdingTurns(() {
        for (final radio in ['A', 'B']) {
          final keyer = _keyerOf(radio);
          if (!keyer.onAir) continue;
          if (keyer.chain.running) _resume.add(radio);
          keyer.stopCurrent();
        }
      });
      _pump();
      return true;
    }
    _resume.clear();
    _holdingTurns(() {
      a.stopAll();
      b.stopAll();
    });
    return true;
  }

  /// [_onVfoChanged] for `vfoB`: retunes Radio B, a band picked by name
  /// included. Smart VFO Snap and the idle retry's nudge stay radio1's.
  void _onVfoBChanged(RadioService radio) {
    if (radio.lastVfoOrigin == VfoOrigin.radio) return;
    final uuid = radio2;
    if (uuid != null) _retune(uuid, 'vfoB');
  }
}
