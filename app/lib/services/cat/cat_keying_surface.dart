// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keying as the keyer area, the function keys and Escape see it: a keyer per
// radio — radio1's, and under SO2R Radio B's — each with its repeat chain and
// the CW and voice keyers behind its [CatKeying], and the app's PTT key.
// What [CatKeying] asks of the station in return stays on [CatService], which
// is radio1's keyer's station; Radio B's has a view of its own.

part of 'cat_service.dart';

mixin _KeyingSurface on ChangeNotifier implements KeyingStation {
  SettingsService get _settings;
  RadioService? get _radio;
  PeerKeying get _peerKeying;
  String? get _localRadio1;
  @override
  String? get radio2;
  bool stopNodeTunes();
  String get operatorRadio;
  void setRunning(String radio, bool running);
  bool get _disposed;

  /// Each radio's keying (cat_keying.dart) — which session keys, what it is
  /// keying, the speed, the memories, its repeat chain (keyer_repeat.dart).
  /// Radio1's is the one a peer link reaches, and holds what the radios
  /// share: Enter Sends Messages and whether the keyer area is shown.
  late final _keyers = {
    'A': CatKeying(
      station: this,
      settings: _settings,
      chain: KeyerRepeat(vfo: () => _radio?.vfoA),
      peer: _peerKeying,
    ),
    'B': CatKeying(
      station: _RadioBKeyingStation(this as CatService),
      settings: _settings,
      chain: KeyerRepeat(vfo: () => _radio?.vfo('vfoB')),
      peer: PeerKeying(),
      radio: 'B',
    ),
  };

  CatKeying _keyerOf(String radio) => _keyers[radio == 'B' ? 'B' : 'A']!;

  /// Radio1's keying, which the peer bridge and the station's own reports
  /// reach.
  CatKeying get _keying => _keyers['A']!;

  /// The keyer whose radio is [uuid]: Radio B's for Radio B, radio1's for
  /// any other.
  CatKeying _keyerForNode(String? uuid) => _keyerOf(uuid != null && uuid == radio2 ? 'B' : 'A');

  /// The computer's voice keyer, where this device can run one
  /// (docs/design/cat.md § The computer's voice keyer): each radio's keying
  /// plays the sets through its own rig's sound device, under its own pick.
  /// Radio1's keeps the desk's recorder and the word sets, and Radio B's says
  /// a templated message through the same maker.
  void _wireComputerVoice(VoiceAudio voiceAudio, Future<String> Function() voiceMessagesDirectory) {
    for (final keyer in _keyers.values) {
      keyer
        ..voiceAudio = voiceAudio
        ..voiceMessagesDirectory = voiceMessagesDirectory
        ..onComputerVoiceChanged = () {
          if (!_disposed) notifyListeners();
        };
      // Every change that makes or unmakes one — a session opened, the
      // directory found, a set picked — is one this service announces.
      addListener(keyer.syncComputerKeyers);
    }
    // Made now rather than when first asked for: it is what makes a
    // templated message, and a key can ask for one before any surface has.
    final words = _keying.voicedWords;
    if (words != null) _keyerOf('B').voiceMaker = words.voice;
  }

  void _disposeComputerKeyers() {
    for (final keyer in _keyers.values) {
      keyer.disposeComputerKeyers();
    }
  }

  late final _radioKeyers = {
    for (final radio in ['A', 'B']) radio: RadioKeyer._(this as CatService, radio),
  };

  /// [radio]'s keyer (`A` or `B`) — what a surface keying for that radio's
  /// set reads and keys through. Under SO2R each set's keyer area is its
  /// radio's.
  RadioKeyer keyer(String radio) => _radioKeyers[radio == 'B' ? 'B' : 'A']!;

  /// The keyer of the set the operator is in: what the function keys and
  /// the service's own keying API below speak for. Radio1's outside SO2R.
  RadioKeyer get operatorKeyer => keyer(operatorRadio);

  ValueNotifier<KeyerRepeatWait?> get keyerRepeat => operatorKeyer.keyerRepeat;
  ValueNotifier<bool> get keyerRepeatActive => operatorKeyer.keyerRepeatActive;
  bool get keyerRepeating => operatorKeyer.keyerRepeating;
  void armKeyerRepeat({required Duration delay, required String text, required void Function() send, int? memory}) =>
      operatorKeyer.armKeyerRepeat(delay: delay, text: text, send: send, memory: memory);
  void cancelKeyerRepeat() => operatorKeyer.cancelKeyerRepeat();

  /// See [KeyerRepeat.deadlineMillis] — the tests' way in.
  @visibleForTesting
  int? get keyerRepeatDeadlineMillis => _keyerOf(operatorRadio).chain.deadlineMillis;

  bool get canKeyCw => operatorKeyer.canKeyCw;
  bool get designatedKeyIsKeyer => operatorKeyer.designatedKeyIsKeyer;
  EquipmentNode? get designatedKeyerNode => operatorKeyer.designatedKeyerNode;
  List<EquipmentNode> get keyerCandidates => _keying.keyerCandidates;
  int? get keyerSpeed => operatorKeyer.keyerSpeed;
  ({int min, int max})? get keyerSpeedRange => operatorKeyer.keyerSpeedRange;
  bool get cwSending => operatorKeyer.cwSending;
  ValueNotifier<CwSendProgress?> get cwProgress => operatorKeyer.cwProgress;
  ValueListenable<int> get cwStops => operatorKeyer.cwStops;
  ValueListenable<int> get keyerOpenRequests => _keying.keyerOpenRequests;
  ValueListenable<int> get keyboardModeRequests => operatorKeyer.keyboardModeRequests;
  ValueNotifier<CwLiveTyping?> get cwTyping => operatorKeyer.cwTyping;
  void toggleKeyboardMode() => operatorKeyer.toggleKeyboardMode();
  void openKeyerControl() => _keying.openKeyerControl();
  ValueNotifier<({bool on, bool running})> get enterSends => _keying.enterSends;

  /// [running] is the operator's radio's under SO2R — see [setRunning].
  void setEnterSends({bool? on, bool? running}) {
    if (running != null && operatorRadio == 'B') {
      setRunning('B', running);
      running = null;
    }
    _keying.setEnterSends(on: on, running: running);
  }

  bool sendCw(String text, {bool hasMessageOne = false}) => operatorKeyer.sendCw(text, hasMessageOne: hasMessageOne);
  void stopCw() => operatorKeyer.stopCw();
  void dropQueuedCw(int id) => operatorKeyer.dropQueuedCw(id);
  bool setKeyerSpeed(int wpm) => operatorKeyer.setKeyerSpeed(wpm);
  void refreshKeyerSpeed() => operatorKeyer.refreshKeyerSpeed();

  bool get canPlayVoice => operatorKeyer.canPlayVoice;
  bool get radio1HasVoiceMemories => operatorKeyer.radio1HasVoiceMemories;
  bool get radio1OffersVoiceMemories => _keying.radio1OffersVoiceMemories;
  bool get phoneKeyingOff => _keying.phoneKeyingOff;
  int get voiceMemoryCount => operatorKeyer.voiceMemoryCount;
  bool get canRecordVoice => operatorKeyer.canRecordVoice;
  bool get voiceMessagesAreLocal => operatorKeyer.voiceMessagesAreLocal;
  bool get voiceMessagesNamedOnRadio => operatorKeyer.voiceMessagesNamedOnRadio;
  String voiceMessageLabel(int n) => operatorKeyer.voiceMessageLabel(n);
  int voiceMessageDuration(int n) => operatorKeyer.voiceMessageDuration(n);
  Future<void> setVoiceMessageLabel(int n, String label) => operatorKeyer.setVoiceMessageLabel(n, label);
  ({String model, String text})? get voiceRecordingHelp => operatorKeyer.voiceRecordingHelp;

  // The computer's voice keyer as radio1's keying has it (docs/design/cat.md
  // § The computer's voice keyer); Radio B's is reached through its
  // [RadioKeyer].
  bool get voiceMessagesFromComputer => _keying.voiceMessagesFromComputer;
  AudioPlayback? listenToVoiceMessage(int n) => _keying.listenToVoiceMessage(n);
  void revealVoiceMessage(int n) => _keying.revealVoiceMessage(n);
  bool get computerVoiceSwitchesAudio => _keying.computerVoiceSwitchesAudio;
  bool get computerVoicePlaysToRadio => _keying.computerVoicePlaysToRadio;
  ComputerVoiceProblem? get computerVoiceProblem => _keying.computerVoiceProblem;

  /// The sound system the computer's voice keyer plays through — null where
  /// this device cannot run one.
  VoiceAudio? get computerVoiceAudio => _keying.computerVoiceAudio;

  /// Where radio1's phone messages come from (CatKeying.selectVoiceKeyingSource);
  /// Radio B's pick is its [RadioKeyer]'s.
  Future<void> selectVoiceKeyingSource(VoiceKeyingSource source) => _keying.selectVoiceKeyingSource(source);

  /// The sets of recorded voice messages, and the one in use.
  Future<void> selectVoiceMessageSet(String id) => _keying.selectVoiceMessageSet(id);
  Future<VoiceMessageSet?> addVoiceMessageSet(String name) => _keying.addVoiceMessageSet(name);
  Future<void> renameVoiceMessageSet(String id, String name) => _keying.renameVoiceMessageSet(id, name);
  Future<void> deleteVoiceMessageSet(String id) => _keying.deleteVoiceMessageSet(id);

  ValueNotifier<VoiceActivity?> get voiceActivity => operatorKeyer.voiceActivity;
  void playVoiceMemory(int n, {bool repeat = true}) => operatorKeyer.playVoiceMemory(n, repeat: repeat);
  void recordVoiceMemory(int n) => operatorKeyer.recordVoiceMemory(n);
  void stopVoice() => operatorKeyer.stopVoice();
  void playVoiceSequence(List<int> memories) => operatorKeyer.playVoiceSequence(memories);
  void cancelVoiceSequence() => operatorKeyer.cancelVoiceSequence();
  void stopMessageOne() => operatorKeyer.stopMessageOne();

  /// Escape: stops every message, chain and repeat — under SO2R, see
  /// `_So2r.stopKeying` for what it leaves.
  bool stopKeying() {
    final released = _ptt.release(), tuneStopped = stopNodeTunes();
    return _keying.stopKeying(alsoStopped: released || tuneStopped);
  }

  bool get escapeStoppedKeying => _keying.escapeStoppedKeying;

  /// ['] in a Phone mode (cat_ptt.dart) — this station's radios, never a peer's.
  late final _ptt = CatPtt()..held.addListener(notifyListeners);
  late final pttKeys = PttKeyboard(
    held: _ptt.held,
    release: () => _cancelPttWait() | (_ptt.owner == null && _ptt.release()),
    escape: stopKeying,
    toggle: togglePtt,
    hold: () => _settings.pttKeyMode == PttKeyMode.hold,
    waiting: () => pttWaiting,
  );

  /// Whether a PTT press waits to key until the other radio is off the air
  /// (SO2R's turns, cat_so2r.dart).
  bool get pttWaiting => false;

  /// Whether that press waits to key [uuid].
  bool pttWaitingOn(String? uuid) => false;

  /// Takes back a PTT press still waiting; false when none was.
  bool _cancelPttWait() => false;
  PttSession? _pttSession(String? uuid) => switch (uuid == null ? null : connectedSession(uuid)) {
    final PttSession session => session,
    _ => null,
  };
  bool get canPtt => operatorKeyer.canPtt;

  /// Whether the app's PTT key is on the logging radio — [pttKeys]' `held` is true for a key on any radio.
  bool get pttHeldOnRadio1 => pttHeldOn(_localRadio1);

  /// Whether the app's PTT key is on [uuid]'s radio.
  bool pttHeldOn(String? uuid) => _ptt.heldOn(_pttSession(uuid));
  void togglePtt(String radio) {
    final session = _pttSession(radio);
    if (session == null) return;
    if (_ptt.heldOn(session)) {
      _ptt.release();
      return;
    }
    _keyPtt(radio, session);
  }

  /// Keys [session], [radio]'s, after ending this operator's own keying —
  /// which a key already on it has done.
  bool _keyPtt(String radio, PttSession session, {Duration timeout = pttTimeout, Object? owner}) {
    if (!_ptt.heldOn(session)) {
      final keyer = _keyerForNode(radio);
      keyer.stopAll();
      keyer.quietOthers(radio);
    }
    return _ptt.key(session, timeout: timeout, owner: owner);
  }

  /// Whether the Main VFO radio can be keyed from here — a local one; a
  /// peer's never is.
  bool get canPttRadio1 => _pttSession(_localRadio1) != null;

  /// Who holds the station's PTT key (CatPtt.owner): null for the operator,
  /// and for no key at all.
  Object? get pttOwner => _ptt.owner;

  /// Keys the Main VFO radio for [owner], a CAT server client
  /// (cat_server_rig.dart). False when it did not key.
  bool keyRadio1Ptt(Object owner, {required Duration timeout}) {
    final radio = _localRadio1;
    final session = _pttSession(radio);
    // Asked before [_keyPtt] ends the operator's own keying: a key refused
    // must change nothing.
    if (radio == null || session == null || !_ptt.mayKey(owner)) return false;
    return _keyPtt(radio, session, timeout: timeout, owner: owner);
  }

  /// Drops [owner]'s key, on whichever radio it went to — the Main VFO may
  /// have moved since. A key anyone else holds stays.
  bool releasePtt(Object owner) => _ptt.release(owner: owner);

  /// One transmitter at a time, whoever asks: before a CW message or a voice
  /// memory goes out on [radio], the app's PTT key drops — on any radio, the
  /// message takes over — and every other radio stops its CW and voice.
  @override
  void yieldTransmitter(String? radio) => _yieldTransmitter(_keying, radio);

  void _yieldTransmitter(CatKeying keyer, String? radio) {
    _ptt.release();
    keyer.quietOthers(radio);
  }
}

