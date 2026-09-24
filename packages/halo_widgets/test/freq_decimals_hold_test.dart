// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// FreqDecimalsHold lives in halo_core, which has no fake clock to drive its
// Timer; testWidgets supplies one here.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

void main() {
  testWidgets('a rig re-reporting the same frequency is settled, not turning', (tester) async {
    // The station panel rebuilds a rig's row on every CAT change, the
    // unchanged frequency included; if each rebuild restarted the wait, a
    // polled rig would never shed its zeros.
    var settles = 0;
    final hold = FreqDecimalsHold(onSettle: () => settles++);
    hold.note(14074.9);
    hold.note(14075);
    expect(hold.decimals, 1);

    await tester.pump(FreqDecimalsHold.settleDelay - const Duration(seconds: 1));
    hold.note(14075);
    await tester.pump(const Duration(seconds: 1));
    expect(hold.decimals, 0);
    expect(settles, 1, reason: 'the owner repaints only when the floor drops');
    hold.dispose();
  });

  testWidgets('whole-kHz steps hold nothing and start no timer', (tester) async {
    var settles = 0;
    final hold = FreqDecimalsHold(onSettle: () => settles++);
    hold.note(14074);
    hold.note(14075);
    expect(hold.decimals, 0);
    await tester.pump(FreqDecimalsHold.settleDelay);
    expect(settles, 0, reason: 'a repaint with nothing to trim is wasted');
    hold.dispose();
  });
}
