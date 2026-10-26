// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Runs the emulated CAT server the operator picked, if any, and follows the
// settings as they change (docs/design/cat.md § CAT server). One at a time:
// the operator chooses which program HaLo stands in for.
//
// App-wide, like the inbound QSO listener: a server stays up whichever
// operation is open, since the programs connecting to it are following the
// radio, not the log.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/experiments.dart';
import '../error_reporting_service.dart';
import '../settings_service.dart';
import 'cat_server_protocol.dart';
import 'cat_server_rig.dart';
import 'cat_server_socket.dart';

/// Whether the CAT server is offered at all.
bool catServerExperimentEnabled(SettingsService settings) => settings.experimentEnabled(kCatServerExperiment);

/// Calls [start] once the settings ask for a CAT server — now, or on the
/// first settings change that does — and stops watching then. The service
/// follows the settings once it exists; until it does, this is what notices.
void whenCatServerWanted(SettingsService settings, void Function() start) {
  void check() {
    if (!catServerExperimentEnabled(settings) || CatServerSettings.protocol(settings) == null) return;
    settings.removeListener(check);
    start();
  }

  settings.addListener(check);
  check();
}

/// Where the server's settings live, in the Radio group: the protocol, a
/// port for each program, and whether access is open.
abstract final class CatServerSettings {
  /// The emulated program, by [CatServerProtocol.key], or [off].
  static const protocolKey = 'catServerProtocol';

  /// [protocol]'s own port. Per program, so switching to another and back
  /// — or turning the server off and on — keeps a port chosen because the
  /// real program still holds the usual one.
  static String portKey(CatServerProtocol protocol) => 'catServer${protocol.key[0].toUpperCase()}${protocol.key.substring(1)}Port';

  /// The program whose port [key] is, or null for any other key.
  static CatServerProtocol? protocolForPortKey(String key) => CatServerProtocol.values.where((p) => portKey(p) == key).firstOrNull;

  static const openAccessKey = 'catServerOpenAccess';

  static const allowTransmitKey = 'catServerAllowTransmit';

  static const off = 'off';

  /// The program being emulated, or null when the server is off.
  static CatServerProtocol? protocol(SettingsService settings) {
    final key = settings.settingValue(SettingsService.radioGroup, protocolKey);
    return CatServerProtocol.values.where((p) => p.key == key).firstOrNull;
  }

  /// The configured port, or [protocol]'s default for anything that is not
  /// one — a stored value the field would refuse today must not leave the
  /// server unbindable.
  static int port(SettingsService settings, CatServerProtocol protocol) {
    final raw = settings.settingValue(SettingsService.radioGroup, portKey(protocol));
    final port = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}'.trim());
    return port != null && isValidPort(port) ? port : protocol.defaultPort;
  }

  static bool isValidPort(int port) => port >= 1 && port <= 65535;

  /// Whether other computers on the network may connect. Off unless the
  /// operator turns it on: until then, only this computer can.
  static bool openAccess(SettingsService settings) => settings.settingValue(SettingsService.radioGroup, openAccessKey) == true;

  /// Whether a client may key the Main VFO radio's PTT. Off unless the
  /// operator turns it on: it puts their transmitter on the air.
  static bool allowTransmit(SettingsService settings) => settings.settingValue(SettingsService.radioGroup, allowTransmitKey) == true;
}

/// The server as the settings show it.
@immutable
class CatServerStatus {
  /// The program being emulated, null while the server is off.
  final CatServerProtocol? protocol;

  /// The port being listened on, null while not listening.
  final int? port;

  /// The port being bound, or the one that could not be — which is not
  /// necessarily the one in the settings, since a change waits a moment
  /// before it is tried.
  final int? attemptedPort;

  final int clients;

  /// Why the server is not listening although it is switched on, as the
  /// system put it.
  final String? error;

  /// What [error] amounts to, where that is something the operator can act
  /// on without reading it.
  final CatServerFailure? failure;

  const CatServerStatus({this.protocol, this.port, this.attemptedPort, this.clients = 0, this.error, this.failure});

  bool get listening => port != null;
}

typedef CatServerBinder =
    Future<CatServerListener> Function(
      CatServerProtocol protocol,
      CatServerRig rig, {
      required int port,
      required bool lan,
      void Function()? onClientsChanged,
      void Function()? onStopped,
    });

