// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_remote_codec.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/k4_remote_connection.dart';

class _SecureConnection implements EquipmentConnection {
  final _incoming = StreamController<Uint8List>(sync: true);
  final _closed = Completer<void>();
  final sent = <List<int>>[];

  @override
  Stream<Uint8List> get data => _incoming.stream;
  @override
  Future<void> get closed => _closed.future;
  @override
  void send(List<int> bytes) => sent.add(List.of(bytes));

  void receive(List<int> bytes) => _incoming.add(Uint8List.fromList(bytes));

  @override
  Future<void> close() async {
    if (_closed.isCompleted) return;
    _closed.complete();
    await _incoming.close();
  }
}

Uint8List _envelope(List<int> payload) {
  final bytes = Uint8List(payload.length + 12);
  bytes.setRange(0, 4, [0xfe, 0xfd, 0xfc, 0xfb]);
  ByteData.sublistView(bytes).setUint32(4, payload.length, Endian.big);
  bytes.setRange(8, bytes.length - 4, payload);
  bytes.setRange(bytes.length - 4, bytes.length, [0xfb, 0xfc, 0xfd, 0xfe]);
  return bytes;
}

// One Main/Sub sample pair, framed independently of the transmit writer.
Uint8List _audio(int left, int right) {
  final payload = Uint8List.fromList([1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0]);
  ByteData.sublistView(payload)
    ..setInt16(7, left, Endian.little)
    ..setInt16(9, right, Endian.little);
  return _envelope(payload);
}

Uint8List _pan() {
  final payload = Uint8List(29);
  payload[0] = 2;
  final data = ByteData.sublistView(payload);
  data.setInt64(11, 14045000, Endian.little);
  data.setInt32(19, 48, Endian.little);
  payload.setRange(27, 29, [80, 90]);
  return _envelope(payload);
}

void main() {
  test('listening to raw audio preserves CAT and PAN and sends no format or transmit commands', () {
    fakeAsync((async) {
      final secure = _SecureConnection();
      final connection = K4RemoteConnection(secure);
      final cat = <int>[], pan = <K4RemotePanPacket>[], audio = <K4RemoteAudioPacket>[];
      final catSubscription = connection.data.listen(cat.addAll);
      final panSubscription = connection.pan.listen(pan.add);
      secure.receive(_audio(100, -100));
      final audioSubscription = connection.audio.listen(audio.add);
      expect(audio, isEmpty, reason: 'subscribing must not replay blocks received without a listener');
      final wire = [
        ..._envelope([0, 0, 0, ...'FA00014045000;'.codeUnits]),
        ..._pan(),
        ..._audio(32767, -32768),
      ];
      for (var offset = 0; offset < wire.length; offset += 9) {
        secure.receive(wire.sublist(offset, (offset + 9).clamp(0, wire.length)));
      }
      expect(String.fromCharCodes(cat), 'FA00014045000;');
      expect(pan.single.centerHz, 14045000);
      expect(audio.single.samples, [32767 / 32768, -1]);
      expect(secure.sent, isEmpty);
      unawaited(audioSubscription.cancel());
      unawaited(panSubscription.cancel());
      unawaited(catSubscription.cancel());
      unawaited(connection.close());
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('removing the last audio listener drops blocks until another listener attaches', () {
    fakeAsync((async) {
      final secure = _SecureConnection();
      final connection = K4RemoteConnection(secure);
      final cat = connection.data.listen((_) {});
      final firstBlocks = <K4RemoteAudioPacket>[], secondBlocks = <K4RemoteAudioPacket>[];
      final first = connection.audio.listen(firstBlocks.add);
      final second = connection.audio.listen(secondBlocks.add);
      secure.receive(_audio(256, -256));
      unawaited(first.cancel());
      secure.receive(_audio(512, -512));
      expect(firstBlocks, hasLength(1));
      expect(secondBlocks, hasLength(2));
      unawaited(second.cancel());
      secure.receive(_audio(768, -768));
      final nextBlocks = <K4RemoteAudioPacket>[];
      final next = connection.audio.listen(nextBlocks.add);
      secure.receive(_audio(1024, -1024));
      expect(nextBlocks.single.samples, [1 / 32, -1 / 32]);
      unawaited(next.cancel());
      unawaited(cat.cancel());
      unawaited(connection.close());
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('disconnecting in an audio callback closes every stream and drops later coalesced packets', () {
    fakeAsync((async) {
      final secure = _SecureConnection();
      final connection = K4RemoteConnection(secure);
      var catDone = false, audioDone = false, panDone = false;
      final cat = <int>[];
      connection.data.listen(cat.addAll, onDone: () => catDone = true);
      connection.pan.listen((_) {}, onDone: () => panDone = true);
      connection.audio.listen((_) => unawaited(connection.close()), onDone: () => audioDone = true);
      secure.receive([
        ..._audio(1, -1),
        ..._envelope([0, 0, 0, ...'TX;'.codeUnits]),
      ]);
      async.flushMicrotasks();
      expect(cat, isEmpty);
      expect((catDone, audioDone, panDone), (true, true, true));
      expect(async.pendingTimers, isEmpty);
    });
  });
}
