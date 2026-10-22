// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/k4_spectrum_capture.dart';

/// Synthetic protocol evidence only: this is not a packet captured from a K4.
/// The fixed CRC footers were calculated independently with Python's
/// binascii.crc_hqx, reflecting its input/output for CRC-16/IBM-SDLC. They do
/// not share the decoder's checksum implementation. These tests exercise the
/// file/socket boundary, not whether the inferred wire format agrees with
/// actual radio firmware.
Uint8List _syntheticFrame({bool secondary = false}) {
  final bytes = Uint8List(4162);
  bytes.setRange(0, 7, [0xff, 0xfe, 0x01, 0x00, 0x02, secondary ? 43 : 42, secondary ? 0x42 : 0x41]);
  bytes.setRange(7, 13, ascii.encode('048000'));
  bytes.setRange(13, 24, ascii.encode('00014200000'));
  bytes.setRange(24, 29, ascii.encode('-1300'));
  var headerSum = 0;
  for (var i = 0; i < 63; i++) {
    headerSum += bytes[i];
  }
  bytes[63] = (-headerSum) & 0xff;
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < 2048; i++) {
    data.setInt16(64 + 2 * i, i == 1024 ? -200 : -1000, Endian.big);
  }
  data.setUint16(4160, secondary ? 0xb16c : 0x2428, Endian.big);
  return bytes;
}

class _TextOutput {
  final _controller = StreamController<List<int>>();
  final _bytes = BytesBuilder();
  late final IOSink sink = IOSink(_controller.sink);
  late final Future<void> _done;

  _TextOutput() {
    _done = _controller.stream.forEach(_bytes.add);
  }

  Future<String> finish() async {
    await sink.close();
    await _done;
    return utf8.decode(_bytes.takeBytes());
  }
}

typedef _Invocation = ({int code, String output, String errors});

Future<_Invocation> _invoke(List<String> args) async {
  final output = _TextOutput();
  final errors = _TextOutput();
  try {
    final code = await runK4SpectrumCapture(args, output: output.sink, errors: errors.sink).timeout(const Duration(seconds: 5));
    return (code: code, output: await output.finish(), errors: await errors.finish());
  } catch (_) {
    await output.finish();
    await errors.finish();
    rethrow;
  }
}

Map<String, Object?> _jsonObject(String text) => jsonDecode(text) as Map<String, Object?>;

Future<Map<String, Object?>> _summary(Directory directory) async => _jsonObject(await File('${directory.path}/summary.json').readAsString());

class _LoopbackRadio {
  final ServerSocket server;
  final connected = Completer<Socket>();
  final peerClosed = Completer<void>();
  final received = <int>[];
  final _peers = <Socket>[];
  int connections = 0;

  _LoopbackRadio(this.server) {
    server.listen((socket) {
      connections++;
      _peers.add(socket);
      socket.listen(
        received.addAll,
        onError: (Object error) {
          // A capture hitting its cap may reset a peer with unread data.
          if (!peerClosed.isCompleted) peerClosed.complete();
        },
        onDone: () {
          if (!peerClosed.isCompleted) peerClosed.complete();
        },
      );
      if (!connected.isCompleted) connected.complete(socket);
    });
  }

  Future<void> close() async {
    for (final peer in _peers) {
      peer.destroy();
    }
    await server.close();
  }
}

/// TCP chunk sizes can differ from the peer's writes. Check that the timing
/// log describes the exact saved byte ranges without depending on chunking.
Future<void> _expectChunkLog(Directory directory, int expectedBytes) async {
  final lines = await File('${directory.path}/chunks.jsonl').readAsLines();
  var offset = 0;
  var elapsedMicros = 0;
  for (final line in lines) {
    final chunk = _jsonObject(line);
    expect(chunk['offset'], offset);
    final length = chunk['length']! as int;
    expect(length, greaterThan(0));
    final elapsed = chunk['elapsedMicros']! as int;
    expect(elapsed, greaterThanOrEqualTo(elapsedMicros));
    offset += length;
    elapsedMicros = elapsed;
  }
  expect(offset, expectedBytes);
}

