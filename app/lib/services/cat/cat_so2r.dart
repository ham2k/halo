// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SO2R's second radio (docs/design/cat.md § Radio B, for SO2R): the role
// that drives `vfoB`, the set the operator is in, and the turns the two
// radios' keyers take on the air.

part of 'cat_service.dart';

/// How long a PTT press waits for the other radio to come off the air before
/// it is given up. Nothing shows the wait, and a key that went down long
/// after the press would put an open mic on the air with nobody at it.
const so2rPttWait = Duration(seconds: 2);

mixin _So2r on _KeyingSurface {
  Map<String, _NodeRuntime> get _runtimes;
  Future<void> _save();
  void _withKeyInUseTidied(void Function() mutate);
  void _retune(String uuid, String vfoKey);
  void _setEnterSendsOf(bool running);
  bool _nodeTransmitting(String? uuid);
  void setNodeAntenna(String uuid, {String? rx, String? tx});
  String? designatedFor(String category, {String? radio});
  Future<void> setDesignated(String category, String? uuid, {String? radio});
  EquipmentNode? get so2rAudioRadio;

  void _startSo2rAudio();
  void _stopSo2rAudio();

  /// Brings the picked SO2R switcher up as a reconnect would, and nothing
  /// else.
  Future<void> _connectSo2rSwitch();

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
    // A rig's own TX report changes with the service's state. Pumped after
    // the report is taken in, not inside the notify that carries it: the
    // rest of the report — the PTT key's and the keyers' — is still on its
    // way.
    addListener(_pumpSoon);
    _startSo2rAudio();
    for (final radio in const ['A', 'B']) {
      _lastStyles[radio] = isRunning(radio);
    }
    _styles.addListener(_noteStyles);
    _radio?.addListener(_onStyleVfo);
  }

  void _stopSo2r() {
    _settings.removeListener(_onSo2rSetting);
    _onAirChanges.removeListener(_pump);
    removeListener(_pumpSoon);
    _setPttWaiting(null);
    _styles.removeListener(_noteStyles);
    _radio?.removeListener(_onStyleVfo);
    runningB.dispose();
    _styleChanges.dispose();
    _stopSo2rAudio();
  }

  void _onSo2rSetting() {
    final on = _settings.experimentEnabled('so2r') /* stored key, see experiments.yaml */;
    if (on == _so2rOn) return;
    if (!on) _stopRadioB();
    _withKeyInUseTidied(() => _so2rOn = on);
    // Radio B becomes a set of its own, or stops being one: its style is
    // now runningB's, or Radio A's, and what it ran before is no run of it.
    _lastStyles['B'] = isRunning('B');
    operatingStyle.forget('B');
    _styleChanges.notify();
    // Radio B and the SO2R switcher are kept connected, and nothing else
    // would bring them up until the next launch or a link drop.
    if (on) {
      unawaited(_connectRadio2());
      unawaited(_connectSo2rSwitch());
    }
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
    // A Radio B is what the switcher switches to: the pick takes effect now.
    unawaited(_connectSo2rSwitch());
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

  /// [radio]'s operating style (`A` or `B`) — the same Run or S&P Enter
  /// Sends Messages plays, kept whether or not ESM is on
  /// (docs/design/logging-fields.md § Operating style).
  OperatingStyle styleOf(String radio) => isRunning(radio) ? OperatingStyle.run : OperatingStyle.normal;

  void setStyle(String radio, OperatingStyle style) => setRunning(radio, style == OperatingStyle.run);

  /// Run ↔ S&P: ⌥U, and a tap on the FYI area's pill.
  void toggleStyle(String radio) => setStyle(radio, styleOf(radio) == OperatingStyle.run ? OperatingStyle.normal : OperatingStyle.run);

  /// Moves each set's style with what the operator does — message 1, a
  /// self-spot, a QSY, a spot picked, a return to the run frequency.
  late final operatingStyle = OperatingStyleTracker(
    isRunning: isRunning,
    setRunning: setRunning,
    vfoOf: (radio) => _radio?.vfo(radio == 'B' ? 'vfoB' : 'vfoA') ?? const Vfo(),
    // The repeat chain's rule (CatService._onVfoChanged): only the rig's own
    // report while it says it transmits. A move the operator makes during a
    // message counts — the store notifies once, and skipped, it is lost.
    transmitting: (radio) => _radio?.lastVfoOrigin == VfoOrigin.radio && _nodeTransmitting(_radioUuid(radio)),
  );

  @override
  void _messageOneKeyed(String radio) {
    if (styledRadios.contains(radio)) operatingStyle.messageOne(radio);
  }

  /// The sets whose style is their own: Radio B's only under SO2R, where
  /// otherwise [isRunning] answers it with Radio A's.
  List<String> get styledRadios => _so2rOn ? const ['A', 'B'] : const ['A'];

  /// Everything a style is kept in. [enterSends] changes with ESM's switch
  /// too, so [_noteStyles] tells a change of style from a restatement.
  late final Listenable _styles = Listenable.merge([enterSends, runningB]);

  final _styleChanges = _StyleChanges();

  /// A set's style changing, or SO2R making Radio B a set or not
  /// ([styledRadios]) — and never ESM's switch alone.
  Listenable get styleChanges => _styleChanges;

  /// [meterReadings], and a set's style changing — which a radio reports
  /// nothing for: what a panel's `radio` trigger reads its dial on.
  late final Listenable dialChanges = Listenable.merge([(this as CatService).meterReadings, _styleChanges]);

  /// A set's VFO moved; the other VFOs are no set's.
  void _onStyleVfo() {
    final key = _radio!.lastVfoKey;
    if (key == 'vfoA' || (key == 'vfoB' && _so2rOn)) operatingStyle.vfoMoved(key == 'vfoB' ? 'B' : 'A');
  }

  final _lastStyles = <String, bool>{};

  /// Set while SWAP trades the styles: the run frequencies trade with them
  /// ([OperatingStyleTracker.swap]) and are not taken afresh.
  bool _tradingStyles = false;

  void _noteStyles() {
    var changed = false;
    for (final radio in styledRadios) {
      final running = isRunning(radio);
      if (_lastStyles[radio] == running) continue;
      _lastStyles[radio] = running;
      changed = true;
      if (!_tradingStyles) operatingStyle.styleChanged(radio);
    }
    if (changed) _styleChanges.notify();
  }

  /// SWAP: Radio A and Radio B trade Run or S&P, and each its run frequency.
  /// Ahead of the entries moving, whose retunes would otherwise read as each
  /// set leaving its own run frequency.
  void swapStyles() {
    if (radio2 == null) return;
    final runningA = isRunning('A');
    _tradingStyles = true;
    try {
      setRunning('A', isRunning('B'));
      setRunning('B', runningA);
    } finally {
      _tradingStyles = false;
    }
    operatingStyle.swap();
  }

  /// SWAP's part beyond the VFOs, which the logging panel's sets move with
  /// their entries, and the styles, which [swapStyles] trades
  /// (docs/design/cat.md § Radio B, for SO2R): when the two are slices of
  /// one radio ([so2rAudioRadio]), each takes the other's antenna ports and
  /// antenna in use.
  ///
  /// Two rigs keep their own: a port name means the same wire only on one
  /// radio — an IC-7610's ANT2 is not a TS-890's — and each rig is still on
  /// its own wire, which the antenna in use names.
  void swapRadioSettings() {
    final a = _localRadio1, b = radio2;
    if (b == null) return;
    if (a != null && so2rAudioRadio != null) {
      final antennasA = stateFor(a).antennas, antennasB = stateFor(b).antennas;
      _takeAntennas(a, antennasB);
      _takeAntennas(b, antennasA);
      final inUseA = designatedFor(kCategoryAntenna), inUseB = designatedFor(kCategoryAntenna, radio: b);
      if (inUseA != inUseB) {
        unawaited(setDesignated(kCategoryAntenna, inUseB));
        unawaited(setDesignated(kCategoryAntenna, inUseA, radio: b));
      }
    }
  }

  /// Points [uuid]'s antenna ports where [from] has the other slice's.
  void _takeAntennas(String uuid, RadioAntennas? from) {
    final own = stateFor(uuid).antennas;
    if (from == null || own == null) return;
    final rx = own.rxPorts.contains(from.rx) ? from.rx : null;
    final tx = own.txPorts.contains(from.tx) ? from.tx : null;
    if ((rx == null && tx == null) || (rx == own.rx && tx == own.tx)) return;
    setNodeAntenna(uuid, rx: rx, tx: tx);
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

  /// Whether [radio] is on the air: its keyer keying, the app's PTT key held
  /// on it, or its rig saying it transmits — a mic, a footswitch, an
  /// external keyer, or a message the app has stopped and the rig has not
  /// yet unkeyed from. What a turn waits on: one radio on the air at a time
  /// is the rig's word, not the app's, and keyed while the other rig still
  /// transmits, the two overlap — on two slices of one Flex, the stopped
  /// slice's unkey lands after the new key and drops it.
  bool _keyedOnAir(String radio) => _keyerOf(radio).onAir || pttHeldOn(_radioUuid(radio)) || _nodeTransmitting(_radioUuid(radio));

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
  /// app is sending on the other radio, and goes once that rig says it is
  /// receiving. What the app did not key there is waited for, never cut
  /// off. Either way an operator's message on one radio sends the other's
  /// repeating CQ again as soon as it is done.
  bool _clearToSend(String radio, {required bool repeat, bool queuedCw = false}) {
    if (!_twoKeyers) return true;
    if (queuedCw && !repeat && _canAppendSharedCw(radio)) return true;
    final other = _otherRadio(radio);
    // A send flushed from [waiting] ([_pump]) was counted at its keypress:
    // counted again, it reads as keyed after a later message on the other
    // radio, which [keyedOverSince] then drops.
    if (!repeat && !_pumping) {
      _keyedAt[radio] = ++_keySequence;
      // The operator keying this radio is a new start for it: a resume
      // still pending here belonged to a chain that message replaces.
      _resume.remove(radio);
      if (_keyerOf(other).chain.running) _resume.add(other);
      // The operator moved on from the PTT key they pressed, and from what
      // they keyed on the other radio that is still waiting for its turn.
      _setPttWaiting(null);
      if (!_settings.so2rQueueMessages) _keyerOf(other).dropWaitingMessages();
    }
    if (!_keyedOnAir(other)) return true;
    if (repeat || _settings.so2rQueueMessages) return false;
    // No turns while the other radio comes off the air: it is quiet for this
    // send, which is about to take the air, and not for what waits.
    _holdingTurns(() {
      _keyerOf(other).interrupt();
      if (pttHeldOn(_radioUuid(other))) _ptt.release();
    });
    return !_keyedOnAir(other);
  }

  /// [_pump], once the change that called for it has been taken in whole.
  void _pumpSoon() {
    if (_pumpScheduled) return;
    _pumpScheduled = true;
    scheduleMicrotask(() {
      _pumpScheduled = false;
      _pump();
    });
  }

  bool _pumpScheduled = false;

  /// The radio whose PTT key the operator pressed while the other radio was
  /// still on the air, keyed once it is not — unless the operator keys
  /// anything else, lets go of a Hold key, or [so2rPttWait] runs out first.
  String? _pttWaiting;
  Timer? _pttWaitLimit;

  void _setPttWaiting(String? radio) {
    _pttWaitLimit?.cancel();
    _pttWaitLimit = radio == null ? null : Timer(so2rPttWait, () => _pttWaiting = null);
    _pttWaiting = radio;
  }

  @override
  bool get pttWaiting => _pttWaiting != null;

  @override
  bool pttWaitingOn(String? uuid) => _pttWaiting != null && uuid != null && _radioUuid(_pttWaiting!) == uuid;

  @override
  bool _cancelPttWait() {
    if (_pttWaiting == null) return false;
    _setPttWaiting(null);
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
  /// A press while the key still waits takes it back.
  @override
  void togglePtt(String radio) {
    if (!_twoKeyers || pttHeldOn(radio)) return super.togglePtt(radio);
    final mine = radio == radio2 ? 'B' : 'A', other = _otherRadio(mine);
    final waited = _pttWaiting;
    _setPttWaiting(null);
    if (waited == mine) return;
    if (_keyerOf(other).chain.running) _resume.add(other);
    _holdingTurns(() {
      _keyerOf(other).interrupt();
      if (pttHeldOn(_radioUuid(other))) _ptt.release();
      if (!_settings.so2rQueueMessages) _keyerOf(other).dropWaitingMessages();
      if (_keyedOnAir(other)) {
        _setPttWaiting(mine);
      } else {
        super.togglePtt(radio);
      }
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
      // The operator's own key, the latest thing they asked for.
      if (_pttWaiting case final radio?) {
        _setPttWaiting(null);
        if (_radioUuid(radio) case final uuid?) super.togglePtt(uuid);
        return;
      }
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
    var alsoStopped = _cancelPttWait();
    _holdingTurns(() => alsoStopped = _ptt.release() | stopNodeTunes() | alsoStopped);
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

class _StyleChanges extends ChangeNotifier {
  void notify() => notifyListeners();
}
