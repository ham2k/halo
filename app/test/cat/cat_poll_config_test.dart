// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The idle poll interval an operator can set on any polling radio or bridge.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/adaptive_poller.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/ft891_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/hrd_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/poll_config.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';

class _QuietSink implements EquipmentSink {
  @override
  void send(List<int> bytes) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('idlePollIntervalFor', () {
    test('blank means the driver default', () {
      expect(idlePollIntervalFor(const {}), kPollSlow);
      expect(idlePollIntervalFor(const {pollIntervalConfigKey: ''}), kPollSlow);
      expect(idlePollIntervalFor(const {}, fallback: const Duration(seconds: 5)), const Duration(seconds: 5));
    });

    test('a number, or the string a text box hands back, is milliseconds', () {
      expect(idlePollIntervalFor(const {pollIntervalConfigKey: 10000}), const Duration(seconds: 10));
      expect(idlePollIntervalFor(const {pollIntervalConfigKey: '750'}), const Duration(milliseconds: 750));
    });

    test('a stored value outside the bounds falls back rather than hammering the radio', () {
      // A config edited by hand, or stored under looser bounds, must not
      // turn into a 1 ms poll — or into a Duration that throws.
      expect(idlePollIntervalFor(const {pollIntervalConfigKey: 1}), kPollSlow);
      expect(idlePollIntervalFor(const {pollIntervalConfigKey: 3600000}), kPollSlow);
      expect(idlePollIntervalFor(const {pollIntervalConfigKey: 'NaN'}), kPollSlow);
    });
  });

  test('the slowest idle poll still hears from the radio well inside the staleness window', () {
    // For most polling drivers the poll is the only proof of life, so an
    // idle interval near catStaleAfter flags a healthy radio as not
    // responding between answers — and one lost answer trips it.
    expect(maxIdlePollInterval * 3, lessThanOrEqualTo(catStaleAfter));
    expect(validatePollInterval(maxIdlePollInterval.inMilliseconds), isNull);
    expect(validatePollInterval(maxIdlePollInterval.inMilliseconds + 1), isNotNull);
  });

  test('the editor refuses what the connection would ignore', () {
    expect(validatePollInterval(null), isNull);
    expect(validatePollInterval(''), isNull);
    expect(validatePollInterval(5000), isNull);
    expect(validatePollInterval(100), isNotNull, reason: 'faster than a moving radio is polled');
    expect(validatePollInterval(120000), isNotNull);
    expect(validatePollInterval(1500.5), isNotNull);
  });

  test('a radio polls its idle radio at the interval its node sets, and still speeds up when it moves', () {
    final session = Ft891Session(_QuietSink(), config: const {telemetryIntervalConfigKey: 600000, pollIntervalConfigKey: 10000})..startUpdates();
    expect(session.pollInterval, const Duration(seconds: 10));
    session.handleData(Uint8List.fromList('FA014074000;'.codeUnits));
    session.handleData(Uint8List.fromList('FA014080000;'.codeUnits));
    expect(session.pollInterval, kPollFast, reason: 'the setting is the idle rate, not a fixed one');
    session.teardown();
  });

  test('a bridge reads the setting through its driver', () {
    // A session that drops its config polls at the default with no error.
    final session = const HrdDriver().createSession(_QuietSink(), const {pollIntervalConfigKey: 10000}) as HrdSession;
    expect(session.pollInterval, const Duration(seconds: 10));
  });

  test('every driver that offers the field accepts a valid value and refuses a bad one', () {
    // The field is shown by the driver, so its validator is the driver's: one
    // that offers the box and forgets the rule accepts a 1 ms poll.
    final registry = EquipmentRegistry();
    final offering = [
      for (final type in registry.types)
        if (type.configElements().any((e) => e['key'] == pollIntervalConfigKey)) type,
    ];
    expect(offering, isNotEmpty);
    for (final type in offering) {
      expect(type.driver.validateField(pollIntervalConfigKey, 5000, const {}), isNull, reason: type.key);
      expect(type.driver.validateField(pollIntervalConfigKey, 1, const {}), isNotNull, reason: type.key);
    }
  });
}
