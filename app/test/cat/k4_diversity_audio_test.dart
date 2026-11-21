// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_remote_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_setting_switch.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_shared_session.dart';

/// A selected radio's ordinary stereo listening route, without a sound
/// device. Deselection can precede closing the CAT connection or its link.
class _Listener implements EquipmentSink, ReceiveAudioSink, RadioAudioLink {
  _Listener(this.engine) : ears = engine.addPulled(channels: 2);

  @override
  final AudioEngine engine;
  final AudioEndpoint ears;
  @override
  bool selectedForListening = true;
  AudioRoute? route;
  int routes = 0;

  @override
  RadioAudioLink get receiveAudio => this;

  @override
  AudioRoute hear(AudioEndpoint source, {required void Function(String reason) why}) {
    expect(source.channels, 2);
    routes++;
    return route = engine.connect(source, ears, start: Duration.zero);
  }

  (double, double) read() {
    final samples = ears.pull(2880);
    return (samples[2000], samples[2001]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Fixture {
  final engine = AudioEngine();
  final sent = <String>[];
  late final audio = StreamController<K4RemoteAudioPacket>.broadcast(sync: true);
  late final owner = K4SharedSession(send: (bytes) => sent.add(ascii.decode(bytes)), pan: const Stream.empty(), config: const {}, audio: audio.stream);
  int sequence = 0;

  (_Listener, EquipmentSession) attach(String receiver) {
    final listener = _Listener(engine);
    final session = owner.attach(listener, receiver: receiver)..startUpdates();
    return (listener, session);
  }

  void cat(String text) => owner.handleData(Uint8List.fromList(ascii.encode(text)));

  void packet({int left = 512, int right = -256, bool gap = false}) {
    if (gap) sequence++;
    final samples = Int16List(720 * 2);
    for (var frame = 0; frame < 720; frame++) {
      samples[frame * 2] = left;
      samples[frame * 2 + 1] = right;
    }
    final decoder = K4RemoteDecoder()..decodeAudio = true;
    final bytes = encodeK4RemoteAudio(sequence: sequence++, frames: 720, samples: samples);
    audio.add(decoder.add(bytes).single as K4RemoteAudioPacket);
  }

  void close() {
    owner.teardown();
    engine.close();
    unawaited(audio.close());
  }
}

void _expect((double, double) actual, (double, double) expected) {
  expect(actual.$1, closeTo(expected.$1, .01), reason: 'left ear');
  expect(actual.$2, closeTo(expected.$2, .01), reason: 'right ear');
}

void main() {
  setUp(K4SettingSwitch.forgetOwed);

  for (final receiver in ['main', 'sub']) {
    test('one $receiver listener switches from its own mono audio to stereo diversity and back without a new route', () {
      final f = _Fixture();
      addTearDown(f.close);
      final (listener, _) = f.attach(receiver);
      f.cat('EM3;EM1;DV0;SB1;');
      f.packet();
      final own = receiver == 'main' ? .5 : -.25;
      _expect(listener.read(), (own, own));

      f.cat('DV1;SB3;');
      f.packet();
      _expect(listener.read(), (.5, -.25));
      f.cat('DV0;');
      f.packet();
      _expect(listener.read(), (own, own));
      expect(listener.routes, 1, reason: 'DV changes the samples, not the operator\'s route or headphones');
      expect(f.sent.join(), isNot(contains('SB1;')), reason: 'listening never enables Sub behind the operator');
    });
  }

  test('diversity needs confirmed Sub enabled, including SB3, and falls back when Sub is off', () {
    final f = _Fixture();
    addTearDown(f.close);
    final (listener, _) = f.attach('main');
    f.cat('EM3;EM1;DV1;');
    f.packet();
    _expect(listener.read(), (.5, .5));
    f.cat('SB3;');
    f.packet();
    _expect(listener.read(), (.5, -.25));
    f.cat('SB0;');
    f.packet();
    _expect(listener.read(), (.5, .5));
    f.cat('SB1;');
    f.packet();
    _expect(listener.read(), (.5, -.25));
    expect(listener.routes, 1);
  });

  test('a disabled Sub listener stays silent and can resume stereo diversity once enabled', () {
    final f = _Fixture();
    addTearDown(f.close);
    final (listener, _) = f.attach('sub');
    f.cat('EM3;EM1;DV1;SB0;');
    f.packet();
    _expect(listener.read(), (0, 0));
    f.cat('SB3;');
    f.packet();
    _expect(listener.read(), (.5, -.25));
  });

  test('two receiver routes retain their own mono samples for ordinary SO2R gains', () {
    final f = _Fixture();
    addTearDown(f.close);
    final (main, _) = f.attach('main');
    final (sub, subSession) = f.attach('sub');
    f.cat('EM3;EM1;DV1;SB3;');
    main.route!.setGain(.5, 0);
    sub.route!.setGain(0, .25);
    f.packet();
    _expect(main.read(), (.25, 0));
    _expect(sub.read(), (0, -.0625));

    subSession.stopUpdates();
    main.route!.setGain(.5, .25);
    f.packet(gap: true);
    _expect(main.read(), (.25, -.0625));
    expect(main.routes, 1, reason: 'the remaining route can carry the pair without being replaced');
  });

  test('a Sub link left connected after leaving its logging set no longer blocks Main stereo', () {
    final f = _Fixture();
    addTearDown(f.close);
    final (main, _) = f.attach('main');
    final (sub, _) = f.attach('sub');
    f.cat('EM3;EM1;DV1;SB3;');
    f.packet();
    _expect(main.read(), (.5, .5));
    _expect(sub.read(), (-.25, -.25));

    sub.selectedForListening = false;
    f.packet();
    _expect(main.read(), (.5, -.25));
    _expect(sub.read(), (0, 0));
    sub.selectedForListening = true;
    f.packet();
    _expect(main.read(), (.5, .5));
    _expect(sub.read(), (-.25, -.25));
    expect((main.routes, sub.routes), (1, 1));
  });

  test('a connected Main link that stopped listening leaves stereo to the selected Sub link', () {
    final f = _Fixture();
    addTearDown(f.close);
    final (main, _) = f.attach('main');
    final (sub, _) = f.attach('sub');
    f.cat('EM3;EM1;DV1;SB1;');
    main.selectedForListening = false;
    f.packet();
    _expect(main.read(), (0, 0));
    _expect(sub.read(), (.5, -.25));
  });
}
