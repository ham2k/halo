// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The computer's voice keyer as CatKeying runs it (docs/design/cat.md § The
// computer's voice keyer): the sets of recordings, which one is in use, and
// a ComputerVoiceKeyer per radio that plays them. A part of cat_keying.dart,
// and an extension rather than a class of its own, because every voice path
// there asks the same questions of it — whether a radio plays from the
// computer, which keyer is its — and the state it keeps (the keyers, the
// directory) is CatKeying's.

part of 'cat_keying.dart';

extension ComputerVoiceKeying on CatKeying {
  void _askDirectory() {
    final resolve = voiceMessagesDirectory;
    if (_directoryAsked || resolve == null) return;
    _directoryAsked = true;
    unawaited(
      resolve().then((dir) {
        voiceMessagesDir = dir;
        onComputerVoiceChanged?.call();
      }),
    );
  }

  /// The sound system, where the computer's voice keyer can run here — and
  /// the moment to start finding its recordings directory.
  VoiceAudio? get computerVoiceAudio {
    if (voiceAudio != null) _askDirectory();
    return voiceAudio;
  }

  /// Whether [uuid] plays a set of recordings rather than its own memories:
  /// the operator picked the computer, and this device can play one. One
  /// pick for every radio, as the CW set is — the recordings are the
  /// operator's voice, not a rig's — and so true with no radio at all: the
  /// sets are named and recorded before the rig is on the desk.
  ///
  /// Only ever radio1: SO2R's Radio B, or a radio this device only offers,
  /// plays its own memories whatever is picked. A keyer of this one's for it
  /// would claim its sound device, or a Flex's DAX source, and offer peers
  /// this desk's recordings as its memories.
  bool _playsFromComputer(String? uuid) {
    if (voiceAudio == null) return false;
    if (uuid != null && uuid != station.localKeyingRadio) return false;
    if (voiceSource != VoiceKeyingSource.computer) return false;
    // Until the directory is known nothing plays: the operator picked the
    // computer, and the radio's own memories are not what they chose.
    _askDirectory();
    return voiceMessagesDir != null;
  }

  /// Whether the operator turned phone keying off (Phone Keying: None) — a
  /// choice, not a radio without memories, and said as one. A peer's radio
  /// plays what its own station picked.
  bool get phoneKeyingOff => voiceMessagesAreLocal && voiceSource == VoiceKeyingSource.none;

  /// Where message [n] of the set in use is recorded.
  String _voiceFile(int n) => _setFile(settings.voiceMessageSetId, n);

  String _setFile(String setId, int n) => '$voiceMessagesDir/$setId/$n.wav';

  /// Where phone messages come from, and the keyers that follow from it —
  /// which stops a message playing from the source being left.
  Future<void> selectVoiceKeyingSource(VoiceKeyingSource source) async {
    if (source == settings.voiceKeyingSource) return;
    stopVoice();
    await settings.setVoiceKeyingSource(source);
    _computerVoiceChanged();
  }

  /// Puts set [id] in use, which stops a message playing from the set being
  /// left.
  Future<void> selectVoiceMessageSet(String id) async {
    if (id == settings.voiceMessageSetId) return;
    stopVoice();
    await settings.setVoiceMessageSets(settings.voiceMessageSets, active: id);
    _computerVoiceChanged();
  }

  /// Adds a set named [name] and puts it in use. A copy of the set in use —
  /// its labels and its recordings — the way a new CW set copies the one on
  /// screen.
  Future<VoiceMessageSet?> addVoiceMessageSet(String name) async {
    final audio = voiceAudio, dir = voiceMessagesDir;
    if (audio == null || dir == null) return null;
    final from = settings.activeVoiceMessageSet;
    final id = uuidGenerator.v4();
    final set = VoiceMessageSet(id: id, name: name, labels: from.labels);
    for (var n = 1; n <= SettingsService.voiceMessageCount; n++) {
      if (audio.lengthOf(_setFile(from.id, n)) != null) audio.copy(_setFile(from.id, n), _setFile(id, n));
    }
    await settings.setVoiceMessageSets([...settings.voiceMessageSets, set], active: id);
    _computerVoiceChanged();
    return set;
  }

