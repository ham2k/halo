// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keying as the keyer area, the function keys and Escape see it: the repeat
// chain, the CW and voice keyers behind [CatKeying], and the app's PTT key.
// What [CatKeying] asks of the station in return stays on [CatService].

part of 'cat_service.dart';

mixin _KeyingSurface on ChangeNotifier implements KeyingStation {
  SettingsService get _settings;
  RadioService? get _radio;
  PeerKeying get _peerKeying;
  String? get _localRadio1;
  bool stopNodeTunes();
  String get keyingRadio;
  String get operatorRadio;
  void setRunning(String radio, bool running);

  /// The repeat chain (keyer_repeat.dart) — one engine for both keyers,
  /// since a message and a memory differ only in what is sent again. It
  /// watches the VFO of the radio keying is for, which a repeat keeps
  /// keying on until it ends.
  late final _repeat = KeyerRepeat(vfo: () => _radio?.vfo(keyingRadio == 'B' ? 'vfoB' : 'vfoA'));

  /// The wait between message 1 finishing and it being keyed again — non-null
  /// only while that wait is running, so the keyer area's countdown bar is
  /// mounted exactly then.
  ValueNotifier<KeyerRepeatWait?> get keyerRepeat => _repeat.wait;

  /// Whether a chain is running at all — armed, keying, waiting, or in the
  /// gap between the wait ending and the next message reaching the radio.
  ValueNotifier<bool> get keyerRepeatActive => _repeat.active;

  /// Whether a repeat is armed or counting down.
  bool get keyerRepeating => _repeat.running;

  /// Arms message 1 to go again [delay] after the one now keying finishes —
  /// see [KeyerRepeat.arm], which is where the five-minute limit lives.
  void armKeyerRepeat({required Duration delay, required String text, required void Function() send, int? memory}) =>
      _repeat.arm(delay: delay, text: text, send: send, memory: memory);

  /// Ends the chain — every stop the operator can make lands here.
  void cancelKeyerRepeat() => _repeat.cancel();

  /// See [KeyerRepeat.deadlineMillis] — the tests' way in.
  @visibleForTesting
  int? get keyerRepeatDeadlineMillis => _repeat.deadlineMillis;

  /// Keying (cat_keying.dart) — which session keys, what it is keying, the
  /// speed, the memories. The API stays HERE: every surface that keys reads
  /// this service and nothing below it, whether the rig answering is plugged
  /// in here or on a peer's desk.
  late final _keying = CatKeying(station: this, settings: _settings, chain: _repeat, peer: _peerKeying);

  bool get canKeyCw => _keying.canKeyCw;
  bool get designatedKeyIsKeyer => _keying.designatedKeyIsKeyer;
  EquipmentNode? get designatedKeyerNode => _keying.designatedKeyerNode;
  List<EquipmentNode> get keyerCandidates => _keying.keyerCandidates;
  int? get keyerSpeed => _keying.keyerSpeed;
  ({int min, int max})? get keyerSpeedRange => _keying.keyerSpeedRange;
  bool get cwSending => _keying.cwSending;
  ValueNotifier<CwSendProgress?> get cwProgress => _keying.cwProgress;
  ValueListenable<int> get cwStops => _keying.cwStops;
  ValueNotifier<bool> get keyerAreaShown => _keying.keyerAreaShown;
  ValueNotifier<int> get keyerShowRequests => _keying.keyerShowRequests;
  ValueListenable<int> get keyboardModeRequests => _keying.keyboardModeRequests;
  void toggleKeyboardMode() => _keying.toggleKeyboardMode();
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

  bool sendCw(String text, {bool hasMessageOne = false}) => _keying.sendCw(text, hasMessageOne: hasMessageOne);
  void stopCw() => _keying.stopCw();
  void dropQueuedCw(int id) => _keying.dropQueuedCw(id);
  bool setKeyerSpeed(int wpm) => _keying.setKeyerSpeed(wpm);
  void refreshKeyerSpeed() => _keying.refreshKeyerSpeed();

  bool get canPlayVoice => _keying.canPlayVoice;
  bool get radio1HasVoiceMemories => _keying.radio1HasVoiceMemories;
  int get voiceMemoryCount => _keying.voiceMemoryCount;
  bool get canRecordVoice => _keying.canRecordVoice;
  bool get voiceMessagesAreLocal => _keying.voiceMessagesAreLocal;
  bool get voiceMessagesNamedOnRadio => _keying.voiceMessagesNamedOnRadio;
  String voiceMessageLabel(int n) => _keying.voiceMessageLabel(n);
  int voiceMessageDuration(int n) => _keying.voiceMessageDuration(n);
  Future<void> setVoiceMessageLabel(int n, String label) => _keying.setVoiceMessageLabel(n, label);
  ({String model, String text})? get voiceRecordingHelp => _keying.voiceRecordingHelp;
  ValueNotifier<VoiceActivity?> get voiceActivity => _keying.voiceActivity;
  void playVoiceMemory(int n, {bool repeat = true}) => _keying.playVoiceMemory(n, repeat: repeat);
  void recordVoiceMemory(int n) => _keying.recordVoiceMemory(n);
  void stopVoice() => _keying.stopVoice();
  void playVoiceSequence(List<int> memories) => _keying.playVoiceSequence(memories);
  void cancelVoiceSequence() => _keying.cancelVoiceSequence();
  void stopMessageOne() => _keying.stopMessageOne();
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
  bool get canPtt => _pttSession(localKeyingRadio) != null;

  /// Whether the app's PTT key is on the logging radio — [pttKeys]' `held` is true for a key on any radio.
  bool get pttHeldOnRadio1 => _ptt.heldOn(_pttSession(_localRadio1));
  void togglePtt(String radio) {
    final session = _pttSession(radio);
    if (session == null) return;
    if (!_ptt.heldOn(session)) {
      _keying.stopAll();
      _keying.quietOthers(radio);
    }
    _ptt.toggle(session);
  }

  /// One transmitter at a time, whoever asks: before a CW message or a voice
  /// memory goes out on [radio], the app's PTT key drops — on any radio, the
  /// message takes over — and every other radio stops its CW and voice.
  @override
  void yieldTransmitter(String? radio) {
    _ptt.release();
    _keying.quietOthers(radio);
  }
}
