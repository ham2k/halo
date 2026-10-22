// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/k4_remote_capture.dart';

// Synthetic wire examples assembled independently of the production encoder.
// These verify CLI behavior; they are not evidence from a physical K4.
Uint8List _frame(List<int> payload) {
  final wire = Uint8List(payload.length + 12);
  wire.setRange(0, 4, [0xfe, 0xfd, 0xfc, 0xfb]);
  ByteData.sublistView(wire).setUint32(4, payload.length, Endian.big);
  wire.setRange(8, wire.length - 4, payload);
  wire.setRange(wire.length - 4, wire.length, [0xfb, 0xfc, 0xfd, 0xfe]);
  return wire;
}

Uint8List _pan({int receiver = 0, int sequence = 42}) {
  final payload = Uint8List(27 + 1024);
  payload.setRange(0, 5, [2, 1, sequence, 0, receiver]);
  final data = ByteData.sublistView(payload);
  data.setUint16(5, 1024, Endian.little);
  data.setInt64(11, 14200000, Endian.little);
  data.setInt32(19, 48, Endian.little);
  data.setInt32(23, -1300, Endian.little);
  payload.fillRange(27, payload.length, 60);
  return _frame(payload);
}

class _TextOutput {
  final _controller = StreamController<List<int>>();
  final _bytes = BytesBuilder();
  late final IOSink sink = IOSink(_controller.sink);
  late final Future<void> _done = _controller.stream.forEach(_bytes.add);

  Future<String> finish() async {
    final done = _done;
    await sink.close();
    await done;
    return utf8.decode(_bytes.takeBytes());
  }
}

typedef _Invocation = ({int code, String output, String errors});

Future<_Invocation> _invoke(List<String> args, {_Transport? transport, Map<String, String>? environment, Future<String?> Function()? readPassword}) async {
  final output = _TextOutput();
  final errors = _TextOutput();
  try {
    final code = await runK4RemoteCapture(
      args,
      output: output.sink,
      errors: errors.sink,
      environment: environment ?? {'K4_TEST_PASSWORD': 'sëcret-for-tests'},
      readPassword: readPassword,
      connect: transport?.connect,
    ).timeout(const Duration(seconds: 5));
    return (code: code, output: await output.finish(), errors: await errors.finish());
  } catch (_) {
    await output.finish();
    await errors.finish();
    rethrow;
  }
}

class _Transport implements K4RemoteCaptureConnection {
  final _incoming = StreamController<Uint8List>();
  final ready = Completer<void>();
  final sent = <List<int>>[];
  var connectionCount = 0;
  var isClosed = false;
  String? identity;
  List<int>? pskCopy;
  Uint8List? originalPsk;
  Future<void>? cancelled;
  Object? connectionError;

  Future<K4RemoteCaptureConnection> connect({
    required String host,
    required int port,
    required Uint8List psk,
    required String identity,
    required Duration timeout,
    required Future<void> cancelled,
  }) async {
    connectionCount++;
    this.identity = identity;
    pskCopy = psk.toList();
    originalPsk = psk;
    this.cancelled = cancelled;
    if (connectionError != null) throw connectionError!;
    return this;
  }

  @override
  Stream<Uint8List> get data => _incoming.stream;

  void receive(List<int> bytes) => _incoming.add(Uint8List.fromList(bytes));

  @override
  void send(List<int> bytes) {
    sent.add(bytes.toList());
    if (!ready.isCompleted) ready.complete();
  }

  @override
  Future<void> close() async {
    if (isClosed) return;
    isClosed = true;
    await _incoming.close();
  }
}

Map<String, Object?> _jsonObject(String value) => jsonDecode(value) as Map<String, Object?>;

Future<Map<String, Object?>> _summary(Directory destination) async => _jsonObject(await File('${destination.path}/summary.json').readAsString());

