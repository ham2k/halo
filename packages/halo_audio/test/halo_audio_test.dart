// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';

/// A 16-bit mono WAV of [ms] milliseconds of a square wave at [amplitude].
File writeWav(Directory dir, String name, int ms, {int rate = 48000, int amplitude = 2000}) {
  final frames = rate * ms ~/ 1000;
  final data = ByteData(44 + frames * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + frames * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, frames * 2, Endian.little);
  for (var i = 0; i < frames; i++) {
    data.setInt16(44 + i * 2, (i % 48 < 24) ? amplitude : -amplitude, Endian.little);
  }
  return File('${dir.path}/$name')..writeAsBytesSync(data.buffer.asUint8List());
}

/// The loudest sample of a 16-bit WAV, 0..1, and how many samples it holds
/// — read off its `data` chunk wherever the writer put it.
(double, int) wavPeak(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var at = 12;
  while (at + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(at, at + 4));
    final size = data.getUint32(at + 4, Endian.little);
    if (id == 'data') {
      var loudest = 0;
      for (var i = at + 8; i + 1 < at + 8 + size && i + 1 < bytes.length; i += 2) {
        final v = data.getInt16(i, Endian.little).abs();
        if (v > loudest) loudest = v;
      }
      return (loudest / 32767, size ~/ 2);
    }
    at += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw StateError('no data chunk');
}

