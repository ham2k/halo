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

import '../discovery.dart';
import '../driver.dart';
import '../equipment.dart';
import '../transports/udp_broadcast.dart';

/// Belt-and-suspenders against a subscription silently going stale — a
/// dropped WiFi/NAT mapping or a radio-side hiccup produces no error to
/// react to. While updates are wanted, re-send the subscription: it's
/// idempotent, and Flex answers with a full status refresh each time, so
/// this doubles as a periodic resync.
const _resyncInterval = Duration(seconds: 60);

const _lineFeed = 0x0a;
const _carriageReturn = 0x0d;

class FlexRadioDriver extends EquipmentDriver {
  const FlexRadioDriver();

  static const defaultPort = 4992;

  @override
  String get key => 'flexradio';

  @override
  String get name => 'FlexRadio (SmartSDR)';

  @override
  bool get hardwareVerified => true;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) =>
      FlexRadioSession(sink);
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

class FlexRadioSession implements EquipmentSession {
  final EquipmentSink _sink;

  FlexRadioSession(this._sink);

  static const _trackedSlice = 0;

  int _seq = 1;

  /// The radio rejects "sub" commands until the handshake (the `H<handle>`
  /// line) has been seen, so a subscription requested before then is
  /// remembered and sent once the handshake lands.
  bool _handshakeDone = false;
  bool _wantUpdates = false;
  Timer? _resyncTimer;

  /// Bytes received since the last complete line.
  final _residual = <int>[];

  void _sendCommand(String command) => _sink.send(utf8.encode('C${_seq++}|$command\n'));

  void _startResyncTimer() {
    _resyncTimer ??= Timer.periodic(_resyncInterval, (_) {
      if (_wantUpdates && _handshakeDone) _sendCommand('sub slice all');
    });
  }

  void _stopResyncTimer() {
    _resyncTimer?.cancel();
    _resyncTimer = null;
  }

  @override
  void handleData(Uint8List chunk) {
    for (final byte in chunk) {
      if (byte == _lineFeed) {
        _handleLine(utf8.decode(_residual, allowMalformed: true));
        _residual.clear();
      } else if (byte != _carriageReturn) {
        _residual.add(byte);
      }
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

  void _handleHandshakeLine(String line) {
    if (_handshakeDone || !_handshakePattern.hasMatch(line)) return;
    _handshakeDone = true;
    if (_wantUpdates) _sendCommand('sub slice all');
  }

  void _handleStatusLine(String line) {
    // e.g. "S40000001|slice 0 RF_frequency=14.250000 mode=USB in_use=1 ..."
    final match = _slicePattern.firstMatch(line);
    if (match == null) return;
    if (int.tryParse(match.group(1)!) != _trackedSlice) return;

    final fields = <String, String>{};
    for (final pair in match.group(2)!.trim().split(' ')) {
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      fields[pair.substring(0, separator)] = pair.substring(separator + 1);
    }

    // Flex reports MHz; we speak kHz throughout (see `Vfo.freq`). Keep the
    // decimals — down to Hz precision — rather than rounding to whole kHz.
    double? freqKHz;
    final rawFrequency = fields['RF_frequency'];
    if (rawFrequency != null) {
      final mhz = double.tryParse(rawFrequency);
      if (mhz != null) freqKHz = double.parse((mhz * 1000).toStringAsFixed(3));
    }
    final mode = fields['mode']?.toUpperCase();

    final reading = VfoReading(freqKHz: freqKHz, mode: mode);
    if (!reading.isEmpty) _sink.report(reading);
  }

  @override
  void setFrequency(double freqKHz) => _sendCommand(
      'slice tune $_trackedSlice ${(freqKHz / 1000).toStringAsFixed(6)}');

  @override
  void setMode(String mode) => _sendCommand('slice set $_trackedSlice mode=${mode.toUpperCase()}');

  /// FlexRadio pushes status on its own — "starting updates" just means
  /// subscribing.
  @override
  void startUpdates() {
    _wantUpdates = true;
    if (_handshakeDone) _sendCommand('sub slice all');
    _startResyncTimer();
  }

  @override
  void stopUpdates() {
    if (!_wantUpdates) return;
    _wantUpdates = false;
    _stopResyncTimer();
    if (_handshakeDone) _sendCommand('unsub slice all');
  }

  @override
  void teardown() {
    _stopResyncTimer();
    if (_wantUpdates && _handshakeDone) _sendCommand('unsub slice all');
    _wantUpdates = false;
  }
}
