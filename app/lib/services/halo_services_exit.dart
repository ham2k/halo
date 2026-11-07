// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What each connection-holding service does to let go when the app quits;
// `closeConnectionsForExit` (services/app_exit.dart) runs them all.

part of 'halo_services.dart';

mixin _ExitClosers {
  /// Filled as the lazy services that hold a connection are built, so the
  /// quit closes what exists and never builds a service only to close it.
  final Map<String, Future<void> Function()> exitClosers = {};

  /// Peer sync, once something has built it. A phone's `detached` pauses it
  /// (services/app_exit.dart) and must not build it to do so.
  PeerService? peerServiceIfBuilt;

  /// Registers [close] as how [service] lets go on the way out, under [name]
  /// (what a failed close is reported as), and hands [service] back.
  T closedOnExit<T>(String name, T service, FutureOr<void> Function(T service) close) {
    exitClosers[name] = () async => close(service);
    return service;
  }
}