/// What Radio B's keyer asks of the station: the service's answers, but for
/// Radio B — its own key in use, its own rig's memories and PTT, and its
/// turn on the air. A peer's radio is never Radio B, so nothing here keys
/// over a peer link.
class _RadioBKeyingStation implements KeyingStation {
  _RadioBKeyingStation(this._cat);

  final CatService _cat;

  @override
  String? get keyInUse => switch (_cat.radio2) {
    final uuid? => _cat.designatedFor(kCategoryKey, radio: uuid),
    null => null,
  };

  @override
  bool get peerKeyIsInUse => false;

  @override
  String? get peerRadioId => null;

  @override
  bool isKeyerNode(EquipmentNode node) => _cat.isKeyerNode(node);

  @override
  List<EquipmentNode> get nodes => _cat.nodes;

  @override
  EquipmentNode? nodeFor(String uuid) => _cat.nodeFor(uuid);

  @override
  EquipmentType? typeFor(EquipmentNode node) => _cat.typeFor(node);

  @override
  EquipmentState stateFor(String uuid) => _cat.stateFor(uuid);

  @override
  String? logicalDeviceIdFor(String uuid) => _cat.logicalDeviceIdFor(uuid);

  @override
  EquipmentSession? connectedSession(String uuid) => _cat.connectedSession(uuid);

