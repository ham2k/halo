// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio as its own SO2R switcher: two slices of one radio switching
// their audio — docs/design/cat.md § The SO2R switcher. `audio_pan` and
// `audio_mute` are the slice status fields SmartSDR reports and `slice set`
// takes; the lines here are shaped like a FLEX-6600's on 4.2.20.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/flex_dax_switch.dart';
import 'package:ham2k_logger/services/cat/drivers/flex_so2r_audio.dart';
import 'package:ham2k_logger/services/cat/drivers/flexradio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/so2r_audio.dart';

class _Sink implements EquipmentSink {
  final sent = <String>[];

  /// The `slice set` commands sent, without their `C<seq>|` envelope.
  List<String> get audio => [
    for (final line in sent)
      if (line.contains('audio_')) line.substring(line.indexOf('|') + 1).trim(),
  ];

  @override
  void send(List<int> bytes) => sent.add(utf8.decode(bytes));
  @override
  void report(VfoReading reading) {}
  @override
  void reportPower(num watts) {}
  @override
  void reportTransmitting(bool transmitting) {}
  @override
  void reportMeter(RadioMeter meter, num value) {}
  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}

const _handshake = 'V1.4.0.0\nH5AC2F980\n';

extension on FlexRadioSession {
  void feed(String text) => handleData(Uint8List.fromList(utf8.encode(text)));
  void status(int n, String fields) => feed('S5AC2F980|slice $n $fields\n');
}

