// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';

SpectrumCapabilities _capabilities({
  List<int> spansHz = const [1000, 2500],
  double refMinDb = -30,
  double refMaxDb = 30,
  double refStepDb = 1,
  Set<SpectrumMode> modes = const {SpectrumMode.center, SpectrumMode.fixed},
  Set<SpectrumSpeed> speeds = const {SpectrumSpeed.slow, SpectrumSpeed.mid, SpectrumSpeed.fast},
  bool canRecenter = true,
}) => SpectrumCapabilities(
  spansHz: spansHz,
  refMinDb: refMinDb,
  refMaxDb: refMaxDb,
  refStepDb: refStepDb,
  modes: modes,
  speeds: speeds,
  canRecenter: canRecenter,
);

void main() {
  test('equivalent snapshots are interchangeable regardless of collection identity or set order', () {
    final first = _capabilities();
    final same = _capabilities(
      spansHz: [1000, 2500],
      modes: {SpectrumMode.fixed, SpectrumMode.center},
      speeds: {SpectrumSpeed.fast, SpectrumSpeed.mid, SpectrumSpeed.slow},
    );
    expect(identical(first, same), isFalse);
    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect({first, same}, hasLength(1));
  });

  test('a changed control option makes a distinct snapshot', () {
    final original = _capabilities();
    final changed = {
      'spans': _capabilities(spansHz: [1000, 2500, 5000]),
      'reference minimum': _capabilities(refMinDb: -20),
      'reference maximum': _capabilities(refMaxDb: 20),
      'reference step': _capabilities(refStepDb: 0.5),
      'modes': _capabilities(modes: {SpectrumMode.fixed}),
      'speeds': _capabilities(speeds: {SpectrumSpeed.fast}),
      'recentering': _capabilities(canRecenter: false),
    };
    for (final entry in changed.entries) {
      expect(entry.value, isNot(original), reason: '${entry.key} changes the controls available to the operator');
    }
    expect({original, ...changed.values}, hasLength(8));
  });
}