  @override
  String? get localKeyingRadio => _cat.radio2;

  @override
  String? get radio2 => _cat.radio2;

  @override
  Future<void> updateNode(EquipmentNode node) => _cat.updateNode(node);

  @override
  void yieldTransmitter(String? radio) => _cat._yieldTransmitter(_cat._keyerOf('B'), radio);

  @override
  bool clearToSend({required bool repeat, bool queuedCw = false}) => _cat._clearToSend('B', repeat: repeat, queuedCw: queuedCw);
}

/// One radio's keyer, as a surface keying for that radio sees it — the same
/// names [CatService] answers for the operator's radio with. Its notifiers
/// are that radio's own, so a surface listening to them follows that radio
/// whichever set the operator is in.
class RadioKeyer {
  RadioKeyer._(this._cat, this.radio);

  final CatService _cat;

  /// `A` or `B`.
  final String radio;

  CatKeying get _k => _cat._keyerOf(radio);

  String? get _uuid => radio == 'B' ? _cat.radio2 : _cat.localRadio1;

  bool get canKeyCw => _k.canKeyCw;
  bool get designatedKeyIsKeyer => _k.designatedKeyIsKeyer;
  EquipmentNode? get designatedKeyerNode => _k.designatedKeyerNode;
  int? get keyerSpeed => _k.keyerSpeed;
  ({int min, int max})? get keyerSpeedRange => _k.keyerSpeedRange;
  bool setKeyerSpeed(int wpm) => _k.setKeyerSpeed(wpm);
  void refreshKeyerSpeed() => _k.refreshKeyerSpeed();

