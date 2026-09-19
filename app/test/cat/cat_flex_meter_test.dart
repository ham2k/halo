// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/flex_meter_codec.dart';

Uint8List packet({int id = 21, double dbm = -93.5, int extra = 0}) {
  final data = ByteData(20 + extra);
  data.setUint32(0, 0x38000000 | ((20 + extra) ~/ 4) | (extra == 12 ? 0x00500000 : 0));
  data.setUint32(4, 0x80000000);
  data.setUint32(8, 0x001c2d);
  data.setUint32(12, 0x534c8002);
  data.setUint16(16 + extra, id);
  data.setInt16(18 + extra, (dbm * 128).round());
  return data.buffer.asUint8List();
}

void main() {
  test('decodes signed dBm only for the configured slice LEVEL meter', () {
    final codec = FlexMeterCodec(0);
    expect(codec.signal(packet()), isNull);
    codec.metadata('21.src=SLC#21.num=0#21.nam=LEVEL#21.unit=dBm#22.src=SLC#22.num=1#22.nam=LEVEL#22.unit=dBm#');
    expect(codec.signal(packet()), -93.5);
    expect(codec.signal(packet(id: 22)), isNull);
    expect(codec.signal(packet(extra: 12)), -93.5);
    codec.metadata('21 removed');
    expect(codec.signal(packet()), isNull);
    codec.metadata('21.src=SLC#21.num=0#21.nam=LEVEL#21.unit=dBFS#');
    expect(codec.signal(packet()), isNull);
  });
  // Every report that differs from the last notifies every CatService
  // listener. At the radio's packet rate and 1/128 dB that is a rebuild storm
  // for the whole session, whether or not anything shows the meter.
  test('the LEVEL stream is reported in whole dB, a few times a second', () {
    final throttle = FlexSignalThrottle();
    expect(throttle.accept(-93.4, 1000), -93);
    expect(throttle.accept(-80.0, 1010), isNull);
    expect(throttle.accept(-80.0, 1000 + FlexSignalThrottle.intervalMillis - 1), isNull);
    // A steady signal is reported again — that is what moves its timestamp —
    // and as the SAME number, which is what CatService does not notify for.
    expect(throttle.accept(-93.2, 1000 + FlexSignalThrottle.intervalMillis), -93);
    expect(throttle.accept(-92.9, 1000 + FlexSignalThrottle.intervalMillis * 2), -93);
    expect(throttle.accept(-60.0, 900), -60, reason: 'a clock stepping backwards must not silence the meter');
  });

  test('ignores truncated packets, other classes and non-Flex data', () {
    final codec = FlexMeterCodec(0)..metadata('21.src=SLC#21.num=0#21.nam=LEVEL#21.unit=dBm#');
    for (var length = 0; length < 20; length++) {
      expect(codec.signal(packet().sublist(0, length)), isNull);
    }
    final other = packet();
    other[15] = 3;
    expect(codec.signal(other), isNull);
    other[15] = 2;
    other[11] = 0;
    expect(codec.signal(other), isNull);
  });
}