  Future<void> renameVoiceMessageSet(String id, String name) async {
    if (id == VoiceMessageSet.defaultId) return;
    final sets = [for (final set in settings.voiceMessageSets) set.id == id ? set.renamed(name) : set];
    await settings.setVoiceMessageSets(sets, active: settings.voiceMessageSetId);
    _computerVoiceChanged();
  }

  /// Deletes set [id] and its recordings — never the default set's. The set
  /// beside it in the list takes over when it was in use, as with CW.
  Future<void> deleteVoiceMessageSet(String id) async {
    if (id == VoiceMessageSet.defaultId) return;
    final sets = settings.voiceMessageSets;
    final index = sets.indexWhere((set) => set.id == id);
    if (index < 0) return;
    final active = settings.voiceMessageSetId;
    if (active == id) stopVoice();
    final left = [...sets]..removeAt(index);
    // Never empty: the default set is never deleted.
    final next = active != id ? active : left[index.clamp(0, left.length - 1)].id;
    await settings.setVoiceMessageSets(left, active: next);
    final dir = voiceMessagesDir;
    if (dir != null) voiceAudio?.deleteDirectory('$dir/$id');
    _computerVoiceChanged();
  }

  void _computerVoiceChanged() {
    onComputerVoiceChanged?.call();
    // A peer keying this radio reads the labels off its status.
    onKeyingChanged();
  }