  bool get cwSending => _k.cwSending;
  ValueNotifier<CwSendProgress?> get cwProgress => _k.cwProgress;
  ValueListenable<int> get cwStops => _k.cwStops;

  /// [repeat] is a repeat chain's own send, which waits its turn under SO2R
  /// ([KeyingStation.clearToSend]).
  bool sendCw(String text, {bool hasMessageOne = false, bool repeat = false}) => _k.sendCw(text, hasMessageOne: hasMessageOne, repeat: repeat);
  void stopCw() => _k.stopCw();
  void dropQueuedCw(int id) => _k.dropQueuedCw(id);

  bool get canPlayVoice => _k.canPlayVoice;
  bool get radio1HasVoiceMemories => _k.radio1HasVoiceMemories;

  /// Whether this radio's entry holds voice memories of its own, whichever
  /// source is picked — what decides whether it is offered as one.
  bool get offersVoiceMemories => _k.radio1OffersVoiceMemories;

  /// Where this radio's phone messages come from — its own pick, which its
  /// Phone Keying line sets.
  VoiceKeyingSource get voiceKeyingSource => _k.voiceSource;
  Future<void> selectVoiceKeyingSource(VoiceKeyingSource source) => _k.selectVoiceKeyingSource(source);

  /// The node this radio's voice messages play on — its rig — whose config
  /// holds the computer's voice keyer settings: its sound devices and the
  /// delays around a message. Null with no rig in the role.
  EquipmentNode? get voiceKeyingNode => switch (_uuid) {
    final String uuid => _cat.nodeFor(uuid),
    null => null,
  };