void main() {
  late Directory scratch;
  late Directory destination;
  late _LoopbackRadio radio;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('halo-k4-capture-test-');
    destination = Directory('${scratch.path}/capture');
    radio = _LoopbackRadio(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));
  });

  tearDown(() async {
    await radio.close();
    await scratch.delete(recursive: true);
  });

  List<String> captureArgs({int seconds = 3, int? maxBytes, String? note}) => [
    'capture',
    '--host',
    radio.server.address.address,
    '--port',
    '${radio.server.port}',
    '--output',
    destination.path,
    '--seconds',
    '$seconds',
    if (maxBytes != null) ...['--max-bytes', '$maxBytes'],
    if (note != null) ...['--note', note],
  ];

  test('capture preserves every raw byte, records timing and decodes without transmitting', () async {
    final wire = <int>[0x12, 0x34, ..._syntheticFrame(), 0xff, 0xfe];
    final attempt = _invoke(captureArgs(note: 'Synthetic loopback — no radio firmware claim'));
    final peer = await radio.connected.future.timeout(const Duration(seconds: 2));
    peer.add(wire.sublist(0, 9));
    await peer.flush();
    peer.add(wire.sublist(9));
    await peer.flush();
    await peer.close();

    final result = await attempt;
    expect(result.code, 0, reason: result.errors);
    expect(await File('${destination.path}/capture.bin').readAsBytes(), wire);
    final summary = await _summary(destination);
    expect(summary['stopReason'], 'remote-closed');
    final connectedAt = DateTime.parse(summary['connectedAtUtc']! as String);
    final startedAt = DateTime.parse(summary['startedAtUtc']! as String);
    expect(connectedAt.isUtc, isTrue);
    expect(connectedAt.isBefore(startedAt), isFalse);
    expect(summary['bytesCaptured'], wire.length);
    expect(summary['pendingBytes'], 2);
    expect(summary['userNote'], 'Synthetic loopback — no radio firmware claim');
    final decoder = summary['decoder']! as Map<String, Object?>;
    expect(decoder['framesDecoded'], 1);
    expect(decoder['discardedBytes'], 2);
    final streams = summary['streams']! as Map<String, Object?>;
    expect((streams['A']! as Map<String, Object?>)['frames'], 1);
    await _expectChunkLog(destination, wire.length);
    await radio.peerClosed.future.timeout(const Duration(seconds: 2));
    expect(radio.received, isEmpty, reason: 'the diagnostic receiver must not send CAT commands, subscriptions or keepalives');
  });

  test('a byte cap inside an incoming chunk saves only the permitted prefix', () async {
    final frame = _syntheticFrame();
    final wire = <int>[...frame, ..._syntheticFrame(secondary: true), ...frame];
    final limit = frame.length + 19;
    final attempt = _invoke(captureArgs(maxBytes: limit));
    final peer = await radio.connected.future.timeout(const Duration(seconds: 2));
    peer.add(wire);
    await peer.flush();

    final result = await attempt;
    expect(result.code, 0, reason: result.errors);
    expect(await File('${destination.path}/capture.bin').readAsBytes(), wire.take(limit).toList());
    final summary = await _summary(destination);
    expect(summary['stopReason'], 'byte-limit');
    expect(summary['bytesCaptured'], limit);
    expect(summary['pendingBytes'], 19);
    expect((summary['decoder']! as Map<String, Object?>)['framesDecoded'], 1);
    await _expectChunkLog(destination, limit);
    await radio.peerClosed.future.timeout(const Duration(seconds: 2));
    expect(radio.received, isEmpty);
  });

  test('duration expires and closes an idle connection even when no data arrives', () async {
    final attempt = _invoke(captureArgs(seconds: 1));
    await radio.connected.future.timeout(const Duration(seconds: 2));

    final result = await attempt.timeout(const Duration(seconds: 15));
    expect(result.code, 1, reason: 'an empty capture is not a validated spectrum stream');
    final summary = await _summary(destination);
    expect(summary['stopReason'], 'duration');
    expect(summary['elapsedMillis'], greaterThanOrEqualTo(1000));
    expect(summary['bytesCaptured'], 0);
    expect(summary['pendingBytes'], 0);
    expect((summary['decoder']! as Map<String, Object?>)['framesDecoded'], 0);
    expect(await File('${destination.path}/capture.bin').readAsBytes(), isEmpty);
    await _expectChunkLog(destination, 0);
    await radio.peerClosed.future.timeout(const Duration(seconds: 2));
    expect(radio.received, isEmpty);
  });

  test('remote EOF with undecodable data preserves evidence and returns failure', () async {
    final wire = List<int>.generate(257, (index) => index % 128);
    final attempt = _invoke(captureArgs());
    final peer = await radio.connected.future.timeout(const Duration(seconds: 2));
    peer.add(wire);
    await peer.flush();
    await peer.close();

    final result = await attempt;
    expect(result.code, 1);
    expect(await File('${destination.path}/capture.bin').readAsBytes(), wire);
    final summary = await _summary(destination);
    expect(summary['stopReason'], 'remote-closed');
    expect(summary['bytesCaptured'], wire.length);
    expect((summary['decoder']! as Map<String, Object?>)['framesDecoded'], 0);
    expect(summary['streams'], isEmpty);
    await _expectChunkLog(destination, wire.length);
    expect(radio.received, isEmpty);
  });

  test('an existing output directory is untouched and no connection is opened', () async {
    await destination.create();
    final sentinel = File('${destination.path}/capture.bin');
    await sentinel.writeAsBytes([0xde, 0xad, 0xbe, 0xef]);

    final result = await _invoke(captureArgs());
    expect(result.code, 1);
    expect(result.errors, isNotEmpty);
    expect(await sentinel.readAsBytes(), [0xde, 0xad, 0xbe, 0xef]);
    expect(await destination.list().map((entry) => entry.path).toList(), [sentinel.path]);
    expect(radio.connections, 0);
  });

  test('malformed arguments are rejected before creating files or opening sockets', () async {
    final base = captureArgs();
    final cases = <(String, List<String>)>[
      ('no command', []),
      ('unknown command', ['receive', ...base.skip(1)]),
      ('missing host', ['capture', '--output', destination.path]),
      ('empty host', ['capture', '--host', ' ', '--output', destination.path]),
      ('missing output', ['capture', '--host', radio.server.address.address]),
      ('missing option value', [...base, '--note']),
      ('unknown option', [...base, '--unknown', 'value']),
      ('duplicate option', [...base, '--seconds', '1']),
      ('port zero', [...base.take(4), '0', ...base.skip(5)]),
      ('port too large', [...base.take(4), '65536', ...base.skip(5)]),
      ('non-integer port', [...base.take(4), '9201.5', ...base.skip(5)]),
      ('seconds zero', [...base.take(8), '0']),
      ('seconds too large', [...base.take(8), '301']),
      ('non-integer seconds', [...base.take(8), '1.5']),
      ('byte cap zero', [...base, '--max-bytes', '0']),
      ('byte cap too large', [...base, '--max-bytes', '1073741825']),
      ('non-integer byte cap', [...base, '--max-bytes', 'ten']),
      ('inspect without file', ['inspect']),
      ('inspect with extra argument', ['inspect', '${scratch.path}/source.bin', 'extra']),
    ];
    for (final (label, args) in cases) {
      final result = await _invoke(args);
      expect(result.code, 2, reason: label);
      expect(result.errors, isNotEmpty, reason: label);
      expect(await destination.exists(), isFalse, reason: label);
      expect(radio.connections, 0, reason: label);
    }
  });

  test('inspect decodes a saved stream offline and prints machine-readable JSON', () async {
    final recording = File('${scratch.path}/recording.bin');
    final wire = <int>[..._syntheticFrame(), ..._syntheticFrame(secondary: true)];
    await recording.writeAsBytes(wire);

    final result = await _invoke(['inspect', recording.path]);
    expect(result.code, 0, reason: result.errors);
    final summary = _jsonObject(result.output);
    expect(summary['bytesCaptured'], wire.length);
    expect(summary['pendingBytes'], 0);
    expect((summary['decoder']! as Map<String, Object?>)['framesDecoded'], 2);
    final streams = summary['streams']! as Map<String, Object?>;
    expect((streams['A']! as Map<String, Object?>)['frames'], 1);
    expect((streams['B']! as Map<String, Object?>)['frames'], 1);
    expect(await recording.readAsBytes(), wire);
    expect(await destination.exists(), isFalse);
    expect(radio.connections, 0);
  });

  test('inspect reports a truncated frame as pending rather than a successful decode', () async {
    final recording = File('${scratch.path}/truncated.bin');
    await recording.writeAsBytes(_syntheticFrame().sublist(0, 113));

    final result = await _invoke(['inspect', recording.path]);
    expect(result.code, 1);
    final summary = _jsonObject(result.output);
    expect(summary['bytesCaptured'], 113);
    expect(summary['pendingBytes'], 113);
    expect((summary['decoder']! as Map<String, Object?>)['framesDecoded'], 0);
    expect(summary['streams'], isEmpty);
    expect(radio.connections, 0);
  });

  test('inspect reports a missing file as an operational error', () async {
    final result = await _invoke(['inspect', '${scratch.path}/missing.bin']);
    expect(result.code, 1);
    expect(result.errors, isNotEmpty);
    expect(await destination.exists(), isFalse);
    expect(radio.connections, 0);
  });

  test('a refused connection leaves an error summary and empty evidence files', () async {
    final vacant = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = vacant.port;
    await vacant.close();
    final args = captureArgs()..[4] = '$port';

    final result = await _invoke(args);
    expect(result.code, 1);
    expect(result.errors, isNotEmpty);
    final summary = await _summary(destination);
    expect(summary['stopReason'], 'error');
    expect(summary['connectedAtUtc'], isNull);
    expect(summary['error'], isNotEmpty);
    expect(summary['bytesCaptured'], 0);
    expect((summary['decoder']! as Map<String, Object?>)['framesDecoded'], 0);
    expect(await File('${destination.path}/capture.bin').readAsBytes(), isEmpty);
    await _expectChunkLog(destination, 0);
    expect(radio.connections, 0);
  });
}
