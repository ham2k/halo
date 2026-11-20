// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio's ears in the computer's mixer, when it is SO2R's switcher
// (docs/design/cat.md § The SO2R switcher): what each route's gains become.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/audio/radio_audio.dart';
import 'package:ham2k_logger/services/cat/so2r_audio.dart';

void main() {
  test('each ear takes the radio\'s level, and an ear it is not in takes none', () {
    final ears = <String, So2rEar>{'a': So2rEar.left, 'b': So2rEar.right, 'c': So2rEar.muted, 'd': So2rEar.both};
    final audio = RadioAudio(outputs: () => const [], level: (radio) => 0.5, volume: () => 0.8, ear: (radio) => ears[radio]);
    expect(audio.gainsFor('a'), (0.4, 0.0));
    expect(audio.gainsFor('b'), (0.0, 0.4));
    expect(audio.gainsFor('c'), (0.0, 0.0));
    expect(audio.gainsFor('d'), (0.4, 0.4));
    // With no switcher, a radio is in both ears at its level.
    expect(audio.gainsFor('none'), (0.4, 0.4));
  });
}
