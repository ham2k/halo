// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The hidden locales change only words. A placeholder whose name changed
// case is a different parameter to slang, and a `**` or a line break spelled
// out in Morse renders as noise.

import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_hidden_locales.dart';

void main() {
  test('QRO and QRP change the case of the words only', () {
    const source = 'Run `rigctl -l` on ${r'$port'} — see **https://stash.ham2k.net/Help** or [Docs](https://ham2k.com/Docs)';
    expect(toQro(source), 'RUN `rigctl -l` ON ${r'$port'} — SEE **https://stash.ham2k.net/Help** OR [DOCS](https://ham2k.com/Docs)');
    expect(toQrp('Slice ${r'${letter}'} IS ON'), 'slice ${r'${letter}'} is on');
  });

  test('CW spells letters, separates words, and keeps the rest', () {
    expect(toMorse(r'Pos: $number'), '·——· ——— ··· ———··· / \$number');
    expect(toMorse('SOS'), '··· ——— ···');
  });

  test('CW keeps markdown and line breaks where they were', () {
    expect(toMorse('A **B**\n\nE'), '·— / ** —··· **\n\n·');
    expect(toMorse('A \n E'), '·—\n·');
  });

  test('CW keeps characters that have no code', () {
    expect(toMorse('É…'), 'É …');
  });
}