/// A 16-bit mono 48 kHz WAV of square-wave stretches, each (ms, amplitude).
File writeSegments(Directory dir, String name, List<(int, int)> segments) {
  final samples = <int>[
    for (final (ms, amplitude) in segments)
      for (var i = 0; i < 48 * ms; i++) (i % 48 < 24) ? amplitude : -amplitude,
  ];
  final data = ByteData(44 + samples.length * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 48000, Endian.little);
  data.setUint32(28, 96000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return File('${dir.path}/$name')..writeAsBytesSync(data.buffer.asUint8List());
}

void main() {
  late Directory dir;

  setUpAll(() {
    HaloAudio.useNullBackend();
    dir = Directory.systemTemp.createTempSync('halo_audio_test');
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  group('matchAudioDevice', () {
    const a = AudioDevice(id: 'aa', name: 'USB Audio CODEC');
    const b = AudioDevice(id: 'bb', name: 'USB Audio CODEC');
    const c = AudioDevice(id: 'cc', name: 'Built-in Output');

    test('a stored id still listed wins over its name', () {
      expect(matchAudioDevice([a, b, c], id: 'bb', name: 'Built-in Output'), b);
    });

    test('an id that changed (a replug, a Linux reboot) falls back to the name', () {
      expect(matchAudioDevice([c], id: 'gone', name: 'Built-in Output'), c);
    });

    // Two radios' identical codecs: the name cannot say which radio is
    // which, and a guess could put one radio's audio into the other.
    test('a name shared by two devices matches neither', () {
      expect(matchAudioDevice([a, b, c], id: 'gone', name: 'USB Audio CODEC'), isNull);
    });
  });

  test('the null backend lists one device each way, as default', () {
    expect(HaloAudio.playbackDevices(), [isA<AudioDevice>().having((d) => d.isDefault, 'isDefault', true)]);
    expect(HaloAudio.captureDevices(), hasLength(1));
  });

  test('fileLength reads a WAV, and is null for a file that is not audio', () {
    expect(HaloAudio.fileLength(writeWav(dir, 'len.wav', 250).path), const Duration(milliseconds: 250));
    final text = File('${dir.path}/not.wav')..writeAsStringSync('not audio');
    expect(HaloAudio.fileLength(text.path), isNull);
  });

  group('an output', () {
    late AudioOutput output;

    setUp(() => output = HaloAudio.openOutput());
    tearDown(() => output.close());

    // The voice keyer unkeys the radio on `done`: an end that came at once
    // would cut every message to nothing, and one that never came would hold
    // the transmitter to the ceiling.
    test('says a file is done when it has played through, not before, and stays open', () async {
      final wav = writeWav(dir, 'play.wav', 300);
      final clock = Stopwatch()..start();
      final playback = output.play(wav.path);
      expect(playback.isPlaying, isTrue);
      await playback.done.timeout(const Duration(seconds: 3));
      expect(clock.elapsedMilliseconds, greaterThanOrEqualTo(250));
      // Kept running into the unkey delay: closing here would drop what the
      // device still holds of the file's end.
      expect(output.isAlive, isTrue);
    });

    test('stop silences it at once and leaves the device open for the next file', () async {
      final playback = output.play(writeWav(dir, 'long.wav', 5000).path);
      final clock = Stopwatch()..start();
      playback.stop();
      playback.stop();
      await playback.done.timeout(const Duration(milliseconds: 500));
      expect(clock.elapsedMilliseconds, lessThan(500));
      expect(output.isAlive, isTrue);
      final next = output.play(writeWav(dir, 'short.wav', 100).path);
      await next.done.timeout(const Duration(seconds: 2));
    });

    test('a second file replaces the first, which is done', () async {
      final first = output.play(writeWav(dir, 'first.wav', 5000).path);
      final second = output.play(writeWav(dir, 'second.wav', 5000).path);
      await first.done.timeout(const Duration(milliseconds: 200));
      expect(second.isPlaying, isTrue);
      second.stop();
    });

    test('a file that will not open is refused, and the output plays the next', () async {
      expect(() => output.play('${dir.path}/missing.wav'), throwsA(isA<HaloAudioException>()));
      final next = output.play(writeWav(dir, 'after.wav', 100).path);
      await next.done.timeout(const Duration(seconds: 2));
    });

    test('closing ends what was playing', () async {
      final playback = output.play(writeWav(dir, 'closing.wav', 5000).path);
      output.close();
      await playback.done.timeout(const Duration(milliseconds: 200));
      expect(output.isAlive, isFalse);
    });
  });

  // A FlexRadio's DAX takes 24 kHz stereo floats: a recording made at 48 kHz
  // mono has to come out at half the frames, the same on both channels, at
  // the level it was recorded at.
  test('decode resamples and spreads a mono recording across the channels asked for', () {
    final wav = writeWav(dir, 'decode.wav', 500, amplitude: 16384);
    final samples = HaloAudio.decode(wav.path, rate: 24000, channels: 2);
    expect(samples.length, 2 * 12000);
    for (var i = 0; i < samples.length; i += 2) {
      expect(samples[i + 1], samples[i]);
    }
    // RMS, not the peak: the resampler's low-pass rings on a square wave's edges.
    final rms = math.sqrt(samples.fold(0.0, (sum, s) => sum + s * s) / samples.length);
    expect(rms, closeTo(0.5, 0.05));
    expect(() => HaloAudio.decode('${dir.path}/missing.wav', rate: 24000, channels: 2), throwsA(isA<HaloAudioException>()));
  });

  group('normalize', () {
    // A voice recorded at a laptop mic's default gain peaks near -15 dBFS:
    // fine through speakers turned up, barely there in a radio's transmit
    // audio, which nothing turns up.
    test("raises a quiet recording's loudest sample to the peak asked for, keeping its length", () {
      final quiet = writeWav(dir, 'quiet.wav', 500, amplitude: 5800); // -15 dBFS
      final out = File('${dir.path}/quiet.out.wav');
      HaloAudio.normalize(quiet.path, out.path, peak: 0.891, maxGain: 10);
      final (peak, samples) = wavPeak(out);
      expect(peak, closeTo(0.891, 0.001));
      expect(samples, 24000);
    });

    // Raised all the way, a near-silent recording would go out as room
    // noise at full level.
    test('raises by no more than the most it is allowed', () {
      final faint = writeWav(dir, 'faint.wav', 200, amplitude: 300);
      final out = File('${dir.path}/faint.out.wav');
      HaloAudio.normalize(faint.path, out.path, peak: 0.891, maxGain: 10);
      expect(wavPeak(out).$1, closeTo(3000 / 32767, 0.001));
    });

    test('never makes a loud recording quieter', () {
      final loud = writeWav(dir, 'loud.wav', 200, amplitude: 32000);
      final out = File('${dir.path}/loud.out.wav');
      HaloAudio.normalize(loud.path, out.path, peak: 0.891, maxGain: 10);
      expect(wavPeak(out).$1, closeTo(32000 / 32767, 0.001));
    });

    const trim = AudioTrim(
      aboveFloorDb: 12,
      belowLoudestDb: 20,
      minSound: Duration(milliseconds: 40),
      lead: Duration(milliseconds: 100),
      tail: Duration(milliseconds: 200),
      cutEnd: Duration(milliseconds: 100),
    );

    // A recording runs from Record to Stop: the room before and after the
    // voice, raised with it, is hiss at both ends of every message.
    test('trims the room before and after the sound, keeping the lead and the tail around it', () {
      final wav = writeSegments(dir, 'trim.wav', [(600, 40), (400, 8000), (800, 40)]);
      final out = File('${dir.path}/trim.out.wav');
      HaloAudio.normalize(wav.path, out.path, peak: 0.891, maxGain: 10, trim: trim);
      expect(HaloAudio.fileLength(out.path)!.inMilliseconds, inInclusiveRange(690, 710));
      expect(wavPeak(out).$1, closeTo(0.891, 0.001));
    });

    // A laptop mic's room has blips in it — a breath, the desk — that reach
    // within 30 dB of the voice's peak. Measured from the peak, they count as
    // sound and the room before the voice is kept.
    test('a blip in the room under the line above its floor is room, not sound', () {
      final wav = writeSegments(dir, 'blip.wav', [(300, 40), (10, 110), (290, 40), (400, 8000), (300, 40)]);
      final out = File('${dir.path}/blip.out.wav');
      HaloAudio.normalize(wav.path, out.path, peak: 0.891, maxGain: 10, trim: trim);
      expect(HaloAudio.fileLength(out.path)!.inMilliseconds, inInclusiveRange(690, 710));
    });

    // Record pressed with a mouse beside the mic starts the recording with a
    // click louder than the voice. Trimmed away, it must not still set the
    // gain: the voice would be raised by far less than it needs.
    test('a click trimmed off the start does not hold down the gain', () {
      final wav = writeSegments(dir, 'start-click.wav', [(200, 40), (30, 20000), (500, 40), (400, 5800), (300, 40)]);
      final out = File('${dir.path}/start-click.out.wav');
      HaloAudio.normalize(wav.path, out.path, peak: 0.891, maxGain: 10, trim: trim);
      expect(HaloAudio.fileLength(out.path)!.inMilliseconds, inInclusiveRange(690, 710));
      expect(wavPeak(out).$1, closeTo(0.891, 0.001));
    });

    // Stop pressed with a mouse beside the mic ends every recording with a
    // click; taken for sound, it holds in all the room between the voice
    // and itself.
    test('a click at the end is not sound', () {
      final wav = writeSegments(dir, 'click.wav', [(300, 40), (400, 8000), (700, 40), (30, 4000), (40, 40)]);
      final out = File('${dir.path}/click.out.wav');
      HaloAudio.normalize(wav.path, out.path, peak: 0.891, maxGain: 10, trim: trim);
      expect(HaloAudio.fileLength(out.path)!.inMilliseconds, inInclusiveRange(690, 710));
    });

    // A soft first word dips under the line between its parts: taken a part
    // at a time, each is as short as a click, and the word is cut.
    test('a soft word broken into short parts is still sound', () {
      final wav = writeSegments(dir, 'choppy.wav', [(300, 40), (20, 3000), (20, 40), (20, 3000), (20, 40), (20, 3000), (300, 40), (400, 8000), (500, 40)]);
      final out = File('${dir.path}/choppy.out.wav');
      HaloAudio.normalize(wav.path, out.path, peak: 0.891, maxGain: 10, trim: trim);
      // From the word's first part: 100 ms lead, 100 ms of word, 300 ms of
      // room, 400 ms of voice, 200 ms tail.
      expect(HaloAudio.fileLength(out.path)!.inMilliseconds, inInclusiveRange(1090, 1110));
    });

    // A press of Stop can sound longer than the 40 ms a click is allowed:
    // the last 100 ms, where it falls, is never measured.
    test('the end of the recording is dropped unmeasured, a long click with it', () {
      final wav = writeSegments(dir, 'long-click.wav', [(300, 40), (400, 8000), (500, 40), (80, 8000), (15, 40)]);
      final out = File('${dir.path}/long-click.out.wav');
      HaloAudio.normalize(wav.path, out.path, peak: 0.891, maxGain: 10, trim: trim);
      expect(HaloAudio.fileLength(out.path)!.inMilliseconds, inInclusiveRange(690, 710));
    });

    test('a recording of nothing but a click is kept whole rather than cut to nothing', () {
      final wav = writeSegments(dir, 'only-click.wav', [(300, 40), (20, 4000), (300, 40)]);
      final out = File('${dir.path}/only-click.out.wav');
      HaloAudio.normalize(wav.path, out.path, peak: 0.891, maxGain: 10, trim: trim);
      expect(HaloAudio.fileLength(out.path)!.inMilliseconds, 520, reason: 'all but the unmeasured end');
    });

    // The room of a noisy laptop mic sits about 30 dB under the voice: a line
    // allowed down to 30 dB under the loudest stretch lands in the room.
    test('a room barely 30 dB under the voice is still room', () {
      final wav = writeSegments(dir, 'noisy.wav', [(400, 260), (400, 8000), (700, 260)]);
      final out = File('${dir.path}/noisy.out.wav');
      HaloAudio.normalize(wav.path, out.path, peak: 0.891, maxGain: 10, trim: trim);
      expect(HaloAudio.fileLength(out.path)!.inMilliseconds, inInclusiveRange(690, 710));
    });

    // A quiet syllable at the start or end is the message too.
    test('keeps a quieter stretch well above the floor, where the voice trails off', () {
      final wav = writeSegments(dir, 'trail.wav', [(400, 8000), (300, 400), (600, 40)]);
      final out = File('${dir.path}/trail.out.wav');
      HaloAudio.normalize(wav.path, out.path, peak: 0.891, maxGain: 10, trim: trim);
      expect(HaloAudio.fileLength(out.path)!.inMilliseconds, inInclusiveRange(890, 910));
    });

    // With hardly any room in a recording, its quietest tenth is speech: a
    // line set only from that floor would cut the soft words at the ends.
    test('a recording that is nearly all voice keeps its softer speech', () {
      final wav = writeSegments(dir, 'voiced.wav', [(300, 2000), (1500, 8000), (300, 2000)]);
      final out = File('${dir.path}/voiced.out.wav');
      HaloAudio.normalize(wav.path, out.path, peak: 0.891, maxGain: 10, trim: trim);
      expect(HaloAudio.fileLength(out.path)!.inMilliseconds, 2000, reason: 'all but the unmeasured end');
    });

    test('the lead fades in and the tail fades out', () {
      final wav = writeSegments(dir, 'fade.wav', [(600, 40), (400, 8000), (800, 40)]);
      final out = File('${dir.path}/fade.out.wav');
      HaloAudio.normalize(wav.path, out.path, peak: 0.891, maxGain: 10, trim: trim);
      final bytes = ByteData.sublistView(out.readAsBytesSync());
      final samples = [for (var at = 44; at + 1 < bytes.lengthInBytes; at += 2) bytes.getInt16(at, Endian.little).abs()];
      // Raised with the voice, the room is 146: what is left of it rises
      // from silence across the lead and falls back across the tail.
      expect(samples.first, lessThan(5));
      expect(samples.last, lessThan(5));
      expect(samples.sublist(0, 2400).reduce((a, b) => a > b ? a : b), lessThan(150));
      expect(samples[4800 + 100], greaterThan(28000), reason: 'the voice itself is not faded');
    });

    test('trims nothing unless asked', () {
      final wav = writeSegments(dir, 'untrimmed.wav', [(600, 40), (400, 8000), (800, 40)]);
      final out = File('${dir.path}/untrimmed.out.wav');
      HaloAudio.normalize(wav.path, out.path, peak: 0.891, maxGain: 10);
      expect(HaloAudio.fileLength(out.path)!.inMilliseconds, 1800);
    });

    test('a file that is not audio is refused', () {
      final text = File('${dir.path}/not-audio.wav')..writeAsStringSync('not audio');
      expect(() => HaloAudio.normalize(text.path, '${dir.path}/x.wav', peak: 0.891, maxGain: 10), throwsA(isA<HaloAudioException>()));
    });
  });

  test('a device id the binding never wrote is refused, not opened as the default', () {
    expect(() => HaloAudio.openOutput(deviceId: 'not-hex'), throwsA(isA<HaloAudioException>()));
  });

  test('a recording becomes a WAV file as long as it ran', () async {
    final path = '${dir.path}/rec.wav';
    final recording = HaloAudio.record(path);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    recording.stop();
    expect(recording.isRecording, isFalse);
    final length = HaloAudio.fileLength(path);
    expect(length, isNotNull);
    expect(length!.inMilliseconds, inInclusiveRange(250, 800));
  });
}
