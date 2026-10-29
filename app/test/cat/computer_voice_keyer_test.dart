// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The computer's voice keyer (computer_voice_keyer.dart): keying the radio
// around a recording played into its sound device.
//
// The traps are a transmitter on the air with nothing to say — keyed with
// no device to play to, or left keyed when the audio stopped — audio that
// starts before the radio has switched to transmit or is cut by an early
// unkey, a CQ played into the laptop's speakers while the radio sends
// silence, a recording that fails — or hears nothing — taking the old
// message with it, and the sound device held open forever or reopened in the
// middle of the key-up delay.

import 'dart:async';
import 'dart:io' show FileSystemException, OSError;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:ham2k_logger/services/cat/computer_voice_keyer.dart';
import 'package:ham2k_logger/services/cat/driver.dart';

import '../support/error_reporting_fakes.dart';
import '../support/fake_voice_audio.dart';

class _FakePtt implements PttSession {
  final sent = <bool>[];
  bool throws = false;

  @override
  void setPtt(bool on) {
    if (throws) throw StateError('link down');
    sent.add(on);
  }

  @override
  Duration? get expectedUpdateInterval => null;
  @override
  void handleData(Uint8List chunk) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  void teardown() {}
}

class _FakeComputerAudioPtt extends _FakePtt implements ComputerAudioPttSession {
  _FakeComputerAudioPtt({required this.switchesToComputerAudio});

  @override
  final bool switchesToComputerAudio;
  final withComputerAudio = <bool>[];

  /// What the last key was told to call if the switch is refused.
  void Function()? refused;

  @override
  void setPttWithComputerAudio(bool on, {void Function()? refused}) {
    withComputerAudio.add(on);
    if (on) this.refused = refused;
  }
}

class _FedOutput extends FakeOutput implements SilenceFedOutput {
  _FedOutput(this.events) : super('radio');

  final List<String> events;

  /// The file each silence was started ahead of.
  final readied = <String>[];

  /// The next file will not decode.
  bool failingDecode = false;

  @override
  void startSilence(String next) {
    if (failingDecode) throw HaloAudioException('decode: no');
    readied.add(next);
    events.add('silence');
  }
}

class _FakeNetworkPtt extends _FakeComputerAudioPtt implements NetworkTransmitAudioSession {
  _FakeNetworkPtt() : super(switchesToComputerAudio: true);

  @override
  bool sendsTransmitAudio = true;

  /// Whether the link is up; an output opened while it is not is null.
  bool linkUp = true;
  final opened = <FakeOutput>[];

  /// Silence started and keys, in order.
  final events = <String>[];

  @override
  AudioOutput? openTransmitAudio(PcmDecoder decode) {
    if (!linkUp) return null;
    final output = _FedOutput(events);
    opened.add(output);
    return output;
  }

  @override
  void setPttWithComputerAudio(bool on, {void Function()? refused}) {
    events.add(on ? 'key' : 'unkey');
    super.setPttWithComputerAudio(on, refused: refused);
  }
}

const codec = AudioDevice(id: 'c0dec', name: 'USB Audio CODEC');
const speakers = AudioDevice(id: '5peak', name: 'MacBook Pro Speakers', isDefault: true);
const lead = Duration(milliseconds: 250);
const tail = Duration(milliseconds: 150);
const message = Duration(seconds: 3);