  /// Builds the computer's voice keyer for each radio connected over a
  /// session that can key while a set is in use, rebuilds one whose session
  /// changed, and drops the rest — stopping what it played, which unkeys.
  ///
  /// Run on the service's own changes (a set picked, a session opened or
  /// closed), never from a getter: dropping a keyer reports its activity
  /// ending, and a report from inside a widget's build would rebuild others
  /// mid-build.
  void syncComputerKeyers() {
    final wanted = <String>{};
    for (final node in station.nodes) {
      final uuid = node.uuid;
      final session = station.connectedSession(uuid);
      if (session is! PttSession || !_playsFromComputer(uuid)) continue;
      wanted.add(uuid);
      final existing = _computerKeyers[uuid];
      if (existing != null && identical(existing.ptt, session)) continue;
      if (existing != null) _dropComputerKeyer(uuid);
      _computerKeyers[uuid] = ComputerVoiceKeyer(
        ptt: session,
        audio: voiceAudio!,
        config: () => station.nodeFor(uuid)?.config ?? const {},
        fileFor: _voiceFile,
        report: (activity) => noteVoiceActivity(uuid, activity),
      );
    }
    for (final uuid in _computerKeyers.keys.where((uuid) => !wanted.contains(uuid)).toList()) {
      _dropComputerKeyer(uuid);
    }
    final recorder = _recorder;
    if (recorder != null && _deskRecorder != recorder) {
      _recorder = null;
      try {
        recorder.stopVoice();
        recorder.dispose();
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'cat:stop-voice');
      }
    }
  }

  void _recordWithoutRadio(int n) {
    try {
      _deskRecorder?.recordVoiceMemory(n);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:record-voice-memory');
    }
  }

  /// What records radio1's messages while radio1 has no keyer of its own —
  /// no radio1, or one not connected over a session that can key. Recording
  /// keys nothing, so the sets are recorded before the rig is on the desk.
  /// Built as asked for, which opens no device; dropped by
  /// [syncComputerKeyers], so a recording ends when the radio's keyer takes
  /// over.
  ComputerVoiceKeyer? get _deskRecorder {
    final uuid = station.localKeyingRadio;
    if (playsVoiceOverPeer || !_playsFromComputer(uuid)) return null;
    if (uuid != null && _computerKeyers.containsKey(uuid)) return null;
    return _recorder ??= ComputerVoiceKeyer(
      ptt: null,
      audio: voiceAudio!,
      // The input picked on radio1's entry, where there is one.
      config: () => switch (station.localKeyingRadio) {
        final uuid? => station.nodeFor(uuid)?.config ?? const {},
        null => const {},
      },
      fileFor: _voiceFile,
      // Never offered to a peer and never repeated: only shown.
      report: (activity) {
        voiceActivity.value = activity;
        onKeyingChanged();
      },
    );
  }

  void _dropComputerKeyer(String uuid, {bool sessionClosing = false}) {
    final keyer = _computerKeyers.remove(uuid);
    if (keyer == null) return;
    // A keyer is dropped mid-message only with its radio going — a source or
    // set change stops the voice first — and that is not the message ending:
    // taken for one, the repeat would wait out its cooldown and key the CQ
    // again on a radio back within it.
    if (uuid == station.localKeyingRadio && chain.memory != null) chain.cancel();
    try {
      if (!sessionClosing) keyer.stopVoice();
      keyer.dispose();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:stop-voice');
    }
  }

  /// Closes every keyer's sound device as the service goes; the sessions'
  /// own teardowns unkey.
  void disposeComputerKeyers() {
    for (final uuid in _computerKeyers.keys.toList()) {
      _dropComputerKeyer(uuid, sessionClosing: true);
    }
    _recorder?.dispose();
    _recorder = null;
  }

  /// Whether the computer's voice keyer holds [uuid] keyed — "on the air"
  /// for a radio that cannot say so itself, as the app's PTT key is.
  bool computerKeyed(String uuid) => _computerKeyers[uuid]?.keyed ?? false;

  /// [uuid] reported its TX state — see [ComputerVoiceKeyer.onTransmitting].
  void noteTransmitting(String uuid, bool transmitting) => _computerKeyers[uuid]?.onTransmitting(transmitting);

  /// Plays radio1's recording [n] on the computer's default output, unkeyed —
  /// the operator hearing what they recorded. Null when there is none, or
  /// the device would not open.
  AudioPlayback? listenToVoiceMessage(int n) {
    if (!voiceMessagesFromComputer) return null;
    final path = _voiceFile(n);
    if (voiceAudio!.lengthOf(path) == null) return null;
    try {
      return voiceAudio!.listen(path);
    } on HaloAudioException {
      return null;
    }
  }

  /// Opens the folder radio1's message [n] is in, for the operator to put a
  /// sound file there or take one out.
  void revealVoiceMessage(int n) {
    if (!voiceMessagesFromComputer) return;
    voiceAudio!.reveal(_voiceFile(n));
  }

  /// Whether radio1 takes a recording over its own network link
  /// ([NetworkTransmitAudioSession]) — what the output picker offers first.
  bool get voiceKeyingRadioTakesAudio {
    final uuid = station.localKeyingRadio;
    final session = uuid == null ? null : station.connectedSession(uuid);
    return session is NetworkTransmitAudioSession && session.sendsTransmitAudio;
  }

  /// Whether radio1's recordings go to it over its network link rather than
  /// into a sound device.
  bool get computerVoicePlaysToRadio => _computerKeyers[station.localKeyingRadio]?.playsToRadio ?? false;

  /// Whether keying radio1 for a recording switches its transmit audio to
  /// the computer by itself ([ComputerAudioPttSession]).
  bool get computerVoiceSwitchesAudio => _computerKeyers[station.localKeyingRadio]?.switchesAudio ?? false;

  /// Whether radio1's messages are recordings on this computer.
  bool get voiceMessagesFromComputer => !playsVoiceOverPeer && _playsFromComputer(station.localKeyingRadio);

  /// What last went wrong with radio1's computer voice keyer, for the Phone
  /// Keyer dialog.
  ComputerVoiceProblem? get computerVoiceProblem {
    final uuid = station.localKeyingRadio;
    if (!voiceMessagesFromComputer) return null;
    final session = uuid == null ? null : station.connectedSession(uuid);
    if (session != null && session is! PttSession) return _recorder?.problem ?? ComputerVoiceProblem.cannotKey;
    return (uuid == null ? null : _computerKeyers[uuid])?.problem ?? _recorder?.problem;
  }
}
