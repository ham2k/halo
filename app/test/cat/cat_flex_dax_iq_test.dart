// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A Flex connection's DAX IQ shared among the scopes drawing one pan: one
// slice's scope alone is covered through FlexDaxSpectrum
// (cat_flex_spectrum_test.dart).

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/drivers/flex_dax_iq.dart';

class _User implements FlexDaxIqUser {
  final rates = <int>[];
  final problems = <String?>[];

  @override
  void iqRate(int rate) => rates.add(rate);

  @override
  void iqSamples(Float32List interleaved) {}

  @override
  void iqProblem(String? message) => problems.add(message);
}

void main() {
  late List<String> sent;
  late List<void Function(int, String)> replies;
  late FlexDaxIq iq;
  late _User a, b;

  setUp(() {
    sent = [];
    replies = [];
    iq = FlexDaxIq(
      send: (command, {onReply}) {
        sent.add(command);
        if (onReply != null && command != 'sub pan all') replies.add(onReply);
      },
      pans: {
        '0x40000000': {'center': '14.200000', 'daxiq_channel': '1'},
      },
    );
    a = _User();
    b = _User();
  });

  /// [a] on the pan, with its stream granted.
  void streaming() {
    iq.join('0x40000000', a);
    replies.last(0, '20000000');
  }

  // A pan's IQ is one stream whatever number of scopes draw it: at the rate
  // of the narrowest ask, a wider display shows less than it asked for, and
  // kept at the widest once that display has gone, the stream spends the
  // radio's DAX budget on a width no display shows.
  test("a pan's stream runs at the widest rate its scopes ask, and narrows when that scope leaves", () {
    streaming();
    iq.ask(a, 96000);
    expect(sent.last, 'stream set 0x20000000 daxiq_rate=96000');
    iq.ask(b, 192000);
    iq.join('0x40000000', b);
    expect(sent.last, 'stream set 0x20000000 daxiq_rate=192000', reason: 'a slice moving onto the pan carries its ask');
    iq.leave(b, forget: true);
    expect(sent.last, 'stream set 0x20000000 daxiq_rate=96000');
  });

  // The widest ask stands in for the narrower ones: refused, the stream would stay at whatever it
  // had while another display on the pan still asks for more.
  test('a rate the radio refuses gives way to the next widest the scopes ask', () {
    iq.join('0x40000000', a);
    iq.join('0x40000000', b);
    iq.ask(a, 96000);
    iq.ask(b, 192000);
    replies.last(0, '20000000');
    expect(sent.last, 'stream set 0x20000000 daxiq_rate=192000');
    replies.last(0x50000015, '');
    expect(sent.last, 'stream set 0x20000000 daxiq_rate=96000');
  });

  // A slice moving from another pan would go on showing that pan's problem over IQ that arrives.
  test("a scope that joins a pan whose IQ arrives hears that nothing is wrong", () {
    streaming();
    iq.join('0x40000000', b);
    expect(b.problems.last, isNull);
  });

  test('a display that joins asks again for a stream the radio refused', () {
    iq.join('0x40000000', a);
    replies.last(0x50000016, '');
    sent.clear();
    iq.join('0x40000000', b);
    expect(sent, ['stream create type=dax_iq daxiq_channel=1']);
  });

  // Said once, as the wait ran out: a display opened after it would wait
  // for IQ that is not coming, saying nothing.
  test("a scope that joins a pan whose IQ is not arriving hears why", () {
    fakeAsync((async) {
      streaming();
      async.elapse(const Duration(seconds: 6));
      iq.join('0x40000000', b);
      expect(b.problems.last, t.settings.station.spectrumNoUdp);
    });
  });
}