void main() {
  late _Sink sink;

  setUp(() {
    FlexDaxSwitch.forgetOwed();
    FlexRadioSession.forgetSessions();
    FlexSo2rAudio.forget();
    sink = _Sink();
  });

  FlexRadioSession onSlice(_Sink by, int slice) =>
      FlexRadioSession(by, slice: slice, meterHost: 'flex.test', openMeterSocket: (host, onData, onError) async => null)..feed(_handshake);

  test('two slices of one radio are one radio: the driver names it by its address', () {
    const driver = FlexRadioDriver();
    expect(driver.so2rAudioReceiverWith({'host': 'flex.test', 'slice': '1'}), (radio: 'flex.test', receiver: 1));
    // Stored blank, a slice is slice 0 — the one a node storing '0' reads.
    expect(driver.so2rAudioReceiverWith({'host': 'flex.test', 'slice': ''}), driver.so2rAudioReceiverWith({'host': 'flex.test', 'slice': '0'}));
    expect(driver.so2rAudioReceiverWith({'slice': '0'}), isNull, reason: 'a radio with no address is no radio to compare');
  });

  test('out of focus is muted, the pan left where the operator had it', () {
    final rig = onSlice(sink, 0)..status(0, 'in_use=1 audio_pan=30 audio_mute=0');
    rig.setSo2rEar(So2rEar.muted);
    expect(sink.audio, ['slice set 0 audio_mute=1']);
  });

  test('stereo pans each slice hard to its ear, and focus centres it', () {
    final rig = onSlice(sink, 1)..status(1, 'in_use=1 audio_pan=50 audio_mute=1');
    rig.setSo2rEar(So2rEar.right);
    expect(sink.audio, ['slice set 1 audio_pan=100', 'slice set 1 audio_mute=0']);
    rig.status(1, 'audio_pan=100 audio_mute=0');
    rig.setSo2rEar(So2rEar.both);
    expect(sink.audio.sublist(2), ['slice set 1 audio_pan=50', 'slice set 1 audio_mute=0']);
  });

  test('switching stopped puts back what the operator had, not a centred, unmuted slice', () {
    final rig = onSlice(sink, 0)..status(0, 'in_use=1 audio_pan=30 audio_mute=0');
    rig.setSo2rEar(So2rEar.left);
    rig.status(0, 'audio_pan=0');
    rig.setSo2rEar(So2rEar.muted);
    rig.status(0, 'audio_mute=1');
    sink.sent.clear();
    rig.setSo2rEar(null);
    expect(sink.audio, ['slice set 0 audio_pan=30', 'slice set 0 audio_mute=0']);
  });

  test('a status push that has not caught up does not send the switch again', () {
    final rig = onSlice(sink, 0)..status(0, 'in_use=1 audio_pan=50 audio_mute=0');
    rig.setSo2rEar(So2rEar.muted);
    // The slice retuned before the mute's own status came back.
    rig.status(0, 'RF_frequency=14.025000');
    rig.status(0, 'audio_mute=0');
    expect(sink.audio, ['slice set 0 audio_mute=1']);
  });

  test('a switch asked for before the slice has said anything waits for its first status', () {
    final rig = onSlice(sink, 0);
    rig.setSo2rEar(So2rEar.muted);
    expect(sink.audio, isEmpty, reason: 'without the slice\'s own audio there is nothing to put back later');
    rig.status(0, 'in_use=1 audio_pan=50 audio_mute=0');
    expect(sink.audio, ['slice set 0 audio_mute=1']);
  });

  test('a link dropped while muted hands the restore to the next session on that slice', () {
    final first = onSlice(sink, 0)..status(0, 'in_use=1 audio_pan=50 audio_mute=0');
    first.setSo2rEar(So2rEar.muted);
    first.status(0, 'audio_mute=1');
    // Sent on teardown, where a dead socket loses it.
    first.teardown();
    expect(sink.audio.last, 'slice set 0 audio_mute=0');

    final next = _Sink();
    // Without the restore kept for the launch, this radio stays silent.
    onSlice(next, 0).status(0, 'in_use=1 audio_pan=50 audio_mute=1');
    expect(next.audio, contains('slice set 0 audio_mute=0'));
  });

  test('a slice whose status never reports its own mute is still unmuted when focus comes back', () {
    final rig = onSlice(sink, 0)..status(0, 'in_use=1 audio_pan=50 audio_mute=0');
    rig.setSo2rEar(So2rEar.both);
    rig.setSo2rEar(So2rEar.muted);
    // No `audio_mute=1` comes back: what goes out is never decided against
    // a status that may not have caught up.
    rig.setSo2rEar(So2rEar.both);
    expect(sink.audio.last, 'slice set 0 audio_mute=0');
    rig.setSo2rEar(So2rEar.muted);
    rig.setSo2rEar(null);
    expect(sink.audio.last, 'slice set 0 audio_mute=0');
  });

  test('once switching is set, the operator moving the pan on the radio is not fought', () {
    final rig = onSlice(sink, 0)..status(0, 'in_use=1 audio_pan=50 audio_mute=0');
    rig.setSo2rEar(So2rEar.left);
    final sent = sink.audio.length;
    rig.status(0, 'audio_pan=20');
    expect(sink.audio, hasLength(sent));
  });

  test('a mute the operator set by hand is undone when that radio takes focus', () {
    final rig = onSlice(sink, 0)..status(0, 'in_use=1 audio_pan=50 audio_mute=0');
    rig.setSo2rEar(So2rEar.muted);
    rig.setSo2rEar(null);
    // Muted by hand in SmartSDR after the restore.
    rig.status(0, 'audio_mute=1');
    sink.sent.clear();
    rig.setSo2rEar(So2rEar.both);
    // Focus is the radio in the headphones, whatever was done to it since
    // this session last said so.
    expect(sink.audio, contains('slice set 0 audio_mute=0'));
  });

  test('what the operator does to the slice between two runs of switching is what the second puts back', () {
    final rig = onSlice(sink, 0)..status(0, 'in_use=1 audio_pan=30 audio_mute=0');
    rig.setSo2rEar(So2rEar.left);
    rig.status(0, 'audio_pan=0');
    rig.setSo2rEar(null);
    rig.status(0, 'audio_pan=30');
    // Set by hand on the radio, with nothing switching.
    rig.status(0, 'audio_pan=70');
    rig.setSo2rEar(So2rEar.left);
    rig.setSo2rEar(null);
    expect(sink.audio.last, 'slice set 0 audio_mute=0');
    expect(sink.audio[sink.audio.length - 2], 'slice set 0 audio_pan=70');
  });

  test('a slice switched again by the next session is put back from what that session set, not what the closed one left', () {
    final first = onSlice(sink, 0)..status(0, 'in_use=1 audio_pan=50 audio_mute=0');
    first.setSo2rEar(So2rEar.left);
    first.status(0, 'audio_pan=0');
    // The link drops in stereo; the restore goes on a socket that is gone.
    first.teardown();

    final next = _Sink();
    final again = onSlice(next, 0);
    // Stereo off, focus on B, by the time A is back.
    again.setSo2rEar(So2rEar.muted);
    again.status(0, 'in_use=1 audio_pan=0 audio_mute=0');
    again.status(0, 'audio_mute=1');
    next.sent.clear();
    again.setSo2rEar(null);
    // Checked against the stereo the closed session left, the muted slice
    // reads as set by hand, and radio A stays silent for the launch.
    expect(next.audio, ['slice set 0 audio_pan=50', 'slice set 0 audio_mute=0']);
  });

  test('a session closed cleanly hands the next one nothing to undo once the slice was put back', () {
    final first = onSlice(sink, 0)..status(0, 'in_use=1 audio_pan=50 audio_mute=0');
    first.setSo2rEar(So2rEar.muted);
    first.status(0, 'audio_mute=1');
    first.teardown();

    final next = _Sink();
    // The restore landed, and the operator has muted the slice by hand since.
    onSlice(next, 0)
      ..status(0, 'in_use=1 audio_pan=20 audio_mute=0')
      ..status(0, 'audio_mute=1');
    final later = _Sink();
    onSlice(later, 0).status(0, 'in_use=1 audio_pan=20 audio_mute=1');
    expect([...next.audio, ...later.audio], isEmpty, reason: 'a later session replaying an old restore undoes what the operator set');
  });
}
