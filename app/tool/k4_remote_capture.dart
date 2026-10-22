// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show realNowUtc;
import 'package:halo_tls_psk/halo_tls_psk.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_remote_codec.dart';

const _usage = '''K4 remote PAN capture over TLS-PSK.

  cd app
  dart run tool/k4_remote_capture.dart capture --host <host> --output <new-directory>
      [--port 9204] [--seconds 20] [--max-bytes 33554432]
      [--password-env <variable-name>] [--note <text>]
  dart run tool/k4_remote_capture.dart inspect <capture.bin>

Capture prompts for the password with terminal echo disabled unless an environment
variable is named. Passwords are never accepted as command-line values or saved.
Only complete PAN frames are saved: CAT text and audio are counted and discarded.
The only commands sent are RDY; and PING; (once per second). No audio is sent.
Writes capture.bin, frames.jsonl, and summary.json to a new directory whose parent
exists. Duration is 1–300 seconds after connection; connection timeout is 5 seconds.
The byte limit (1–1073741824) counts received bytes, including discarded audio/CAT.
Inspection reads only saved data. Dart builds the native asset before starting;
prefetch the TLS source and build once before working offline (see the package README).
Exit 0 means a PAN frame decoded, not hardware validation; 1 means no PAN or an
operational failure; 2 means invalid arguments.
''';

/// The CLI boundary is injectable so tests never require credentials or a radio.
abstract interface class K4RemoteCaptureConnection {
  Stream<Uint8List> get data;
  void send(List<int> bytes);
  Future<void> close();
}

typedef K4RemoteCaptureConnect =
    Future<K4RemoteCaptureConnection> Function({
      required String host,
      required int port,
      required Uint8List psk,
      required String identity,
      required Duration timeout,
      required Future<void> cancelled,
    });

Future<void> main(List<String> args) async {
  exitCode = await runK4RemoteCapture(args);
}

Future<int> runK4RemoteCapture(
  List<String> args, {
  IOSink? output,
  IOSink? errors,
  Map<String, String>? environment,
  Future<String?> Function()? readPassword,
  K4RemoteCaptureConnect? connect,
}) async {
  final out = output ?? stdout;
  final err = errors ?? stderr;
  if (args.length == 1 && (args.single == '--help' || args.single == '-h')) {
    out.write(_usage);
    return 0;
  }
  try {
    if (args.isNotEmpty && args.first == 'inspect') {
      if (args.length != 2 || args[1].startsWith('--')) throw const FormatException('inspect requires one capture file');
      final stats = _CaptureStats();
      await for (final chunk in File(args[1]).openRead()) {
        stats.add(Uint8List.fromList(chunk));
      }
      out.writeln(const JsonEncoder.withIndent('  ').convert(stats.toJson()));
      return stats.decoder.diagnostics.panPackets > 0 ? 0 : 1;
    }
    final options = _Options.parse(args);
    final directory = Directory(options.directory);
    if (await FileSystemEntity.type(directory.path, followLinks: false) != FileSystemEntityType.notFound) {
      err.writeln('Output already exists; choose a new directory.');
      return 1;
    }
    if (!await directory.parent.exists()) {
      err.writeln('The output directory parent must exist.');
      return 1;
    }
    final passwordName = options.passwordEnvironment;
    final password = passwordName == null ? await (readPassword ?? () => _readHiddenPassword(err))() : (environment ?? Platform.environment)[passwordName];
    if (password == null || password.isEmpty) {
      err.writeln(
        passwordName == null ? 'A password is required; use a terminal or --password-env.' : 'The named password environment variable is missing or empty.',
      );
      return 1;
    }
    final psk = Uint8List.fromList(utf8.encode(password));
    try {
      return await _capture(options, psk, connect ?? _connectNative, out, err);
    } finally {
      psk.fillRange(0, psk.length, 0);
    }
  } on FormatException catch (error) {
    err.writeln('${error.message}\n\n$_usage');
    return 2;
  } catch (error) {
    // Native or injected transport errors must not accidentally echo credentials.
    err.writeln('K4 remote capture failed (${_failureKind(error)}).');
    return 1;
  }
}

Future<String?> _readHiddenPassword(IOSink err) async {
  if (!stdin.hasTerminal) return null;
  final wasEchoing = stdin.echoMode;
  final answer = Completer<String?>();
  StreamSubscription<String>? input;
  StreamSubscription<ProcessSignal>? interrupt;
  void finish(String? value) {
    if (!answer.isCompleted) answer.complete(value);
  }

  err.write('K4 remote password: ');
  await err.flush();
  try {
    stdin.echoMode = false;
    input = stdin.transform(utf8.decoder).transform(const LineSplitter()).listen(finish, onError: (Object _) => finish(null), onDone: () => finish(null));
    if (!Platform.isWindows) interrupt = ProcessSignal.sigint.watch().listen((_) => finish(null));
    return await answer.future;
  } finally {
    await input?.cancel();
    await interrupt?.cancel();
    stdin.echoMode = wasEchoing;
    err.writeln();
  }
}

