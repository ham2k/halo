// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import '../drivers/k4_remote_codec.dart';
import '../drivers/k4_shared_session.dart';
import 'k4_remote_connection.dart';
import 'shared_connection.dart';

export 'shared_connection.dart' show SharedReceiverConnection;

typedef K4SharedSessionFactory =
    K4SharedSession Function({
      required void Function(List<int>) send,
      required Stream<K4RemotePanPacket> pan,
      required Map<String, dynamic> config,
      Stream<K4RemoteAudioPacket>? audio,
      void Function(Uint8List envelope)? sendAudio,
    });

typedef K4ReceiverConnection = SharedReceiverConnection;

/// One authenticated connection per explicitly paired K4, its Main and Sub
/// each a lease on it.
class K4SharedConnectionPool extends SharedConnectionPool {
  K4SharedConnectionPool({K4SharedSessionFactory? createSession, super.onSend, super.onReceive})
    : super(
        perReceiverKeys: const {'receiver'},
        createOwner: (connection, send, config) => (createSession ?? K4SharedSession.new)(
          send: send,
          pan: switch (connection) {
            K4RemoteConnection() => connection.pan,
            _ => const Stream<K4RemotePanPacket>.empty(),
          },
          config: config,
          audio: connection is K4RemoteConnection ? connection.audio : null,
          // Kept out of the traffic log, which records CAT. A closed
          // connection refuses it ([K4RemoteConnection.sendAudio]).
          sendAudio: connection is K4RemoteConnection ? connection.sendAudio : null,
        ),
      );
}
