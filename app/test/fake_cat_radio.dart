// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The smallest CatService that reports a CONNECTED radio, for tests about
// behaviour that keys off connection state rather than about CAT itself.
//
// A real CatService only ever reaches `connected` through hardware, so a
// widget test of anything gated on it needs a transport that says yes.
// Deliberately minimal: no command recording, no gated/refusing variants, no
// radio-reports-back path — cat_vfo_wiring_test.dart owns those, and owns
// testing the CAT layer. This exists so a caller can write
// `services.cat.stateFor(...)` is connected and get on with its own subject.

import 'dart:async';
import 'dart:typed_data';

import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

class _AlwaysOpenConnection implements EquipmentConnection {
  final _data = StreamController<Uint8List>();
  final _closed = Completer<void>();

  @override
  Stream<Uint8List> get data => _data.stream;
  @override
  Future<void> get closed => _closed.future;
  @override
  void send(List<int> bytes) {}
  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
    unawaited(_data.close());
  }
}

class _AlwaysConnectingTransport extends EquipmentTransport {
  @override
  String get key => 'fake';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async =>
      _AlwaysOpenConnection();
}

class _SilentSession implements EquipmentSession {
  @override
  void handleData(Uint8List chunk) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  void setFrequency(double freqKHz) {}
  @override
  void setMode(String mode) {}
  @override
  void setPower(num watts) {}
  @override
  Duration? get expectedUpdateInterval => null;
  @override
  void teardown() {}
}

class _SilentDriver extends EquipmentDriver {
  @override
  String get key => 'fake-driver';
  @override
  String get name => 'Fake Radio';
  @override
  bool get hardwareVerified => false;
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => _SilentSession();
}

EquipmentRegistry _fakeRegistry() {
  final transport = _AlwaysConnectingTransport();
  return EquipmentRegistry(
    models: [
      EquipmentModel(
        key: 'fake',
        category: kCategoryTransceiver,
        name: () => 'Fake Radio',
        variants: [EquipmentVariant(key: 'fake-type', driver: _SilentDriver(), transport: transport)],
      ),
    ],
    transports: {'fake': transport},
  );
}

/// A CatService over a transport that always connects. Nothing is connected
/// yet — call [connectFakeRadio1] for that.
CatService fakeCatService(SettingsService settings, RadioService radio) =>
    CatService(settings, radio: radio, registry: _fakeRegistry());

/// Adds a fake transceiver to [cat], connects it, and makes it `radio1` — the
/// state a feature gated on "a radio is connected" is waiting for.
Future<void> connectFakeRadio1(CatService cat) async {
  final node = await cat.addNode(typeKey: 'fake-type', config: {'host': 'radio.local'});
  await cat.connect(node.uuid);
  await cat.setRadio1(node.uuid);
}