class _Options {
  const _Options(this.host, this.directory, this.port, this.seconds, this.maxBytes, this.passwordEnvironment, this.note);

  final String host;
  final String directory;
  final int port;
  final int seconds;
  final int maxBytes;
  final String? passwordEnvironment;
  final String? note;

  factory _Options.parse(List<String> args) {
    if (args.isEmpty || args.first != 'capture') throw const FormatException('Choose capture or inspect');
    const names = {'--host', '--output', '--port', '--seconds', '--max-bytes', '--password-env', '--note'};
    final values = <String, String>{};
    for (var i = 1; i < args.length; i += 2) {
      final key = args[i];
      // Do not repeat unknown arguments: --password=... could contain a secret.
      if (!names.contains(key)) throw const FormatException('Unknown option');
      if (values.containsKey(key)) throw FormatException('Duplicate option: $key');
      if (i + 1 == args.length || args[i + 1].startsWith('--')) throw FormatException('Missing value for $key');
      values[key] = args[i + 1];
    }
    String requiredValue(String key) {
      final value = values[key]?.trim();
      if (value == null || value.isEmpty) throw FormatException('$key is required');
      return value;
    }

    int boundedInt(String key, int fallback, int maximum) {
      final value = values.containsKey(key) ? int.tryParse(values[key]!) : fallback;
      if (value == null || value < 1 || value > maximum) throw FormatException('$key must be an integer from 1 to $maximum');
      return value;
    }

    final passwordEnvironment = values['--password-env'];
    if (passwordEnvironment != null && !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(passwordEnvironment)) {
      throw const FormatException('--password-env must name an environment variable');
    }
    return _Options(
      requiredValue('--host'),
      requiredValue('--output'),
      boundedInt('--port', 9204, 65535),
      boundedInt('--seconds', 20, 300),
      boundedInt('--max-bytes', 32 * 1024 * 1024, 1024 * 1024 * 1024),
      passwordEnvironment,
      values['--note'],
    );
  }
}

Future<K4RemoteCaptureConnection> _connectNative({
  required String host,
  required int port,
  required Uint8List psk,
  required String identity,
  required Duration timeout,
  required Future<void> cancelled,
}) async => _NativeConnection(await PskTlsConnection.connect(host: host, port: port, psk: psk, identity: identity, timeout: timeout, cancelled: cancelled));

class _NativeConnection implements K4RemoteCaptureConnection {
  _NativeConnection(this.connection);
  final PskTlsConnection connection;
  @override
  Stream<Uint8List> get data => connection.data;
  @override
  void send(List<int> bytes) => connection.send(bytes);
  @override
  Future<void> close() => connection.close();
}

String _failureKind(Object error) => switch (error) {
  FileSystemException() => 'file-system',
  SocketException() => 'socket',
  PskTlsException() => error.code,
  _ => 'connection-or-capture',
};

