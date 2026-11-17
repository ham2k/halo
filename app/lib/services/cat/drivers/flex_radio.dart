// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'flexradio_driver.dart';

/// One connection to a FlexRadio, and everything on it that is the radio's
/// rather than a slice's: the handshake, the subscriptions, the client it is
/// bound to, the UDP socket the meters, DAX and spectrum share, the
/// transmitter (its interlock, flag, power, tuner), the CWX buffer and the
/// DVK. Each slice the station uses is a [FlexRadioSession] attached to it,
/// so two slices of one radio share one connection and one subscription —
/// a second `sub slice all` would break the first slice's audio
/// ([flexRadioPingInterval]).
///
/// The radio has one transmitter, one CWX buffer and one DVK: a slice that
/// keys, sends CW or plays a memory takes the transmit flag to itself
/// first, and what those report reaches every slice, as the K4's do
/// (k4_shared_session.dart).
class FlexRadio implements SharedConnectionOwner {
  final void Function(List<int> bytes) _sendBytes;

  /// The radio's address, where the meters' UDP socket reaches it. Null
  /// where no socket can be opened (a test that gives none).
  final String? meterHost;

  /// How the UDP socket is opened where no slice on it is heard in HaLo:
  /// a parameter because the real one binds a port and resolves a host.
  final FlexUdpSocketOpener openMeterSocket;

  final Duration voiceMemoryCeiling;

  /// Whether this connection is HaLo's own station on the radio (a GUI
  /// client, owning the slices it opens) rather than bound to another's.
  final bool gui;

  /// The station this connection binds to, by the radio's id for it; null
  /// for one that binds to the owner of the first slice it follows.
  final String? bindTo;

  /// The id the radio gave HaLo's station, under which it keeps the
  /// station's slices and panadapters between connections; null for one
  /// never registered. A new one is handed to [onClientId] to keep.
  final String? clientId;
  final void Function(String clientId)? onClientId;

  /// What other stations see HaLo's as: this computer's name, or the one
  /// the operator gave it.
  String? station;

  FlexRadio({
    required void Function(List<int> bytes) send,
    this.meterHost,
    this.openMeterSocket = FlexMeterSocket.open,
    this.voiceMemoryCeiling = voiceActivityCeiling,
    this.gui = false,
    this.bindTo,
    this.clientId,
    this.onClientId,
    this.station,
  }) : _sendBytes = send;

  /// The radio's settings out of a node's: what every slice of it shares.
  factory FlexRadio.fromConfig(
    Map<String, dynamic> config, {
    required void Function(List<int> bytes) send,
    String? clientId,
    String? station,
    void Function(String clientId)? onClientId,
  }) => FlexRadio(
    send: send,
    meterHost: config['host'] as String?,
    voiceMemoryCeiling: voiceCeilingFromConfig(config),
    gui: config[flexGuiConfigKey] == true,
    bindTo: config[flexBindConfigKey] as String?,
    clientId: clientId,
    onClientId: onClientId,
    station: station,
  );

  /// The slices attached, in the order they attached.
  final _sessions = <FlexRadioSession>[];

  /// What the radio last reported about itself, by kind, for a slice that
  /// attaches after it was said: the radio pushes each once, on subscribe.
  final _remembered = <String, void Function(EquipmentSink sink)>{};

  bool _disposed = false;

  @override
  EquipmentSession attach(EquipmentSink sink, {required String receiver}) {
    if (_disposed) throw StateError('The Flex connection is closed');
    if (receiver.startsWith(flexOwnSlicePrefix)) {
      if (!gui) throw StateError("HaLo's own slice is on its own station's connection");
      return FlexRadioSession._on(this, sink, ownLetter: receiver.substring(flexOwnSlicePrefix.length));
    }
    final slice = parseFlexSlice(receiver);
    if (slice == null) throw ArgumentError.value(receiver, 'receiver');
    return FlexRadioSession._on(this, sink, slice: slice);
  }

  Iterable<FlexRadioSession> get _active => _sessions.where((session) => session._active);

  /// [last] hears it after every other slice: see [_voice].
  void _remember(String key, void Function(EquipmentSink sink) report, {FlexRadioSession? last}) {
    _remembered[key] = report;
    final sessions = _sessions.toList();
    if (last != null && sessions.remove(last)) sessions.add(last);
    for (final session in sessions) {
      // A report can synchronously start the next message. Its new state
      // must not be overwritten on another slice by this older report.
      if (_disposed || !identical(_remembered[key], report)) return;
      if (_sessions.contains(session)) report(session._sink);
    }
  }

  void _broadcast(void Function(EquipmentSink sink) report) {
    for (final session in _sessions.toList()) {
      report(session._sink);
    }
  }

  void _start(FlexRadioSession session) {
    if (_disposed || session._active) return;
    if (!_sessions.contains(session)) _sessions.add(session);
    session._active = true;
    final first = !_wantUpdates;
    _wantUpdates = true;
    if (first) {
      if (_handshakeDone) _subscribe();
      // Armed here too, not only in _subscribe: a handshake that never lands
      // (or lands in a shape the pattern does not match) means no subscribe,
      // and every path that would say so hangs off the subscribe that never
      // happened. The staleness watchdog would eventually flag the row, but
      // with the same word it uses for an unplugged radio.
      _armSettleTimer();
      _startPeriodicTimers();
    } else {
      if (_handshakeDone) session._spectrum.subscribe();
      if (_meterSocket != null) session._spectrum.socketReady();
      // A slice heard in HaLo, or talking through it, starting on a socket
      // the engine does not own: its audio has nowhere to arrive, so the
      // socket is opened again through the engine.
      final wantsAudio = session._receiveAudio != null || session._talkAudio != null;
      if (_engineRefused && wantsAudio) {
        session._socketProblem = _engineRefusedWhy;
        session._reportAudioProblem();
      } else if (_meterSocket case final socket?) {
        if (socket.audioSocket == null && wantsAudio) {
          _reopenForAudio();
        } else {
          session._startAudioStreams(socket);
        }
      }
      if (_metersUnavailable) session._spectrum.socketUnavailable();
      // Said before this slice was listening: its node's state is set
      // only from its start.
      for (final report in _remembered.values.toList()) {
        if (!session._active) return;
        report(session._sink);
      }
      _bindTrackedClient();
      if (_slices.isNotEmpty) {
        session._sliceChanged(whole: true);
        session._reportOnAir();
      }
    }
  }

  void _stop(FlexRadioSession session) {
    if (!session._active) return;
    _release(session);
    session._active = false;
    if (_active.isNotEmpty) return;
    _wantUpdates = false;
    _stopPeriodicTimers();
    if (_handshakeDone) _unsubscribe();
  }

  /// What [session] holds of the radio's, given up as it leaves: its CW,
  /// its memory, its key.
  void _release(FlexRadioSession session) {
    final messages = [
      for (final MapEntry(:key, :value) in _cwOwners.entries)
        if (value == session) key,
    ];
    if (messages.contains(_cwQueue.currentId)) {
      _cwOwners.clear();
      _cwQueue.clear();
      _sendCommand('cwx clear');
    } else {
      for (final id in messages) {
        _cwOwners.remove(id);
        _cwQueue.dropPending(id);
      }
    }
    if (_voiceOwner == session) stopVoice();
    if (_pttOwner == session && _keyedByUs) {
      _daxOutput?.lost();
      _key(null, false);
      _daxSwitch.afterUnkey();
    }
  }

  void _detach(FlexRadioSession session) {
    if (!_sessions.contains(session)) return;
    _stop(session);
    _sessions.remove(session);
    for (final other in _sessions.toList()) {
      other._reportOnAir();
    }
  }