/// Runs the one emulated server the settings ask for, if any.
class CatServerService extends ChangeNotifier {
  final SettingsService settings;
  final CatServerRig rig;

  /// The socket layer, swapped for a fake in tests that exercise the
  /// settings wiring rather than the wire.
  final CatServerBinder bind;

  /// How long a changed setting waits before the server rebinds. The port
  /// field saves as it is typed, and without the wait every prefix of the
  /// port being typed — `4`, `45`, `453` — is a socket opened and closed.
  final Duration rebindDelay;

  /// How long a failed bind waits before it is tried again. The usual cause
  /// is the program being replaced still holding the port, and closing it is
  /// something the operator does elsewhere — nothing here would otherwise
  /// notice.
  final Duration retryDelay;

  CatServerService({
    required this.settings,
    required this.rig,
    this.bind = bindCatServer,
    this.rebindDelay = const Duration(milliseconds: 800),
    this.retryDelay = const Duration(seconds: 10),
  }) {
    settings.addListener(_onSettingsChanged);
    rig.changes.addListener(_onRigChanged);
    _available = rig.available;
    // At launch there is nothing to wait out.
    _apply();
  }

  /// The attempt that owns the server: binding, or bound. Compared by
  /// identity — two attempts at the same settings are still two sockets.
  _Attempt? _current;
  ({_Wanted wanted, String error, CatServerFailure failure})? _failure;

  /// The previous socket's close, which the next bind waits for: the same
  /// port rebound while the old socket still holds it fails.
  Future<void> _closing = Future.value();

  Timer? _rebind;
  Timer? _retry;
  bool _available = false;
  bool _disposed = false;

  CatServerStatus get status {
    final current = _current;
    final failure = _failure;
    // A change waiting out the typing delay is what the status says is coming
    // — unless a server is still listening, or a failure is still standing,
    // which remain true until the change is tried.
    final pending = _rebind == null ? null : _wanted;
    if (pending != null && current?.listener == null && failure == null) {
      return CatServerStatus(protocol: pending.protocol, attemptedPort: pending.port);
    }
    // A retry of a failed bind is not news until it succeeds or fails again:
    // flipping to "starting" and back every few seconds says nothing.
    if (failure != null && current?.listener == null) {
      return CatServerStatus(protocol: failure.wanted.protocol, attemptedPort: failure.wanted.port, error: failure.error, failure: failure.failure);
    }
    if (current != null) {
      return CatServerStatus(
        protocol: current.wanted.protocol,
        port: current.listener?.port,
        attemptedPort: current.wanted.port,
        clients: current.listener?.clientCount ?? 0,
      );
    }
    return const CatServerStatus();
  }

  /// Behind its own experiment as well as CAT's, and never on web, where
  /// nothing can listen.
  bool get _allowed => !kIsWeb && catServerExperimentEnabled(settings);

  _Wanted? get _wanted {
    final protocol = CatServerSettings.protocol(settings);
    if (!_allowed || protocol == null) return null;
    return _Wanted(protocol, CatServerSettings.port(settings, protocol), CatServerSettings.openAccess(settings));
  }

  /// Whether a Main VFO radio is there to answer for — part of what the
  /// status says, so a change is announced.
  bool get radioAvailable => _available;

  void _onRigChanged() {
    final available = rig.available;
    if (available == _available) return;
    _available = available;
    if (!_disposed) notifyListeners();
  }

  void _onSettingsChanged() {
    // Unticking the permission is how the operator stops a client's
    // transmission, so it takes effect at once.
    if (!CatServerSettings.allowTransmit(settings)) rig.releaseClientPtt();
    final wanted = _wanted;
    // Switching off is not delayed: a server the operator turned off must not
    // go on answering for most of a second.
    if (wanted == null) {
      _apply();
      return;
    }
    if (_rebind == null && (wanted == _current?.wanted || wanted == _failure?.wanted)) return;
    _rebind?.cancel();
    _rebind = Timer(rebindDelay, _apply);
    notifyListeners();
  }

