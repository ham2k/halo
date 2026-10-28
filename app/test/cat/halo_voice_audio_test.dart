// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HaloVoiceAudio's recording lengths, against real files and the real
// decoder: asked for on every rebuild, read off the disk at most once a
// recheck window, and never stale after this app's own writes.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart' show HaloAudioException;
import 'package:ham2k_logger/services/cat/computer_voice_keyer.dart';

/// A silent 16-bit mono WAV of [ms] milliseconds at 8 kHz.
void writeWav(String path, int ms) {
  final frames = 8000 * ms ~/ 1000;
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
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, frames * 2, Endian.little);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(data.buffer.asUint8List());
}

void main() {
  late Directory dir;

  /// The steady clock the cache reads, moved by hand.
  late int millis;
  HaloVoiceAudio makeAudio() => HaloVoiceAudio(elapsedMillis: () => millis);
  void elapse(Duration by) => millis += by.inMilliseconds;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('halo_voice_audio_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    millis = 0;
  });

  // The trap: the disk asked on every call. The surfaces ask for all eight
  // lengths on every rebuild, which is two file-system calls per message
  // several times a second; a file changed behind the app's back inside the
  // window still reading as it was is the proof the disk was not asked.
  test('a file put in the folder by hand shows once the window has passed, and the disk is not asked inside it', () {
    final audio = makeAudio();
    final path = '${dir.path}/1.wav';
    expect(audio.lengthOf(path), isNull, reason: 'not recorded yet');

    writeWav(path, 250);
    expect(audio.lengthOf(path), isNull, reason: 'a missing file is remembered too: inside the window, nothing is asked');
    elapse(HaloVoiceAudio.recheckAfter);
    expect(audio.lengthOf(path), const Duration(milliseconds: 250));

    writeWav(path, 500);
    File(path).setLastModifiedSync(File(path).lastModifiedSync().add(const Duration(seconds: 5)));
    expect(audio.lengthOf(path), const Duration(milliseconds: 250));
    elapse(HaloVoiceAudio.recheckAfter);
    expect(audio.lengthOf(path), const Duration(milliseconds: 500));
  });

  // The trap: a recording just made through the app shown with the length
  // of the one it replaced — or as not recorded — for up to the window.
  test("this app's own writes show at once", () {
    final audio = makeAudio();
    final path = '${dir.path}/set/2.wav', other = '${dir.path}/other.wav';
    expect(audio.lengthOf(path), isNull);

    writeWav('$path.recording', 300);
    audio.replace('$path.recording', path);
    expect(audio.lengthOf(path), const Duration(milliseconds: 300), reason: 'a recording kept');

    writeWav(other, 400);
    audio.copy(other, path);
    expect(audio.lengthOf(path), const Duration(milliseconds: 400), reason: 'a set copied');

    audio.delete(path);
    expect(audio.lengthOf(path), isNull, reason: 'a message deleted');

    writeWav(path, 200);
    elapse(HaloVoiceAudio.recheckAfter);
    expect(audio.lengthOf(path), const Duration(milliseconds: 200));
    audio.deleteDirectory('${dir.path}/set');
    expect(audio.lengthOf(path), isNull, reason: 'a set deleted');
  });

  // A normalize that fails partway leaves its copy half written beside the
  // recording, where nothing else would ever remove it. Stood in for here
  // by one already there: the decoder refuses the file before writing.
  test('a normalize that fails leaves no copy of its own behind, and the recording as it was', () {
    final path = '${dir.path}/3.wav.recording';
    File(path).writeAsStringSync('not a sound file');
    File('$path.normalized').writeAsStringSync('half written');
    expect(() => HaloVoiceAudio().normalize(path), throwsA(isA<HaloAudioException>()));
    expect(File('$path.normalized').existsSync(), isFalse);
    expect(File(path).readAsStringSync(), 'not a sound file');
  });

  test('a file that is there and will not decode is told apart from no file', () {
    final audio = makeAudio();
    final path = '${dir.path}/4.wav';
    expect(audio.exists(path), isFalse);
    File(path).writeAsStringSync('an m4a, renamed');
    elapse(HaloVoiceAudio.recheckAfter);
    expect(audio.lengthOf(path), isNull);
    expect(audio.exists(path), isTrue);
  });
}
