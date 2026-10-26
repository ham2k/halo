// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat_server/cat_server_protocol.dart';
import 'package:ham2k_logger/services/cat_server/cat_server_rig.dart';
import 'package:ham2k_logger/services/cat_server/cat_server_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_cat_server_rig.dart';
import '../support/fake_clock.dart';

class _FakeListener implements CatServerListener {
  final CatServerProtocol protocol;
  @override
  final int port;
  final bool lan;
  bool closed = false;

  /// When set, a close takes until it completes — a socket still releasing
  /// its port.
  final Completer<void>? closeGate;

  _FakeListener(this.protocol, this.port, this.lan, this.closeGate);

  @override
  int get clientCount => 0;

  @override
  Future<void> close() async {
    await closeGate?.future;
    closed = true;
  }
}

void main() {
  late SettingsService settings;
  late CatServerService service;
  late FakeCatServerRig rig;
  late List<_FakeListener> bound;

  /// When set, the next bind waits on it — a bind still in flight.
  Completer<void>? holdBind;

  /// When set, every bind fails with it.
  Object? bindError;

  /// What the last bind was told to call if the system closes its socket.
  void Function()? stopped;

  var bindCalls = 0;

  /// When set, each listener bound from now on closes only when it completes.
  Completer<void>? closeGate;

  Future<CatServerListener> fakeBind(
    CatServerProtocol protocol,
    CatServerRig rig, {
    required int port,
    required bool lan,
    void Function()? onClientsChanged,
    void Function()? onStopped,
  }) async {
    bindCalls++;
    stopped = onStopped;
    final hold = holdBind;
    holdBind = null;
    if (hold != null) await hold.future;
    if (bindError != null) throw bindError!;
    // As an OS does: a port a listener still holds cannot be bound again.
    if (bound.any((l) => l.port == port && !l.closed)) throw StateError('address in use: $port');
    final listener = _FakeListener(protocol, port, lan, closeGate);
    bound.add(listener);
    return listener;
  }

  Map<String, Object> prefsWith(Map<String, dynamic> radio, {bool server = true}) => {
    'experiments': jsonEncode({
      if (server) 'server': {'enabled': true},
    }),
    'settings.radio': jsonEncode(radio),
  };

  Future<void> start({
    Map<String, dynamic> radio = const {},
    bool server = true,
    bool disposeAfter = true,
    Duration rebindDelay = Duration.zero,
    Duration retryDelay = const Duration(hours: 1),
  }) async {
    SharedPreferences.setMockInitialValues(prefsWith(radio, server: server));
    settings = SettingsService(await SharedPreferences.getInstance());
    rig = FakeCatServerRig();
    service = CatServerService(settings: settings, rig: rig, bind: fakeBind, rebindDelay: rebindDelay, retryDelay: retryDelay);
    if (disposeAfter) addTearDown(service.dispose);
    await pumpEventQueue();
  }

  Future<void> set(Map<String, dynamic> changes) async {
    await settings.updateSettingsGroup(SettingsService.radioGroup, changes);
    await pumpEventQueue();
  }

  const protocolKey = CatServerSettings.protocolKey;
  final rigctldPort = CatServerSettings.portKey(CatServerProtocol.rigctld);

  setUp(() {
    bound = [];
    holdBind = null;
    bindError = null;
    closeGate = null;
    stopped = null;
    bindCalls = 0;
  });

  test('binds nothing while the protocol is Disabled', () async {
    await start(radio: {protocolKey: CatServerSettings.off});
    expect(bound, isEmpty);
    expect(service.status.protocol, isNull);
  });

  test('a protocol picked listens on its program\'s own port, this computer only', () async {
    await start();
    await set({protocolKey: 'rigctld'});
    expect(bound.single.protocol, CatServerProtocol.rigctld);
    expect(bound.single.port, 4532);
    expect(bound.single.lan, isFalse, reason: 'the network is opened only when asked for');
    expect(service.status.port, 4532);
  });

  test('binds nothing without its own experiment, even with a protocol picked', () async {
    await start(radio: {protocolKey: 'rigctld'}, server: false);
    expect(bound, isEmpty);

    await settings.setExperimentEnabled('server', true);
    await pumpEventQueue();
    expect(bound.single.protocol, CatServerProtocol.rigctld);
  });

  test('a protocol left on starts with the service', () async {
    await start(radio: {protocolKey: 'flrig'});
    expect(bound.single.protocol, CatServerProtocol.flrig);
  });

  test('one server at a time: picking another program closes the first', () async {
    await start(radio: {protocolKey: 'rigctld'});
    await set({protocolKey: 'n3fjp'});
    expect(bound.map((l) => (l.protocol, l.closed)), [(CatServerProtocol.rigctld, true), (CatServerProtocol.n3fjp, false)]);
  });

  test('a new port, or opening to the network, closes the old socket and binds again', () async {
    await start(radio: {protocolKey: 'rigctld'});
    await set({rigctldPort: 4533});
    await set({CatServerSettings.openAccessKey: true});
    expect(bound.map((l) => (l.port, l.lan, l.closed)), [(4532, false, true), (4533, false, true), (4533, true, false)]);
  });

  test("withdrawing 'Allow apps to transmit' drops a client's key at once, and changes no socket", () async {
    await start(radio: {protocolKey: 'rigctld', CatServerSettings.allowTransmitKey: true});
    await set({'smartVfoSnap': true});
    expect(rig.clientPttReleases, 0);

    await set({CatServerSettings.allowTransmitKey: false});
    expect(rig.clientPttReleases, greaterThan(0), reason: 'unticking it is how the operator stops a transmission they did not start');
    expect(bound, hasLength(1));
  });

  test('an unrelated setting changing does not rebind a running server', () async {
    await start(radio: {protocolKey: 'rigctld'});
    await set({'smartVfoSnap': true});
    expect(bound, hasLength(1));
  });

  test('a port being typed binds once, after the typing stops', () {
    // The port field saves on every keystroke. Binding each prefix would open
    // 4, 45 and 453 on the way to 4533.
    fakeAsync((async) {
      SharedPreferences.setMockInitialValues(prefsWith({protocolKey: 'rigctld'}));
      late SettingsService settings;
      SharedPreferences.getInstance().then((prefs) => settings = SettingsService(prefs));
      async.flushMicrotasks();
      final service = CatServerService(settings: settings, rig: FakeCatServerRig(), bind: fakeBind);
      async.flushMicrotasks();
      for (final typed in [4, 45, 453, 4533]) {
        settings.setSettingValue(SettingsService.radioGroup, rigctldPort, typed);
        async.elapse(const Duration(milliseconds: 200));
      }
      async.elapse(const Duration(seconds: 1));
      expect(bound.map((l) => l.port), [4532, 4533]);
      service.dispose();
    });
  });

  test('a port that is not one falls back to the program\'s default rather than failing', () async {
    await start(radio: {protocolKey: 'rigctld', rigctldPort: 99999});
    expect(bound.single.port, 4532);
  });

  test('Disabled, or the experiment turned off, closes the socket', () async {
    await start(radio: {protocolKey: 'hrd'});
    await set({protocolKey: CatServerSettings.off});
    expect(bound.single.closed, isTrue);

    await set({protocolKey: 'hrd'});
    await settings.setExperimentEnabled('server', false);
    await pumpEventQueue();
    expect(bound, hasLength(2));
    expect(bound.every((l) => l.closed), isTrue);
  });

  test('a failed bind is shown, and retried when the port changes but not on every settings write', () async {
    bindError = StateError('port held');
    await start(radio: {protocolKey: 'rigctld'});
    expect(service.status.error, contains('port held'));
    expect(service.status.protocol, CatServerProtocol.rigctld, reason: 'the status names what failed');
    expect(service.status.listening, isFalse);

    bindError = null;
    await set({'smartVfoSnap': true});
    expect(bound, isEmpty, reason: 'retrying a held port on every unrelated write only repeats the failure');

    await set({rigctldPort: 4600});
    expect(bound.single.port, 4600);
    expect(service.status.error, isNull);
  });

  test('a bind that lands after the server was turned off is closed, not kept', () async {
    await start();
    final hold = holdBind = Completer<void>();
    await set({protocolKey: 'rigctld'});
    await set({protocolKey: CatServerSettings.off});
    hold.complete();
    await pumpEventQueue();
    expect(bound.single.closed, isTrue);
    expect(service.status.listening, isFalse);
  });

  test('the radio coming and going is announced, since the status says whether there is one', () async {
    await start(radio: {protocolKey: 'rigctld'});
    var notified = 0;
    service.addListener(() => notified++);
    rig.available = false;
    rig.move(freqKHz: 7000);
    expect(service.radioAvailable, isFalse);
    expect(notified, 1);
    rig.move(freqKHz: 7001);
    expect(notified, 1, reason: 'a VFO move with no change in availability is not news to the status');
  });

  test('a rebind on the same port waits for the old socket to let go of it', () async {
    // Opening to the network keeps the port and changes the address, so the
    // new bind asks for a port the old socket still holds until its close
    // lands. Binding without waiting fails, and a failure is not retried on
    // its own until the retry timer comes round.
    final gate = closeGate = Completer<void>();
    await start(radio: {protocolKey: 'rigctld'});
    await set({CatServerSettings.openAccessKey: true});
    expect(bound, hasLength(1), reason: 'not bound again while the first socket is still closing');
    gate.complete();
    await pumpEventQueue();
    expect(bound.map((l) => (l.lan, l.closed)), [(false, true), (true, false)]);
    expect(service.status.error, isNull);
  });

  test(
    'a failed bind is tried again on its own — the program holding the port may have quit',
    () => runOnFakeClock((_) async {
      bindError = const SocketException('port held');
      await start(radio: {protocolKey: 'rigctld'}, retryDelay: const Duration(milliseconds: 20));
      expect(service.status.error, isNotNull);
      bindError = null;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await pumpEventQueue();
      expect(bound.single.port, 4532);
      expect(service.status.listening, isTrue);
      expect(service.status.error, isNull);
    }),
  );

  test('a bind overtaken by settings that changed and changed back is not mistaken for the current one', () async {
    await start();
    final firstBind = holdBind = Completer<void>();
    await set({protocolKey: 'rigctld'});
    await set({protocolKey: 'flrig'});
    await set({protocolKey: 'rigctld'});
    firstBind.complete();
    await pumpEventQueue();
    final open = bound.where((l) => !l.closed);
    expect(open.map((l) => l.protocol), [CatServerProtocol.rigctld], reason: 'one server, and no socket leaked');
    expect(service.status.listening, isTrue);
    expect(service.status.error, isNull);
  });

  test('while a change waits to be applied, the status says what is coming rather than Off', () async {
    await start(rebindDelay: const Duration(hours: 1));
    await set({protocolKey: 'rigctld'});
    expect(service.status.protocol, CatServerProtocol.rigctld);
    expect(service.status.attemptedPort, 4532);
    expect(service.status.listening, isFalse);
  });

  test('a failure names the port that was tried, not the one being typed', () async {
    bindError = StateError('port held');
    await start(radio: {protocolKey: 'rigctld'});
    expect(service.status.attemptedPort, 4532);
    expect(service.status.error, contains('port held'));
  });

  test('a retry falling due while a port is being typed waits for the typing, and binds only the finished port', () {
    fakeAsync((async) {
      SharedPreferences.setMockInitialValues(prefsWith({protocolKey: 'rigctld'}));
      late SettingsService settings;
      SharedPreferences.getInstance().then((prefs) => settings = SettingsService(prefs));
      async.flushMicrotasks();
      bindError = StateError('port held');
      final service = CatServerService(settings: settings, rig: FakeCatServerRig(), bind: fakeBind, retryDelay: const Duration(seconds: 10));
      async.flushMicrotasks();
      expect(service.status.error, isNotNull);
      bindError = null;

      async.elapse(const Duration(milliseconds: 9500));
      settings.setSettingValue(SettingsService.radioGroup, rigctldPort, 45);
      async.elapse(const Duration(milliseconds: 600)); // the retry falls due here
      expect(bound, isEmpty, reason: 'the half-typed 45 is not bound');
      settings.setSettingValue(SettingsService.radioGroup, rigctldPort, 4533);
      async.elapse(const Duration(seconds: 2));
      expect(bound.map((l) => l.port), [4533]);
      service.dispose();
      async.elapse(const Duration(minutes: 1));
      expect(bound, hasLength(1), reason: 'no stray timer binds anything later');
    });
  });

  test('while Disabled, an unrelated settings write is not news to anyone listening', () async {
    await start(radio: {protocolKey: CatServerSettings.off});
    var notified = 0;
    service.addListener(() => notified++);
    await set({'smartVfoSnap': true});
    await set({'avoidZeroBeat': true});
    expect(notified, 0);
  });

  group('whenCatServerWanted', () {
    test('starts nothing while the experiment is off, then starts once it comes on over a protocol already picked', () async {
      SharedPreferences.setMockInitialValues(prefsWith({protocolKey: 'rigctld'}, server: false));
      final settings = SettingsService(await SharedPreferences.getInstance());
      var starts = 0;
      whenCatServerWanted(settings, () => starts++);
      expect(starts, 0);
      await settings.setExperimentEnabled('server', true);
      expect(starts, 1);
      await settings.setSettingValue(SettingsService.radioGroup, 'smartVfoSnap', true);
      expect(starts, 1, reason: 'once started, the service follows the settings itself');
    });

    test('starts at once for a server left on', () async {
      SharedPreferences.setMockInitialValues(prefsWith({protocolKey: 'flrig'}));
      final settings = SettingsService(await SharedPreferences.getInstance());
      var starts = 0;
      whenCatServerWanted(settings, () => starts++);
      expect(starts, 1);
    });
  });

  test('a port another program holds is told apart from other failures, whatever the OS calls it', () async {
    for (final errno in [48, 98, 10048]) {
      bound.clear();
      bindError = SocketException('Failed to create server socket', osError: OSError('Address already in use', errno));
      await start(radio: {protocolKey: 'rigctld'});
      expect(service.status.failure, CatServerFailure.portInUse, reason: 'errno $errno');
    }
    bindError = SocketException('Failed to create server socket', osError: const OSError('Permission denied', 13));
    await start(radio: {protocolKey: 'rigctld'});
    expect(service.status.failure, CatServerFailure.portDenied);
  });

  test(
    'a retry keeps the failure on show until it has an answer, rather than flickering to "starting"',
    () => runOnFakeClock((_) async {
      bindError = const SocketException('port held');
      await start(radio: {protocolKey: 'rigctld'}, retryDelay: const Duration(milliseconds: 20));
      bindError = null;
      holdBind = Completer<void>();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bindCalls, 2, reason: 'the retry is in flight');
      expect(service.status.error, isNotNull);
      holdBind?.complete();
    }),
  );

  test('a bind that fails for a reason other than the network is shown but not retried', () async {
    // Retrying a bug every few seconds only buries it; it goes to error
    // reporting instead, and the status still says the server is not up.
    bindError = StateError('a bug, not a held port');
    await start(radio: {protocolKey: 'rigctld'}, retryDelay: const Duration(milliseconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(bindCalls, 1);
    expect(service.status.failure, CatServerFailure.other);
    expect(service.status.listening, isFalse);
  });

  test(
    'a listening socket the system closes is shown as stopped, and tried again',
    () => runOnFakeClock((_) async {
      await start(radio: {protocolKey: 'rigctld'}, retryDelay: const Duration(milliseconds: 20));
      expect(service.status.listening, isTrue);
      bound.single.closed = true; // the system took it
      stopped!();
      expect(service.status.failure, CatServerFailure.stopped);
      expect(service.status.listening, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bound, hasLength(2));
      expect(service.status.listening, isTrue);
    }),
  );

  test('disposing the service closes the server', () async {
    await start(radio: {protocolKey: 'rigctld'}, disposeAfter: false);
    service.dispose();
    await pumpEventQueue();
    expect(bound.single.closed, isTrue);
  });
}
