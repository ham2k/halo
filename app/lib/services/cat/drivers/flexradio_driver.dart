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

import '../../../i18n/strings.g.dart';
import '../discovery.dart';
import '../driver.dart';
import '../equipment.dart';
import '../transports/udp_broadcast.dart';
import 'cw_send_queue.dart';
import 'line_framer.dart';

/// Belt-and-suspenders against a subscription silently going stale — a
/// dropped WiFi/NAT mapping or a radio-side hiccup produces no error to
/// react to. While updates are wanted, re-send the subscription: it's
/// idempotent, and Flex answers with a full status refresh each time, so
/// this doubles as a periodic resync.
const _resyncInterval = Duration(seconds: 60);

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
  bool get hardwareVerified => true;

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
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) =>
      FlexRadioSession(sink, slice: sliceFromConfig(config));

  @override
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) =>
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
                  for (var i = 0; i < sliceLabels.length; i++)
                    {'value': '$i', 'label': t.settings.station.flexSliceLabel(letter: sliceLabels[i])},
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
    if (overrides.containsKey(sliceConfigKey)) return null;
    return ' · ${t.settings.station.flexSliceLabel(letter: sliceLabel(sliceFromConfig(config)))}';
  }

  /// The configured slice, defaulting to 0 — a node stored before this
  /// setting existed has no `slice` key at all, and slice A is what it was
  /// tracking.
  static int sliceFromConfig(Map<String, dynamic> config) => _parseSlice(config[sliceConfigKey]) ?? 0;

  /// The radio's own letter for a slice index; the index itself for one
  /// past the letters we name, which the radio would have to have invented.
  static String sliceLabel(int slice) =>
      slice >= 0 && slice < sliceLabels.length ? sliceLabels[slice] : '$slice';

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
  Stream<DiscoveredEquipment> discover() =>
      udpBroadcastDatagrams(port: FlexRadioDriver.defaultPort).map(parseFlexDiscovery).where((found) => found != null).map(
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

  const FlexDiscovery({
    required this.model,
    required this.host,
    required this.port,
    this.serial,
    this.nickname,
    this.version,
  });
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

class FlexRadioSession implements CwKeyerSession {
  final EquipmentSink _sink;

  /// Which slice this node reads from and tunes. Symmetric on purpose: a
  /// node that watched one slice and tuned another would log a frequency
  /// the operator never transmitted on.
  final int slice;

  FlexRadioSession(this._sink, {this.slice = 0});

  int _seq = 1;

  /// What the radio last said about each slice, by index. Rebuilt from the
  /// status stream, never from configuration.
  final Map<int, _SliceStatus> _slices = {};

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

  void _sendCommand(String command) => _sink.send(utf8.encode('C${_seq++}|$command\n'));

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
  }

  void _unsubscribe() {
    _sendCommand('unsub slice all');
    _sendCommand('unsub tx all');
    _sendCommand('unsub client all');
    _sendCommand('unsub cwx all');
  }

  void _armSettleTimer() {
    _settleTimer?.cancel();
    _settleTimer = Timer(_sliceRefreshSettle, _checkTrackedSlice);
  }

  void _startResyncTimer() {
    _resyncTimer ??= Timer.periodic(_resyncInterval, (_) {
      if (_wantUpdates && _handshakeDone) _subscribe();
    });
  }

  void _stopResyncTimer() {
    _resyncTimer?.cancel();
    _resyncTimer = null;
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
    if (line.startsWith('H')) {
      _handleHandshakeLine(line);
    } else if (line.startsWith('S')) {
      _handleStatusLine(line);
    }
    // 'V' is the version banner and 'R' lines are command acknowledgements;
    // nothing to do with either yet.
  }

  static final _handshakePattern = RegExp(r'^H[0-9a-fA-F]+$');
  static final _slicePattern = RegExp(r'^S[0-9a-fA-F]+\|slice (\d+) (.+)$');
  static final _transmitPattern = RegExp(r'^S[0-9a-fA-F]+\|transmit (.+)$');
  static final _cwxPattern = RegExp(r'^S[0-9a-fA-F]+\|cwx (.+)$');
  static final _clientPattern = RegExp(r'^S[0-9a-fA-F]+\|client (0x[0-9a-fA-F]+) (.+)$');

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
    final transmitMatch = _transmitPattern.firstMatch(line);
    if (transmitMatch != null) _handleTransmitLine(transmitMatch);
    final cwxMatch = _cwxPattern.firstMatch(line);
    if (cwxMatch != null) _handleCwxLine(cwxMatch);
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
    final mode = fields['mode']?.toUpperCase();

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
      );
    }
    _publishChannels();

    if (index != slice) return;
    _checkTrackedSlice();

    final reading = VfoReading(freqKHz: freqKHz, mode: mode);
    if (!reading.isEmpty) _sink.report(reading);
  }

  /// e.g. "S5AC2F980|client 0x1C61D553 connected program=SmartSDR-Win
  /// station=SHACK-PC", and "…|client 0x1C61D553 disconnected …" on the way
  /// out.
  void _handleClientLine(RegExpMatch match) {
    final handle = match.group(1)!.toLowerCase();
    final rest = match.group(2)!;
    if (rest.startsWith('disconnected')) {
      _clients.remove(handle);
      _publishChannels();
      return;
    }
    final fields = _parseFields(rest);
    final program = fields['program'];
    final station = fields['station'];
    // A client that names neither still gets an entry: an empty name is how
    // a slice says "held, by something I cannot name", and dropping the line
    // would leave that slice looking free.
    _clients[handle] = [
      ?program,
      if (station != null) '($station)',
    ].join(' ');
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
    _sink.reportProblem(
      inUse == true ? null : t.settings.station.flexSliceMissing(letter: FlexRadioDriver.sliceLabel(slice)),
    );
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
            heldByUnknown: status.clientHandle != null &&
                _nonEmpty(_clients[status.clientHandle!.toLowerCase()]) == null,
          )
        else
          EquipmentChannel(key: '$index', label: FlexRadioDriver.sliceLabel(index)),
    ]);
  }

  /// `rfpower` is 0-100 on SmartSDR's own status object — NOT captured
  /// against the live FLEX-6600 the freq/mode path above was verified
  /// against, but the whole line this driver targets (6300-6700) is
  /// 100W-rated HF, which is why treating the value as watts directly is
  /// less of a leap here than the same assumption in the Icom/Kenwood/
  /// FT-891 drivers, where the rated maximum varies by model.
  void _handleTransmitLine(RegExpMatch match) {
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
  void setFrequency(double freqKHz) =>
      _sendCommand('slice tune $slice ${(freqKHz / 1000).toStringAsFixed(6)}');

  @override
  void setMode(String mode) => _sendCommand('slice set $slice mode=${mode.toUpperCase()}');

  @override
  void setPower(num watts) => _sendCommand('transmit set rfpower=${watts.round().clamp(0, 100)}');

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
    _startResyncTimer();
  }

  @override
  void stopUpdates() {
    if (!_wantUpdates) return;
    _wantUpdates = false;
    _stopResyncTimer();
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
    _cwQueue.clear();
    _stopResyncTimer();
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

  const _SliceStatus({
    required this.label,
    required this.inUse,
    this.freqKHz,
    this.mode,
    this.clientHandle,
  });
}
