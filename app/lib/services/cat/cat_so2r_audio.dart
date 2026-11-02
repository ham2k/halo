// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SO2R's switcher (docs/design/cat.md § The SO2R switcher): what puts the
// two radios in the operator's headphones — an OTRSP box, or two slices of
// one FlexRadio switching their own audio — and the rule it follows.

part of 'cat_service.dart';

/// The switcher pick naming the radios themselves: both SO2R radios are
/// slices of one radio, which switches its own audio.
const so2rSwitchRadios = 'radios';

mixin _So2rAudio on _So2r {
  /// The stored pick: an SO2R switcher node's uuid, [so2rSwitchRadios], or
  /// null for None.
  String? _so2rSwitch;

  /// What the operator hears, as the switcher last said or was last told —
  /// null with no switcher switching. The SO2R pills' headphones.
  final so2rAudio = ValueNotifier<So2rAudio?>(null);

  /// The pick, while SO2R is on with a Radio B — the only time there are two
  /// radios to switch between.
  String? get so2rSwitch => radio2 == null ? null : _so2rSwitch;

  /// The switcher node picked, when one is: what is kept connected.
  String? get _so2rSwitchNode => switch (so2rSwitch) {
    final uuid? when uuid != so2rSwitchRadios && nodeFor(uuid) != null => uuid,
    _ => null,
  };

  Future<void> setSo2rSwitch(String? pick) async {
    if (pick == _so2rSwitch) return;
    _so2rSwitch = pick;
    // Whatever the box said before is not what it says now: it was not being
    // listened to in between.
    _so2rReported = null;
    _so2rSent = null;
    await _save();
    notifyListeners();
    unawaited(_connectSo2rSwitch());
  }

  /// The switchers this station has, as nodes.
  List<EquipmentNode> get so2rSwitchNodes => [
    for (final node in nodes)
      if (typeFor(node)?.category == kCategorySo2rSwitch) node,
  ];

  /// The radio both SO2R radios are slices of, when they are — what the
  /// pick names "Built into …" — or null. Two different slices: two nodes on
  /// one slice would switch that one slice against itself.
  @override
  EquipmentNode? get so2rAudioRadio {
    final a = _localRadio1, b = radio2;
    if (a == null || b == null) return null;
    ({String radio, int receiver})? receiverOf(String uuid) {
      final node = nodeFor(uuid), type = node == null ? null : typeFor(node);
      return type?.driver.so2rAudioReceiverWith(type.driverConfig(node!.config));
    }

    final (ra, rb) = (receiverOf(a), receiverOf(b));
    return ra != null && rb != null && ra.radio == rb.radio && ra.receiver != rb.receiver ? nodeFor(a) : null;
  }

  /// Toggles stereo — the operator's key for it. False, and nothing
  /// changed, while no switcher is switching: the key stays free.
  bool toggleSo2rStereo() {
    if (so2rAudio.value == null) return false;
    unawaited(_settings.setSo2rStereo(!_settings.so2rStereo));
    return true;
  }

  /// The box's own word on what it is set to, for the session that said it.
  ({EquipmentSession session, So2rAudio audio})? _so2rReported;

  void _noteSo2rAudioReport(String uuid, So2rAudio audio) {
    // Only the picked box's word: another connected by hand says nothing
    // about what the operator hears.
    if (uuid != _so2rSwitchNode) return;
    final session = _runtimes[uuid]?.session;
    if (session == null) return;
    _so2rReported = (session: session, audio: audio);
    _so2rAudioSoon();
  }

  So2rSwitchSession? get _so2rSwitchSession => switch (_so2rSwitchNode) {
    final uuid? => switch (connectedSession(uuid)) {
      final So2rSwitchSession session => session,
      _ => null,
    },
    null => null,
  };

  /// The OTRSP session last told, and what.
  ({So2rSwitchSession session, So2rAudio audio})? _so2rSent;

  /// What each radio switching its own audio was last told.
  final _so2rEars = <So2rRadioAudioSession, So2rEar>{};

  late final Listenable _so2rAudioChanges = Listenable.merge([this, _settings, _onAirChanges]);

  @override
  void _startSo2rAudio() => _so2rAudioChanges.addListener(_so2rAudioSoon);

  @override
  void _stopSo2rAudio() {
    _so2rAudioChanges.removeListener(_so2rAudioSoon);
    so2rAudio.dispose();
  }

  bool _so2rAudioScheduled = false;

  /// [_applySo2rAudio], once the change that called for it is taken in whole
  /// — a notify carries a rig's TX report before the keyers' have caught up.
  void _so2rAudioSoon() {
    // Nothing switching and nothing to give back: every notify of a station
    // with no switcher would otherwise run the whole rule for nothing.
    if (_so2rAudioScheduled || (_so2rSwitch == null && _so2rEars.isEmpty && so2rAudio.value == null)) return;
    _so2rAudioScheduled = true;
    scheduleMicrotask(() {
      _so2rAudioScheduled = false;
      if (!_disposed) _applySo2rAudio();
    });
  }

  So2rAudio _wantedSo2rAudio() => wantedSo2rAudio(
    operatorRadio: operatorRadio,
    stereo: _settings.so2rStereo,
    listenWhileTransmitting: _settings.so2rListenWhileTransmitting,
    transmittingA: isTransmitting('A'),
    transmittingB: isTransmitting('B'),
  );

  /// Tells the switcher what the operator should hear, when it changes and
  /// whenever the switcher's session is a new one. A box the operator set
  /// by hand since is not set back until what they should hear changes.
  void _applySo2rAudio() {
    final pick = so2rSwitch;
    final wanted = _wantedSo2rAudio();
    final ears = <So2rRadioAudioSession, So2rEar>{};
    So2rAudio? heard;
    if (pick == so2rSwitchRadios && so2rAudioRadio != null) {
      for (final (radio, uuid) in [('A', _localRadio1), ('B', radio2)]) {
        if (uuid == null) continue;
        if (connectedSession(uuid) case final So2rRadioAudioSession session) ears[session] = so2rEarFor(wanted, radio);
      }
      // Both or neither: one slice switched alone, with its partner's link
      // down, is the operator hearing nothing at all.
      if (ears.length == 2) {
        heard = wanted;
      } else {
        ears.clear();
      }
    } else if (_so2rSwitchSession case final session?) {
      final sent = _so2rSent;
      if (sent == null || !identical(sent.session, session) || sent.audio != wanted) {
        session.setSo2rAudio(wanted);
        _so2rSent = (session: session, audio: wanted);
        // Its word on the audio before this command is out of date; until it
        // answers, what it was told is what it is set to.
        _so2rReported = null;
      }
      final said = _so2rReported;
      heard = said != null && identical(said.session, session) ? said.audio : wanted;
    }
    // A radio no longer switching gets the operator's own audio back.
    for (final session in [..._so2rEars.keys]) {
      if (ears.containsKey(session)) continue;
      if (_so2rEars.remove(session) != null && nodes.any((node) => identical(connectedSession(node.uuid), session))) session.setSo2rEar(null);
    }
    for (final MapEntry(key: session, value: ear) in ears.entries) {
      if (_so2rEars[session] == ear) continue;
      _so2rEars[session] = ear;
      session.setSo2rEar(ear);
    }
    so2rAudio.value = heard;
  }
}