  // ------------------------------------------------------------- the wire

  int _seq = 1;

  /// Answers the sequence number the command went out under, which its
  /// `R<seq>|` reply names. [onReply], when given, is handed that reply's
  /// code and body.
  int _sendCommand(String command, {void Function(int code, String body)? onReply}) {
    final seq = _seq++;
    if (onReply != null) _replies[seq] = onReply;
    if (!_disposed) _sendBytes(utf8.encode('C$seq|$command\n'));
    return seq;
  }

  /// Answers awaited by sequence number — the only commands whose answer
  /// carries something, like a stream id.
  final _replies = <int, void Function(int code, String body)>{};

  final _rawReplies = <int, void Function(String line)>{};

  /// An extension's raw commands: see [FlexRadioSession.sendRaw].
  int _sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) {
    final commands = rawCommandLines(bytes);
    for (final command in commands) {
      final seq = _sendCommand(command);
      if (onAnswer != null) _rawReplies[seq] = (line) => onAnswer(utf8.encode('$line\n'));
    }
    return commands.length;
  }

  final _framer = LineFramer();

  @override
  void handleData(Uint8List chunk) {
    if (_disposed) return;
    for (final line in _framer.add(chunk)) {
      _handleLine(line);
    }
  }

  void _handleLine(String line) {
    if (line.isEmpty) return;
    final metadata = _meterMetadataLine.firstMatch(line);
    if (metadata != null) _meters.metadata(metadata[1]!);
    if (line.startsWith('H')) {
      _handleHandshakeLine(line);
    } else if (line.startsWith('S')) {
      _handleStatusLine(line);
    } else if (_replyPattern.firstMatch(line) case final reply?) {
      final seq = int.parse(reply[1]!), code = int.tryParse(reply[2]!, radix: 16);
      _handleReply(seq, code ?? 0);
      _replies.remove(seq)?.call(code ?? -1, reply[3]!);
      _rawReplies.remove(seq)?.call(line);
      // A command acknowledgement: the radio answered, so it is alive. WHICH
      // command does not matter — the ping exists only so that there is one
      // to answer while the dial is still. Status and acknowledgements share
      // this one socket, which is what lets an acknowledgement stand in for
      // a reading here (see [EquipmentSink.reportAlive]).
      _broadcast((sink) => sink.reportAlive());
    }
    // 'V' is the version banner; nothing to do with it yet.
  }

  static final _handshakePattern = RegExp(r'^H[0-9a-fA-F]+$');
  static final _replyPattern = RegExp(r'^R(\d+)\|([0-9A-Fa-f]*)\|?(.*)$');
  static final _panPattern = RegExp(r'^S[0-9a-fA-F]+\|display pan (0x[0-9a-fA-F]+) (.+)$');
  static final _streamPattern = RegExp(r'^S[0-9a-fA-F]+\|stream (0x[0-9a-fA-F]+) (.+)$');
  static final _slicePattern = RegExp(r'^S[0-9a-fA-F]+\|slice (\d+) (.+)$');
  static final _transmitPattern = RegExp(r'^S[0-9a-fA-F]+\|transmit (.+)$');

  /// Meter metadata arrives two ways, and both carry the `meter ` token —
  /// captured from a FLEX-6600 on 4.2.20: pushed as `S<handle>|meter 13.src=…`
  /// after `sub meter all`, and as the `meter list` reply, `R<seq>|0|meter 1.src=…`.
  static final _meterMetadataLine = RegExp(r'^[SR][^|]+\|(?:0\|)?meter (.+)$');
  static final _cwxPattern = RegExp(r'^S[0-9a-fA-F]+\|cwx (.+)$');
  static final _interlockPattern = RegExp(r'^S[0-9a-fA-F]+\|interlock (.+)$');

  /// Captured from a FLEX-6600 on 4.2.20, on `sub atu all`:
  /// `atu status=TUNE_SUCCESSFUL atu_enabled=1 memories_enabled=1 using_mem=1`.
  static final _atuPattern = RegExp(r'^S[0-9a-fA-F]+\|atu (.+)$');
  static final _clientPattern = RegExp(r'^S[0-9a-fA-F]+\|client (0x[0-9a-fA-F]+) (.+)$');

  /// Captured from a FLEX-6600 on 4.2.20, on `sub dvk all`:
  /// `dvk status=idle enabled=1`, then one `dvk added id=3 name="59-NY-TU"
  /// duration=2165` per slot. `status=` also reads `playback`, `recording`,
  /// `preview` and `disabled`, with an `id=`.
  static final _dvkPattern = RegExp(r'^S[0-9a-fA-F]+\|dvk (.+)$');

  /// Captured from a FLEX-6600 on 4.2.20, one of a burst answering
  /// `sub license all` at once: `license feature name=DIGITAL_VOICE_KEYER
  /// enabled=1 reason=PLUS`.
  static final _licenseFeaturePattern = RegExp(r'^S[0-9a-fA-F]+\|license feature (.+)$');

  /// The radio rejects "sub" commands until the handshake (the `H<handle>`
  /// line) has been seen, so a subscription requested before then is
  /// remembered and sent once the handshake lands.
  bool _handshakeDone = false;

  /// Whether any slice wants updates: the radio is subscribed while one does.
  bool _wantUpdates = false;

  /// This connection's handle, as a slice's `client_handle` names its
  /// owner: `0x158f8cc1`.
  String? _handle;

  /// Completed with the handshake: what opening a slice right after the
  /// connection came up waits for.
  final _handshaken = Completer<void>();

  void _handleHandshakeLine(String line) {
    if (_handshakeDone || !_handshakePattern.hasMatch(line)) return;
    _handshakeDone = true;
    _handshaken.complete();
    _handle = '0x${line.substring(1)}'.toLowerCase();
    if (gui) _register();
    if (_wantUpdates) _subscribe();
  }

  /// HaLo's station, under the id the radio keeps its slices by. The radio
  /// opens a slice and a panadapter for a station on its own, or brings
  /// back what that id had open.
  void _register() {
    _sendCommand(
      'client gui ${clientId ?? ''}'.trim(),
      onReply: (code, body) {
        final id = body.trim();
        if (code != 0) {
          // Said on each slice's row, where it would otherwise read as a
          // slice the radio is not running.
          _stationRefused = true;
          _broadcast((sink) => sink.reportDiagnostic('Flex refused HaLo as a station: 0x${code.toRadixString(16).toUpperCase()}'));
          for (final session in _sessions.toList()) {
            session._checkTrackedSlice();
          }
        } else if (id.isNotEmpty && id != clientId) {
          onClientId?.call(id);
        }
      },
    );
    _sendCommand('client program $flexProgramName');
    if (station case final station? when station.isNotEmpty) _sendCommand('client station $station');
  }

  /// What every client lists HaLo's station as, from now on.
  void renameStation(String name) {
    if (!gui || name.isEmpty || name == station) return;
    station = name;
    if (_handshakeDone) _sendCommand('client station $name');
  }

  /// The radio refused `client gui`: this connection holds no slices of
  /// HaLo's, and opens none.
  bool _stationRefused = false;

  /// How many more slices the radio can open (`radio slices=`), as it last
  /// said; null before it has.
  int? freeSlices;

  static final _radioPattern = RegExp(r'^S[0-9a-fA-F]+\|radio (.+)$');

  void _handleStatusLine(String line) {
    if (_radioPattern.firstMatch(line) case final radio?) {
      if (int.tryParse(_parseFields(radio[1]!)['slices'] ?? '') case final free?) freeSlices = free;
    }
    final sliceMatch = _slicePattern.firstMatch(line);
    if (sliceMatch != null) {
      _handleSliceLine(sliceMatch);
      return;
    }
    final clientMatch = _clientPattern.firstMatch(line);
    if (clientMatch != null) {
      _handleClientLine(clientMatch);
      return;
    }
    if (_panPattern.firstMatch(line) case final pan?) {
      final rest = pan[2]!;
      final fields = rest == 'removed' ? const {'removed': '1'} : _parseFields(rest);
      for (final session in _sessions) {
        session._spectrum.panStatus(pan[1]!.toLowerCase(), fields);
      }
      return;
    }
    if (_streamPattern.firstMatch(line) case final stream?) {
      final rest = stream[2]!;
      final fields = rest == 'removed' ? const {'removed': '1'} : _parseFields(rest);
      for (final session in _sessions) {
        session._spectrum.streamStatus(stream[1]!.toLowerCase(), fields);
      }
      return;
    }
    final transmitMatch = _transmitPattern.firstMatch(line);
    if (transmitMatch != null) _handleTransmitLine(transmitMatch);
    final cwxMatch = _cwxPattern.firstMatch(line);
    if (cwxMatch != null) _handleCwxLine(cwxMatch);
    final interlockMatch = _interlockPattern.firstMatch(line);
    if (interlockMatch != null) _handleInterlockLine(interlockMatch);
    final dvkMatch = _dvkPattern.firstMatch(line);
    if (dvkMatch != null) _handleDvkLine(dvkMatch.group(1)!);
    final licenseMatch = _licenseFeaturePattern.firstMatch(line);
    if (licenseMatch != null) _handleLicenseFeatureLine(licenseMatch.group(1)!);
    final atuMatch = _atuPattern.firstMatch(line);
    if (atuMatch != null) _handleAtuLine(atuMatch.group(1)!);
  }

  static Map<String, String> _parseFields(String text) {
    final fields = <String, String>{};
    for (final pair in text.trim().split(' ')) {
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      fields[pair.substring(0, separator)] = pair.substring(separator + 1);
    }
    return fields;
  }

  /// [_parseFields] for a line whose values may be quoted with spaces in
  /// them — a DVK slot's name.
  static Map<String, String> _parseQuotedFields(String text) => {
    for (final match in RegExp(r'(\w+)=(?:"([^"]*)"|(\S*))').allMatches(text)) match[1]!: match[2] ?? match[3]!,
  };

  // ------------------------------------------------------- subscriptions

  Timer? _settleTimer;
  Timer? _pingTimer;
  Timer? _powerRefreshTimer;

  /// Re-reads the tuner while it tunes: the radio may not echo a status to
  /// the client that asked, and a tune's outcome is the line that matters.
  Timer? _atuRefreshTimer;

  /// Once per connection: re-subscribing to a slice breaks its audio
  /// ([flexRadioPingInterval]).
  void _subscribe() {
    // Each subscription answers with a full status refresh, so this is also
    // when a slice that does not exist can be told apart from one that has
    // simply not been mentioned yet.
    _armSettleTimer();
    _sendCommand('sub slice all');
    _sendCommand('sub tx all');
    // Not for tuning anything: a slice identifies its owner by handle only,
    // so this is the only way to answer "who else is on slice B" with a
    // program and a station name rather than a hex handle.
    _sendCommand('sub client all');
    // The keyer speed: `cwx wpm=` arrives on this subscription, with the
    // refresh, so the speed is known without asking for it.
    _sendCommand('sub cwx all');
    // The voice keyer's slots — names and lengths — and what it is doing.
    _sendCommand('sub dvk all');
    // Whether the radio's licence lets it play them: the DVK is a
    // SmartSDR+ feature.
    _sendCommand('sub license all');
    // The tuner: `atu status=… atu_enabled=…`.
    _sendCommand('sub atu all');
    // How many slices the radio has free: `radio slices=`, for "New Slice".
    _sendCommand('sub radio all');
    for (final session in _sessions) {
      session._spectrum.subscribe();
    }
    _bindTrackedClient();
    _startMeters();
  }

  void _unsubscribe() {
    _sendCommand('unsub slice all');
    _sendCommand('unsub tx all');
    _sendCommand('unsub client all');
    _sendCommand('unsub cwx all');
    _sendCommand('unsub dvk all');
    _sendCommand('unsub license all');
    _sendCommand('unsub atu all');
    _sendCommand('unsub radio all');
  }

  /// Whether the subscription's full refresh has had its time
  /// ([_sliceRefreshSettle]): until then, a slice not described yet may be
  /// one the refresh has not reached.
  bool _settled = false;

  void _armSettleTimer() {
    _settled = false;
    _settleTimer?.cancel();
    _settleTimer = Timer(_sliceRefreshSettle, _settle);
  }

  void _startPeriodicTimers() {
    _pingTimer ??= Timer.periodic(flexRadioPingInterval, (_) {
      if (_wantUpdates && _handshakeDone) _sendCommand('ping');
    });
  }

  void _stopPeriodicTimers() {
    _stopMeters();
    _powerRefreshTimer?.cancel();
    _powerRefreshTimer = null;
    _atuRefreshTimer?.cancel();
    _atuRefreshTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _settleTimer?.cancel();
    _settleTimer = null;
  }

  /// The settled verdict on each slice, and one more `sub slice all` when
  /// the radio has described no slice at all: a subscription refused or lost
  /// at connect would otherwise read as "no slices" for the whole session.
  /// Once — this does not re-arm the settle — since re-subscribing breaks
  /// the audio of any slice the radio does have ([flexRadioPingInterval]); a
  /// slice it then describes clears the verdict.
  void _settle() {
    _settled = true;
    for (final session in _sessions.toList()) {
      session._checkTrackedSlice();
    }
    if (_slices.isEmpty && _wantUpdates && _handshakeDone) _sendCommand('sub slice all');
  }

  // ---------------------------------------------------- slices and clients

  /// What the radio last said about each slice, by index. Rebuilt from the
  /// status stream, never from configuration.
  final Map<int, _SliceStatus> _slices = {};
  final Map<String, String> _clientIds = {};
  String? _boundClientId;

  /// `program`/`station` per client handle, from the `client` status object.
  /// A slice names its owner only by handle, so without this the answer to
  /// "who has slice B" is a hex number.
  final Map<String, String> _clients = {};

  /// Each client's station name, or its program where it gave none, by
  /// handle: who holds a slice, in a word.
  final Map<String, String> _holders = {};

  // SmartSDR v3+ power belongs to a GUI client. Follow the owner of the
  // first slice attached whose owner is known, not the first client
  // discovered (there may be several operators).
  void _bindTrackedClient() {
    // A station of its own binds to nobody: its slices are its own.
    if (gui || !_handshakeDone || !_wantUpdates) return;
    for (final session in _sessions) {
      final handle = _slices[session.slice]?.clientHandle?.toLowerCase();
      // Its own station's, once the radio lists it: bound before, the
      // radio refuses the bind.
      final id = switch (bindTo) {
        final station? => _clientIds.containsValue(station) ? station : null,
        null => _clientIds[handle],
      };
      if (id == null) continue;
      if (id == _boundClientId) return;
      _boundClientId = id;
      _sendCommand('client bind client_id=$id');
      _sendCommand('sub tx all');
      for (final session in _sessions.toList()) {
        session._updateAudioStreams();
        session._checkTrackedSlice();
      }
      return;
    }
  }

  void _handleSliceLine(RegExpMatch match) {
    // e.g. "S40000001|slice 0 RF_frequency=14.250000 mode=USB in_use=1 ..."
    final index = int.tryParse(match.group(1)!);
    if (index == null) return;
    _handleSliceFields(index, _parseFields(match.group(2)!));
  }

  /// A slice's status, as the radio pushes it or as an acknowledged change
  /// stands in for the push it does not send ([FlexRadioSession._changeSlice]).
  void _handleSliceFields(int index, Map<String, String> fields) {
    // Flex reports MHz; we speak kHz throughout (see `Vfo.freq`). Keep the
    // decimals — down to Hz precision — rather than rounding to whole kHz.
    double? freqKHz;
    final rawFrequency = fields['RF_frequency'];
    if (rawFrequency != null) {
      final mhz = double.tryParse(rawFrequency);
      if (mhz != null) freqKHz = double.parse((mhz * 1000).toStringAsFixed(3));
    }
    final rawMode = fields['mode']?.toUpperCase();
    final mode = rawMode == null ? null : appModesByFlexMode[rawMode] ?? rawMode;

    // A status push carries only what CHANGED, so each field falls back to
    // what this slice last said rather than to null — treating an absent
    // `mode=` as "no mode" would blank the inventory on every retune.
    final previous = _slices[index];
    // `removed=1` is how a slice being torn down is announced; the fields
    // that would describe it are gone by then, so nothing is merged.
    if (fields['removed'] == '1') {
      _slices.remove(index);
    } else {
      _slices[index] = _SliceStatus(
        label: fields['index_letter'] ?? previous?.label ?? FlexRadioDriver.sliceLabel(index),
        inUse: fields['in_use'] != null ? fields['in_use'] == '1' : previous?.inUse,
        freqKHz: freqKHz ?? previous?.freqKHz,
        mode: mode ?? previous?.mode,
        clientHandle: fields['client_handle'] ?? previous?.clientHandle,
        tx: fields['tx'] != null ? fields['tx'] == '1' : previous?.tx,
        pan: fields['pan'] ?? previous?.pan,
        filterLo: int.tryParse(fields['filter_lo'] ?? '') ?? previous?.filterLo,
        filterHi: int.tryParse(fields['filter_hi'] ?? '') ?? previous?.filterHi,
        rxant: fields['rxant'] ?? previous?.rxant,
        txant: fields['txant'] ?? previous?.txant,
        rxPorts: fields['ant_list']?.split(',').where((p) => p.isNotEmpty).toList() ?? previous?.rxPorts,
        txPorts: fields['tx_ant_list']?.split(',').where((p) => p.isNotEmpty).toList() ?? previous?.txPorts,
        audioPan: int.tryParse(fields['audio_pan'] ?? '') ?? previous?.audioPan,
        audioMute: fields['audio_mute'] != null ? fields['audio_mute'] == '1' : previous?.audioMute,
        dax: int.tryParse(fields['dax'] ?? '') ?? previous?.dax,
      );
    }
    _publishChannels();
    for (final MapEntry(key: pan, value: opened) in _openingSlices.entries.toList()) {
      if (_sliceOnPan(pan) case final letter?) {
        _openingSlices.remove(pan);
        if (!opened.isCompleted) opened.complete(letter);
      }
    }
    for (final session in _sessions.toList()) {
      session._updateAudioStreams();
    }
    _bindTrackedClient();
    for (final session in _sessions.toList()) {
      if (session.slice == index) {
        session._sliceChanged(freqKHz: freqKHz, mode: mode);
      } else if (fields.containsKey('tx') || fields['removed'] == '1') {
        // The transmit flag moving between slices changes which slice is
        // on the air, whichever slice the line was about.
        session._reportOnAir();
      }
    }
  }

  /// The radio's number for HaLo's own slice [letter] on this connection,
  /// or null before the radio has described it. Each station letters its
  /// own slices from A, and the number can differ from one connection to
  /// the next.
  int? _ownedIndex(String letter) {
    final handle = _handle;
    if (!gui || handle == null) return null;
    for (final MapEntry(:key, :value) in _slices.entries) {
      if (value.clientHandle?.toLowerCase() == handle && value.label == letter && value.inUse != false) return key;
    }
    return null;
  }

  /// The panadapters HaLo asked for and is waiting to see a slice of, by
  /// pan id: each brings a slice of its own.
  final _openingSlices = <String, Completer<String?>>{};

  /// Opens a slice on HaLo's station, with the panadapter every slice comes
  /// with, and answers its letter: null when the radio refused or never
  /// said, or this is not HaLo's station.
  ///
  /// Asked right after the station's connection came up, it waits for the
  /// radio's handshake first: sent before it, the radio refuses it.
  Future<String?> openSlice() async {
    if (!gui) return null;
    if (!_handshakeDone) await _handshaken.future.timeout(_sliceOpenWait, onTimeout: () {});
    if (!_handshakeDone || _stationRefused) return null;
    final opened = Completer<String?>();
    _sendCommand(
      'display pan create x=$_panPixels y=$_panRows',
      onReply: (code, body) {
        final pan = body.split(',').first.trim().toLowerCase();
        if (code != 0 || pan.isEmpty) {
          _broadcast((sink) => sink.reportDiagnostic('Flex refused a new slice: 0x${code.toRadixString(16).toUpperCase()}'));
          if (!opened.isCompleted) opened.complete(null);
          return;
        }
        if (_sliceOnPan(pan) case final letter?) return opened.complete(letter);
        _openingSlices[pan] = opened;
      },
    );
    return opened.future.timeout(
      _sliceOpenWait,
      onTimeout: () {
        // Not left waiting: a slice the radio opens later is one the picker
        // offers to add, not one added here behind the operator's back.
        _openingSlices.removeWhere((_, waiting) => identical(waiting, opened));
        return null;
      },
    );
  }

  /// Closes HaLo's slice [letter] on the radio, and the panadapter it came
  /// with; the radio removes the slice with its panadapter. Whether the
  /// radio did: false, with nothing sent, for a slice it has not described.
  Future<bool> closeSlice(String letter) {
    final index = _ownedIndex(letter);
    if (index == null) return Future.value(false);
    final closed = Completer<bool>();
    final command = switch (_slices[index]?.pan) {
      final pan? => 'display pan remove $pan',
      null => 'slice remove $index',
    };
    _sendCommand(command, onReply: (code, _) => closed.complete(code == 0));
    return closed.future.timeout(_sliceOpenWait, onTimeout: () => false);
  }

  String? _sliceOnPan(String pan) {
    for (final status in _slices.values) {
      if (status.pan?.toLowerCase() == pan && status.clientHandle?.toLowerCase() == _handle) return status.label;
    }
    return null;
  }

  /// e.g. "S5AC2F980|client 0x1C61D553 connected program=SmartSDR-Win
  /// station=SHACK-PC", and "…|client 0x1C61D553 disconnected …" on the way
  /// out.
  void _handleClientLine(RegExpMatch match) {
    final handle = match.group(1)!.toLowerCase();
    final rest = match.group(2)!;
    if (rest.startsWith('disconnected')) {
      _clients.remove(handle);
      _holders.remove(handle);
      final removedId = _clientIds.remove(handle);
      if (removedId == _boundClientId) {
        _boundClientId = null;
        for (final session in _sessions.toList()) {
          session._checkTrackedSlice();
        }
      }
      _publishChannels();
      return;
    }
    final fields = _parseFields(rest);
    final id = fields['client_id'];
    if (id != null && RegExp(r'^[a-zA-Z0-9-]{1,128}$').hasMatch(id)) _clientIds[handle] = id;
    _bindTrackedClient();
    final program = fields['program'];
    final station = fields['station'];
    // A client that names neither still gets an entry: an empty name is how
    // a slice says "held, by something I cannot name", and dropping the line
    // would leave that slice looking free.
    _clients[handle] = [?program, if (station != null) '($station)'].join(' ');
    if (_nonEmpty(station) ?? _nonEmpty(program) case final holder?) _holders[handle] = holder;
    _publishChannels();
  }

  void _publishChannels() {
    final channels = [
      for (var index = 0; index < FlexRadioDriver.sliceLabels.length; index++)
        if (_slices[index] case final status?)
          EquipmentChannel(
            key: '$index',
            label: status.label,
            // A slice the radio described without saying whether it runs is
            // shown as running: it has an entry, which no idle slice gets.
            inUse: status.inUse ?? true,
            freqKHz: status.freqKHz,
            mode: status.mode,
            usedBy: _nonEmpty(_clients[status.clientHandle?.toLowerCase()]),
            holder: _holders[status.clientHandle?.toLowerCase()],
            holderId: _clientIds[status.clientHandle?.toLowerCase()],
            // A handle we cannot resolve is the dangerous case, not a
            // harmless one: `sub client all` may have been refused, or the
            // radio may format a handle differently in the two places it
            // appears. Either way something IS on this slice.
            heldByUnknown: status.clientHandle != null && _nonEmpty(_clients[status.clientHandle!.toLowerCase()]) == null,
          )
        else
          EquipmentChannel(key: '$index', label: FlexRadioDriver.sliceLabel(index)),
    ];
    _remember('channels', (sink) => sink.reportChannels(channels));
  }

  // --------------------------------------------------------------- meters

  /// Every meter the radio has described, once per connection, whichever
  /// slice attached first: a slice attaching later reads its LEVEL from
  /// what was described before it was there.
  late final _meters = FlexMeterCodec(0);
  final _powerThrottle = FlexSignalThrottle(decimals: 1);
  final _swrThrottle = FlexSignalThrottle(decimals: 1);
  FlexUdpSocket? _meterSocket;
  bool _openingMeters = false;
  int _meterGeneration = 0;

  /// Set once an open has failed, or answered with no socket (the web), so
  /// that nothing retries a host that cannot be resolved — a 5 s lookup and
  /// a diagnostic each time. A fresh subscription ([_stopMeters]) tries again.
  bool _metersUnavailable = false;

  void _startMeters() {
    if (meterHost == null || _openingMeters || _metersUnavailable) return;
    if (_meterSocket != null) {
      _sendCommand('sub meter all');
      _sendCommand('meter list');
      return;
    }
    _openingMeters = true;
    final generation = _meterGeneration;
    // The audio engine opens it where any slice on it is heard in HaLo or
    // talks through it: the slice's DAX audio arrives on it, and the
    // microphone's leaves from it. Not once the engine has refused it.
    final engine = _engineRefused ? null : _audioEngine();
    // An address the engine cannot take (IPv6) still gets the meters and the
    // spectrum, on a socket of its own: only the audio goes without.
    final FlexUdpSocketOpener open = engine == null
        ? openMeterSocket
        : (host, onData, onError) async {
            try {
              return await openFlexEngineSocket(engine, host, onData, onError);
            } on FlexAudioNeedsIpv4 catch (error) {
              _engineRefusedWith(t.settings.station.audioProblemIpv4, '$error');
            } on HaloAudioException catch (error) {
              _engineRefusedWith(t.settings.station.audioProblemEngine, error.message);
            }
            return openMeterSocket(host, onData, onError);
          };
    void failed(Object error, StackTrace stack) {
      if (generation == _meterGeneration && _wantUpdates) {
        _broadcast((sink) => sink.reportDiagnostic('Flex receive meter unavailable: $error'));
      }
    }

    unawaited(
      open(meterHost!, (data) {
        if (generation != _meterGeneration || !_wantUpdates) return;
        for (final session in _sessions.toList()) {
          if (session._spectrum.packet(data)) return;
        }
        // The real clock: a rate limit on wire data must not travel.
        final now = realNowMillis();
        for (final session in _sessions.toList()) {
          session._meterPacket(data, now);
        }
        final tx = _meters.transmit(data);
        if (tx.watts case final watts?) {
          if (_powerThrottle.accept(watts, now) case final value?) _broadcast((sink) => sink.reportMeter(RadioMeter.powerOut, value));
        }
        if (tx.swr case final swr?) {
          if (_swrThrottle.accept(swr, now) case final value?) _broadcast((sink) => sink.reportMeter(RadioMeter.swr, value));
        }
      }, failed).then(
        (socket) {
          if (generation != _meterGeneration || !_wantUpdates) {
            socket?.close();
            return;
          }
          _openingMeters = false;
          _meterSocket = socket;
          _metersUnavailable = socket == null;
          for (final session in _sessions) {
            if (socket == null) {
              session._spectrum.socketUnavailable();
            } else {
              session._spectrum.socketReady();
            }
          }
          if (socket != null) {
            // A slice wanting audio that attached while a plain socket was
            // opening: its audio has nowhere to arrive, so it opens again.
            if (socket.audioSocket == null && !_engineRefused && _audioEngine() != null && _reopenForAudio()) return;
            _sendCommand('client udpport ${socket.port}');
            _sendCommand('sub meter all');
            _sendCommand('meter list');
            for (final session in _sessions.toList()) {
              session._startAudioStreams(socket);
            }
          }
        },
        onError: (Object error, StackTrace stack) {
          if (generation == _meterGeneration) {
            _openingMeters = false;
            _metersUnavailable = true;
            for (final session in _sessions) {
              session._spectrum.socketUnavailable();
            }
          }
          failed(error, stack);
        },
      ),
    );
  }

  /// The socket opened again through the audio engine, for a slice that
  /// wants audio on a plain one; whether it was. Not under a key: the
  /// socket carries the voice keyer's message and the microphone, and the
  /// radio keyed on DAX with them cut puts noise on the air. Then it waits
  /// for the unkey ([_handleInterlockLine]).
  bool _reopenForAudio() {
    _reopenAfterUnkey = _keyedByUs || _transmitting == true;
    if (_reopenAfterUnkey) return false;
    _stopMeters();
    _startMeters();
    return true;
  }

  bool _reopenAfterUnkey = false;

  /// Whether the audio engine refused this connection's socket — the
  /// radio at an IPv6 address, the engine not starting — after which the
  /// socket is a plain one and is not opened through it again.
  bool _engineRefused = false;

  /// The engine, where a slice on this connection is heard in HaLo or
  /// talks through it; null where none is, or the engine will not start.
  AudioEngine? _audioEngine() {
    try {
      return [for (final session in _sessions) session._receiveAudio?.engine ?? session._talkAudio?.engine].nonNulls.firstOrNull;
    } on HaloAudioException catch (error) {
      _engineRefusedWith(t.settings.station.audioProblemEngine, error.message);
      return null;
    }
  }

  /// Each slice wanting audio says, on its row, why it gets none.
  String? _engineRefusedWhy;

  void _engineRefusedWith(String why, String detail) {
    _engineRefused = true;
    _engineRefusedWhy = why;
    for (final session in _sessions.toList()) {
      if (session._receiveAudio == null && session._talkAudio == null) continue;
      session._sink.reportDiagnostic('Flex audio socket unavailable: $detail');
      session._socketProblem = why;
      session._reportAudioProblem();
    }
  }

  void _stopMeters() {
    // The DAX audio comes and goes on the same socket.
    _daxOutput?.lost();
    _daxOutput = null;
    for (final session in _sessions) {
      session._stopAudioStreams();
    }
    _meterGeneration++;
    _openingMeters = false;
    _metersUnavailable = false;
    if (_meterSocket != null && _handshakeDone) _sendCommand('unsub meter all');
    if (_meterSocket != null) {
      for (final session in _sessions) {
        session._spectrum.socketLost();
      }
    }
    _meterSocket?.close();
    _meterSocket = null;
  }

  /// Whether `sub pan all` has gone out on this connection and not been
  /// withdrawn.
  bool _panSubscribed = false;

  /// A slice's spectrum's commands. The pan subscription is the
  /// connection's: sent once, however many slices ask for it, and withdrawn
  /// only by the last slice wanting a display, since one slice closing its
  /// display must not end another's.
  int _sendForSpectrum(FlexRadioSession session, String command, {void Function(int code, String body)? onReply}) {
    switch (command) {
      case 'sub pan all':
        if (_panSubscribed) return 0;
        _panSubscribed = true;
      case 'unsub pan all':
        if (!_panSubscribed || _sessions.any((other) => !identical(other, session) && other._spectrum.wanted)) return 0;
        _panSubscribed = false;
    }
    return _sendCommand(command, onReply: onReply);
  }

  // ---------------------------------------------------------- transmitter

  /// What the interlock last said. It speaks for the whole radio, which has
  /// one transmitter whatever slice it is on.
  bool? _transmitting;

  /// `interlock state=TRANSMITTING …`, on the `tx` subscription this driver
  /// already takes — so a Flex costs nothing at all to watch, unlike every
  /// polled radio here.
  ///
  /// Three of the eight documented states count as keyed, not one. RF is
  /// either about to be on the antenna (`PTT_REQUESTED`), on it
  /// (`TRANSMITTING`), or still on it while the radio winds down
  /// (`UNKEY_REQUESTED`) — and what reads this is the rule that no relay
  /// moves under RF, where the cost of being early is nothing and the cost
  /// of being late is a burnt relay.
  void _handleInterlockLine(RegExpMatch match) {
    final state = _parseFields(match.group(1)!)['state']?.toUpperCase();
    // A push carries only what changed: a line with no `state=` says
    // nothing about transmitting rather than saying "receiving".
    if (state == null) return;
    final transmitting = const {'PTT_REQUESTED', 'TRANSMITTING', 'UNKEY_REQUESTED'}.contains(state);
    _transmitting = transmitting;
    _daxSwitch.interlock(transmitting: transmitting, onAir: state == 'TRANSMITTING');
    if (!transmitting && _reopenAfterUnkey) _reopenForAudio();
    for (final session in _sessions.toList()) {
      session._reportOnAir();
    }
  }

  /// Whether the transmit flag is on a slice another of the app's slices on
  /// this radio reads from.
  ///
  /// Each station has a transmit slice of its own: a flag on another
  /// station's slice is that station's, and not one to move.
  bool _txOnAnotherSlice(FlexRadioSession session) {
    final holder = _slices[session.slice];
    if (holder?.tx == true) return false;
    return _slices.entries.any(
      (e) => e.value.tx == true && e.value.clientHandle == holder?.clientHandle && _sessions.any((other) => !identical(other, session) && other.slice == e.key),
    );
  }

  /// The station holding [session]'s slice, where this connection is bound
  /// to another: under multiFLEX the key, the power read back and a DAX
  /// channel are each the bound station's own, so through this binding
  /// they would be another's. Null until the radio has said both.
  ///
  /// So is a connection for a station not bound to it yet: unbound, a key
  /// is nobody's.
  String? _otherStation(FlexRadioSession session) {
    if (gui) return null;
    final handle = _slices[session.slice]?.clientHandle?.toLowerCase();
    final id = _clientIds[handle];
    if (bindTo case final station? when _boundClientId != station) return _holders[handle] ?? station;
    if (_boundClientId == null || id == null || id == _boundClientId) return null;
    return _holders[handle] ?? id;
  }

  /// Current power from the bound client's transmit state. A subscription
  /// also returns saved per-band settings; those are not current readings.
  /// Verified against FLEX-6600: unbound returned 1 W, bound returned 60 W.
  void _handleTransmitLine(RegExpMatch match) {
    if (match.group(1)!.startsWith('band ')) return;
    final fields = _parseFields(match.group(1)!);
    // The transmit object carries the keyer speed as `speed=` alongside
    // the CWX subscription's `wpm=`; either is the same knob.
    if (fields['dax'] case final dax?) _daxSwitch.daxReported(dax == '1');
    if (fields['tune'] case final tune?) {
      _remember('tune', (sink) {
        if (sink case final TuneCarrierSink sink) sink.reportTuneCarrier(tune == '1');
      });
    }
    final speed = int.tryParse(fields['speed'] ?? '');
    if (speed != null) _reportKeyerSpeed(speed);
    final rfpower = fields['rfpower'];
    if (rfpower == null) return;
    final watts = num.tryParse(rfpower);
    if (watts != null) _remember('power', (sink) => sink.reportPower(watts));
  }

  void _setPower(num watts) {
    _sendCommand('transmit set rfpower=${watts.round().clamp(0, 100)}');
    // The radio sends the client that set the power no status for it, and
    // re-subscribing to `tx`, unlike to a slice, is silent. Coalesce slider
    // bursts.
    if (!_wantUpdates || !_handshakeDone || _powerRefreshTimer != null) return;
    _powerRefreshTimer = Timer(const Duration(milliseconds: 100), () {
      _powerRefreshTimer = null;
      if (_wantUpdates && _handshakeDone) _sendCommand('sub tx all');
    });
  }

  /// Whether the app keyed the radio, so [teardown] can unkey it.
  bool _keyedByUs = false;

  /// The slice whose key is down: an unkey from another slice does not
  /// lift it.
  FlexRadioSession? _pttOwner;

  /// Keys the radio's transmit slice, which [session] takes first: `xmit`
  /// names none. Whether it keyed comes back as the interlock push
  /// ([_handleInterlockLine]).
  void _key(FlexRadioSession? session, bool on) {
    if (!on && _pttOwner != null && session != null && _pttOwner != session) return;
    // Set before a key and cleared only after an unkey: either one that
    // throws leaves [teardown] an unkey to send.
    _keyedByUs |= on;
    _pttOwner = on ? session : null;
    if (on) session?._takeTx();
    _sendCommand('xmit ${on ? 1 : 0}');
    _keyedByUs = on;
  }

  late final _daxSwitch = FlexDaxSwitch(
    host: () => meterHost,
    send: _sendCommand,
    transmitting: () => _transmitting,
    keyedByUs: () => _keyedByUs,
    diagnose: (note) => _broadcast((sink) => sink.reportDiagnostic(note)),
  );

  /// The DAX transmit stream this connection opened, if any — lost with the
  /// socket it is sent on.
  FlexDaxOutput? _daxOutput;

  bool get _sendsTransmitAudio => meterHost != null && !_metersUnavailable;

  AudioOutput? _openTransmitAudio(PcmDecoder decode) {
    final socket = _meterSocket;
    if (socket == null || !_handshakeDone) return null;
    _daxOutput?.close();
    return _daxOutput = FlexDaxOutput(
      send: (command, {onReply}) => _sendCommand(command, onReply: onReply),
      sendPacket: (packet) => socket.send(packet, flexDaxPort),
      decode: decode,
      diagnose: (what) => _broadcast((sink) => sink.reportDiagnostic('Flex DAX $what')),
    );
  }

  // ---------------------------------------------------------------- tuner

  /// A push carries only what changed, so both fields are kept between lines.
  String? _atuStatus;
  bool? _atuEnabled;

  void _handleAtuLine(String rest) {
    final fields = _parseFields(rest);
    _atuStatus = fields['status']?.toUpperCase() ?? _atuStatus;
    if (fields['atu_enabled'] case final enabled?) _atuEnabled = enabled == '1';
    // `atu_enabled=0` is a radio without the tuner fitted, or with it
    // switched off in its setup: either way, nothing to put in line.
    final status = _atuEnabled == false
        ? null
        : switch (_atuStatus) {
            'TUNE_IN_PROGRESS' => TunerStatus.tuning,
            'TUNE_SUCCESSFUL' || 'TUNE_OK' => TunerStatus.inline,
            'TUNE_FAIL' || 'TUNE_ABORTED' => TunerStatus.failed,
            null => null,
            // TUNE_BYPASS, TUNE_MANUAL_BYPASS, TUNE_FAIL_BYPASS, TUNE_NOT_STARTED, NONE.
            _ => TunerStatus.bypassed,
          };
    if (_atuEnabled == null && status == null) return;
    _remember('tuner', (sink) {
      if (sink case final TunerSink sink) sink.reportTuner(status);
    });
    if (status == TunerStatus.tuning) _refreshAtu(const Duration(seconds: 1));
  }

  void _refreshAtu(Duration after) {
    if (!_wantUpdates || !_handshakeDone || _atuRefreshTimer != null) return;
    _atuRefreshTimer = Timer(after, () {
      _atuRefreshTimer = null;
      if (_wantUpdates && _handshakeDone) _sendCommand('sub atu all');
    });
  }

  void _setTuner({required bool inline}) {
    _sendCommand(inline ? 'atu start' : 'atu bypass');
    _refreshAtu(const Duration(milliseconds: 300));
  }

  // ------------------------------------------------------------------ CWX

  /// What the radio last said its keyer runs at — `cwx wpm=` on the CWX
  /// status, or `speed=` on the transmit one.
  int? _keyerSpeed;

  /// The slice each queued message is from, by its queue id: a message
  /// goes out on its own slice, whichever slice queued last.
  final _cwOwners = <int, FlexRadioSession>{};

  /// CWX buffers text on the radio, so a message goes over in one `cwx
  /// send`; the queue still paces one MESSAGE behind another, which keeps
  /// the app's picture of what is keying honest (the indicator shows what
  /// the radio is on, not what it has been handed). Spaces travel as 0x7F —
  /// the API's own rule, since a space ends the command's argument.
  late final CwSendQueue _cwQueue = CwSendQueue(
    maxChunkLength: _cwxChunkLength,
    send: (chunk) {
      final owner = _cwOwners[_cwQueue.currentId];
      if (owner == null || owner.cannotTransmit != null) return;
      owner._takeTx();
      _sendCommand('cwx send "${chunk.replaceAll(' ', '\x7F')}"');
    },
    speedWpm: () => _keyerSpeed,
    onProgress: (progress) {
      if (progress == null) _cwOwners.clear();
      _remember('cw', (sink) => sink.reportCwProgress(progress));
    },
  );

  void _sendCw(FlexRadioSession session, String text) {
    // Owned before it is queued: queued with nothing going, it starts at once.
    final id = _cwQueue.nextId;
    _cwOwners[id] = session;
    if (_cwQueue.enqueue(text) == null) _cwOwners.remove(id);
  }

  /// A real stop, unlike Yaesu's: `cwx clear` empties the radio's buffer,
  /// so only the character in flight completes. Whichever slice asks: every
  /// slice shows the buffer sending, and a stop that did nothing on one of
  /// them would leave the operator's Escape unanswered with RF on the air.
  void _stopCw() {
    _cwQueue.clear();
    _sendCommand('cwx clear');
  }

  /// `cwx wpm=25 break_in_delay=…`, on the CWX subscription — the speed
  /// `cw wpm` sets and the front panel's knob turns. `sent=` and the erase
  /// fields arrive here too and are not read: the indicator estimates its
  /// progress the same way for every radio (cw_send_queue.dart).
  void _handleCwxLine(RegExpMatch match) {
    final wpm = int.tryParse(_parseFields(match.group(1)!)['wpm'] ?? '');
    if (wpm != null) _reportKeyerSpeed(wpm);
  }

  void _reportKeyerSpeed(int wpm) {
    _keyerSpeed = wpm;
    _remember('speed', (sink) => sink.reportKeyerSpeed(wpm));
  }

  void _refreshKeyerSpeed() {
    if (_handshakeDone && _wantUpdates) _sendCommand('sub cwx all');
  }

  // ------------------------------------------------------- voice keyer (DVK)
  //
  // Per FlexRadio's API reference for the DVK
  // (https://github.com/flexradio/smartsdr-api-docs/wiki/TCPIP-dvk): every
  // state change — the radio ending a play or a recording by itself included
  // — is pushed to every client on `sub dvk all`, so the status drives the
  // activity and nothing is polled.

  /// None once the radio says the DVK is unavailable — its licence off, or
  /// its status disabled: it is then a radio with no voice keyer, its keys
  /// disabled and F1-F8 left to whatever else they do, not a radio whose
  /// every memory is refused.
  int get _voiceMemoryCount => _dvkLicensed == false || _dvkDisabled ? 0 : maxVoiceMemories;

  /// Every slot the radio has described, by id — all twelve, though only
  /// the first [maxVoiceMemories] are reported.
  final Map<int, VoiceMemory> _dvkSlots = {};

  /// What was last reported, so a refresh that changed nothing is not
  /// reported again.
  List<VoiceMemory>? _reportedSlots;

  /// Whether the radio is licensed for the DVK: the licence line's
  /// `enabled=`, or a `50004001` answer to any `dvk` command. Null until
  /// either has said — unknown is offered.
  bool? _dvkLicensed;

  /// `status=disabled` or `enabled=0` on the status line, which the API
  /// reference defines as the DVK being unavailable.
  bool _dvkDisabled = false;

  /// The `dvk` starts still awaiting their `R` line, by sequence number, each
  /// with the [_voiceStarts] it began — a refusal is about THAT start, and a
  /// later play of the same memory is not the one refused.
  final Map<int, ({int memory, int start})> _dvkStarts = {};

  /// Counts starts, so a reply can tell its own from a later one.
  int _voiceStarts = 0;

  /// The `dvk set_name` commands still awaiting their `R` line: memory by
  /// sequence number.
  final Map<int, int> _dvkRenames = {};

  /// The bound for the activity [_voice] is about to start, set just before
  /// each start — the tracker asks for it as it starts.
  Duration _activityCeiling = voiceActivityCeiling;

  /// The slice whose memory the DVK is playing or recording.
  FlexRadioSession? _voiceOwner;

  late final VoiceActivityTracker _voice = VoiceActivityTracker(
    report: (activity) {
      final owner = activity == null ? _voiceOwner : null;
      if (activity == null) _voiceOwner = null;
      // The owner last: its sequence may play the next memory at once, and
      // that start must not be overwritten on another slice by this end.
      _remember('voice', (sink) => sink.reportVoiceActivity(activity), last: owner);
    },
    stop: stopVoice,
    ceiling: () => _activityCeiling,
    onCeiling: (limit) => _broadcast((sink) => sink.reportDiagnostic('DVK stopped at the ${limit.inSeconds} s ceiling')),
  );

  /// The four forms the API reference gives: `status=…`, `added …`,
  /// `deleted id=…`, and the bare `id=… name=… duration=…` update the radio
  /// pushes after a recording, a rename or a clear.
  void _handleDvkLine(String text) {
    final fields = _parseQuotedFields(text);
    final id = int.tryParse(fields['id'] ?? '');
    final status = fields['status'];
    if (status != null) {
      _handleDvkStatus(status, id, enabled: fields['enabled']);
      return;
    }
    if (id == null) return;
    if (text.startsWith('deleted')) {
      _dvkSlots.remove(id);
    } else {
      final previous = _dvkSlots[id];
      final name = fields['name'] ?? previous?.name ?? '';
      _dvkSlots[id] = VoiceMemory(
        memory: id,
        name: name == _dvkDefaultName(id) ? '' : name,
        durationMs: int.tryParse(fields['duration'] ?? '') ?? previous?.durationMs ?? 0,
      );
    }
    _reportSlots();
  }

  /// An unavailable keyer reports holding none — which is also what tells
  /// the surfaces, through the state, that the memory count just changed.
  void _reportSlots() {
    final slots = [for (var n = 1; n <= _voiceMemoryCount; n++) _dvkSlots[n] ?? VoiceMemory(memory: n)];
    if (listEquals(slots, _reportedSlots)) return;
    _reportedSlots = slots;
    _remember('memories', (sink) => sink.reportVoiceMemories(slots));
  }

  /// What the keyer is doing, against what the app asked it to do. A status
  /// naming another slot, or `preview` (another client auditioning one), is
  /// as much "not ours" as `idle` is.
  void _handleDvkStatus(String status, int? id, {String? enabled}) {
    final disabled = status == 'disabled' || enabled == '0';
    if (disabled != _dvkDisabled) {
      _dvkDisabled = disabled;
      _reportSlots();
    }
    final activity = _voice.activity;
    if (activity == null) return;
    final ours = id == null || id == activity.memory;
    final going = ours && (activity.recording ? status == 'recording' : status == 'playback');
    if (going) {
      _voice.confirm();
    } else {
      _voice.endFromPoll();
    }
  }

  void _handleLicenseFeatureLine(String text) {
    final fields = _parseFields(text);
    if (fields['name']?.toLowerCase() != 'digital_voice_keyer') return;
    final licensed = switch (fields['enabled']) {
      '1' => true,
      '0' => false,
      _ => null,
    };
    if (licensed == null) return;
    _setLicensed(licensed);
  }

  void _setLicensed(bool licensed) {
    _dvkLicensed = licensed;
    _reportSlots();
  }

  /// What the API reference answers a `dvk` command with, on a radio
  /// without the feature licence — every `dvk` command, `sub dvk all` aside.
  static const _dvkNotLicensed = 0x50004001;

  /// A non-zero answer to a start is the radio refusing it — no licence, an
  /// unparseable command, no such slot — which no status would say: nothing
  /// starts, so nothing changes. One to a rename leaves the slot showing a
  /// name the radio never took, so the slots are asked for again.
  void _handleReply(int seq, int code) {
    final start = _dvkStarts.remove(seq);
    final renamed = _dvkRenames.remove(seq);
    if (code == 0 || (start == null && renamed == null)) return;
    if (code == _dvkNotLicensed) _setLicensed(false);
    final hex = '0x${code.toRadixString(16).toUpperCase()}';
    if (renamed != null) {
      _broadcast((sink) => sink.reportDiagnostic('DVK refused to rename memory $renamed: $hex'));
      if (_handshakeDone && _wantUpdates) _sendCommand('sub dvk all');
      return;
    }
    _broadcast((sink) => sink.reportDiagnostic('DVK refused memory ${start!.memory}: $hex'));
    if (start!.start == _voiceStarts) _voice.refuse();
  }

  /// An EMPTY slot is refused here rather than sent: the API reference says
  /// a play of one answers `0` and can leave the radio keyed. So is any slot
  /// while [session] cannot transmit: the play would go out on another slice.
  void _playVoiceMemory(FlexRadioSession session, int n) {
    final slot = _dvkSlots[n];
    if ((slot != null && slot.durationMs == 0) || session.cannotTransmit != null) {
      stopVoice();
      _voiceOwner = session;
      _activityCeiling = voiceMemoryCeiling;
      _voice.start(VoiceActivity(memory: n));
      _voice.refuse();
      return;
    }
    final length = slot?.durationMs ?? 0;
    _startVoice(
      session,
      'dvk playback_start id=$n',
      VoiceActivity(memory: n),
      length > 0 ? Duration(milliseconds: length) + _dvkPlayMargin : voiceMemoryCeiling,
    );
  }

  void _recordVoiceMemory(FlexRadioSession session, int n) =>
      _startVoice(session, 'dvk rec_start id=$n', VoiceActivity(memory: n, recording: true), voiceMemoryCeiling);

  /// Whatever is going is stopped first: the API reference warns that an
  /// operation started over another can leave the DVK inconsistent, and once
  /// the tracker follows the new one, nothing would stop the old one.
  void _startVoice(FlexRadioSession session, String command, VoiceActivity activity, Duration ceiling) {
    stopVoice();
    // After the stop, so the flag does not move under a playback on the air.
    if (!activity.recording) session._takeTx();
    _voiceOwner = session;
    _activityCeiling = ceiling;
    _dvkStarts[_sendCommand(command)] = (memory: activity.memory, start: ++_voiceStarts);
    _voice.start(activity);
  }

  /// The stops name no slot: there is one DVK, doing one thing. A recording
  /// stopped is saved, and the radio pushes the slot's new length.
  void stopVoice() {
    final activity = _voice.activity;
    if (activity == null) return;
    _sendCommand(activity.recording ? 'dvk rec_stop' : 'dvk playback_stop');
    _voice.end();
  }

  /// The longest name the radio takes inside its quotes.
  static const _dvkNameMax = 61;

  /// Shown at once, as the radio will hold it: no `"` or `|`, which the API
  /// reference forbids, runs of spaces collapsed the way the radio collapses
  /// them, and no longer than it takes. The radio pushes the slot back
  /// renamed; a refusal re-reads it ([_handleReply]).
  void _renameVoiceMemory(int n, String name) {
    var clean = name.replaceAll(RegExp(r'["|]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length > _dvkNameMax) clean = clean.substring(0, _dvkNameMax).trimRight();
    _dvkRenames[_sendCommand('dvk set_name id=$n name="${clean.isEmpty ? _dvkDefaultName(n) : clean}"')] = n;
    final previous = _dvkSlots[n];
    _dvkSlots[n] = VoiceMemory(memory: n, name: clean, durationMs: previous?.durationMs ?? 0);
    _reportSlots();
  }

  // --------------------------------------------------------------- teardown

  @override
  void teardown() {
    if (_disposed) return;
    if (_keyedByUs) {
      // First, and sent even though the connection is closing: nothing else
      // will unkey this radio.
      _keyedByUs = false;
      _sendCommand('xmit 0');
    }
    _daxSwitch.teardown();
    for (final session in _sessions.toList()) {
      session._leaveSlice();
    }
    // A memory transmits, and nothing else will stop it once this client
    // is gone.
    stopVoice();
    _voice.dispose();
    _dvkStarts.clear();
    _dvkRenames.clear();
    // Answers to a connection that is closing would come to nobody.
    _replies.clear();
    _rawReplies.clear();
    _cwQueue.clear();
    _stopPeriodicTimers();
    if (_wantUpdates && _handshakeDone) _unsubscribe();
    _wantUpdates = false;
    for (final session in _sessions) {
      session._active = false;
    }
    _sessions.clear();
    _remembered.clear();
    _disposed = true;
  }
}
