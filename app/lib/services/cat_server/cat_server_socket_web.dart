// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A browser cannot listen on a socket. Throws, per the transports'
// convention: a silent no-op would show a server as running that no client
// can ever reach.

import 'cat_server_protocol.dart';
import 'cat_server_rig.dart';

Future<CatServerListener> bindCatServer(
  CatServerProtocol protocol,
  CatServerRig rig, {
  required int port,
  required bool lan,
  void Function()? onClientsChanged,
  void Function()? onStopped,
}) async => throw UnsupportedError('A CAT server cannot listen in a web browser');

/// Nothing binds here, so nothing fails in a way worth telling apart.
CatServerFailure? catServerFailureOf(Object error) => null;
