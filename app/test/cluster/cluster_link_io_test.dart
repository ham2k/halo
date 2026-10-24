// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cluster/cluster_link_io.dart';

void main() {
  // A dropped connection fails the socket's write side as well as ending its
  // reads; the session hears of the drop through the reads, so the write
  // side's failure must not escape on its own as an uncaught error.
  test('a connection the peer resets ends the reads without an uncaught error', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((peer) {
      peer.listen((_) {}, onError: (_) {});
      Timer(const Duration(milliseconds: 50), peer.destroy);
    });

    final uncaught = <Object>[];
    final ended = Completer<void>();
    await runZonedGuarded(() async {
      final link = await connectClusterLink(server.address.address, server.port, const Duration(seconds: 5));
      link.data.listen((_) {}, onDone: ended.complete, onError: (_) => ended.complete(), cancelOnError: true);
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        link.write(List.filled(1000, 0x41));
      }
      await ended.future.timeout(const Duration(seconds: 5));
      await link.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }, (error, _) => uncaught.add(error));

    expect(ended.isCompleted, isTrue);
    expect(uncaught, isEmpty);
  });
}
