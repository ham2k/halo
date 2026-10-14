// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Speaks the FlexRadio SmartSDR API: a line-oriented protocol over a single
// TCP stream, mixing command/response pairs ("C<seq>|command" /
// "R<seq>|code|result") with unsolicited status pushes ("S<handle>|...").
// We track slice 0's frequency and mode.
//
// Ported from app-polo's FlexRadioDriver.js, which was verified against a
// live FLEX-6600. Two deliberate divergences: readings go to a sink
// instead of straight into the store, and chunks are reassembled into lines
// (polo split each chunk on '\n' with no residual buffer, so a status line
// straddling two TCP reads was mangled).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../discovery.dart';
import '../driver.dart';
import '../equipment.dart';
import '../spectrum.dart';
import '../transports/udp_broadcast.dart';
import 'cw_send_queue.dart';
import 'line_framer.dart';
import 'flex_meter_codec.dart';
import 'voice_activity_tracker.dart';
import 'flex_spectrum.dart';
import '../transports/flex_meter_socket.dart';

/// App mode names → SmartSDR's, where the spellings differ. SmartSDR calls
/// its data sidebands `DIGU`/`DIGL`; the app names them the way every other
/// driver reports them.
const flexModesByAppMode = <String, String>{'DATA-USB': 'DIGU', 'DATA-LSB': 'DIGL', 'DATA-FM': 'DFM'};

final appModesByFlexMode = {for (final entry in flexModesByAppMode.entries) entry.value: entry.key};

/// Belt-and-suspenders against a subscription silently going stale — a
/// dropped WiFi/NAT mapping or a radio-side hiccup produces no error to
/// react to. While updates are wanted, re-send the subscription: it's
/// idempotent, and Flex answers with a full status refresh each time, so
/// this doubles as a periodic resync.
const _resyncInterval = Duration(seconds: 60);

/// The manager marks a node "Not responding" after 30 s without a word from
/// it, and this radio says nothing while the dial is still — so with only the
/// resync above to speak for it, an idle Flex reads as dead for the second
/// half of every minute. A `ping` gives the radio something to answer inside
/// the window; the `R` line it sends back is the proof of life. One ping per
/// window is enough because TCP delivers late but never drops.
///
/// A ping rather than resyncing inside the window (the Antenna Genius way):
/// the resync is four commands answered with a full slice/tx/client/cwx
/// burst that re-runs the settle timer and the channel inventory, and a
/// ping is one line each way. The trade is that a subscription dying over a
/// healthy socket now shows a frozen frequency for up to one resync instead
/// of going stale at 30 s — bounded, and never captured on hardware.
const flexRadioPingInterval = Duration(seconds: 25);

/// How long a subscription's full status refresh is given to arrive before
/// a slice that has not appeared is taken to be one the radio does not
/// have.
///
/// A slice in use announces itself; a slice that does not exist announces
/// nothing, and silence is only distinguishable from a slow refresh by
/// waiting. Long enough that a busy radio is not accused of missing a slice
/// it is about to report, short enough that the operator is not left staring
/// at a blank row wondering.
const _sliceRefreshSettle = Duration(seconds: 3);

class FlexRadioDriver extends EquipmentDriver {
  const FlexRadioDriver();

  static const defaultPort = 4992;

  @override
  String get key => 'flexradio';

  @override
  String get name => 'FlexRadio (SmartSDR)';

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(['LSB', 'USB', 'CW', 'AM', 'FM', 'RTTY', ...flexModesByAppMode.keys]);

  /// A FLEX-6600 runs up to eight slices; smaller models run fewer, and the
  /// radio says how many in its `radio slices=` status. Offering all eight
  /// regardless is deliberate — the list is built before any connection
  /// exists, and a slice the radio does not have is reported as missing once
  /// connected (see [FlexRadioSession._reportProblem]) rather than being
  /// silently unofferable.
  static const sliceLabels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  static const sliceConfigKey = 'slice';

  @override
  String? get channelKey => sliceConfigKey;

  @override
  List<String> get channelValues => [for (var i = 0; i < sliceLabels.length; i++) '$i'];

  @override
  bool get canKeyCw => true;

  /// The DVK holds twelve; the app offers one per function key. Whether the
  /// radio's licence lets it play any is known only once connected, when
  /// the session's own count says so ([FlexRadioSession.voiceMemoryCount]).
  @override
  int voiceMemoryCountWith(Map<String, dynamic> config) => maxVoiceMemories;

