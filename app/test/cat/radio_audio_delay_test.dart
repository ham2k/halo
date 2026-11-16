// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio's Receive Audio Max Buffering (docs/design/audio.md § 3): how far
// behind the radio its audio may fall to ride out a network stall, set per
// radio.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:ham2k_logger/services/audio/radio_audio.dart';

/// The route's target after a 200 ms stall, for a radio heard with
/// [delayMs] on the null backend's output, which pulls in real time.
Future<double> targetAfterStall(int delayMs) async {
  final audio = RadioAudio(outputs: () => const []);
  addTearDown(audio.close);
  final link = audio.link(radio: 'flex-a', delayMs: delayMs);
  final radio = link.engine.addPushed();
  final route = link.hear(radio, why: (reason) => fail(reason))!;
  final packet = Float32List.fromList(List.filled(4800, 0.25));
  radio.push(packet);
  await Future<void>.delayed(const Duration(milliseconds: 300));
  radio.push(packet);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  expect(route.stats.underruns, greaterThanOrEqualTo(1), reason: 'the stall ran it dry: ${route.stats}');
  return route.stats.targetMs;
}

void main() {
  setUpAll(() {
    try {
      HaloAudio.useNullBackend();
    } on StateError {
      // Chosen already by another test in this process.
    }
  });

  test('a stall raises the target only as far as the radio\'s delay allows', () async {
    // Unbounded by the setting, a wired radio's operator hears Wi-Fi's
    // 200 ms of delay after one stall; capped too low by default, a Wi-Fi
    // radio drops out at every stall.
    expect(await targetAfterStall(40), lessThanOrEqualTo(40));
    expect(await targetAfterStall(receiveAudioDelayDefault), greaterThan(150));
  });
}
