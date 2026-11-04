// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// dart:ffi binding to the plugin's own library (src/halo_sdr_usb.h). Desktop
// only — the plugin declares macOS, Windows and Linux; on any other platform
// nothing is loaded and nothing opens.
//
// Every call that reaches the hardware runs on a worker isolate of the
// receiver's own: opening one enumerates USB or talks to SDRplay's service,
// starting and stopping one waits on its library's threads, and a rate change
// stops and restarts an Airspy's stream — any of them long enough to stall
// the UI. The worker takes them one at a time, in the order they were asked
// for. Reading the ring is a lock and a copy, made from the calling isolate
// with the same native handle.

import 'dart:async';
import 'dart:ffi';
import 'dart:io' show Directory, File, Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'sdr_usb.dart';

bool get _desktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

DynamicLibrary? _openLibrary() {
  if (!_desktop) return null;
  const envOverride = String.fromEnvironment('HALO_SDR_USB_LIB');
  if (envOverride.isNotEmpty) return DynamicLibrary.open(envOverride);

  if (Platform.isMacOS) {
    try {
      final p = DynamicLibrary.process();
      p.lookup<Void>('hsu_available'); // present only when linked into the app
      return p;
    } on ArgumentError {
      // Not linked in — under `flutter test`.
    }
  }

  // The app's own copy first: the host build the tests use has no USB
  // receivers in it, and one left in the checkout must not stand in for it
  // in a `flutter run` from there.
  try {
    if (Platform.isLinux) return DynamicLibrary.open('libhalo_sdr_usb.so');
    if (Platform.isWindows) return DynamicLibrary.open('halo_sdr_usb.dll');
  } on ArgumentError {
    // Not bundled — under `flutter test`.
  }

  for (final candidate in _hostCandidates()) {
    if (File(candidate).existsSync()) return DynamicLibrary.open(candidate);
  }
  return null;
}

List<String> _hostCandidates() {
  final ext = Platform.isMacOS ? 'dylib' : (Platform.isWindows ? 'dll' : 'so');
  final name = Platform.isWindows ? 'halo_sdr_usb.$ext' : 'libhalo_sdr_usb.$ext';
  // `flutter test` runs with the cwd at whichever package is under test:
  // walk up to the repo root rather than guess one depth.
  final candidates = <String>['build/host/$name'];
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    candidates.add('${dir.path}/packages/halo_sdr_usb/build/host/$name');
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return candidates;
}

/// Opened once in each isolate that uses it: the caller's, and each worker's.
final DynamicLibrary? _lib = _openLibrary();

class _Api {
  final DynamicLibrary lib;
  _Api(this.lib);

  late final available = lib.lookupFunction<Int32 Function(Int32), int Function(int)>('hsu_available');
  late final open = lib
      .lookupFunction<Pointer<Void> Function(Int32, Pointer<Utf8>, Pointer<Utf8>, Int32), Pointer<Void> Function(int, Pointer<Utf8>, Pointer<Utf8>, int)>(
        'hsu_open',
      );
  late final close = lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('hsu_close');
  late final sampleRates = lib.lookupFunction<Int32 Function(Pointer<Void>, Pointer<Uint32>, Int32), int Function(Pointer<Void>, Pointer<Uint32>, int)>(
    'hsu_sample_rates',
  );
  late final minFrequency = lib.lookupFunction<Uint64 Function(Pointer<Void>), int Function(Pointer<Void>)>('hsu_min_frequency');
  late final maxFrequency = lib.lookupFunction<Uint64 Function(Pointer<Void>), int Function(Pointer<Void>)>('hsu_max_frequency');
  late final setSampleRate = lib.lookupFunction<Int32 Function(Pointer<Void>, Uint32), int Function(Pointer<Void>, int)>('hsu_set_sample_rate');
  late final setFrequency = lib.lookupFunction<Int32 Function(Pointer<Void>, Uint64), int Function(Pointer<Void>, int)>('hsu_set_frequency');
  late final setGain = lib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>('hsu_set_gain');
  late final start = lib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('hsu_start');
  late final stop = lib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('hsu_stop');
  late final streaming = lib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('hsu_streaming');
  late final written = lib.lookupFunction<Uint64 Function(Pointer<Void>), int Function(Pointer<Void>)>('hsu_written');
  late final read = lib.lookupFunction<Int32 Function(Pointer<Void>, Uint64, Int32, Pointer<Float>), int Function(Pointer<Void>, int, int, Pointer<Float>)>(
    'hsu_read',
  );
  late final capacity = lib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('hsu_capacity');
  late final openTestTone = lib.lookupFunction<Pointer<Void> Function(Uint32, Int32), Pointer<Void> Function(int, int)>('hsu_open_test_tone');
}

