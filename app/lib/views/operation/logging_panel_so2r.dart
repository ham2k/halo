// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The radios the logging panel's sets follow: the Main VFO's connect action,
// and under SO2R (docs/design/logging-fields.md § SO2R) set B's radio, the
// two sets' link, and which set each kind of outside input goes to.

part of 'logging_panel.dart';

mixin _LoggingPanelSo2r on State<LoggingPanel> {
  // Owned by `_LoggingPanelState`.
  Qso? get _selectedQso;
  List<String> get _enabledBands;
  List<String> get _enabledModes;
  bool get _trackingPower;
  Future<void> _openStationConfigDialog(BuildContext context);
  LoggingControlsController get _loggingController;

  /// SO2R (docs/design/logging-fields.md § SO2R): one set of logging
  /// controls per radio. Kept in sync by _onSettingsChanged.
  late bool _so2r = widget.services.settings.experimentEnabled('so2r') /* stored key, see experiments.yaml */;
  final _so2rLink = So2rLink();

  /// Set B's handle, beside [_loggingController], which is set A's.
  final _loggingControllerB = LoggingControlsController();

  /// The set a loaded row edits in: the one that logged it, else A.
  String _setFor(Qso? qso) => _so2r && qso?.ourRadio == 'B' ? 'B' : 'A';
  String get _editingSet => _setFor(_selectedQso);

  /// The set the panel's own keys and focus moves address: the one editing a
  /// loaded row, else the one the keyboard was last in.
  LoggingControlsController get _controller =>
      (_selectedQso != null ? _editingSet : (_so2r ? _so2rLink.active : 'A')) == 'B' ? _loggingControllerB : _loggingController;

  /// The suggestion and the log request each set was last handed. One goes
  /// to the set the keyboard is in when it ARRIVES, and stays with it: a
  /// set whose suggestion vanished because the operator moved to the other
  /// would read that as the suggestion being withdrawn.
  final _suggestions = <String, ({Map<String, dynamic>? qso, bool tentative, int settled})>{};
  String _suggestionSet = 'A';
  final _logRequests = <String, ({int serial, Map<String, dynamic> qso})?>{};

  /// Each set's last extension patch to its draft ([LoggingPanel.draftPatch]),
  /// kept with the set that was active when it came, as a log request is.
  final _draftPatches = <String, ({int serial, Map<String, dynamic> patch})?>{};

  /// Each set's command dispatcher; the active set's is the one published
  /// for the ⌘K dialog.
  final _dispatchers = <String, CommandActionsDispatcher?>{};

  void _publishDispatch() => widget.services.setCommandDispatchFor(widget.operation.uuid, _dispatchers[_so2r ? _so2rLink.active : 'A'] ?? _dispatchers['A']);

  /// What the sets' pills read beyond the set itself: each radio's Run /
  /// S&P, which radio is on the air, and which the operator hears.
  late final _so2rTransmitting = _So2rTransmitting(widget.services.cat);
  late final _so2rPills = Listenable.merge([widget.services.cat.enterSends, widget.services.cat.runningB, _so2rTransmitting, widget.services.cat.so2rAudio]);

  So2rSet _so2rSet(String radio) {
    final cat = widget.services.cat;
    return So2rSet(
      radio: radio,
      link: _so2rLink,
      running: cat.isRunning(radio),
      onToggleRunning: () => cat.setRunning(radio, !cat.isRunning(radio)),
      transmitting: radio == 'B' ? _so2rTransmitting.value.b : _so2rTransmitting.value.a,
      heard: cat.so2rAudio.value?.hears(radio),
    );
  }

  /// Follows the set the keyboard is in — told to CAT now, too, after the
  /// first frame: the operator's radio is the service's, and outlives a
  /// panel, so the last operation's set B would otherwise keep keying on
  /// radio B while this one opens in set A.
  void _startSo2rLink() {
    _so2rLink.activeSet.addListener(_onSo2rLinkChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSo2rLinkChanged());
  }

  void _onSo2rLinkChanged() {
    if (!mounted) return;
    widget.services.cat.noteOperatorRadio(_so2r ? _so2rLink.active : 'A');
    _publishDispatch();
    setState(() {});
  }

  /// Radio B's state as set B's Radio control shows it — compared whole by
  /// _onCatChanged, which rebuilds only when it moves.
  late ({bool configured, bool connected, String? name}) _radioB = _radioBSignature();

  ({bool configured, bool connected, String? name}) _radioBSignature() {
    final cat = widget.services.cat;
    final node = switch (cat.radio2) {
      final uuid? => cat.nodeFor(uuid),
      null => null,
    };
    return (
      configured: node != null,
      connected: node != null && cat.stateFor(node.uuid).status == EquipmentStatus.connected,
      name: node == null ? null : cat.displayNameFor(node),
    );
  }

  /// What each set hears of the VFOs under SO2R: its own alone.
  late final _vfoUpdates = {
    for (final radio in ['A', 'B']) radio: RadioVfoUpdates(widget.services.radio, 'vfo$radio'),
  };

  /// What each set's next Enter would hand ESM, as it last published it —
  /// what that set's keyer area highlights the next messages from.
  final _esmFacts = {
    for (final radio in ['A', 'B']) radio: ValueNotifier<EsmFacts?>(null),
  };

  /// [radio]'s set's FYI area — its own radio's messages and the station's,
  /// with its radio's keyer line while [keyer] is on: its messages going
  /// out, its repeat, and what waits for the other radio.
  FyiArea _fyiArea(String radio, {required bool editingHere, required bool keyer}) => FyiArea(
    services: widget.services,
    radio: radio,
    keyer: keyer,
    phone: widget.keyingSuperMode == 'Phone',
    digital: widget.keyingSuperMode == 'Digital',
    suppressed: editingHere && _selectedQso != null,
  );

  /// What [radio]'s set says its contact lacks of the radio state, said in
  /// that radio's FYI area (logging-fields.md § The FYI area): the band and
  /// the mode, each a high-priority pill — a contact with neither band nor
  /// frequency is refused at the log, and one with no mode by every award
  /// programme. No tap puts one away; a tap opens that radio's Radio
  /// control, where the pick that answers it is. Each under one key per
  /// radio, taken down the moment the set reports it answered, and not
  /// when the panel goes: the radio's state is the station's, not this
  /// operation's, and the next panel reports it afresh on its first frame. A
  /// clear from dispose would also land while the tree is locked, on an area
  /// a panel taking over the slot has already mounted.
  void _postMissingRadio(String radio, MissingRadioState missing) {
    final fyi = widget.services.fyi;
    if (missing.band) {
      fyi.post(
        FyiMessage(
          key: 'band:$radio',
          category: FyiCategory.alert,
          priority: FyiPriority.high,
          dismissible: false,
          onTap: () => _openRadioControl(radio),
          icon: MdiIcons.radio,
          text: t.loggingControls.missingBand,
          radio: radio,
        ),
      );
    } else {
      fyi.clear('band:$radio');
    }
    if (missing.mode) {
      fyi.post(
        FyiMessage(
          key: 'mode:$radio',
          category: FyiCategory.alert,
          priority: FyiPriority.high,
          dismissible: false,
          onTap: () => _openRadioControl(radio),
          icon: MdiIcons.waveform,
          text: t.loggingControls.missingMode,
          radio: radio,
        ),
      );
    } else {
      fyi.clear('mode:$radio');
    }
  }

  /// What each set's command actions reach: SWAP moves both sets, which only
  /// the panel holds; every other action goes to [others].
  CommandActionHandler _withSwap(CommandActionHandler others) => (action, [params]) async {
    if (action != 'swapRadios') return others(action, params);
    _swapRadios();
  };

  /// SWAP (`radio-commands`; docs/design/logging-fields.md § SO2R): each
  /// set's entry goes to the other set with the frequency, band and mode it
  /// is on, and the set it lands in tunes its radio there — so Radio A ends
  /// where Radio B was and B where A was, each with the contact being worked
  /// there. The radios' Run or S&P cross with them ([CatService.swapStyles]),
  /// and on two slices of one radio their antennas too
  /// ([CatService.swapRadioSettings]).
  ///
  /// Refused, with nothing moved, while either radio is on the air or has a
  /// message going or waiting — a radio retuned under a message would send
  /// the rest of it on the other radio's frequency — and while a set shows a
  /// logged contact, which is a record and not an entry to move. A rig that
  /// is not connected does not stop it, but is named: its entry and VFO
  /// moved, and the rig did not.
  void _swapRadios() {
    final services = widget.services, cat = services.cat;
    final refusal = _swapRefusal();
    if (refusal != null) return services.reportCommandOutcome((text: refusal, failed: true));
    final a = _loggingController.takeEntry();
    final b = _loggingControllerB.takeEntry();
    // Both sets were checked above; one declining anyway gets its entry back
    // rather than losing it.
    if (a == null || b == null) {
      if (a != null) _loggingController.putEntry(a);
      if (b != null) _loggingControllerB.putEntry(b);
      return services.reportCommandOutcome((text: t.commands.swapLocked, failed: true));
    }
    cat.swapStyles();
    _loggingController.putEntry(b);
    _loggingControllerB.putEntry(a);
    cat.swapRadioSettings();
    bool idle(String? uuid) => uuid != null && cat.stateFor(uuid).status != EquipmentStatus.connected;
    final idleRadios = [if (idle(cat.localRadio1)) 'A', if (idle(cat.radio2)) 'B'];
    services.reportCommandOutcome(switch (idleRadios) {
      [] => (text: t.commands.swapDone, failed: false),
      [final radio] => (text: t.commands.swapNotConnected(radio: radio), failed: true),
      _ => (text: t.commands.swapNoneConnected, failed: true),
    });
  }

  String? _swapRefusal() {
    final cat = widget.services.cat;
    if (!_so2r) return t.commands.swapExperimentOff;
    if (cat.radio2 == null || !_loggingControllerB.isAttached) return t.commands.swapNoRadioB;
    if (_selectedQso != null) return t.commands.swapEditing;
    if (_loggingController.isFieldsLocked || _loggingControllerB.isFieldsLocked) return t.commands.swapLocked;
    for (final radio in ['A', 'B']) {
      final keyer = cat.keyer(radio);
      if (keyer.transmitting) return t.commands.swapOnAir(radio: radio);
      if (keyer.busy || keyer.keyerRepeatActive.value) return t.commands.swapKeyerBusy(radio: radio);
    }
    return null;
  }

  /// Opens [radio]'s Radio control. Set A's strip holds both — set B's is
  /// its `radioB` pill, as [So2rLink.openRadio] has it — so set A's
  /// controller opens either, with or without a second set.
  void _openRadioControl(String radio) => _loggingController.openControl(radio == 'A' ? 'radio' : 'radioB');

  void _disposeSo2r() {
    for (final facts in _esmFacts.values) {
      facts.dispose();
    }
    _so2rTransmitting.dispose();
    for (final updates in _vfoUpdates.values) {
      updates.dispose();
    }
  }

  /// Set B's rig: Radio B, through `vfoB`.
  RadioHookup _radioBHookup(BuildContext context) {
    final cat = widget.services.cat;
    final radioB = _radioB;
    return RadioHookup(
      enabledBands: _enabledBands,
      enabledModes: _enabledModes,
      radioService: RadioVfoView(widget.services.radio, 'vfoB'),
      radioUpdates: _vfoUpdates['B'],
      hasConfiguredRadio: radioB.configured,
      radioConnected: radioB.connected,
      radioTransmitting: _so2rTransmitting.value.b,
      readStatus: () => (connected: _radioBSignature().connected, transmitting: cat.isTransmitting('B')),
      onOpenStationConfig: () => _openStationConfigDialog(context),
      onConnectRadio: switch (cat.radio2) {
        final uuid? => localRadioConnectAction(cat, uuid, connected: radioB.connected),
        _ => null,
      },
      radioName: radioB.name,
      ourItuRegion: widget.ourItuRegion,
      ourCountryCode: widget.ourCountryCode,
      trackingPower: _trackingPower,
    );
  }

  /// Stamps the SO2R radio a contact is logged from, so an edit loads it back
  /// into that set. An edit keeps the radio it already names.
  Map<String, dynamic> _withSo2rRadio(Map<String, dynamic> qso, String radio) {
    final our = {...(qso['our'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{}};
    our['radio'] ??= radio;
    return {...qso, 'our': our};
  }

  /// Stamps a new contact with the operating style of the set it is logged
  /// from — Run or S&P, docs/design/logging-fields.md § Operating style. An
  /// edit keeps the style it was worked in, or none: today's style is not
  /// how an older contact was made. Event rows are not contacts.
  Map<String, dynamic> _withStyle(Map<String, dynamic> qso, String radio) {
    if (qso['band'] == 'event' || (asQsonString(qso['uuid']) ?? '').isNotEmpty || qso['opStyle'] != null) return qso;
    return {...qso, 'opStyle': widget.services.cat.styleOf(radio).value};
  }

  /// Merges the operator's tracked station-info fields (Station
  /// Configuration's "Track Station Info for each QSO") into a QSO at save
  /// time. Runs before `decorateQsoBeforeSave`'s extension hooks, so an
  /// activity can still see and adjust the captured values. Rig/antenna/key
  /// nest under `our`; power is top-level (`Qso.power`), matching QSON
  /// convention (freq/band/mode) rather than app-only placement.
  Map<String, dynamic> _withStationInfo(Map<String, dynamic> qso, {String radio = 'A'}) {
    final settings = widget.services.settings;
    final cat = widget.services.cat;
    // Set B with no Radio B is a set tuned by hand: radio A's rig, power,
    // antenna and key are not what it was worked with.
    if (!settings.trackStationInfo || (radio == 'B' && cat.radio2 == null)) return qso;
    final tracked = settings.stationInfoTrackedFields;

    String? nameFor(String? uuid) {
      final node = uuid == null ? null : cat.nodeFor(uuid);
      return node == null ? null : cat.displayNameFor(node);
    }

    final our = {...(qso['our'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{}};
    num? power;
    if (tracked.contains('rig')) {
      // Whatever drives the VFO — a peer's rig is the one the contact was
      // worked through, and the panel names it two rows up.
      final name = radio == 'B' ? _radioB.name : widget.services.radio1Name;
      if (name != null) our['rig'] = name;
    }
    // Never over a power the entry already states — the Power control's
    // field, the More pane, or the record's own value. Ambient capture fills
    // a gap; it does not correct the operator, and on a saved edit it would
    // otherwise rewrite what a contact was actually worked at with whatever
    // the rig is set to today.
    // Radio B's own picks and power for a contact logged on it.
    final radioB = radio == 'B' ? cat.radio2 : null;
    if (tracked.contains('power') && qso['power'] == null) {
      power = radioB == null ? cat.displayedPower : cat.stateFor(radioB).power ?? widget.services.radio.vfo('vfoB').power;
    }
    if (tracked.contains('antenna')) {
      final name = nameFor(cat.designatedFor(kCategoryAntenna, radio: radioB));
      if (name != null) our['antenna'] = name;
    }
    if (tracked.contains('key')) {
      // The key in use may be a radio keying over CAT; that is a keying
      // source, not a key on the desk worth a QSO's key field. A keyer
      // device is one.
      final uuid = cat.designatedFor(kCategoryKey, radio: radioB);
      final node = uuid == null ? null : cat.nodeFor(uuid);
      final name = nameFor(uuid);
      if (name != null && node != null && cat.typeFor(node)?.category != kCategoryTransceiver) our['key'] = name;
    }
    return {...qso, 'our': our, 'power': ?power};
  }
}

/// What the Radio control's plug does: connect the main radio while it is
/// down, disconnect it while it is up — offered either way, so a radio
/// that has wedged can be dropped and brought back from the logging row.
/// Only for this station's own radio with somewhere to connect to — a
/// peer's session is the other device's, and a radio with no port or
/// address has nothing to open. Null hides the plug.
VoidCallback? radio1ConnectAction(CatService cat, {required bool connected}) {
  if (cat.radio1 case LocalRadio(:final uuid)) return localRadioConnectAction(cat, uuid, connected: connected);
  return null;
}

/// [radio1ConnectAction] for a local rig by [uuid], Radio B's too.
VoidCallback? localRadioConnectAction(CatService cat, String uuid, {bool connected = false}) {
  final node = cat.nodeFor(uuid);
  if (node == null || (cat.typeFor(node)?.isUnconfigured(node.config) ?? true)) return null;
  return connected ? () => unawaited(cat.disconnect(uuid)) : () => unawaited(cat.connect(uuid));
}

/// Which of the two radios are on the air — firing only when that changes,
/// not at every character a message advances.
class _So2rTransmitting extends ValueNotifier<({bool a, bool b})> {
  _So2rTransmitting(this.cat) : super(_read(cat)) {
    _sources.addListener(_update);
  }

  final CatService cat;
  late final _sources = Listenable.merge([
    cat,
    for (final radio in ['A', 'B']) ...[cat.keyer(radio).cwProgress, cat.keyer(radio).voiceActivity, cat.keyer(radio).voiceStarting],
  ]);

  static ({bool a, bool b}) _read(CatService cat) => (a: cat.isTransmitting('A'), b: cat.isTransmitting('B'));

  void _update() => value = _read(cat);

  @override
  void dispose() {
    _sources.removeListener(_update);
    super.dispose();
  }
}