Future<int> _capture(_Options options, Uint8List psk, K4RemoteCaptureConnect connect, IOSink out, IOSink err) async {
  final directory = Directory(options.directory);
  await directory.create();
  final rawFile = File('${directory.path}/capture.bin');
  final framesFile = File('${directory.path}/frames.jsonl');
  final summaryFile = File('${directory.path}/summary.json');
  for (final file in [rawFile, framesFile, summaryFile]) {
    await file.create(exclusive: true);
  }
  final stats = _CaptureStats();
  final startedAt = realNowUtc().toIso8601String();
  final elapsed = Stopwatch();
  final cancelled = Completer<void>();
  String? connectedAt;
  String? stopReason;
  String? failure;
  RandomAccessFile? raw;
  RandomAccessFile? frames;
  K4RemoteCaptureConnection? connection;
  Future<void>? closing;
  Timer? deadline;
  Timer? ping;
  StreamSubscription<ProcessSignal>? interrupt;
  var bytesCaptured = 0;
  var framesCaptured = 0;
  void stop(String reason) {
    stopReason ??= reason;
    if (!cancelled.isCompleted) cancelled.complete();
    closing ??= connection?.close().catchError((Object error) {
      failure ??= _failureKind(error);
      stopReason = 'error';
    });
  }

  try {
    raw = await rawFile.open(mode: FileMode.writeOnly);
    frames = await framesFile.open(mode: FileMode.writeOnly);
    if (!Platform.isWindows) interrupt = ProcessSignal.sigint.watch().listen((_) => stop('interrupted'));
    out.writeln('Connecting to ${options.host}:${options.port}; saving PAN only, up to ${options.seconds}s / ${options.maxBytes} received bytes.');
    final active = await connect(
      host: options.host,
      port: options.port,
      psk: psk,
      identity: '',
      timeout: const Duration(seconds: 5),
      cancelled: cancelled.future,
    );
    connection = active;
    if (stopReason != null) throw const PskTlsCancelledException();
    connectedAt = realNowUtc().toIso8601String();
    elapsed.start();
    deadline = Timer(Duration(seconds: options.seconds), () => stop('duration'));
    active.send(encodeK4RemoteCat(ascii.encode('RDY;')));
    ping = Timer.periodic(const Duration(seconds: 1), (_) {
      if (stopReason != null) return;
      try {
        active.send(encodeK4RemoteCat(ascii.encode('PING;')));
      } catch (error) {
        failure = _failureKind(error);
        stop('error');
      }
    });
    await for (final chunk in active.data) {
      if (stopReason != null) break;
      final elapsedMicros = elapsed.elapsedMicroseconds;
      final remaining = options.maxBytes - stats.bytesReceived;
      final bytes = chunk.length <= remaining ? chunk : Uint8List.sublistView(chunk, 0, remaining);
      for (final packet in stats.add(bytes)) {
        await raw.writeFrom(packet.rawFrame);
        await frames.writeString(
          '${jsonEncode({'offset': bytesCaptured, 'length': packet.rawFrame.length, 'elapsedMicros': elapsedMicros, 'receiver': packet.receiver})}\n',
        );
        bytesCaptured += packet.rawFrame.length;
        framesCaptured++;
      }
      if (stats.bytesReceived == options.maxBytes) {
        stop('byte-limit');
        break;
      }
    }
    stopReason ??= 'remote-closed';
  } catch (error) {
    if (stopReason != 'interrupted') {
      failure = _failureKind(error);
      stopReason = 'error';
    }
  } finally {
    deadline?.cancel();
    ping?.cancel();
    await interrupt?.cancel();
    if (!cancelled.isCompleted) cancelled.complete();
    try {
      await (closing ?? connection?.close());
    } catch (error) {
      failure ??= _failureKind(error);
      stopReason = 'error';
    }
    elapsed.stop();
    for (final file in [raw, frames]) {
      try {
        await file?.close();
      } catch (error) {
        failure ??= _failureKind(error);
        stopReason = 'error';
      }
    }
  }
  final summary = <String, Object?>{
    'format': 'halo-k4-remote-capture-v1',
    'recordedPayloads': ['pan'],
    'host': options.host,
    'port': options.port,
    'startedAtUtc': startedAt,
    'connectedAtUtc': connectedAt,
    'elapsedMillis': elapsed.elapsedMilliseconds,
    'requestedSeconds': options.seconds,
    'maxReceivedBytes': options.maxBytes,
    'userNote': options.note,
    'stopReason': stopReason,
    'error': ?failure,
    'bytesCaptured': bytesCaptured,
    'framesCaptured': framesCaptured,
    ...stats.toJson(),
  };
  await summaryFile.writeAsString('${const JsonEncoder.withIndent('  ').convert(summary)}\n', flush: true);
  out.writeln('$framesCaptured PAN frames saved ($bytesCaptured bytes); ${stats.bytesReceived} bytes received; stopped: $stopReason.');
  out.writeln('Capture: ${directory.absolute.path}');
  if (failure != null) err.writeln('K4 remote capture failed ($failure).');
  if (framesCaptured == 0) err.writeln('No complete PAN frames were saved.');
  return failure == null && framesCaptured > 0 ? 0 : 1;
}

class _CaptureStats {
  final decoder = K4RemoteDecoder();
  final streams = <String, _PanStats>{};
  int bytesReceived = 0;

  List<K4RemotePanPacket> add(Uint8List chunk) {
    bytesReceived += chunk.length;
    final packets = decoder.add(chunk).whereType<K4RemotePanPacket>().toList();
    for (final packet in packets) {
      (streams['${packet.receiver}'] ??= _PanStats()).add(packet);
    }
    return packets;
  }

  Map<String, Object?> toJson() {
    final d = decoder.diagnostics;
    return {
      'bytesReceived': bytesReceived,
      'pendingBytes': decoder.pendingBytes,
      'decoder': {
        'framesDecoded': d.framesDecoded,
        'catPackets': d.catPackets,
        'panPackets': d.panPackets,
        'audioPackets': d.audioPackets,
        'miniPanPackets': d.miniPanPackets,
        'unknownPackets': d.unknownPackets,
        'invalidLengths': d.invalidLengths,
        'invalidFooters': d.invalidFooters,
        'invalidPayloads': d.invalidPayloads,
        'unsupportedVersions': d.unsupportedVersions,
        'discardedBytes': d.discardedBytes,
      },
      'streams': {for (final entry in streams.entries) entry.key: entry.value.toJson()},
    };
  }
}

class _PanStats {
  int frames = 0;
  final metadataSamples = <Map<String, Object?>>[];

  void add(K4RemotePanPacket packet) {
    frames++;
    if (metadataSamples.length < 16) {
      metadataSamples.add({
        'frame': frames,
        'version': packet.version,
        'sequence': packet.sequence,
        'panType': packet.panType,
        'declaredDataLength': packet.declaredDataLength,
        'binCount': packet.levels.length,
        'centerHz': packet.centerHz,
        'sampleRateHz': packet.sampleRateHz,
        'noiseFloorDb': packet.noiseFloorDb,
        'headerHex': packet.headerBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      });
    }
  }

  Map<String, Object?> toJson() => {'frames': frames, 'metadataSamples': metadataSamples};
}
