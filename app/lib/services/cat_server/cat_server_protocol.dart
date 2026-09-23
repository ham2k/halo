// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The programs whose rig-control servers HaLo can stand in for, and the
// shape every emulation shares: one [CatServerConnection] per client, fed
// raw bytes and answering through a callback — no sockets, so each codec is
// tested as a pure function of what a real client sends.

import 'dart:typed_data';

import 'cat_server_rig.dart';
import 'flrig_server.dart';
import 'hrd_server.dart';
import 'n3fjp_server.dart';
import 'rigctld_server.dart';

/// Declared in the order the settings list them. [key] is persisted as part
/// of each protocol's settings keys, so renaming one strands its settings.
enum CatServerProtocol {
  rigctld('rigctld', 4532),
  flrig('flrig', 12345),
  hrd('hrd', 7809),
  n3fjp('n3fjp', 1100);

  const CatServerProtocol(this.key, this.defaultPort);

  final String key;

  /// The port the emulated program listens on out of the box, which is
  /// where its clients look first.
  final int defaultPort;
}

/// One client's conversation with an emulated server.
abstract class CatServerConnection {
  /// Bytes as they arrived — any split, including mid-command.
  void receive(Uint8List bytes);

  /// The client has gone; anything the connection subscribed to ends here.
  void close();
}

/// The most a client may send without completing a request. With the
/// network open, anyone on it can connect, and a stream that never ends a
/// request would otherwise grow the buffer holding it without bound. A
/// client past it is dropped: no real request comes near it.
const catServerMaxPending = 64 * 1024;

final _httpRequestLine = RegExp(r'^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|CONNECT|TRACE) \S+ HTTP/', caseSensitive: false);

/// Whether [line], the first a connection sent, opens an HTTP request — a web
/// page reaching for `localhost`, not a radio program. A page can post to any
/// port without asking, and a line protocol would read each line of the body
/// as a command, so a page the operator happens to have open could retune the
/// radio. None of the emulated protocols starts that way.
bool isHttpRequestLine(String line) => _httpRequestLine.hasMatch(line.trimLeft());

/// The failures an operator can do something about, told apart from the
/// system's own wording — which differs by OS, and is in English whatever the
/// app's language.
enum CatServerFailure {
  /// Another program holds the port: usually the very program HaLo is
  /// standing in for, still running.
  portInUse,

  /// The system will not let this app listen there — a port below 1024.
  portDenied,

  /// The system closed the listening socket after it was open.
  stopped,

  /// Anything else; [CatServerStatus.error] says what.
  other,
}

/// A bound server, as the service holds it.
abstract class CatServerListener {
  int get port;

  int get clientCount;

  Future<void> close();
}

/// Where a connection's replies go.
typedef CatServerSend = void Function(List<int> bytes);

/// Hangs up on the client: it asked to quit, or sent what no client of the
/// emulated program would. Bad input from the network is not a bug in HaLo,
/// so a codec hangs up rather than throwing.
typedef CatServerHangUp = void Function();

/// [quit] ends the connection at the client's own request: what was already
/// sent to it is still delivered, where [hangUp] drops it.
CatServerConnection createCatServerConnection(
  CatServerProtocol protocol,
  CatServerRig rig, {
  required CatServerSend send,
  required CatServerHangUp hangUp,
  required void Function() quit,
}) => switch (protocol) {
  CatServerProtocol.rigctld => RigctldServerConnection(rig, send: send, hangUp: hangUp, quit: quit),
  CatServerProtocol.flrig => FlrigServerConnection(rig, send: send, hangUp: hangUp),
  CatServerProtocol.hrd => HrdServerConnection(rig, send: send, hangUp: hangUp),
  CatServerProtocol.n3fjp => N3fjpServerConnection(rig, send: send, hangUp: hangUp),
};