void main() {
  late _FakePtt radio;
  late FakeVoiceAudio audio;
  late Map<String, dynamic> config;
  late List<VoiceActivity?> reports;
  late ComputerVoiceKeyer keyer;

  setUp(() {
    radio = _FakePtt();
    audio = FakeVoiceAudio()
      ..outputDevices = [speakers, codec]
      ..inputDevices = [const AudioDevice(id: 'm1c', name: 'Headset', isDefault: true)]
      ..lengths['/v/1.wav'] = message;
    config = {voiceOutputConfigKey: voiceDeviceToConfig(codec), voiceLeadConfigKey: lead.inMilliseconds, voiceTailConfigKey: tail.inMilliseconds};
    reports = [];
    forgetVoiceFailuresReported();
  });

  /// Built inside each test's fake time: the keyer starts its idle timer as
  /// it is made.
  void start() => keyer = ComputerVoiceKeyer(ptt: radio, audio: audio, config: () => config, fileFor: (n) => '/v/$n.wav', report: reports.add);

  /// [body] in fake time, and what it reported as the keyer's failures —
  /// what each was doing when it failed.
  Future<List<String>> reporting(void Function(FakeAsync async) body) async {
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(backend: backend, () async => fakeAsync(body));
    return [
      for (final e in backend.exceptions)
        if (e.error case VoiceAudioFailure(:final doing)) doing,
    ];
  }

  /// Plays message 1 through to its end, and the unkey after it.
  void playThrough(FakeAsync async) {
    keyer.playVoiceMemory(1);
    async.elapse(lead);
    audio.plays.last.end();
    async.flushMicrotasks();
    async.elapse(tail);
  }

  group('playing a message', () {
    test('keys, waits the lead before the audio and the tail after it, then unkeys', () {
      fakeAsync((async) {
        start();
        keyer.playVoiceMemory(1);
        expect(radio.sent, [true]);
        expect(reports, [const VoiceActivity(memory: 1)]);
        // Audio before the radio has switched over loses the first syllable.
        async.elapse(lead - const Duration(milliseconds: 1));
        expect(audio.plays, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        expect(audio.plays.single.output!.deviceId, codec.id, reason: 'into the radio, not the default device');

        async.elapse(message);
        audio.plays.single.end();
        async.flushMicrotasks();
        // The device still sounds what it holds of the end: it is neither
        // silenced nor closed until the unkey.
        expect(audio.plays.single.stopped, isFalse);
        expect(audio.opened.single.closed, isFalse);
        async.elapse(tail - const Duration(milliseconds: 1));
        expect(radio.sent, [true]);
        async.elapse(const Duration(milliseconds: 1));
        expect(radio.sent, [true, false]);
        expect(reports.last, isNull);
        expect(keyer.keyed, isFalse);
      });
    });

    test('a word recording started while a message plays ends the message where it is shown', () {
      // Unshown, the keyer area keeps the message playing for good, and a
      // repeat waiting for it to clear never comes back round.
      fakeAsync((async) {
        start();
        keyer.playVoiceMemory(1);
        async.elapse(lead);
        expect(keyer.recordFile('/v/words/.reading.wav', ceiling: const Duration(seconds: 10), done: (_) {}), isTrue);
        expect(reports.last, isNull);
        expect(radio.sent, [true, false]);
      });
    });

    test('a device whose id changed is found by its name', () {
      fakeAsync((async) {
        config[voiceOutputConfigKey] = {'id': 'old-id', 'name': codec.name};
        start();
        keyer.playVoiceMemory(1);
        async.elapse(lead);
        expect(audio.plays.single.output!.deviceId, codec.id);
      });
    });
  });

  // Opening a device costs tens of milliseconds, and the first open of the
  // session more: inside a message, that comes out of the key-up delay.
  group('the sound device', () {
    test('opens with the keyer and stays open from one message to the next', () {
      fakeAsync((async) {
        start();
        expect(keyer.outputOpen, isTrue);
        playThrough(async);
        playThrough(async);
        expect(audio.opened, hasLength(1));
        expect(audio.listings, 1, reason: 'the devices are not listed again for every message');
      });
    });

    test('closes after five minutes with nothing played, and opens again before the next key', () {
      fakeAsync((async) {
        start();
        playThrough(async);
        async.elapse(computerVoiceIdleRelease - const Duration(seconds: 1));
        expect(keyer.outputOpen, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(keyer.outputOpen, isFalse);
        expect(audio.opened.single.closed, isTrue);

        radio.sent.clear();
        keyer.playVoiceMemory(1);
        expect(audio.opened, hasLength(2), reason: 'reopened before the radio was keyed');
        expect(radio.sent, [true]);
      });
    });

    test('every message starts the five minutes again', () {
      fakeAsync((async) {
        start();
        async.elapse(const Duration(minutes: 4));
        playThrough(async);
        async.elapse(const Duration(minutes: 4));
        expect(keyer.outputOpen, isTrue);
      });
    });

    test('a device unplugged and plugged back in is found again', () {
      fakeAsync((async) {
        start();
        audio.opened.single.unplug();
        async.flushMicrotasks();
        expect(keyer.outputOpen, isFalse);
        keyer.playVoiceMemory(1);
        async.elapse(lead);
        expect(audio.opened, hasLength(2));
        expect(audio.plays.single.output, audio.opened.last);
      });
    });

    test('unplugged mid-message, the message stops and the radio unkeys', () {
      fakeAsync((async) {
        start();
        keyer.playVoiceMemory(1);
        async.elapse(lead + const Duration(seconds: 1));
        audio.outputDevices = [speakers];
        audio.opened.single.unplug();
        async.flushMicrotasks();
        expect(radio.sent, [true, false]);
        expect(reports.last, const VoiceActivity(memory: 1, doubtful: true), reason: 'a doubtful end is what stops a repeat of it');
        expect(keyer.problem, ComputerVoiceProblem.outputMissing);
        async.elapse(voiceDoubtLinger);
        expect(reports.last, isNull);
      });
    });

    test('a device failing as the message starts unkeys the radio, and ends doubtful', () {
      fakeAsync((async) {
        start();
        keyer.playVoiceMemory(1);
        audio.opened.single.failingPlay = true;
        async.elapse(lead);
        expect(radio.sent, [true, false]);
        expect(keyer.problem, ComputerVoiceProblem.deviceFailed);
        expect(reports.last, const VoiceActivity(memory: 1, doubtful: true));
        async.elapse(voiceDoubtLinger);
        expect(reports.last, isNull);
      });
    });

    // The trap: a file that breaks off partway ending as if it had finished
    // — the rest of the message never sent, nothing said, and a repeat
    // keying it cut short every cooldown.
    test('a file that breaks off partway unkeys the radio, ends doubtful, and says why', () async {
      final reported = await reporting((async) {
        start();
        keyer.playVoiceMemory(1);
        async.elapse(lead);
        audio.plays.single.breakOff();
        async.flushMicrotasks();
        expect(radio.sent, [true, false]);
        expect(keyer.problem, ComputerVoiceProblem.unplayable);
        expect(reports.last, const VoiceActivity(memory: 1, doubtful: true));
        async.elapse(voiceDoubtLinger);
      });
      expect(reported, ['play']);
    });

    test('closed with the keyer', () {
      fakeAsync((async) {
        start();
        keyer.dispose();
        expect(audio.opened.single.closed, isTrue);
        async.elapse(computerVoiceIdleRelease);
      });
    });
  });

  group('refused before keying', () {
    void expectRefused(FakeAsync async, ComputerVoiceProblem problem) {
      expect(radio.sent, isEmpty, reason: 'keyed with nowhere to send the audio is a dead carrier');
      expect(audio.plays, isEmpty);
      expect(keyer.problem, problem);
      expect(reports.single, const VoiceActivity(memory: 1, doubtful: true));
      async.elapse(voiceDoubtLinger);
      expect(reports.last, isNull);
    }

    test('with no output device picked', () {
      fakeAsync((async) {
        config.remove(voiceOutputConfigKey);
        start();
        keyer.playVoiceMemory(1);
        expectRefused(async, ComputerVoiceProblem.noOutput);
      });
    });

    // The system default is the laptop's speakers far more often than the
    // radio: a CQ heard in the shack while the radio transmits silence.
    test('with the picked device unplugged, rather than playing to the default', () {
      fakeAsync((async) {
        audio.outputDevices = [speakers];
        start();
        keyer.playVoiceMemory(1);
        expectRefused(async, ComputerVoiceProblem.outputMissing);
      });
    });

    // Reported for the sound system's reason, which "would not open" leaves
    // out and a field report cannot be diagnosed without.
    test('with the picked device listed but refusing to open', () async {
      final reported = await reporting((async) {
        audio.failingOpens.add(codec.id);
        start();
        keyer.playVoiceMemory(1);
        expectRefused(async, ComputerVoiceProblem.deviceFailed);
      });
      expect(reported, ['open']);
    });

    test('with no recording for the message, or an empty one', () {
      fakeAsync((async) {
        audio.lengths['/v/1.wav'] = Duration.zero;
        start();
        keyer.playVoiceMemory(1);
        expectRefused(async, ComputerVoiceProblem.notRecorded);
      });
    });

    // An .m4a renamed to .wav is a file the operator put there: "no
    // recording yet" would send them to record over it.
    test('with a file there that will not decode, saying so rather than "not recorded"', () {
      fakeAsync((async) {
        audio.lengths.remove('/v/1.wav');
        audio.unreadable.add('/v/1.wav');
        start();
        keyer.playVoiceMemory(1);
        expectRefused(async, ComputerVoiceProblem.unplayable);
      });
    });

    test('a stop during the doubt clears it at once', () {
      fakeAsync((async) {
        audio.lengths.clear();
        start();
        keyer.playVoiceMemory(1);
        keyer.stopVoice();
        expect(reports.last, isNull);
      });
    });
  });

  group('stopping', () {
    test('a stop mid-message silences the audio and unkeys, the device left open', () {
      fakeAsync((async) {
        start();
        keyer.playVoiceMemory(1);
        async.elapse(lead + const Duration(seconds: 1));
        keyer.stopVoice();
        expect(audio.plays.single.stopped, isTrue);
        expect(audio.opened.single.closed, isFalse);
        expect(radio.sent, [true, false]);
        expect(reports.last, isNull);
        // The play's end, arriving after, starts no tail and sends nothing.
        async.elapse(const Duration(seconds: 5));
        expect(radio.sent, [true, false]);
      });
    });

    test('a stop during the lead never starts the audio', () {
      fakeAsync((async) {
        start();
        keyer.playVoiceMemory(1);
        async.elapse(const Duration(milliseconds: 100));
        keyer.stopVoice();
        async.elapse(const Duration(seconds: 1));
        expect(audio.plays, isEmpty);
        expect(radio.sent, [true, false]);
      });
    });

    // A device that stops calling back would otherwise hold the transmitter
    // until the PTT key's own minute.
    test('a play whose end never comes is stopped past its own length', () {
      fakeAsync((async) {
        start();
        keyer.playVoiceMemory(1);
        async.elapse(lead + message + tail + computerVoicePlayMargin - const Duration(milliseconds: 1));
        expect(radio.sent, [true]);
        async.elapse(const Duration(milliseconds: 1));
        expect(radio.sent, [true, false]);
        expect(audio.plays.single.stopped, isTrue);
      });
    });

    test('a second message replaces the first, with the radio unkeyed between', () {
      fakeAsync((async) {
        audio.lengths['/v/2.wav'] = const Duration(seconds: 2);
        start();
        keyer.playVoiceMemory(1);
        async.elapse(lead);
        keyer.playVoiceMemory(2);
        expect(audio.plays.first.stopped, isTrue);
        expect(radio.sent, [true, false, true]);
        async.elapse(lead);
        expect(audio.plays.last.path, '/v/2.wav');
      });
    });
  });

  group('the radio dropping the key itself', () {
    test('after it confirmed transmitting, the message stops with it', () {
      fakeAsync((async) {
        start();
        keyer.playVoiceMemory(1);
        async.elapse(lead);
        keyer.onTransmitting(true);
        keyer.onTransmitting(false);
        expect(audio.plays.single.stopped, isTrue);
        // Unkeyed anyway: a CAT key is latched, and a misread report would
        // otherwise leave it on with nothing left to drop it.
        expect(radio.sent, [true, false]);
      });
    });

    test('a "not transmitting" before any confirmation is the poll already on the wire', () {
      fakeAsync((async) {
        start();
        keyer.playVoiceMemory(1);
        keyer.onTransmitting(false);
        async.elapse(lead);
        expect(audio.plays, hasLength(1));
        expect(audio.plays.single.stopped, isFalse);
      });
    });
  });

  // Keyed plainly, a radio set up for its mic sends the mic, not the
  // recording; asked to switch where it cannot, a session would send a
  // command its radio may read as something else.
  test("keys with the radio's audio switched to the computer where the session can, plainly where it cannot", () {
    fakeAsync((async) {
      final switching = _FakeComputerAudioPtt(switchesToComputerAudio: true);
      keyer = ComputerVoiceKeyer(ptt: switching, audio: audio, config: () => config, fileFor: (n) => '/v/$n.wav', report: reports.add);
      expect(keyer.switchesAudio, isTrue);
      playThrough(async);
      expect(switching.withComputerAudio, [true, false]);
      expect(switching.sent, isEmpty);
      keyer.dispose();

      final plain = _FakeComputerAudioPtt(switchesToComputerAudio: false);
      keyer = ComputerVoiceKeyer(ptt: plain, audio: audio, config: () => config, fileFor: (n) => '/v/$n.wav', report: reports.add);
      expect(keyer.switchesAudio, isFalse);
      playThrough(async);
      expect(plain.sent, [true, false]);
      expect(plain.withComputerAudio, isEmpty);
      keyer.dispose();
    });
  });

  // The radio was on the air with its mic: it is unkeyed already, and a
  // message left "playing" into it would show nothing wrong for its length.
  test('a source switch the radio refused stops the message and says why', () {
    fakeAsync((async) {
      final switching = _FakeComputerAudioPtt(switchesToComputerAudio: true);
      keyer = ComputerVoiceKeyer(ptt: switching, audio: audio, config: () => config, fileFor: (n) => '/v/$n.wav', report: reports.add);
      keyer.playVoiceMemory(1);
      async.elapse(lead);
      switching.refused!();
      expect(switching.withComputerAudio, [true, false]);
      expect(audio.plays.single.stopped, isTrue);
      expect(keyer.problem, ComputerVoiceProblem.sourceRefused);
      async.elapse(voiceDoubtLinger);
      keyer.dispose();
    });
  });

  group('a radio that takes its audio over the network', () {
    late _FakeNetworkPtt flex;

    setUp(() => flex = _FakeNetworkPtt());

    void startOn() => keyer = ComputerVoiceKeyer(ptt: flex, audio: audio, config: () => config, fileFor: (n) => '/v/$n.wav', report: reports.add);

    // A Flex needs no sound device: one picked anyway would be a GUI
    // client's virtual device, which need not reach the transmitter.
    test('plays into the radio itself when no output is picked, opening no sound device', () {
      fakeAsync((async) {
        config.remove(voiceOutputConfigKey);
        startOn();
        expect(keyer.playsToRadio, isTrue);
        keyer.playVoiceMemory(1);
        async.elapse(lead);
        expect(flex.opened.single.plays.single.path, '/v/1.wav');
        expect(audio.opened, isEmpty);
        expect(flex.withComputerAudio, [true], reason: 'keyed with DAX switched on');
        flex.opened.single.plays.single.end();
        async.flushMicrotasks();
        async.elapse(tail);
        expect(flex.withComputerAudio, [true, false]);
      });
    });

    // A Flex keyed before anything arrives on its DAX transmits noise for
    // the whole key-up delay.
    test('starts the silence before keying', () {
      fakeAsync((async) {
        config.remove(voiceOutputConfigKey);
        startOn();
        keyer.playVoiceMemory(1);
        expect(flex.events, ['silence', 'key']);
        expect((flex.opened.single as _FedOutput).readied, ['/v/1.wav'], reason: 'the file decoded before the key, not in the middle of the feed');
      });
    });

    // Found only as it plays, a file that will not decode leaves the radio
    // keyed with nothing to send.
    test('a recording that will not decode is refused before keying', () {
      fakeAsync((async) {
        config.remove(voiceOutputConfigKey);
        startOn();
        (flex.opened.single as _FedOutput).failingDecode = true;
        keyer.playVoiceMemory(1);
        expect(flex.withComputerAudio, isEmpty);
        expect(keyer.problem, ComputerVoiceProblem.deviceFailed);
        expect(reports.single, const VoiceActivity(memory: 1, doubtful: true));
        async.elapse(voiceDoubtLinger);
      });
    });

    test('and when the radio is picked as the output', () {
      fakeAsync((async) {
        config[voiceOutputConfigKey] = voiceOutputRadio;
        startOn();
        keyer.playVoiceMemory(1);
        async.elapse(lead);
        expect(flex.opened.single.plays, hasLength(1));
        expect(audio.opened, isEmpty);
      });
    });

    test('a sound device picked instead is still the one played into', () {
      fakeAsync((async) {
        startOn();
        expect(keyer.playsToRadio, isFalse);
        keyer.playVoiceMemory(1);
        async.elapse(lead);
        expect(audio.plays.single.output!.deviceId, codec.id);
        expect(flex.opened, isEmpty);
      });
    });

    // Keyed with no link to send on is a dead carrier.
    test('with the link down, refuses before keying', () {
      fakeAsync((async) {
        config.remove(voiceOutputConfigKey);
        flex.linkUp = false;
        startOn();
        keyer.playVoiceMemory(1);
        expect(flex.withComputerAudio, isEmpty);
        expect(keyer.problem, ComputerVoiceProblem.radioAudioUnavailable);
        async.elapse(voiceDoubtLinger);
      });
    });

    test('the link lost mid-message stops it and unkeys', () {
      fakeAsync((async) {
        config.remove(voiceOutputConfigKey);
        startOn();
        keyer.playVoiceMemory(1);
        async.elapse(lead);
        flex.opened.single.unplug();
        async.flushMicrotasks();
        expect(flex.withComputerAudio, [true, false]);
        expect(keyer.problem, ComputerVoiceProblem.radioAudioUnavailable, reason: 'the radio, not a sound device, stopped taking the audio');
        async.elapse(voiceDoubtLinger);
      });
    });
  });

  test('a closing session is not sent an unkey — its own teardown sends one', () {
    fakeAsync((async) {
      start();
      keyer.playVoiceMemory(1);
      async.elapse(lead);
      keyer.dispose();
      expect(radio.sent, [true]);
      expect(audio.plays.single.stopped, isTrue);
      expect(reports.last, isNull);
    });
  });

  test('a key that throws leaves nothing showing as playing', () {
    fakeAsync((async) {
      start();
      radio.throws = true;
      expect(() => keyer.playVoiceMemory(1), throwsStateError);
      expect(reports.last, isNull);
      async.elapse(const Duration(seconds: 10));
      expect(audio.plays, isEmpty);
    });
  });

  group('reporting', () {
    // The trap: a file error's text names its path, and a path under the
    // operator's home names their OS account — which goes out only behind
    // the consent gate.
    test('a reason goes up without the path a file error carries', () {
      final failure = VoiceAudioFailure(
        'keep',
        const FileSystemException('Cannot rename file', r'C:\Users\Ada Lovelace\AppData\voice\1.wav', OSError('Access is denied', 5)),
      );
      expect(failure.reason, isNot(contains('Lovelace')));
      expect(failure.reason, contains('Cannot rename file'));
      expect(failure.reason, contains('Access is denied'));
    });

    // A device another program holds refuses every key pressed; the second
    // upload of the same reason says nothing the first did not.
    test('the same reason goes up once a session', () async {
      final reported = await reporting((async) {
        audio.failingOpens.add(codec.id);
        start();
        for (var i = 0; i < 3; i++) {
          keyer.playVoiceMemory(1);
          async.elapse(voiceDoubtLinger);
        }
      });
      expect(reported, ['open']);
    });
  });

  group('recording', () {
    test('records off the air, beside the message, and keeps it on stop', () {
      fakeAsync((async) {
        start();
        keyer.recordVoiceMemory(1);
        expect(radio.sent, isEmpty, reason: 'recording never keys');
        expect(reports.single, const VoiceActivity(memory: 1, recording: true));
        final recording = audio.recordings.single;
        expect(recording.path, isNot('/v/1.wav'), reason: 'the old message stays until the new one is done');
        expect(recording.deviceId, isNull, reason: 'no input picked: the system default');

        async.elapse(const Duration(seconds: 4));
        audio.lengths[recording.path] = const Duration(seconds: 4);
        keyer.stopVoice();
        expect(recording.stopped, isTrue);
        expect(audio.normalized, [recording.path], reason: 'raised before it replaces the message');
        expect(audio.replaced, [(recording.path, '/v/1.wav')]);
        expect(audio.lengths['/v/1.wav'], const Duration(seconds: 4));
        expect(reports.last, isNull);
      });
    });

    // The set in use is read through fileFor, and a pick can land while a
    // recording runs: resolved again at the stop, the recording would
    // overwrite that message in a set the operator was not recording.
    test('a recording is kept in the set it started in, whatever is picked meanwhile', () {
      fakeAsync((async) {
        var set = 'pota';
        keyer = ComputerVoiceKeyer(ptt: radio, audio: audio, config: () => config, fileFor: (n) => '/v/$set/$n.wav', report: reports.add);
        keyer.recordVoiceMemory(1);
        final recording = audio.recordings.single;
        set = 'contest';
        async.elapse(const Duration(seconds: 4));
        audio.lengths[recording.path] = const Duration(seconds: 4);
        keyer.stopVoice();
        expect(audio.replaced, [(recording.path, '/v/pota/1.wav')]);
      });
    });

    // The level is a nicety; the recording is the operator's message.
    // Reported, though: kept untrimmed it goes out with the room's hiss
    // around it, and a normalize failing everywhere would send every
    // recording that way without anyone hearing of it.
    test('a recording that will not normalize is kept as recorded, and reported', () async {
      final reported = await reporting((async) {
        start();
        audio.failingNormalize = true;
        keyer.recordVoiceMemory(1);
        final recording = audio.recordings.single;
        async.elapse(const Duration(seconds: 2));
        audio.lengths[recording.path] = const Duration(seconds: 2);
        keyer.stopVoice();
        expect(audio.replaced, [(recording.path, '/v/1.wav')]);
        expect(keyer.problem, isNull);
      });
      expect(reported, ['normalize']);
    });

    test('a recording whose normalized copy will not take its place is kept as recorded', () async {
      final reported = await reporting((async) {
        start();
        audio.failingNormalizeRename = true;
        keyer.recordVoiceMemory(1);
        final recording = audio.recordings.single;
        async.elapse(const Duration(seconds: 2));
        audio.lengths[recording.path] = const Duration(seconds: 2);
        keyer.stopVoice();
        expect(audio.replaced, [(recording.path, '/v/1.wav')], reason: 'a file error in the level is not one in the recording');
        expect(keyer.problem, isNull);
      });
      expect(reported, ['normalize']);
    });

    // The trap: a delete failing inside the keep caught one level up — the
    // reason the operator is shown replaced by "couldn't be saved", and the
    // one failure uploaded several times over.
    test('a recording not kept that will not delete keeps its own reason', () async {
      final reported = await reporting((async) {
        start();
        audio.failingDelete = true;
        keyer.recordVoiceMemory(1);
        final recording = audio.recordings.single..peak = 0;
        async.elapse(const Duration(seconds: 3));
        audio.lengths[recording.path] = const Duration(seconds: 3);
        keyer.stopVoice();
        expect(keyer.problem, ComputerVoiceProblem.recordingSilent);
        expect(audio.replaced, isEmpty);
      });
      expect(reported, ['discard']);
    });

    test('a recording that wrote nothing is thrown away, not kept over the old one', () {
      fakeAsync((async) {
        start();
        keyer.recordVoiceMemory(1);
        final recording = audio.recordings.single;
        keyer.stopVoice();
        expect(audio.replaced, isEmpty);
        expect(audio.deleted, [recording.path]);
        expect(audio.lengths['/v/1.wav'], message);
      });
    });

    // The trap: a recording that failed treated as Record pressed by
    // mistake — thrown away without a word, the operator believing the
    // message was replaced.
    test('a recording written and not readable back replaces nothing, and says so', () async {
      final reported = await reporting((async) {
        start();
        keyer.recordVoiceMemory(1);
        final recording = audio.recordings.single;
        async.elapse(const Duration(seconds: 4));
        audio.unreadable.add(recording.path);
        keyer.stopVoice();
        expect(audio.replaced, isEmpty);
        expect(audio.deleted, [recording.path]);
        expect(keyer.problem, ComputerVoiceProblem.recordingFailed);
        expect(audio.lengths['/v/1.wav'], message);
      });
      expect(reported, ['keep']);
    });

    // The trap: the mic unplugged or the disk full mid-recording. What was
    // heard before it already lifted the level past the silence check, so
    // the truncated file would replace the operator's message.
    test('a recording cut short replaces nothing, and says so', () async {
      final reported = await reporting((async) {
        start();
        keyer.recordVoiceMemory(1);
        final recording = audio.recordings.single..cutShort = true;
        async.elapse(const Duration(seconds: 4));
        audio.lengths[recording.path] = const Duration(seconds: 2);
        keyer.stopVoice();
        expect(audio.normalized, isEmpty);
        expect(audio.replaced, isEmpty);
        expect(audio.deleted, [recording.path], reason: 'no file left beside the message');
        expect(keyer.problem, ComputerVoiceProblem.recordingFailed);
        expect(audio.lengths['/v/1.wav'], message);
      });
      expect(reported, ['record']);
    });

    // A message file held open — on Windows, by Listen — cannot be renamed
    // over. That is no sound device failing, and the recording left beside
    // the message is a file nothing reads.
    test('a recording that cannot take the message\'s place says so, and leaves no file behind', () async {
      final reported = await reporting((async) {
        start();
        audio.failingReplace = true;
        keyer.recordVoiceMemory(1);
        final recording = audio.recordings.single;
        async.elapse(const Duration(seconds: 2));
        audio.lengths[recording.path] = const Duration(seconds: 2);
        keyer.stopVoice();
        expect(keyer.problem, ComputerVoiceProblem.fileFailed);
        expect(audio.deleted, [recording.path]);
        expect(audio.lengths['/v/1.wav'], message);
      });
      expect(reported, ['keep']);
    });

    // F1 pressed with a recording running ends the recording first: a
    // problem that ending raised, cleared by the play that follows, is a
    // recording thrown away without a word.
    test("a message keyed during a recording keeps what went wrong with the recording", () {
      fakeAsync((async) {
        start();
        keyer.recordVoiceMemory(2);
        final recording = audio.recordings.single..peak = 0;
        async.elapse(const Duration(seconds: 3));
        audio.lengths[recording.path] = const Duration(seconds: 3);
        keyer.playVoiceMemory(1);
        expect(keyer.problem, ComputerVoiceProblem.recordingSilent);
        expect(radio.sent, [true], reason: 'the message still plays');
        keyer.stopVoice();
      });
    });

    // Record pressed and stopped by mistake.
    test('a recording too short to be a message replaces nothing', () {
      fakeAsync((async) {
        start();
        keyer.recordVoiceMemory(1);
        final recording = audio.recordings.single;
        audio.lengths[recording.path] = computerVoiceShortestRecording - const Duration(milliseconds: 1);
        keyer.stopVoice();
        expect(audio.replaced, isEmpty);
        expect(audio.lengths['/v/1.wav'], message);
      });
    });

    // A muted input, or macOS refusing the microphone, records seconds of
    // silence without an error: kept, it would replace the CQ with nothing
    // and key the radio for it.
    test('a recording that heard nothing replaces nothing, and says so', () {
      fakeAsync((async) {
        start();
        keyer.recordVoiceMemory(1);
        final recording = audio.recordings.single..peak = 0;
        async.elapse(const Duration(seconds: 3));
        audio.lengths[recording.path] = const Duration(seconds: 3);
        keyer.stopVoice();
        expect(audio.replaced, isEmpty);
        expect(audio.deleted, [recording.path]);
        expect(audio.normalized, isEmpty);
        expect(keyer.problem, ComputerVoiceProblem.recordingSilent);
        expect(audio.lengths['/v/1.wav'], message);
      });
    });

    test('a recording left running stops at the ceiling', () {
      fakeAsync((async) {
        start();
        keyer.recordVoiceMemory(1);
        audio.lengths[audio.recordings.single.path] = computerVoiceRecordingCeiling;
        async.elapse(computerVoiceRecordingCeiling);
        expect(audio.recordings.single.stopped, isTrue);
        expect(reports.last, isNull);
      });
    });

    test('an unplugged input refuses rather than recording from another device', () {
      fakeAsync((async) {
        config[voiceInputConfigKey] = {'id': 'gone', 'name': 'Shure MV7'};
        start();
        keyer.recordVoiceMemory(1);
        expect(audio.recordings, isEmpty);
        expect(keyer.problem, ComputerVoiceProblem.inputMissing);
        expect(reports.single, const VoiceActivity(memory: 1, recording: true, doubtful: true));
      });
    });
  });

  // A message said from the operator's words is made as it is asked for
  // (voiced_words.dart). The traps are a carrier keyed while it is still
  // being made, a message that cannot be made keyed anyway, and one made
  // after the operator stopped it — or pressed another — keyed late.
  group('a message made as it plays', () {
    late Completer<String> making;
    setUp(() => audio.lengths['/v/made.wav'] = message);

    /// Inside each test's fake time, the completer with it: one made outside
    /// completes on the real microtask queue, which fake time never runs.
    void startMaking() {
      making = Completer<String>();
      keyer = ComputerVoiceKeyer(
        ptt: radio,
        audio: audio,
        config: () => config,
        fileFor: (n) => '/v/$n.wav',
        report: reports.add,
        prepare: (n) => n == 2 ? making.future : null,
      );
    }

    test('is made before the radio is keyed, and plays what was made', () {
      fakeAsync((async) {
        startMaking();
        keyer.playVoiceMemory(2);
        expect(radio.sent, isEmpty);
        expect(reports, [const VoiceActivity(memory: 2)], reason: 'shown going out while it is made, so the key does not look dead');
        making.complete('/v/made.wav');
        async.flushMicrotasks();
        expect(radio.sent, [true]);
        async.elapse(lead);
        expect(audio.plays.single.path, '/v/made.wav');
      });
    });

    test('a failure making it is reported though the operator moved on, and a bug as a bug', () async {
      // Dropped with the stale turn, a damaged take or a failed write goes
      // nowhere; wrapped as a sound-system failure, a bug in the making is
      // uploaded under the quiet rule meant for devices, with no notice.
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(backend: backend, () async {
        fakeAsync((async) {
          startMaking();
          keyer.playVoiceMemory(2);
          keyer.stopVoice();
          making.completeError(StateError('a bug'));
          async.flushMicrotasks();
        });
      });
      expect(radio.sent, isEmpty);
      expect([for (final e in backend.exceptions) e.error], [isA<StateError>()]);
    });

    test('one that cannot be made is refused without keying, and says what it lacks', () {
      fakeAsync((async) {
        startMaking();
        keyer.playVoiceMemory(2);
        making.completeError(const VoicedMessageRefused(ComputerVoiceProblem.wordsMissing, 'India'));
        async.flushMicrotasks();
        expect(radio.sent, isEmpty);
        expect(keyer.problem, ComputerVoiceProblem.wordsMissing);
        expect(keyer.problemDetail, 'India');
        expect(reports.last, const VoiceActivity(memory: 2, doubtful: true));
      });
    });

    test('stopped while it is made, it is never keyed', () {
      fakeAsync((async) {
        startMaking();
        keyer.playVoiceMemory(2);
        keyer.stopVoice();
        making.complete('/v/made.wav');
        async.flushMicrotasks();
        async.elapse(lead);
        expect(radio.sent, isEmpty);
        expect(audio.plays, isEmpty);
        expect(reports.last, isNull);
      });
    });

    test('another message pressed while one is made plays alone', () {
      fakeAsync((async) {
        startMaking();
        keyer.playVoiceMemory(2);
        keyer.playVoiceMemory(1);
        making.complete('/v/made.wav');
        async.flushMicrotasks();
        async.elapse(lead);
        expect(radio.sent, [true]);
        expect([for (final play in audio.plays) play.path], ['/v/1.wav']);
      });
    });
  });
}