  void _apply({bool retrying = false}) {
    final wasPending = _rebind != null;
    _rebind?.cancel();
    _rebind = null;
    if (_disposed) return;
    final wanted = _wanted;
    final settled =
        (wanted != null && wanted == _current?.wanted) ||
        // A failed bind is tried again on its timer, or when what it was
        // asked to do changes — not on every unrelated settings write.
        (!retrying && wanted != null && wanted == _failure?.wanted) ||
        (wanted == null && _current == null && _failure == null);
    if (settled) {
      // Nothing moved, so there is nothing to announce — unless the status
      // was saying a change was coming, and must now say what is.
      if (wasPending) notifyListeners();
      return;
    }
    // A retry keeps the failure it is retrying on show until it has an
    // answer; anything else starts from a clean slate.
    _stop(keepFailure: retrying);
    if (wanted != null) {
      final attempt = _current = _Attempt(wanted);
      unawaited(_start(attempt));
    }
    notifyListeners();
  }

  Future<void> _start(_Attempt attempt) async {
    final wanted = attempt.wanted;
    await _closing;
    if (_disposed || _current != attempt) return;
    final CatServerListener listener;
    try {
      listener = await bind(
        wanted.protocol,
        rig,
        port: wanted.port,
        lan: wanted.network,
        onClientsChanged: () {
          if (!_disposed) notifyListeners();
        },
        onStopped: () => _onStopped(attempt),
      );
    } catch (e, st) {
      if (_disposed || _current != attempt) return;
      debugPrint('[cat-server] ${wanted.protocol.key} could not listen on ${wanted.port}: $e');
      // Only what the network says is the operator's to see and wait out.
      // Anything else is a bug here: it is still shown, since the server is
      // not listening, but reported, and not retried.
      final failure = catServerFailureOf(e);
      final network = failure != null;
      if (!network) ErrorReportingService.report(e, st, context: 'CatServer:${wanted.protocol.key}:bind');
      _current = null;
      _failure = (wanted: wanted, error: e.toString(), failure: failure ?? CatServerFailure.other);
      if (network) _scheduleRetry();
      if (!_disposed) notifyListeners();
      return;
    }
    // Settings moved on while the bind was in flight: this one is no longer
    // wanted, and whatever replaced it owns the slot.
    if (_disposed || _current != attempt) {
      _closing = _closeReporting(listener);
      return;
    }
    attempt.listener = listener;
    _failure = null;
    debugPrint('[cat-server] ${wanted.protocol.key} listening on ${wanted.network ? 'all interfaces' : 'loopback'}:${listener.port}');
    notifyListeners();
  }

  /// The system closed [attempt]'s socket under it. Treated as a failed bind:
  /// shown, and retried, since whatever took the interface away may bring it
  /// back.
  void _onStopped(_Attempt attempt) {
    if (_disposed || _current != attempt) return;
    debugPrint('[cat-server] ${attempt.wanted.protocol.key} stopped listening');
    _stop();
    _failure = (wanted: attempt.wanted, error: 'stopped listening', failure: CatServerFailure.stopped);
    _scheduleRetry();
    notifyListeners();
  }

  Future<void> _closeReporting(CatServerListener listener) =>
      listener.close().then((_) {}, onError: (Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'CatServer:close'));

  void _scheduleRetry() {
    _retry = Timer(retryDelay, () {
      _retry = null;
      // A change is waiting out the typing delay: the retry follows it rather
      // than binding whatever half-typed port the settings hold right now.
      if (_rebind != null) return _scheduleRetry();
      _apply(retrying: true);
    });
  }

  void _stop({bool keepFailure = false}) {
    _retry?.cancel();
    _retry = null;
    final listener = _current?.listener;
    _current = null;
    if (!keepFailure) _failure = null;
    if (listener != null) _closing = _closeReporting(listener);
  }

  @override
  void dispose() {
    _disposed = true;
    _rebind?.cancel();
    settings.removeListener(_onSettingsChanged);
    rig.changes.removeListener(_onRigChanged);
    _stop();
    super.dispose();
  }
}

@immutable
class _Wanted {
  final CatServerProtocol protocol;
  final int port;
  final bool network;

  const _Wanted(this.protocol, this.port, this.network);

  @override
  bool operator ==(Object other) => other is _Wanted && other.protocol == protocol && other.port == port && other.network == network;

  @override
  int get hashCode => Object.hash(protocol, port, network);
}

/// One bind of [wanted], and the socket it produced once it has.
class _Attempt {
  final _Wanted wanted;
  CatServerListener? listener;

  _Attempt(this.wanted);
}
