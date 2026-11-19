// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The sound cards the computer offers (docs/design/station-model.md § 3), as
// the audio engine lists them: read with each card's channels, which probes
// every card, so not on every ask.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/audio/radio_audio.dart';

import '../support/error_reporting_fakes.dart';

void main() {
  setUp(() => AppClock.followZoneClock = true);
  tearDown(() => AppClock.followZoneClock = false);

  const codec = AudioDevice(id: 'aa', name: 'USB Audio CODEC', channels: 2);

  test('a picker asking on every build probes the cards once a while, not each time', () {
    fakeAsync((async) {
      var reads = 0;
      final audio = RadioAudio(
        soundCards: () {
          reads++;
          return (playback: const [codec], capture: const <AudioDevice>[]);
        },
      );
      for (var i = 0; i < 10; i++) {
        expect(audio.soundCards.playback, [codec]);
      }
      expect(reads, 1);
      // A card plugged in is never announced: only a later read finds it.
      async.elapse(RadioAudio.soundCardsFresh);
      audio.soundCards;
      expect(reads, 2);
    });
  });

  test('cards that will not list are none, and an unexpected failure is reported once', () async {
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(backend: backend, () async {
      fakeAsync((async) {
        final audio = RadioAudio(soundCards: () => throw StateError('library missing a symbol'));
        expect(audio.soundCards.playback, isEmpty);
        async.elapse(RadioAudio.soundCardsFresh);
        expect(audio.soundCards.capture, isEmpty);
      });
      // Read again every few seconds, the same failure would otherwise be
      // an upload every few seconds.
      expect(backend.exceptions.where((e) => e.context == 'audio:sound-cards'), hasLength(1));
    });
  });

  test('a backend that will not open is no cards and no report', () async {
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(backend: backend, () async {
      final audio = RadioAudio(soundCards: () => throw HaloAudioException('no audio backend could be opened'));
      expect(audio.soundCards.playback, isEmpty);
      expect(backend.exceptions, isEmpty);
    });
  });

  test('lists given for routing are the cards too, without reaching the native library', () {
    // A test that keeps the engine's devices fake would otherwise list, and
    // probe, the real machine's.
    final audio = RadioAudio(outputs: () => const [codec], inputs: () => const []);
    expect(audio.soundCards.playback, [codec]);
  });
}