  /// Merges [changes] into [voiceKeyingNode]'s config; a null value removes
  /// its key.
  Future<void> updateVoiceKeyingConfig(Map<String, dynamic> changes) async {
    final node = voiceKeyingNode;
    if (node == null) return;
    final config = {...node.config};
    changes.forEach((key, value) => value == null ? config.remove(key) : config[key] = value);
    await _cat.updateNode(node.copyWith(config: config));
  }

  bool get voiceKeyingRadioTakesAudio => _k.voiceKeyingRadioTakesAudio;
  int get voiceMemoryCount => _k.voiceMemoryCount;
  bool get canRecordVoice => _k.canRecordVoice;
  bool get voiceMessagesAreLocal => _k.voiceMessagesAreLocal;
  bool get voiceMessagesNamedOnRadio => _k.voiceMessagesNamedOnRadio;
  String voiceMessageLabel(int n) => _k.voiceMessageLabel(n);
  String voiceMessageShownLabel(int n) => _k.voiceMessageShownLabel(n);
  int voiceMessageDuration(int n) => _k.voiceMessageDuration(n);
  Future<void> setVoiceMessageLabel(int n, String label) => _k.setVoiceMessageLabel(n, label);
  ({String model, String text})? get voiceRecordingHelp => _k.voiceRecordingHelp;
  ValueNotifier<VoiceActivity?> get voiceActivity => _k.voiceActivity;

  /// The computer's voice keyer, as this radio has it: a keyer of its own on
  /// its own rig's sound device, playing the one set in use.
  bool get voiceMessagesFromComputer => _k.voiceMessagesFromComputer;
  bool voiceMessageUnplayable(int n) => _k.voiceMessageUnplayable(n);
  ComputerVoiceProblem? get computerVoiceProblem => _k.computerVoiceProblem;
  String? get computerVoiceProblemDetail => _k.computerVoiceProblemDetail;
  bool get phoneKeyingOff => _k.phoneKeyingOff;