void main() {
  late Directory scratch;
  late Directory destination;
  late _Transport transport;

  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('halo-k4-remote-capture-test-');
    destination = Directory('${scratch.path}/capture');
    transport = _Transport();
  });

  tearDown(() async {
    await scratch.delete(recursive: true);
  });

  List<String> captureArgs({int seconds = 3, int? maxBytes}) => [
    'capture',
    '--host',
    'synthetic.invalid',
    '--output',
    destination.path,
    '--seconds',
    '$seconds',
    '--password-env',
    'K4_TEST_PASSWORD',
    if (maxBytes != null) ...['--max-bytes', '$maxBytes'],
  ];

  test('capture saves exact complete PAN frames while omitting CAT and audio content', () async {
    final a = _pan();
    final b = _pan(receiver: 1, sequence: 43);
    final cat = _frame([0, 0, 0, ...ascii.encode('SECRET-CAT-TEXT;')]);
    final audio = _frame([1, 1, 1, 3, 240, 0, 0, ...ascii.encode('SECRET-AUDIO-CONTENT')]);
    final mini = _frame([3, 1, 2, 0, 0, ...List.filled(128, 80)]);
    final unknown = _frame([127, 1, 3, 11, 12]);
    final wire = [...cat, ...a, ...audio, ...mini, ...unknown, ...b];
    final attempt = _invoke(captureArgs(), transport: transport);
    await transport.ready.future;
    transport.receive(wire.sublist(0, 39));
    transport.receive(wire.sublist(39, 100));
    transport.receive(wire.sublist(100));
    await transport.close();

    final result = await attempt;
    expect(result.code, 0, reason: result.errors);
    expect(await File('${destination.path}/capture.bin').readAsBytes(), [...a, ...b]);
    expect(transport.sent, [
      _frame([0, 0, 0, ...ascii.encode('RDY;')]),
    ]);
    expect(transport.identity, '');
    expect(transport.pskCopy, utf8.encode('sëcret-for-tests'));
    expect(transport.originalPsk, everyElement(0), reason: 'the mutable credential copy is cleared after use');
    await transport.cancelled;
    final summary = await _summary(destination);
    expect(summary['stopReason'], 'remote-closed');
    expect(summary['bytesReceived'], wire.length);
    expect(summary['bytesCaptured'], a.length + b.length);
    expect(summary['framesCaptured'], 2);
    expect(summary['recordedPayloads'], ['pan']);
    expect(DateTime.parse(summary['connectedAtUtc']! as String).isUtc, isTrue);
    final counters = summary['decoder']! as Map<String, Object?>;
    expect(counters['panPackets'], 2);
    expect(counters['catPackets'], 1);
    expect(counters['audioPackets'], 1);
    expect(counters['miniPanPackets'], 1);
    expect(counters['unknownPackets'], 1);
    final log = (await File('${destination.path}/frames.jsonl').readAsLines()).map(_jsonObject).toList();
    expect(log.map((frame) => frame['offset']), [0, a.length]);
    expect(log.map((frame) => frame['length']), [a.length, b.length]);
    expect(log.map((frame) => frame['receiver']), [0, 1]);
    expect(log.last['elapsedMicros']! as int, greaterThanOrEqualTo(log.first['elapsedMicros']! as int));
    for (final entry in await destination.list().toList()) {
      final bytes = await File(entry.path).readAsBytes();
      final text = latin1.decode(bytes);
      expect(text, isNot(contains('SECRET-CAT-TEXT')));
      expect(text, isNot(contains('SECRET-AUDIO-CONTENT')));
      expect(text, isNot(contains('sëcret-for-tests')));
    }
    expect('${result.output}${result.errors}', isNot(contains('sëcret-for-tests')));
  });

  test('received-byte cap bounds audio too and never saves a truncated PAN frame', () async {
    final a = _pan();
    final audio = _frame([1, 1, 2, 3, 240, 0, 0, ...List.filled(80, 120)]);
    final b = _pan(sequence: 43);
    final cap = a.length + audio.length + 40;
    final attempt = _invoke(captureArgs(maxBytes: cap), transport: transport);
    await transport.ready.future;
    transport.receive([...a, ...audio, ...b]);
    final result = await attempt;

    expect(result.code, 0, reason: result.errors);
    expect(await File('${destination.path}/capture.bin').readAsBytes(), a);
    final summary = await _summary(destination);
    expect(summary['stopReason'], 'byte-limit');
    expect(summary['bytesReceived'], cap);
    expect(summary['bytesCaptured'], a.length);
    expect(summary['pendingBytes'], 40);
    expect(transport.isClosed, isTrue);
  });

  test('idle capture times out and sends only framed RDY and PING commands', () async {
    final attempt = _invoke(captureArgs(seconds: 2), transport: transport);
    await transport.ready.future;
    final result = await attempt;

    expect(result.code, 1);
    final summary = await _summary(destination);
    expect(summary['stopReason'], 'duration');
    expect(summary['elapsedMillis'], greaterThanOrEqualTo(2000));
    expect(summary['bytesReceived'], 0);
    expect(summary['framesCaptured'], 0);
    expect(transport.sent.first, _frame([0, 0, 0, ...ascii.encode('RDY;')]));
    expect(transport.sent.length, greaterThanOrEqualTo(2));
    for (final sent in transport.sent.skip(1)) {
      expect(sent, _frame([0, 0, 0, ...ascii.encode('PING;')]));
    }
    expect(transport.isClosed, isTrue);
  });

  test('CAT-only traffic returns no-PAN failure without recording text', () async {
    final attempt = _invoke(captureArgs(), transport: transport);
    await transport.ready.future;
    transport.receive(_frame([0, 0, 0, ...ascii.encode('FA00014200000;')]));
    await transport.close();
    final result = await attempt;

    expect(result.code, 1);
    expect(await File('${destination.path}/capture.bin').readAsBytes(), isEmpty);
    expect(await File('${destination.path}/frames.jsonl').readAsString(), isEmpty);
    expect((await _summary(destination))['stopReason'], 'remote-closed');
  });

  test('existing output is untouched before requesting a password or connecting', () async {
    await destination.create();
    final sentinel = File('${destination.path}/capture.bin');
    await sentinel.writeAsBytes([1, 2, 3]);
    var prompts = 0;
    final result = await _invoke(
      captureArgs().take(7).toList(),
      transport: transport,
      readPassword: () async {
        prompts++;
        return 'unused';
      },
    );

    expect(result.code, 1);
    expect(prompts, 0);
    expect(transport.connectionCount, 0);
    expect(await sentinel.readAsBytes(), [1, 2, 3]);
    expect(await destination.list().length, 1);
  });

  test('invalid arguments are rejected before passwords, files, or connections', () async {
    var prompts = 0;
    final base = captureArgs();
    final cases = <List<String>>[
      [],
      ['unknown'],
      ['capture'],
      ['inspect'],
      ['inspect', 'one', 'two'],
      [...base, '--password', 'DO-NOT-PRINT-THIS'],
      [...base, '--password=DO-NOT-PRINT-THIS'],
      [...base, '--port', '0'],
      [...base, '--port', '65536'],
      [...base.take(6), '0', ...base.skip(7)],
      [...base.take(6), '301', ...base.skip(7)],
      [...base, '--max-bytes', '0'],
      [...base, '--max-bytes', '1073741825'],
      [...base, '--seconds', '1'],
      [...base, '--note'],
      [...base.take(8), 'bad=name'],
    ];
    for (final args in cases) {
      final result = await _invoke(
        args,
        transport: transport,
        readPassword: () async {
          prompts++;
          return 'unused';
        },
      );
      expect(result.code, 2, reason: '$args');
      expect(result.errors, isNot(contains('DO-NOT-PRINT-THIS')));
      expect(await destination.exists(), isFalse);
    }
    expect(prompts, 0);
    expect(transport.connectionCount, 0);
  });

  test('missing environment password fails before creating output or connecting', () async {
    final result = await _invoke(captureArgs(), transport: transport, environment: {});
    expect(result.code, 1);
    expect(await destination.exists(), isFalse);
    expect(transport.connectionCount, 0);
  });

  test('connection errors never save or print transport-provided secret text', () async {
    transport.connectionError = StateError('sëcret-for-tests should never appear');
    final result = await _invoke(captureArgs(), transport: transport);
    expect(result.code, 1);
    final summaryText = await File('${destination.path}/summary.json').readAsString();
    expect('$summaryText${result.output}${result.errors}', isNot(contains('sëcret-for-tests')));
    final summary = _jsonObject(summaryText);
    expect(summary['stopReason'], 'error');
    expect(summary['connectedAtUtc'], isNull);
    expect(summary['error'], 'connection-or-capture');
    expect(summary['bytesCaptured'], 0);
    expect(transport.originalPsk, everyElement(0));
  });

  test('offline inspection decodes saved frames without credentials or a connection', () async {
    final source = File('${scratch.path}/saved.bin');
    final wire = [..._pan(), ..._pan(receiver: 1, sequence: 43)];
    await source.writeAsBytes(wire);
    var prompts = 0;
    final result = await _invoke(
      ['inspect', source.path],
      transport: transport,
      readPassword: () async {
        prompts++;
        return null;
      },
    );

    expect(result.code, 0, reason: result.errors);
    final summary = _jsonObject(result.output);
    expect(summary['bytesReceived'], wire.length);
    expect((summary['decoder']! as Map<String, Object?>)['panPackets'], 2);
    expect((summary['streams']! as Map<String, Object?>).keys, ['0', '1']);
    expect(prompts, 0);
    expect(transport.connectionCount, 0);
    expect(await source.readAsBytes(), wire);
    expect(await destination.exists(), isFalse);
  });

  test('offline inspection reports truncation and missing input as failures', () async {
    final source = File('${scratch.path}/truncated.bin');
    await source.writeAsBytes(_pan().sublist(0, 35));
    final result = await _invoke(['inspect', source.path], transport: transport);
    expect(result.code, 1);
    final summary = _jsonObject(result.output);
    expect(summary['pendingBytes'], 35);
    expect((summary['decoder']! as Map<String, Object?>)['panPackets'], 0);
    final missing = await _invoke(['inspect', '${scratch.path}/missing.bin'], transport: transport);
    expect(missing.code, 1);
    expect(missing.errors, contains('file-system'));
    expect(transport.connectionCount, 0);
  });
}