  @override
  Set<String> get recognizedConfigKeys => {...super.recognizedConfigKeys, voiceCeilingConfigKey};

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) =>
      FlexRadioSession(sink, slice: sliceFromConfig(config), meterHost: config['host'] as String?, voiceMemoryCeiling: voiceCeilingFromConfig(config));

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) =>
      // A pairing that fixes the slice has nothing to ask — the same escape
      // hatch the CI-V address field uses.
      overrides.containsKey(sliceConfigKey)
      ? const []
      : [
          {
            'type': 'field',
            'fieldType': 'select',
            'key': sliceConfigKey,
            'label': t.settings.station.flexSlice,
            'description': t.settings.station.flexSliceDescription,
            'options': [
              for (var i = 0; i < sliceLabels.length; i++) {'value': '$i', 'label': t.settings.station.flexSliceLabel(letter: sliceLabels[i])},
            ],
          },
        ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key != sliceConfigKey) return null;
    // Unset is slice A, not a rejection: a node configured before this
    // setting existed carries no `slice` at all, and failing it here would
    // stop a radio that has been connecting fine from connecting at all.
    if (value == null || '$value'.trim().isEmpty) return null;
    return _parseSlice(value) == null ? t.settings.station.flexSliceInvalid : null;
  }

  @override
  String? describeSuffix(Map<String, dynamic> config, {Map<String, dynamic> overrides = const {}}) {
    final channel = describeChannel(config, overrides: overrides);
    return channel == null ? null : ' · $channel';
  }

  @override
  String? describeChannel(Map<String, dynamic> config, {Map<String, dynamic> overrides = const {}}) {
    if (overrides.containsKey(sliceConfigKey)) return null;
    return t.settings.station.flexSliceLabel(letter: sliceLabel(sliceFromConfig(config)));
  }

  /// The configured slice, defaulting to 0 — a node stored before this
  /// setting existed has no `slice` key at all, and slice A is what it was
  /// tracking.
  static int sliceFromConfig(Map<String, dynamic> config) => _parseSlice(config[sliceConfigKey]) ?? 0;

  /// The radio's own letter for a slice index; the index itself for one
  /// past the letters we name, which the radio would have to have invented.
  static String sliceLabel(int slice) => slice >= 0 && slice < sliceLabels.length ? sliceLabels[slice] : '$slice';

  /// Null for anything that isn't a slice this driver offers. A value
  /// round-tripped through JSON (or a form) arrives as a String or a num
  /// depending on the path, so both are read.
  static int? _parseSlice(dynamic raw) {
    final value = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}'.trim());
    if (value == null) return null;
    return (value >= 0 && value < sliceLabels.length) ? value : null;
  }
}

/// A FlexRadio announces itself over UDP broadcast on its default port —
/// found automatically on the same subnet, and typed in manually otherwise
/// (behind a router that doesn't forward broadcasts, or on another subnet).
///
/// A pairing (an [EquipmentType]) wires this in as its `discoverer` rather
/// than the driver implementing [EquipmentDiscoverer] itself: discovery is
/// protocol knowledge tied to one specific transport (this radio's
/// broadcast, not a generic "any FlexRadio-driver pairing" capability).
class FlexRadioDiscoverer implements EquipmentDiscoverer {
  final String typeKey;

  const FlexRadioDiscoverer({required this.typeKey});

  @override
  Stream<DiscoveredEquipment> discover() => udpBroadcastDatagrams(port: FlexRadioDriver.defaultPort)
      .map(parseFlexDiscovery)
      .where((found) => found != null)
      .map(
        (found) => DiscoveredEquipment(
          typeKey: typeKey,
          // Serial when the radio offers one, so a radio that moves to a
          // new address updates its entry instead of appearing twice.
          id: found!.serial ?? '${found.host}:${found.port}',
          name: found.nickname ?? found.model,
          detail: [found.model, if (found.version != null) 'v${found.version}', found.host].join(' · '),
          config: {'host': found.host, 'port': found.port},
        ),
      );
}

/// What a FlexRadio says about itself when it announces on the network.
@immutable
class FlexDiscovery {
  final String model;
  final String? serial;
  final String? nickname;
  final String? version;
  final String host;
  final int port;

  const FlexDiscovery({required this.model, required this.host, required this.port, this.serial, this.nickname, this.version});
}

/// Reads one discovery datagram.
///
/// A Flex broadcasts VITA-49 frames on UDP 4992 whose payload is plain
/// ASCII `key=value` pairs. Parsing the VITA-49 header properly would buy
/// nothing here, so this scans for the payload the way app-polo did — but
/// it also requires an address, so a datagram from something else sharing
/// the port is ignored rather than half-parsed into a radio with nowhere
/// to connect to.
///
/// Returns null for anything that isn't a usable Flex announcement.
FlexDiscovery? parseFlexDiscovery(List<int> datagram) {
  final text = String.fromCharCodes(datagram.where((b) => b >= 0x20 && b < 0x7f).toList());
  final start = text.indexOf('model=');
  if (start < 0) return null;

  final fields = <String, String>{};
  for (final pair in text.substring(start).split(' ')) {
    final separator = pair.indexOf('=');
    if (separator <= 0) continue;
    fields[pair.substring(0, separator)] = pair.substring(separator + 1).trim();
  }

  final model = fields['model'];
  final host = fields['ip'];
  if (model == null || model.isEmpty) return null;
  // Without an address there is nothing to connect to, so this is not a
  // usable discovery no matter how well-formed the rest of it is.
  if (host == null || host.isEmpty) return null;

  return FlexDiscovery(
    model: model,
    host: host,
    port: int.tryParse(fields['port'] ?? '') ?? FlexRadioDriver.defaultPort,
    serial: _nonEmpty(fields['serial']),
    nickname: _nonEmpty(fields['nickname']),
    version: _nonEmpty(fields['version']),
  );
}