  /// Voiced words (voiced_words.dart). The word sets are the desk's, kept on
  /// radio A's keying — [voicedWords] is null on B's — and a message said
  /// from them plays on either radio.
  bool voiceMessageVoiced(int n) => _k.voiceMessageVoiced(n);
  VoicedWords? get voicedWords => _k.voicedWords;
  String voiceMessageTemplate(int n) => _k.settings.activeVoiceMessageSet.template(n);
  Future<void> setVoiceMessageTemplate(int n, String template) => _k.setVoiceMessageTemplate(n, template);
  AudioPlayback? listenToVoiceMessage(int n) => _k.listenToVoiceMessage(n);
  void revealVoiceMessage(int n) => _k.revealVoiceMessage(n);

  /// A memory asked for and not yet heard starting — on the air for the app.
  ValueListenable<bool> get voiceStarting => _k.voiceStarting;
  void playVoiceMemory(int n, {bool repeat = true}) => _k.playVoiceMemory(n, repeat: repeat);
  void queueVoiceMemory(int n) => _k.queueVoiceMemory(n);

  /// What waits behind the memory playing, in order.
  ValueListenable<List<int>> get voiceQueue => _k.voiceQueue;
  void dropQueuedVoice(int index) => _k.dropQueuedVoice(index);
  void recordVoiceMemory(int n) => _k.recordVoiceMemory(n);
  void stopVoice() => _k.stopVoice();
  void playVoiceSequence(List<int> memories) => _k.playVoiceSequence(memories);
  void cancelVoiceSequence() => _k.cancelVoiceSequence();
  void stopMessageOne() => _k.stopMessageOne();

  /// The wait between message 1 finishing and it being keyed again — non-null
  /// only while that wait is running, so the keyer area's countdown bar is
  /// mounted exactly then.
  ValueNotifier<KeyerRepeatWait?> get keyerRepeat => _k.chain.wait;

  /// Whether a chain is running at all — armed, keying, waiting, or in the
  /// gap between the wait ending and the next message reaching the radio.
  ValueNotifier<bool> get keyerRepeatActive => _k.chain.active;

  /// Whether a repeat is armed or counting down.
  bool get keyerRepeating => _k.chain.running;

  /// Arms message 1 to go again [delay] after the one now keying finishes —
  /// see [KeyerRepeat.arm], which is where the five-minute limit lives.
  void armKeyerRepeat({required Duration delay, required String text, required void Function() send, int? memory}) =>
      _k.chain.arm(delay: delay, text: text, send: send, memory: memory);

  /// Ends the chain — every stop the operator can make lands here.
  void cancelKeyerRepeat() => _k.chain.cancel();

  /// What waits for the other SO2R radio to fall quiet before it goes out
  /// on this one — see [CatKeying.waiting].
  ValueListenable<List<WaitingSend>> get waiting => _k.waiting;

  /// Whether this radio is on the air — see [CatService.isTransmitting].
  bool get transmitting => _cat.isTransmitting(radio);

  bool get canPtt => _cat._pttSession(_uuid) != null;

  /// Bumped as keyboard mode starts on this radio — see
  /// [CatKeying.keyboardModeRequests].
  ValueListenable<int> get keyboardModeRequests => _k.keyboardModeRequests;

  /// Keyboard mode on this radio, while it is on (cw_live_typing.dart): the
  /// keyer control's field types into it, and the radio's keyer line shows
  /// what it sends. It ends by itself on Enter, a pause, Escape or the key
  /// going away.
  final cwTyping = ValueNotifier<CwLiveTyping?>(null);

  /// ⌥K / Alt+K, or the keyer control's keyboard button: keyboard mode on,
  /// or off with what was typed still going out.
  void toggleKeyboardMode() {
    final typing = cwTyping.value;
    if (typing != null) return typing.finish();
    if (!canKeyCw) return;
    // Typing is the operator moving on, the same as a message key: a CQ
    // repeat left armed would restart its wait after every typed piece and
    // key message 1 into the middle of the contact.
    cancelKeyerRepeat();
    late final CwLiveTyping started;
    started = CwLiveTyping(
      send: sendCw,
      stop: stopCw,
      busy: () => cwSending,
      progress: cwProgress,
      stops: cwStops,
      onDone: () {
        if (identical(cwTyping.value, started)) cwTyping.value = null;
      },
    );
    cwTyping.value = started;
    _k.keyboardModeRequests.value++;
  }
}
