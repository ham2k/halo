// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The real GS-232 driver on a line the test speaks for: a CatService whose
// rotator answers whatever the test says, when it says it, for widget tests
// of what a rotator's state looks like on screen. cat_integration_test.dart
// owns the protocol over a real socket; this exists so a pane or the editor
// can be shown a connected, stale or refusing controller without one.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/drivers/gs232_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/settings_service.dart';

/// The node type a [FakeGs232Line]'s registry offers.
const fakeGs232TypeKey = 'fake-gs232';

class _Connection implements EquipmentConnection {
  final FakeGs232Line line;
  final _data = StreamController<Uint8List>();
  final _closed = Completer<void>();

  _Connection(this.line);

  @override
  Stream<Uint8List> get data => _data.stream;
  @override
  Future<void> get closed => _closed.future;
  @override
  void send(List<int> bytes) => line.sent.add(ascii.decode(bytes));
  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
    unawaited(_data.close());
  }
}

class _Transport extends EquipmentTransport {
  final FakeGs232Line line;

  _Transport(this.line);

  @override
  String get key => 'fake-line';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async => line._connection = _Connection(line);
}

class FakeGs232Line {
  /// Every command the driver sent, as text.
  final sent = <String>[];

  _Connection? _connection;

  late final _transport = _Transport(this);

  late final EquipmentRegistry registry = EquipmentRegistry(
    models: [
      EquipmentModel(
        key: 'fake-gs232',
        category: kCategoryRotator,
        name: () => 'Fake Rotator',
        variants: [EquipmentVariant(key: fakeGs232TypeKey, driver: const Gs232Driver(), transport: _transport)],
      ),
    ],
    transports: {_transport.key: _transport},
  );

  /// A CatService over this line, marking a node stale after [staleAfter].
  CatService catService(SettingsService settings, {Duration staleAfter = catStaleAfter}) => CatService(settings, registry: registry, staleAfter: staleAfter);

  /// The controller says [text] — `+0123\r\n`, or `?>\r\n` to refuse.
  void say(String text) => _connection!._data.add(Uint8List.fromList(ascii.encode(text)));
}