String? _nonEmpty(String? value) => (value == null || value.isEmpty) ? null : value;

/// SmartSDR's CWX buffer takes a whole message at once, so a chunk here is
/// only what keeps one `cwx send` line a sane length — not a radio limit.
const _cwxChunkLength = 128;

/// `cw wpm` per the SmartSDR API.
const _flexKeyerSpeedMin = 5;
const _flexKeyerSpeedMax = 100;

/// Past a recording's own length, how long a play may run before the session
/// stops it: the radio's end report travels the same socket as everything
/// else, and a busy link should not cut the last word of a CQ.
const _dvkPlayMargin = Duration(seconds: 3);

/// What SmartSDR names a DVK slot nobody has named. Shown as no label at
/// all, so the key ("M3") stands in for it the way it does for every other
/// radio's unnamed memory.
String _dvkDefaultName(int id) => 'Recording $id';

class FlexRadioSession
    implements
        TransceiverSession,
        CwKeyerSession,
        PttSession,
        RadioNamedVoiceMemories,
        SpectrumSession,
        AntennaTunerSession,
        PassbandSession,
        RadioAntennaSession {
  final EquipmentSink _sink;

  /// Which slice this node reads from and tunes. Symmetric on purpose: a
  /// node that watched one slice and tuned another would log a frequency
  /// the operator never transmitted on.
  final int slice;

  FlexRadioSession(this._sink, {this.slice = 0, this.meterHost, this.openMeterSocket = FlexMeterSocket.open, this.voiceMemoryCeiling = voiceActivityCeiling});
  final String? meterHost;

  /// How the receive-meter UDP socket is opened. A parameter because the real
  /// one binds a port and resolves a host, which no test of what the session
  /// does WITH the socket — or without one — can do.
  final Future<FlexMeterSocket?> Function(String host, void Function(Uint8List data) onData, void Function(Object error, StackTrace stack) onError)
  openMeterSocket;
  late final _meters = FlexMeterCodec(slice);
  final _signalThrottle = FlexSignalThrottle();
  final _powerThrottle = FlexSignalThrottle(decimals: 1);
  final _swrThrottle = FlexSignalThrottle(decimals: 1);
  FlexMeterSocket? _meterSocket;
  bool _openingMeters = false;
  int _meterGeneration = 0;

  /// Set once an open has failed, or answered with no socket (the web). Every
  /// resync comes back through [_startMeters]; without this latch a host that
  /// cannot be resolved costs a 5 s lookup and a diagnostic per resync, for the
  /// whole session. A fresh subscription ([_stopMeters]) tries again.
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
    void failed(Object error, StackTrace stack) {
      if (generation == _meterGeneration && _wantUpdates) {
        _sink.reportDiagnostic('Flex receive meter unavailable: $error');
      }
    }

    unawaited(
      openMeterSocket(meterHost!, (data) {
        if (generation != _meterGeneration || !_wantUpdates) return;
        if (_spectrum.packet(data)) return;
        // The real clock: a rate limit on wire data must not travel.
        final now = realNowMillis();
        if (_meters.signal(data) case final dbm?) {
          if (_signalThrottle.accept(dbm, now) case final value?) _sink.reportMeter(RadioMeter.signalDbm, value);
        }
        final tx = _meters.transmit(data);
        if (tx.watts case final watts?) {
          if (_powerThrottle.accept(watts, now) case final value?) _sink.reportMeter(RadioMeter.powerOut, value);
        }
        if (tx.swr case final swr?) {
          if (_swrThrottle.accept(swr, now) case final value?) _sink.reportMeter(RadioMeter.swr, value);
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
          if (socket == null) _spectrum.socketUnavailable();
          if (socket != null) {
            _sendCommand('client udpport ${socket.port}');
            _sendCommand('sub meter all');
            _sendCommand('meter list');
            _spectrum.socketReady();
          }
        },
        onError: (Object error, StackTrace stack) {
          if (generation == _meterGeneration) {
            _openingMeters = false;
            _metersUnavailable = true;
            _spectrum.socketUnavailable();
          }
          failed(error, stack);
        },
      ),
    );
  }

  void _stopMeters() {
    _meterGeneration++;
    _openingMeters = false;
    _metersUnavailable = false;
    if (_meterSocket != null && _handshakeDone) _sendCommand('unsub meter all');
    if (_meterSocket != null) _spectrum.socketLost();
    _meterSocket?.close();
    _meterSocket = null;
  }

  int _seq = 1;

  /// What the radio last said about each slice, by index. Rebuilt from the
  /// status stream, never from configuration.
  final Map<int, _SliceStatus> _slices = {};
  final Map<String, String> _clientIds = {};
  String? _boundClientId;

  // SmartSDR v3+ power belongs to a GUI client. Follow the owner of OUR
  // slice, not the first client discovered (there may be several operators).
  void _bindTrackedClient() {
    final handle = _slices[slice]?.clientHandle?.toLowerCase();
    final id = _clientIds[handle];
    if (id == null || id == _boundClientId || !_handshakeDone || !_wantUpdates) return;
    _boundClientId = id;
    _sendCommand('client bind client_id=$id');
    _sendCommand('sub tx all');
  }

  /// `program`/`station` per client handle, from the `client` status object.
  /// A slice names its owner only by handle, so without this the answer to
  /// "who has slice B" is a hex number.
  final Map<String, String> _clients = {};

  Timer? _settleTimer;

  /// The radio rejects "sub" commands until the handshake (the `H<handle>`
  /// line) has been seen, so a subscription requested before then is
  /// remembered and sent once the handshake lands.
  bool _handshakeDone = false;
  bool _wantUpdates = false;
  Timer? _resyncTimer;
  Timer? _pingTimer;
  Timer? _tuneRefreshTimer;
  Timer? _powerRefreshTimer;

  /// Re-reads the tuner while it tunes: the radio may not echo a status to
  /// the client that asked, and a tune's outcome is the line that matters.
  Timer? _atuRefreshTimer;

  final _framer = LineFramer();

  /// What the radio last said its keyer runs at — `cwx wpm=` on the CWX
  /// status, or `speed=` on the transmit one.
  int? _keyerSpeed;

  /// CWX buffers text on the radio, so a message goes over in one `cwx
  /// send`; the queue still paces one MESSAGE behind another, which keeps
  /// the app's picture of what is keying honest (the indicator shows what
  /// the radio is on, not what it has been handed). Spaces travel as 0x7F —
  /// the API's own rule, since a space ends the command's argument.
  late final _cwQueue = CwSendQueue(
    maxChunkLength: _cwxChunkLength,
    send: (chunk) => _sendCommand('cwx send "${chunk.replaceAll(' ', '\x7F')}"'),
    speedWpm: () => _keyerSpeed,
    onProgress: _sink.reportCwProgress,
  );

  /// Answers the sequence number the command went out under, which its
  /// `R<seq>|` reply names. [onReply], when given, is handed that reply's
  /// code and body.
  int _sendCommand(String command, {void Function(int code, String body)? onReply}) {
    final seq = _seq++;
    if (onReply != null) _replies[seq] = onReply;
    _sink.send(utf8.encode('C$seq|$command\n'));
    return seq;
  }

  /// Answers awaited by sequence number — the only commands whose answer
  /// carries something, like a stream id.
  final _replies = <int, void Function(int code, String body)>{};

  late final _spectrum = FlexDaxSpectrum(
    send: _sendCommand,
    sink: switch (_sink) {
      final SpectrumSink sink => sink,
      _ => null,
    },
  );

  /// The bound client's own panadapter streams never reach this one; see
  /// flex_spectrum.dart for why the spectrum is mirrored through DAX IQ.
  @override
  String? get spectrumUnavailable => meterHost == null ? t.settings.station.spectrumUnsupported : null;

  @override
  SpectrumCapabilities get spectrumCapabilities => _spectrum.capabilities;

  @override
  void startSpectrum() => _spectrum.start();

  @override
  void stopSpectrum() => _spectrum.stop();

  @override
  bool setSpectrum(SpectrumRequest request) => _spectrum.set(request);

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
    _spectrum.subscribe();
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
  }

  void _armSettleTimer() {
    _settleTimer?.cancel();
    _settleTimer = Timer(_sliceRefreshSettle, _checkTrackedSlice);
  }

  void _startPeriodicTimers() {
    _resyncTimer ??= Timer.periodic(_resyncInterval, (_) {
      if (_wantUpdates && _handshakeDone) _subscribe();
    });
    _pingTimer ??= Timer.periodic(flexRadioPingInterval, (_) {
      if (_wantUpdates && _handshakeDone) _sendCommand('ping');
    });
  }

  void _stopPeriodicTimers() {
    _stopMeters();
    _tuneRefreshTimer?.cancel();
    _tuneRefreshTimer = null;
    _powerRefreshTimer?.cancel();
    _powerRefreshTimer = null;
    _atuRefreshTimer?.cancel();
    _atuRefreshTimer = null;
    _resyncTimer?.cancel();
    _resyncTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _settleTimer?.cancel();
    _settleTimer = null;
  }

  @override
  void handleData(Uint8List chunk) {
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
      // A command acknowledgement: the radio answered, so it is alive. WHICH
      // command does not matter — the ping exists only so that there is one
      // to answer while the dial is still. Status and acknowledgements share
      // this one socket, which is what lets an acknowledgement stand in for
      // a reading here (see [EquipmentSink.reportAlive]).
      _sink.reportAlive();
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

  void _handleHandshakeLine(String line) {
    if (_handshakeDone || !_handshakePattern.hasMatch(line)) return;
    _handshakeDone = true;
    if (_wantUpdates) _subscribe();
  }

  void _handleStatusLine(String line) {
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
      _spectrum.panStatus(pan[1]!.toLowerCase(), rest == 'removed' ? const {'removed': '1'} : _parseFields(rest));
      return;
    }
    if (_streamPattern.firstMatch(line) case final stream?) {
      final rest = stream[2]!;
      _spectrum.streamStatus(stream[1]!.toLowerCase(), rest == 'removed' ? const {'removed': '1'} : _parseFields(rest));
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
    if (_sink case final TunerSink sink) sink.reportTuner(status);
    if (status == TunerStatus.tuning) _refreshAtu(const Duration(seconds: 1));
  }

  void _refreshAtu(Duration after) {
    if (!_wantUpdates || !_handshakeDone || _atuRefreshTimer != null) return;
    _atuRefreshTimer = Timer(after, () {
      _atuRefreshTimer = null;
      if (_wantUpdates && _handshakeDone) _sendCommand('sub atu all');
    });
  }

  /// A Flex has no "in line" switch: its tuner engages by tuning, which keys
  /// a carrier — briefly, from its memory for the frequency when it has one
  /// and memories are on. Bypass transmits nothing.
  @override
  void setTuner({required bool inline}) {
    _sendCommand(inline ? 'atu start' : 'atu bypass');
    _refreshAtu(const Duration(milliseconds: 300));
  }

  /// In line already is the tune here.
  @override
  bool get canStartTune => false;

  @override
  void startTune() {}

  @override
  void stopTune() {}

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
    if (_transmitting == transmitting) return;
    _transmitting = transmitting;
    _sink.reportTransmitting(transmitting);
  }

  /// What the interlock last said, so a restatement is not re-reported —
  /// SmartSDR refreshes the whole object on every subscribe.
  bool? _transmitting;

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
    _sink.reportKeyerSpeed(wpm);
  }

  void _handleSliceLine(RegExpMatch match) {
    // e.g. "S40000001|slice 0 RF_frequency=14.250000 mode=USB in_use=1 ..."
    final index = int.tryParse(match.group(1)!);
    if (index == null) return;
    final fields = _parseFields(match.group(2)!);

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
        pan: fields['pan'] ?? previous?.pan,
        filterLo: int.tryParse(fields['filter_lo'] ?? '') ?? previous?.filterLo,
        filterHi: int.tryParse(fields['filter_hi'] ?? '') ?? previous?.filterHi,
        rxant: fields['rxant'] ?? previous?.rxant,
        txant: fields['txant'] ?? previous?.txant,
        rxPorts: fields['ant_list']?.split(',').where((p) => p.isNotEmpty).toList() ?? previous?.rxPorts,
        txPorts: fields['tx_ant_list']?.split(',').where((p) => p.isNotEmpty).toList() ?? previous?.txPorts,
      );
    }
    _publishChannels();

    if (index != slice) return;
    _spectrum.slicePan(_slices[index]?.pan?.toLowerCase());
    _bindTrackedClient();
    _checkTrackedSlice();

    final reading = VfoReading(freqKHz: freqKHz, mode: mode);
    if (!reading.isEmpty) _sink.report(reading);
    // `filter_lo=100 filter_hi=2800`, as RadioRoom (FLEX-6600, 4.2.20) states
    // them: already Hz from the slice frequency, the convention [Passband] uses.
    if (_slices[index] case _SliceStatus(:final filterLo?, :final filterHi?) when filterLo < filterHi) {
      if (_sink case final PassbandSink sink) sink.reportPassband(Passband(filterLo, filterHi));
    }
    // `rxant=ANT1 txant=ANT1 ant_list=ANT1,ANT2,RX_A,RX_B,XVTA,XVTB tx_ant_list=ANT1,ANT2,XVTA,XVTB`,
    // as RadioRoom (FLEX-6600, 4.2.20) states slice A: a slice picks each independently.
    if (_slices[index] case _SliceStatus(:final rxPorts?, :final txPorts?, :final rxant, :final txant)) {
      if (_sink case final RadioAntennaSink sink) sink.reportAntennas(RadioAntennas(rxPorts: rxPorts, txPorts: txPorts, rx: rxant, tx: txant, separate: true));
    }
  }

  /// The slice's receive and transmit antennas, each its own setting.
  @override
  void setAntenna({String? rx, String? tx}) {
    if (rx != null) _sendCommand('slice set $slice rxant=$rx');
    if (tx != null) _sendCommand('slice set $slice txant=$tx');
    _refreshAfterTune();
  }

  /// SmartSDR's `filt`: the slice's edges, in Hz from its frequency. The
  /// radio clamps them to the mode's limits; the read-back says where.
  @override
  void setPassband(Passband passband) {
    _sendCommand('filt $slice ${passband.lowHz} ${passband.highHz}');
    _refreshAfterTune();
  }

  /// e.g. "S5AC2F980|client 0x1C61D553 connected program=SmartSDR-Win
  /// station=SHACK-PC", and "…|client 0x1C61D553 disconnected …" on the way
  /// out.
  void _handleClientLine(RegExpMatch match) {
    final handle = match.group(1)!.toLowerCase();
    final rest = match.group(2)!;
    if (rest.startsWith('disconnected')) {
      _clients.remove(handle);
      final removedId = _clientIds.remove(handle);
      if (removedId == _boundClientId) _boundClientId = null;
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
    _publishChannels();
  }

  /// The tracked slice not being in use is a configuration mistake the
  /// operator has to fix — the radio is fine, the link is fine, and there is
  /// simply nothing at the address they picked. Left unsaid it looks exactly
  /// like a dead radio: a connected row with a frequency that never arrives.
  ///
  /// Three outcomes, and conflating any two of them sends the operator to
  /// the wrong remedy:
  ///
  /// - the radio has described slices and this one is not among them, or
  ///   says it is not in use — the slice is wrong, change it;
  /// - the radio has described NO slices at all — the subscription or the
  ///   handshake failed, and telling someone to pick another slice would
  ///   send them to change a setting that was right;
  /// - the radio mentioned the slice without saying whether it runs — no
  ///   verdict, so the last one stands.
  ///
  /// Reported unconditionally rather than on transitions: `CatService`
  /// dedupes what it holds, and a driver keeping its own copy of what it
  /// last said is what [EquipmentSink.reportDiagnostic]'s own note forbids.
  void _checkTrackedSlice() {
    if (_slices.isEmpty) {
      _sink.reportProblem(t.settings.station.flexNoSlices);
      return;
    }
    final inUse = _slices[slice]?.inUse;
    // Mentioned, but the radio never said whether it runs: no verdict to
    // give, so whatever was last reported stands.
    if (_slices.containsKey(slice) && inUse == null) return;
    _sink.reportProblem(inUse == true ? null : t.settings.station.flexSliceMissing(letter: FlexRadioDriver.sliceLabel(slice)));
  }

  void _publishChannels() {
    _sink.reportChannels([
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
            // A handle we cannot resolve is the dangerous case, not a
            // harmless one: `sub client all` may have been refused, or the
            // radio may format a handle differently in the two places it
            // appears. Either way something IS on this slice.
            heldByUnknown: status.clientHandle != null && _nonEmpty(_clients[status.clientHandle!.toLowerCase()]) == null,
          )
        else
          EquipmentChannel(key: '$index', label: FlexRadioDriver.sliceLabel(index)),
    ]);
  }

  /// Current power from the bound client's transmit state. A subscription
  /// also returns saved per-band settings; those are not current readings.
  /// Verified against FLEX-6600: unbound returned 1 W, bound returned 60 W.
  void _handleTransmitLine(RegExpMatch match) {
    if (match.group(1)!.startsWith('band ')) return;
    final fields = _parseFields(match.group(1)!);
    // The transmit object carries the keyer speed as `speed=` alongside
    // the CWX subscription's `wpm=`; either is the same knob.
    final speed = int.tryParse(fields['speed'] ?? '');
    if (speed != null) _reportKeyerSpeed(speed);
    final rfpower = fields['rfpower'];
    if (rfpower == null) return;
    final watts = num.tryParse(rfpower);
    if (watts != null) _sink.reportPower(watts);
  }

  Map<String, String> _parseFields(String text) {
    final fields = <String, String>{};
    for (final pair in text.trim().split(' ')) {
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      fields[pair.substring(0, separator)] = pair.substring(separator + 1);
    }
    return fields;
  }

  @override
  void setFrequency(double freqKHz) {
    _sendCommand('slice tune $slice ${(freqKHz / 1000).toStringAsFixed(6)}');
    _refreshAfterTune();
  }

  @override
  void setMode(String mode) {
    _sendCommand('slice set $slice mode=${flexModesByAppMode[mode.toUpperCase()] ?? mode.toUpperCase()}');
    _refreshAfterTune();
  }

  // Flex suppresses status echoes to the client issuing a command. A fresh
  // subscription returns actual slice state, including any radio-side clamp
  // or rejection. Coalesce a frequency/mode burst into one read-back without
  // postponing it indefinitely during continuous tuning.
  void _refreshAfterTune() {
    if (!_wantUpdates || !_handshakeDone || _tuneRefreshTimer != null) return;
    _tuneRefreshTimer = Timer(const Duration(milliseconds: 100), () {
      _tuneRefreshTimer = null;
      if (_wantUpdates && _handshakeDone) _sendCommand('sub slice all');
    });
  }

  @override
  void setPower(num watts) {
    _sendCommand('transmit set rfpower=${watts.round().clamp(0, 100)}');
    // Like slice tuning, transmit changes need a read-back when the radio
    // suppresses the originating client's status echo. Coalesce slider bursts.
    if (!_wantUpdates || !_handshakeDone || _powerRefreshTimer != null) return;
    _powerRefreshTimer = Timer(const Duration(milliseconds: 100), () {
      _powerRefreshTimer = null;
      if (_wantUpdates && _handshakeDone) _sendCommand('sub tx all');
    });
  }

  @override
  void sendCw(String text) => _cwQueue.enqueue(text);

  /// A real stop, unlike Yaesu's: `cwx clear` empties the radio's buffer,
  /// so only the character in flight completes.
  @override
  void stopCw() {
    _cwQueue.clear();
    _sendCommand('cwx clear');
  }

  @override
  bool get cwSending => _cwQueue.sending;

  @override
  void dropQueuedCw(int id) => _cwQueue.dropPending(id);

  @override
  ({int min, int max}) get keyerSpeedRange => (min: _flexKeyerSpeedMin, max: _flexKeyerSpeedMax);

  /// The radio answers a `cw wpm` with a `cwx wpm=` status push, which is
  /// the read-back the other drivers have to ask for.
  @override
  void setKeyerSpeed(int wpm) => _sendCommand('cw wpm ${wpm.clamp(_flexKeyerSpeedMin, _flexKeyerSpeedMax)}');

  /// Nothing to ask: the speed is pushed. Re-subscribing answers with a
  /// full refresh, which carries it.
  @override
  void refreshKeyerSpeed() {
    if (_handshakeDone && _wantUpdates) _sendCommand('sub cwx all');
  }

  /// Whether the app keyed the radio, so [teardown] can unkey it.
  bool _keyedByUs = false;

  /// Keys the radio's transmit slice, which need not be [slice]: `xmit`
  /// names none. Whether it keyed comes back as the interlock push
  /// ([_handleInterlockLine]).
  @override
  void setPtt(bool on) {
    // Set before a key and cleared only after an unkey: either one that
    // throws leaves [teardown] an unkey to send.
    _keyedByUs |= on;
    _sendCommand('xmit ${on ? 1 : 0}');
    _keyedByUs = on;
  }

  // ------------------------------------------------------- voice keyer (DVK)
  //
  // Per FlexRadio's API reference for the DVK
  // (https://github.com/flexradio/smartsdr-api-docs/wiki/TCPIP-dvk): every
  // state change — the radio ending a play or a recording by itself included
  // — is pushed to every client on `sub dvk all`, so the status drives the
  // activity and nothing is polled.

  /// The memory length the entry pinned, or [voiceActivityCeiling]: what
  /// bounds a RECORDING, as a backstop to the radio's own ten-second limit.
  /// A play is bounded by its slot's own length instead ([_activityCeiling]).
  @override
  final Duration voiceMemoryCeiling;

  /// None once the radio says the DVK is unavailable — its licence off, or
  /// its status disabled: it is then a radio with no voice keyer, its keys
  /// disabled and F1-F8 left to whatever else they do, not a radio whose
  /// every memory is refused.
  @override
  int get voiceMemoryCount => _dvkLicensed == false || _dvkDisabled ? 0 : maxVoiceMemories;

  @override
  bool get canRecordVoice => true;

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

  late final VoiceActivityTracker _voice = VoiceActivityTracker(
    report: _sink.reportVoiceActivity,
    stop: stopVoice,
    ceiling: () => _activityCeiling,
    onCeiling: (limit) => _sink.reportDiagnostic('DVK stopped at the ${limit.inSeconds} s ceiling'),
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
  /// the surfaces, through the state, that [voiceMemoryCount] just changed.
  void _reportSlots() {
    final slots = [for (var n = 1; n <= voiceMemoryCount; n++) _dvkSlots[n] ?? VoiceMemory(memory: n)];
    if (listEquals(slots, _reportedSlots)) return;
    _reportedSlots = slots;
    _sink.reportVoiceMemories(slots);
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
      _sink.reportDiagnostic('DVK refused to rename memory $renamed: $hex');
      if (_handshakeDone && _wantUpdates) _sendCommand('sub dvk all');
      return;
    }
    _sink.reportDiagnostic('DVK refused memory ${start!.memory}: $hex');
    if (start.start == _voiceStarts) _voice.refuse();
  }

  /// An EMPTY slot is refused here rather than sent: the API reference says
  /// a play of one answers `0` and can leave the radio keyed.
  @override
  void playVoiceMemory(int n) {
    final slot = _dvkSlots[n];
    if (slot != null && slot.durationMs == 0) {
      stopVoice();
      _activityCeiling = voiceMemoryCeiling;
      _voice.start(VoiceActivity(memory: n));
      _voice.refuse();
      return;
    }
    final length = slot?.durationMs ?? 0;
    _startVoice('dvk playback_start id=$n', VoiceActivity(memory: n), length > 0 ? Duration(milliseconds: length) + _dvkPlayMargin : voiceMemoryCeiling);
  }

  @override
  void recordVoiceMemory(int n) => _startVoice('dvk rec_start id=$n', VoiceActivity(memory: n, recording: true), voiceMemoryCeiling);

  /// Whatever is going is stopped first: the API reference warns that an
  /// operation started over another can leave the DVK inconsistent, and once
  /// the tracker follows the new one, nothing would stop the old one.
  void _startVoice(String command, VoiceActivity activity, Duration ceiling) {
    stopVoice();
    _activityCeiling = ceiling;
    _dvkStarts[_sendCommand(command)] = (memory: activity.memory, start: ++_voiceStarts);
    _voice.start(activity);
  }

  /// The stops name no slot: there is one DVK, doing one thing. A recording
  /// stopped is saved, and the radio pushes the slot's new length.
  @override
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
  @override
  void renameVoiceMemory(int n, String name) {
    var clean = name.replaceAll(RegExp(r'["|]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length > _dvkNameMax) clean = clean.substring(0, _dvkNameMax).trimRight();
    _dvkRenames[_sendCommand('dvk set_name id=$n name="${clean.isEmpty ? _dvkDefaultName(n) : clean}"')] = n;
    final previous = _dvkSlots[n];
    _dvkSlots[n] = VoiceMemory(memory: n, name: clean, durationMs: previous?.durationMs ?? 0);
    _reportSlots();
  }

  /// [_parseFields] for a line whose values may be quoted with spaces in
  /// them — a DVK slot's name.
  static Map<String, String> _parseQuotedFields(String text) => {
    for (final match in RegExp(r'(\w+)=(?:"([^"]*)"|(\S*))').allMatches(text)) match[1]!: match[2] ?? match[3]!,
  };

  /// FlexRadio pushes status on its own — "starting updates" just means
  /// subscribing.
  @override
  void startUpdates() {
    _wantUpdates = true;
    if (_handshakeDone) _subscribe();
    // Armed here too, not only in _subscribe: a handshake that never lands
    // (or lands in a shape the pattern does not match) means no subscribe,
    // and every path that would say so hangs off the subscribe that never
    // happened. The staleness watchdog would eventually flag the row, but
    // with the same word it uses for an unplugged radio.
    _armSettleTimer();
    _startPeriodicTimers();
  }

  @override
  void stopUpdates() {
    if (!_wantUpdates) return;
    _wantUpdates = false;
    _stopPeriodicTimers();
    if (_handshakeDone) _unsubscribe();
  }

  /// Null, and NOT [_resyncInterval]: this radio pushes a slice status the
  /// moment the dial moves, so a quiet VFO is a still one. The 60 s resync
  /// is a backstop against a missed push, not the rate at which movement is
  /// reported — keying anything to it would treat a live stream as if it
  /// were a once-a-minute poll.
  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void teardown() {
    if (_keyedByUs) {
      // First, and sent even though the connection is closing: nothing else
      // will unkey this radio.
      _keyedByUs = false;
      _sendCommand('xmit 0');
    }
    // A memory transmits, and nothing else will stop it once this client
    // is gone.
    stopVoice();
    _voice.dispose();
    _dvkStarts.clear();
    _dvkRenames.clear();
    _spectrum.teardown();
    // Answers to a connection that is closing would come to nobody.
    _replies.clear();
    _cwQueue.clear();
    _stopPeriodicTimers();
    if (_wantUpdates && _handshakeDone) _unsubscribe();
    _wantUpdates = false;
  }
}

/// What the radio last said about one slice. Merged field-by-field from the
/// status pushes, which carry only what changed.
@immutable
class _SliceStatus {
  final String label;

  /// Null when the radio has mentioned this slice without ever saying
  /// whether it is running. Guessing either way is a real answer to a
  /// question nobody asked: `true` withdraws a missing-slice problem that is
  /// still true, and `false` accuses a slice that is fine. Both are silent,
  /// so the state is representable instead.
  final bool? inUse;
  final double? freqKHz;
  final String? mode;
  final String? clientHandle;

  /// The panadapter showing this slice, as `0x40000000`.
  final String? pan;

  /// The receive filter's edges, in Hz from the slice frequency.
  final int? filterLo, filterHi;

  /// The antennas in use, and the ports each can choose.
  final String? rxant, txant;
  final List<String>? rxPorts, txPorts;

  const _SliceStatus({
    required this.label,
    required this.inUse,
    this.freqKHz,
    this.mode,
    this.clientHandle,
    this.pan,
    this.filterLo,
    this.filterHi,
    this.rxant,
    this.txant,
    this.rxPorts,
    this.txPorts,
  });
}
