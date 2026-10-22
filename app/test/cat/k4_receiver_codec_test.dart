// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_receiver_codec.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

void main() {
  test('receiver writes preserve Elecraft dollar targets and DATA submodes', () {
    expect(buildK4ReceiverFrequency(K4Receiver.main, 14074), 'FA00014074000;');
    expect(buildK4ReceiverFrequency(K4Receiver.sub, 7045), 'FB00007045000;');
    expect(buildK4ReceiverFrequency(K4Receiver.sub, double.nan), isNull);
    expect(buildK4ReceiverFrequency(K4Receiver.sub, 100000000), isNull);
    expect(buildK4ReceiverMode(K4Receiver.sub, 'FT8'), r'MD$6;DT$0;');
    expect(buildK4ReceiverMode(K4Receiver.sub, 'RTTY-R'), r'MD$9;DT$2;');
    expect(buildK4ReceiverMode(K4Receiver.sub, 'CW-R'), r'MD$7;');
    expect(buildK4ReceiverMode(K4Receiver.sub, 'invented'), isNull);
  });

  test('only high-resolution signal replies have dBm semantics', () {
    expect(parseK4Signal('H-073'), (receiver: K4Receiver.main, dbm: -73));
    expect(parseK4Signal(r'H$-099'), (receiver: K4Receiver.sub, dbm: -99));
    for (final invalid in ['0021', r'$0021', 'H-73', 'H-999', 'H+999']) {
      expect(parseK4Signal(invalid), isNull);
    }
  });

  test('filters reflect sideband and omit undocumented DATA or shifted CW geometry', () {
    Passband? filter(String mode, {int center = 1500, int width = 2700}) => k4ReceiverPassband(mode: mode, widthHz: width, centerHz: center, cwPitchHz: 600);
    expect(filter('USB'), const Passband(150, 2850));
    expect(filter('LSB'), const Passband(-2850, -150));
    expect(filter('CW', center: 600, width: 500), const Passband(-250, 250));
    expect(filter('CW', center: 650, width: 500), isNull);
    expect(filter('DATA-USB'), isNull);
  });
}
