// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/iq_audio.dart';
import 'package:ham2k_logger/services/cat/transports/none_transport.dart';

class _ActionDriver extends KenwoodDriver {
  final void Function() requested;
  final Completer<EquipmentActionResult?> result;
  const _ActionDriver(this.requested, this.result);

  @override
  Future<EquipmentActionResult?>? runAction(String actionKey, String method, Map<String, dynamic> state) {
    if (actionKey != 'driver-access') return null;
    requested();
    return result.future;
  }
}

class _ActionTransport extends NoneTransport {
  final void Function() requested;
  const _ActionTransport(this.requested);

  @override
  Future<EquipmentActionResult?> runAction(String actionKey, String method, Map<String, dynamic> state) {
    requested();
    return Future.value(const EquipmentActionResult(fieldUpdates: {'port': 'granted-device'}));
  }
}

void main() {
  test('driver actions and transport fallback start before the caller loses its gesture', () async {
    var inGesture = true;
    var driverCalls = 0;
    var transportCalls = 0;
    final answer = Completer<EquipmentActionResult?>();
    final driver = _ActionDriver(() {
      expect(inGesture, isTrue, reason: 'audio access must run before the action call yields');
      driverCalls++;
    }, answer);
    final transport = _ActionTransport(() {
      expect(inGesture, isTrue, reason: 'trying the driver must not consume a serial-device permission gesture');
      transportCalls++;
    });
    final type = EquipmentType(kx3Model, EquipmentVariant(key: 'gesture-test', driver: driver, transport: transport));
    final handled = type.runAction('driver-access', 'prepare', {});
    inGesture = false;
    expect(driverCalls, 1);
    expect(transportCalls, 0);
    answer.complete(null);
    expect(await handled, isNull);
    expect(transportCalls, 0, reason: 'cancelling a handled driver prompt must not open an unrelated transport prompt');

    inGesture = true;
    final fallback = type.runAction('transport-access', 'prepare', {});
    inGesture = false;
    expect(transportCalls, 1);
    expect((await fallback)?.fieldUpdates, {'port': 'granted-device'});
  });

  testWidgets('explicit input refresh reports a native backend failure without invoking a transport action', (tester) async {
    const channel = MethodChannel('com.llfbandit.record/messages');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'create' || 'dispose' => null,
        'hasPermission' => true,
        'listInputDevices' => throw PlatformException(code: 'record', message: 'iq_audio_unsupported', details: 'Audio backend is unavailable'),
        _ => throw StateError('Refreshing devices must not call ${call.method}'),
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    var transportCalls = 0;
    final type = EquipmentType(kx3Model, EquipmentVariant(key: 'refresh-test', driver: const Kx3Driver(), transport: _ActionTransport(() => transportCalls++)));
    final result = await type.runAction(kx3IqAccessActionKey, 'prepare', const {kx3IqDeviceKey: 'saved-usb-input', kx3IqRateKey: 48000});
    expect(
      result?.message,
      t.settings.station.kx3IqUnsupported,
      reason: 'an explicit refresh must expose a usable failure message instead of claiming success',
    );
    expect(result?.fieldUpdates, isNull, reason: 'a failed refresh must not overwrite the saved selection or signal a successful options rebuild');
    expect(transportCalls, 0, reason: 'a handled audio failure must not launch an unrelated CAT permission prompt');
    expect(calls, contains('listInputDevices'));
    expect(calls.last, 'dispose');
    expect(calls, isNot(contains('startStream')));
    expect(tester.takeException(), isNull);
  }, skip: !iqAudioSupported);

  for (final initiallyEmpty in [false, true]) {
    testWidgets('saving an unplugged I/Q input preserves its ID with ${initiallyEmpty ? 'no' : 'other'} available inputs', (tester) async {
      const driver = Kx3Driver();
      const channel = MethodChannel('com.llfbandit.record/messages');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      var inputs = <Map<String, dynamic>>[
        if (!initiallyEmpty) {'id': 'built-in-microphone', 'label': 'Built-in Microphone'},
      ];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'create' || 'dispose' => null,
          'listInputDevices' => inputs,
          _ => throw StateError('Opening input settings must not call ${call.method}'),
        };
      });
      addTearDown(() async {
        inputs = [];
        await driver.prepareConfigElements();
        messenger.setMockMethodCallHandler(channel, null);
      });

      await driver.prepareConfigElements();
      expect(calls, ['create', 'listInputDevices', 'dispose']);
      final inputField = driver.configElements().singleWhere((field) => field['key'] == kx3IqDeviceKey);
      final options = (inputField['options'] as List).cast<Map<String, dynamic>>();
      expect(options.where((option) => option['isAction'] != true).map((option) => option['value']), [if (!initiallyEmpty) 'built-in-microphone']);

      // A nonempty list exposes the trap: a normal dropdown clears an absent
      // saved value during build, even though the operator changes nothing.
      const savedDevice = 'unplugged-usb-stereo-input';
      Map<String, dynamic>? submitted;
      var elements = [inputField];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => FormRenderer(
                formDefinition: {'elements': elements},
                initialState: const {kx3IqEnabledKey: true, kx3IqDeviceKey: savedDevice},
                validator: (key, value, state) async => driver.validateField(key, value, state),
                onAction: (key, method, state) async {
                  final result = await driver.runAction(key, method, state);
                  return FormActionResult(
                    fieldUpdates: result?.fieldUpdates,
                    elements: [driver.configElements().singleWhere((field) => field['key'] == kx3IqDeviceKey)],
                  );
                },
                onElementsChanged: (updated) => setState(() => elements = updated),
                onSubmit: (values) => submitted = values,
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(savedDevice), findsOneWidget);
      if (!iqAudioNeedsAccess) {
        inputs = [
          {'id': 'another-usb-input', 'label': 'Another USB input'},
        ];
        await tester.tap(find.text(savedDevice));
        await tester.pumpAndSettle();
        final refresh = options.singleWhere((option) => option['isAction'] == true)['label'] as String;
        await tester.tap(find.text(refresh));
        await tester.pumpAndSettle();
        expect(find.text(savedDevice), findsOneWidget, reason: 'refreshing available inputs must preserve the selected disconnected device');
        expect(calls, ['create', 'listInputDevices', 'dispose', 'create', 'listInputDevices', 'dispose']);
        inputs = [];
        await tester.tap(find.text(savedDevice));
        await tester.pumpAndSettle();
        await tester.tap(find.text(refresh));
        await tester.pumpAndSettle();
        expect(find.text(savedDevice), findsOneWidget, reason: 'an action-only input list must not clear the saved device');
        expect(calls.where((method) => method == 'listInputDevices').length, 3);
      }
      final callsBeforeSave = List<String>.of(calls);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(submitted?[kx3IqDeviceKey], savedDevice, reason: 'saving unrelated settings must not discard the selected USB input while it is unplugged');
      expect(calls, callsBeforeSave, reason: 'rendering and saving input choices must not open the microphone');
    }, skip: !iqAudioSupported);
  }
}
