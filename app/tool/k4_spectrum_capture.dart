// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show realNowUtc;
import 'package:ham2k_logger/services/cat/drivers/k4_spectrum_codec.dart';

const _usage = '''K4 LAN spectrum capture (receive-only; no CAT or stream commands).

  mise run k4:capture -- capture --host <host> --output <new-directory>
      [--port 9201] [--seconds 20] [--max-bytes 33554432] [--note <text>]
  mise run k4:capture -- inspect <capture.bin>

Capture writes capture.bin, chunks.jsonl, and summary.json. The output directory
must not exist; its parent must exist. Duration is 1–300 seconds, measured after
connection; connection timeout is 5 seconds. The byte limit is 1–1073741824.
Exit 0 means at least one candidate-format frame decoded, not hardware validation.
Exit 1 means no decoded frames or an I/O failure; exit 2 means invalid arguments.
''';

Future<void> main(List<String> args) async {
  exitCode = await runK4SpectrumCapture(args);
}

Future<int> runK4SpectrumCapture(List<String> args, {IOSink? output, IOSink? errors}) async {
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
      return stats.decoder.diagnostics.framesDecoded > 0 ? 0 : 1;
    }
    return await _capture(_Options.parse(args), out, err);
  } on FormatException catch (error) {
    err.writeln('${error.message}\n\n$_usage');
    return 2;
  } on FileSystemException catch (error) {
    err.writeln('K4 capture: $error');
    return 1;
  } on SocketException catch (error) {
    err.writeln('K4 capture: $error');
    return 1;
  }
}

class _Options {
  const _Options(this.host, this.directory, this.port, this.seconds, this.maxBytes, this.note);

  final String host;
  final String directory;
  final int port;
  final int seconds;
  final int maxBytes;
  final String? note;

  factory _Options.parse(List<String> args) {
    if (args.isEmpty || args.first != 'capture') throw const FormatException('Choose capture or inspect');
    const names = {'--host', '--output', '--port', '--seconds', '--max-bytes', '--note'};
    final values = <String, String>{};
    for (var i = 1; i < args.length; i += 2) {
      final key = args[i];
      if (!names.contains(key)) throw FormatException('Unknown option: $key');
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

    return _Options(
      requiredValue('--host'),
      requiredValue('--output'),
      boundedInt('--port', 9201, 65535),
      boundedInt('--seconds', 20, 300),
      boundedInt('--max-bytes', 32 * 1024 * 1024, 1024 * 1024 * 1024),
      values['--note'],
    );
  }
}

Future<int> _capture(_Options options, IOSink out, IOSink err) async {
  final directory = Directory(options.directory);
  if (await FileSystemEntity.type(directory.path, followLinks: false) != FileSystemEntityType.notFound) {
    throw FileSystemException('Output already exists; choose a new directory', directory.path);
  }
  await directory.create();
  final rawFile = File('${directory.path}/capture.bin');
  final chunksFile = File('${directory.path}/chunks.jsonl');
  final summaryFile = File('${directory.path}/summary.json');
  // Exclusive creation prevents a retry or another capture from truncating data.
  await rawFile.create(exclusive: true);
  await chunksFile.create(exclusive: true);
  await summaryFile.create(exclusive: true);

  final stats = _CaptureStats();
  final startedAt = realNowUtc().toIso8601String();
  String? connectedAt;
  final elapsed = Stopwatch();
  RandomAccessFile? raw;
  RandomAccessFile? chunks;
  Socket? socket;
  Timer? deadline;
  StreamSubscription<ProcessSignal>? interrupt;
  String? stopReason;
  String? failure;
  try {
    raw = await rawFile.open(mode: FileMode.writeOnly);
    chunks = await chunksFile.open(mode: FileMode.writeOnly);
    out.writeln('Connecting to ${options.host}:${options.port}; receive-only, up to ${options.seconds}s / ${options.maxBytes} bytes.');
    final connection = await Socket.connect(options.host, options.port, timeout: const Duration(seconds: 5));
    socket = connection;
    connectedAt = realNowUtc().toIso8601String();
    elapsed.start();
    void stop(String reason) {
      stopReason ??= reason;
      connection.destroy();
    }

    deadline = Timer(Duration(seconds: options.seconds), () => stop('duration'));
    if (!Platform.isWindows) interrupt = ProcessSignal.sigint.watch().listen((_) => stop('interrupted'));
    await for (final chunk in connection) {
      if (stopReason != null) break;
      final receivedAt = elapsed.elapsedMicroseconds;
      final remaining = options.maxBytes - stats.bytesCaptured;
      final bytes = chunk.length <= remaining ? chunk : Uint8List.sublistView(chunk, 0, remaining);
      final offset = stats.bytesCaptured;
      await raw.writeFrom(bytes);
      stats.add(bytes);
      await chunks.writeString('${jsonEncode({'offset': offset, 'length': bytes.length, 'elapsedMicros': receivedAt})}\n');
      if (stats.bytesCaptured == options.maxBytes) {
        stop('byte-limit');
        break;
      }
    }
    stopReason ??= 'remote-closed';
  } catch (error) {
    failure = error.toString();
    stopReason = 'error';
  } finally {
    deadline?.cancel();
    await interrupt?.cancel();
    socket?.destroy();
    elapsed.stop();
    for (final file in [raw, chunks]) {
      try {
        await file?.close();
      } catch (error) {
        failure ??= error.toString();
        stopReason = 'error';
      }
    }
  }
  final summary = <String, Object?>{
    'format': 'halo-k4-spectrum-capture-v1',
    'host': options.host,
    'port': options.port,
    'startedAtUtc': startedAt,
    'connectedAtUtc': connectedAt,
    'elapsedMillis': elapsed.elapsedMilliseconds,
    'requestedSeconds': options.seconds,
    'maxBytes': options.maxBytes,
    'userNote': options.note,
    'stopReason': stopReason,
    'error': ?failure,
    ...stats.toJson(),
  };
  await summaryFile.writeAsString('${const JsonEncoder.withIndent('  ').convert(summary)}\n', flush: true);
  out.writeln('${stats.bytesCaptured} bytes; ${stats.decoder.diagnostics.framesDecoded} decoded frames; stopped: $stopReason.');
  out.writeln('Capture: ${directory.absolute.path}');
  if (failure != null) err.writeln('K4 capture: $failure');
  if (stats.decoder.diagnostics.framesDecoded == 0) err.writeln('No candidate-format frames decoded. Keep the raw capture for protocol inspection.');
  return failure == null && stats.decoder.diagnostics.framesDecoded > 0 ? 0 : 1;
}

class _CaptureStats {
  final decoder = K4SpectrumDecoder();
  final streams = <String, _PanStats>{};
  int bytesCaptured = 0;
  int sequenceDiscontinuities = 0;
  int? _previousSequence;