final _Api? _api = switch (_lib) {
  final lib? => _Api(lib),
  null => null,
};

/// Opens [kind]'s receiver with serial number [serial], or the first found
/// when it is blank. Throws [SdrUsbOpenException] with the vendor library's
/// reason when it cannot.
Future<SdrUsbDevice> openSdrUsb(SdrUsbKind kind, {String serial = ''}) => _FfiDevice._open(kind, ['open', kind.code, serial.trim()]);

/// A receiver that is a thread writing a tone [offsetHz] from the centre at
/// [rate]: the binding's tests, which have no hardware, read the ring through
/// it. Only the host test library has it (tool/build_host.sh).
@visibleForTesting
Future<SdrUsbDevice> openSdrUsbTestTone(int rate, int offsetHz) => _FfiDevice._open(SdrUsbKind.airspy, ['tone', rate, offsetHz]);

// ---------------------------------------------------------------------------
// The worker

/// One receiver's worker. Each request is an op, its arguments, then the
/// port its answer goes to; requests are taken one at a time, in order.
void _worker(SendPort ready) {
  final requests = ReceivePort();
  ready.send(requests.sendPort);
  final api = _api;
  Pointer<Void> handle = nullptr;
  requests.listen((message) {
    final request = message as List<Object?>;
    final reply = request.last! as SendPort;
    Object? answer;
    switch (request[0]) {
      case 'open' || 'tone':
        answer = api == null ? const ['unavailable'] : _openHere(api, request, (h) => handle = h);
      case 'rate':
        answer = api!.setSampleRate(handle, request[1]! as int);
      case 'frequency':
        answer = api!.setFrequency(handle, request[1]! as int);
      case 'gain':
        answer = api!.setGain(handle, request[1]! as int);
      case 'start':
        answer = api!.start(handle);
      case 'stop':
        answer = api!.stop(handle);
      case 'close':
        if (handle != nullptr) api!.close(handle);
        handle = nullptr;
        reply.send(0);
        // No port left open: the worker ends.
        requests.close();
        return;
    }
    reply.send(answer);
  });
}

/// Opens the receiver in the worker; the answer is what the calling isolate
/// needs to read it and to describe it.
List<Object?> _openHere(_Api api, List<Object?> request, void Function(Pointer<Void>) keep) {
  final Pointer<Void> handle;
  if (request[0] == 'tone') {
    handle = api.openTestTone(request[1]! as int, request[2]! as int);
  } else {
    final kind = request[1]! as int;
    if (api.available(kind) != 1) return const ['unavailable'];
    const errorSize = 256;
    final error = calloc<Uint8>(errorSize);
    final serial = (request[2]! as String).toNativeUtf8();
    try {
      handle = api.open(kind, serial, error.cast<Utf8>(), errorSize);
      if (handle == nullptr) return ['error', error.cast<Utf8>().toDartString()];
    } finally {
      calloc.free(error);
      calloc.free(serial);
    }
  }
  keep(handle);
  final rates = calloc<Uint32>(16);
  try {
    final count = api.sampleRates(handle, rates, 16);
    return [
      'ok',
      handle.address,
      [for (var i = 0; i < count && i < 16; i++) rates[i]],
      api.minFrequency(handle),
      api.maxFrequency(handle),
    ];
  } finally {
    calloc.free(rates);
  }
}

Future<Object?> _ask(SendPort worker, List<Object?> request) async {
  final reply = ReceivePort();
  worker.send([...request, reply.sendPort]);
  return reply.first;
}

