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
    ),
  };

  CatKeying _keyerOf(String radio) => _keyers[radio == 'B' ? 'B' : 'A']!;

  /// Radio1's keying, which the peer bridge and the station's own reports
  /// reach.
  CatKeying get _keying => _keyers['A']!;

  /// The keyer whose radio is [uuid]: Radio B's for Radio B, radio1's for
  /// any other.
  CatKeying _keyerForNode(String? uuid) => _keyerOf(uuid != null && uuid == radio2 ? 'B' : 'A');

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
  ValueNotifier<bool> get keyerAreaShown => _keying.keyerAreaShown;
  ValueNotifier<int> get keyerShowRequests => _keying.keyerShowRequests;
  ValueListenable<int> get keyboardModeRequests => operatorKeyer.keyboardModeRequests;
  void toggleKeyboardMode() => operatorKeyer.toggleKeyboardMode();
  void showKeyerArea() => _keying.showKeyerArea();
  void hideKeyerArea() => _keying.hideKeyerArea();
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
  int get voiceMemoryCount => operatorKeyer.voiceMemoryCount;
  bool get canRecordVoice => operatorKeyer.canRecordVoice;
  bool get voiceMessagesAreLocal => operatorKeyer.voiceMessagesAreLocal;
  bool get voiceMessagesNamedOnRadio => operatorKeyer.voiceMessagesNamedOnRadio;
  String voiceMessageLabel(int n) => operatorKeyer.voiceMessageLabel(n);
  int voiceMessageDuration(int n) => operatorKeyer.voiceMessageDuration(n);
  Future<void> setVoiceMessageLabel(int n, String label) => operatorKeyer.setVoiceMessageLabel(n, label);
  ({String model, String text})? get voiceRecordingHelp => operatorKeyer.voiceRecordingHelp;
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
  late final pttKeys = PttKeyboard(held: _ptt.held, release: _ptt.release, escape: stopKeying, toggle: togglePtt);
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
    if (!_ptt.heldOn(session)) {
      final keyer = _keyerForNode(radio);
      keyer.stopAll();
      keyer.quietOthers(radio);
    }
    _ptt.toggle(session);
  }

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
  bool clearToSend({required bool repeat}) => _cat._clearToSend('B', repeat: repeat);
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
  int get voiceMemoryCount => _k.voiceMemoryCount;
  bool get canRecordVoice => _k.canRecordVoice;
  bool get voiceMessagesAreLocal => _k.voiceMessagesAreLocal;
  bool get voiceMessagesNamedOnRadio => _k.voiceMessagesNamedOnRadio;
  String voiceMessageLabel(int n) => _k.voiceMessageLabel(n);
  int voiceMessageDuration(int n) => _k.voiceMessageDuration(n);
  Future<void> setVoiceMessageLabel(int n, String label) => _k.setVoiceMessageLabel(n, label);
  ({String model, String text})? get voiceRecordingHelp => _k.voiceRecordingHelp;
  ValueNotifier<VoiceActivity?> get voiceActivity => _k.voiceActivity;

  /// A memory asked for and not yet heard starting — on the air for the app.
  ValueListenable<bool> get voiceStarting => _k.voiceStarting;
  void playVoiceMemory(int n, {bool repeat = true}) => _k.playVoiceMemory(n, repeat: repeat);
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

  /// ⌥K / Alt+K for this radio's keyer area — see [CatKeying.keyboardModeRequests].
  ValueListenable<int> get keyboardModeRequests => _k.keyboardModeRequests;
  void toggleKeyboardMode() => _k.toggleKeyboardMode();
}