  void add(Uint8List chunk) {
    bytesCaptured += chunk.length;
    for (final packet in decoder.add(chunk)) {
      final previous = _previousSequence;
      if (previous != null && packet.sequence != (previous + 1) % 256) sequenceDiscontinuities++;
      _previousSequence = packet.sequence;
      (streams[packet.panId] ??= _PanStats()).add(packet);
    }
  }

  Map<String, Object?> toJson() {
    final diagnostics = decoder.diagnostics;
    return {
      'bytesCaptured': bytesCaptured,
      'pendingBytes': decoder.pendingBytes,
      'decoder': {
        'framesDecoded': diagnostics.framesDecoded,
        'discardedBytes': diagnostics.discardedBytes,
        'invalidHeaders': diagnostics.invalidHeaders,
        'invalidPayloadChecksums': diagnostics.invalidPayloadChecksums,
        'unsupportedVersions': diagnostics.unsupportedVersions,
        'unsupportedPanIds': diagnostics.unsupportedPanIds,
      },
      // Until sequence scope is known, neither counter means packet loss.
      'sequenceDiscontinuities': sequenceDiscontinuities,
      'streams': {for (final entry in streams.entries) entry.key: entry.value.toJson()},
    };
  }
}

class _PanStats {
  int frames = 0;
  int sequenceDiscontinuities = 0;
  int? _previousSequence;
  double? minLevelDb;
  double? maxLevelDb;
  int? minCenterHz;
  int? maxCenterHz;
  int? minSampleRateHz;
  int? maxSampleRateHz;
  final metadataSamples = <Map<String, Object?>>[];
  Map<String, Object?>? _lastMetadata;

  void add(K4SpectrumPacket packet) {
    frames++;
    final previous = _previousSequence;
    if (previous != null && packet.sequence != (previous + 1) % 256) sequenceDiscontinuities++;
    _previousSequence = packet.sequence;
    minCenterHz = minCenterHz == null || packet.centerHz < minCenterHz! ? packet.centerHz : minCenterHz;
    maxCenterHz = maxCenterHz == null || packet.centerHz > maxCenterHz! ? packet.centerHz : maxCenterHz;
    minSampleRateHz = minSampleRateHz == null || packet.sampleRateHz < minSampleRateHz! ? packet.sampleRateHz : minSampleRateHz;
    maxSampleRateHz = maxSampleRateHz == null || packet.sampleRateHz > maxSampleRateHz! ? packet.sampleRateHz : maxSampleRateHz;
    for (final level in packet.levels) {
      if (minLevelDb == null || level < minLevelDb!) minLevelDb = level;
      if (maxLevelDb == null || level > maxLevelDb!) maxLevelDb = level;
    }
    final metadata = <String, Object?>{
      'frame': frames,
      'sequence': packet.sequence,
      'centerHz': packet.centerHz,
      'sampleRateHz': packet.sampleRateHz,
      'noiseFloorDb': packet.noiseFloorDb,
      'headerHex': packet.headerBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
    };
    // Bound summaries even when the dial or AutoRef changes every frame.
    final last = _lastMetadata;
    if (metadataSamples.length < 16 &&
        (last == null || last['centerHz'] != packet.centerHz || last['sampleRateHz'] != packet.sampleRateHz || last['noiseFloorDb'] != packet.noiseFloorDb)) {
      metadataSamples.add(metadata);
    }
    _lastMetadata = metadata;
  }

  Map<String, Object?> toJson() => {
    'frames': frames,
    'sequenceDiscontinuities': sequenceDiscontinuities,
    'minLevelDb': minLevelDb,
    'maxLevelDb': maxLevelDb,
    'minCenterHz': minCenterHz,
    'maxCenterHz': maxCenterHz,
    'minSampleRateHz': minSampleRateHz,
    'maxSampleRateHz': maxSampleRateHz,
    'metadataSamples': metadataSamples,
    'lastMetadata': _lastMetadata,
  };
}