// ---------------------------------------------------------------------------
// The calling isolate's side

class _FfiDevice implements SdrUsbDevice {
  final _Api _calls;
  final SendPort _port;
  Pointer<Void> _handle;

  @override
  final SdrUsbKind kind;
  @override
  final List<int> sampleRates;
  @override
  final int minFrequencyHz;
  @override
  final int maxFrequencyHz;

  /// Reused between reads: a window is a few thousand samples, read many
  /// times a second.
  Pointer<Float> _buffer = nullptr;
  int _bufferSamples = 0;

  /// Commands sent and not yet done, and whether streaming was last asked
  /// for: see [streaming].
  int _pending = 0;
  bool _wantStreaming = false;

  _FfiDevice._(this._calls, this._port, this._handle, this.kind, this.sampleRates, this.minFrequencyHz, this.maxFrequencyHz);

  static Future<SdrUsbDevice> _open(SdrUsbKind kind, List<Object?> request) async {
    final api = _api;
    if (api == null) throw const SdrUsbOpenException('USB receivers are not part of this build', unavailable: true);
    final ready = ReceivePort();
    await Isolate.spawn(_worker, ready.sendPort, debugName: 'sdr-usb ${kind.name}');
    final worker = await ready.first as SendPort;
    final answer = await _ask(worker, request) as List<Object?>;
    if (answer[0] == 'ok') {
      return _FfiDevice._(api, worker, Pointer<Void>.fromAddress(answer[1]! as int), kind, answer[2]! as List<int>, answer[3]! as int, answer[4]! as int);
    }
    await _ask(worker, ['close']);
    final why = answer[0] == 'error' ? answer[1]! as String : '';
    throw SdrUsbOpenException(why.isEmpty ? 'the receiver could not be opened' : why, unavailable: answer[0] == 'unavailable');
  }

  bool get _closed => _handle == nullptr;

  Future<void> _send(List<Object?> request) {
    if (_closed) return Future.value();
    _pending++;
    return _ask(_port, request).whenComplete(() => _pending--);
  }

  @override
  void setSampleRate(int rate) => unawaited(_send(['rate', rate]));

  @override
  void setFrequency(int hz) => unawaited(_send(['frequency', hz]));

  @override
  void setGain(int? step) => unawaited(_send(['gain', step ?? -1]));

  @override
  Future<bool> start() async {
    if (_closed) return false;
    _wantStreaming = true;
    _pending++;
    try {
      return await _ask(_port, ['start']) == 0;
    } finally {
      _pending--;
    }
  }

  @override
  Future<void> stop() {
    _wantStreaming = false;
    return _send(['stop']);
  }

  @override
  SdrUsbStreaming get streaming {
    if (_closed) return SdrUsbStreaming.lost;
    if (_pending > 0) return _wantStreaming ? SdrUsbStreaming.streaming : SdrUsbStreaming.stopped;
    return switch (_calls.streaming(_handle)) {
      1 => SdrUsbStreaming.streaming,
      0 => SdrUsbStreaming.stopped,
      _ => SdrUsbStreaming.lost,
    };
  }

  @override
  int get written => _closed ? 0 : _calls.written(_handle);

  @override
  int get capacity => _closed ? 1 : _calls.capacity(_handle);

  @override
  int read(int from, int count, Float32List into, int at) {
    if (count <= 0 || _closed) return 0;
    if (count > _bufferSamples) {
      if (_buffer != nullptr) calloc.free(_buffer);
      _buffer = calloc<Float>(count * 2);
      _bufferSamples = count;
    }
    final copied = _calls.read(_handle, from, count, _buffer);
    if (copied > 0) into.setRange(at, at + copied * 2, _buffer.asTypedList(copied * 2));
    return copied;
  }

  /// Marked gone here first, so nothing on this side reads a handle the
  /// worker is about to free; the worker frees it after anything queued.
  @override
  Future<void> close() async {
    if (_closed) return;
    _handle = nullptr;
    _wantStreaming = false;
    if (_buffer != nullptr) calloc.free(_buffer);
    _buffer = nullptr;
    _bufferSamples = 0;
    await _ask(_port, ['close']);
  }
}
