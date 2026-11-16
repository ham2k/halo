// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PTT (cat_ptt.dart): the app's key, and how it follows the radio.
//
// The traps are all about a transmitter left on the air, or an unkey sent for
// a key nobody holds: a timeout that never fires, a key the radio dropped by
// itself that the next key is taken for one still held and never sent, a key
// on one radio left on while another one keys, a client's unkey dropping a
// key it does not hold.

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_ptt.dart';
import 'package:ham2k_logger/services/cat/driver.dart';

class _FakePtt implements PttSession {
  final sent = <bool>[];
  void Function(bool on)? onSet;

  @override
  void setPtt(bool on) {
    sent.add(on);
    onSet?.call(on);
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

/// A radio the operator talks through HaLo on: what keys it for their voice
/// is [talked], and [plain] what keys it with its own mic.
class _FakeTalk extends _FakePtt implements TalkPttSession {
  final talked = <bool>[];
  bool refuse = false;

  @override
  bool get talksThroughHalo => true;

  @override
  bool setPttTalking(bool on) {
    if (on && refuse) return false;
    talked.add(on);
    return true;
  }
}

void main() {
  late _FakePtt radio;
  late CatPtt ptt;

  setUp(() {
    radio = _FakePtt();
    ptt = CatPtt();
  });

  tearDown(() => ptt.dispose());

  test('a key goes out, and a release unkeys', () {
    fakeAsync((async) {
      ptt.key(radio);
      expect(ptt.held.value, isTrue);
      ptt.onTransmitting(radio, true);
      ptt.release();
      expect(radio.sent, [true, false]);
      expect(ptt.held.value, isFalse);
    });
  });

  test('keying a radio already keyed keeps the key and its timeout, so asking again cannot hold it on longer', () {
    fakeAsync((async) {
      ptt.key(radio, timeout: const Duration(minutes: 3));
      async.elapse(const Duration(minutes: 2));
      ptt.key(radio, timeout: const Duration(minutes: 3));
      expect(radio.sent, [true]);
      async.elapse(const Duration(minutes: 1));
      expect(radio.sent, [true, false]);
    });
  });

  test('a held key drops itself at the timeout, and not before', () {
    fakeAsync((async) {
      ptt.key(radio);
      ptt.onTransmitting(radio, true);
      async.elapse(pttTimeout - const Duration(seconds: 1));
      expect(radio.sent, [true], reason: 'unkeyed early: an operator mid-over loses the key');
      async.elapse(const Duration(seconds: 1));
      expect(radio.sent, [true, false], reason: 'a forgotten key must not stay on the air');
      expect(ptt.held.value, isFalse);
    });
  });

  test('a radio that drops the key itself clears it, and the next key goes out again', () {
    fakeAsync((async) {
      ptt.key(radio);
      ptt.onTransmitting(radio, true);
      ptt.onTransmitting(radio, false);
      expect(ptt.held.value, isFalse);
      // The unkey goes out anyway: a CAT key is latched, and a report that was
      // transient or misread would leave the radio keyed with no timeout.
      expect(radio.sent, [true, false]);
      // Without following the radio, this key would be taken for one still
      // held and never sent, and ['] would unkey instead: two presses to talk.
      ptt.key(radio);
      expect(radio.sent, [true, false, true]);
      ptt.onTransmitting(radio, true);
      // And the timeout of the dropped key does not cut the new one short.
      async.elapse(pttTimeout - const Duration(seconds: 1));
      expect(radio.sent, [true, false, true]);
    });
  });

  test('a radio that reports TX as it keys is heard, so its own unkey still clears the key', () {
    fakeAsync((async) {
      radio.onSet = (on) => ptt.onTransmitting(radio, on);
      ptt.key(radio);
      // The radio's own time-out timer.
      ptt.onTransmitting(radio, false);
      expect(ptt.held.value, isFalse, reason: 'a confirmation that arrived before the key was held went unheard');
    });
  });

  test('a stale "not transmitting" before the radio confirms does not drop the key', () {
    fakeAsync((async) {
      ptt.key(radio);
      // The poll that was already on the wire when the key went out.
      ptt.onTransmitting(radio, false);
      expect(ptt.held.value, isTrue);
      expect(radio.sent, [true]);
    });
  });

  test('a radio that never reports TX keeps the key until the timeout', () {
    fakeAsync((async) {
      // A slow TX watch, a radio that cannot say, or one that refused: none
      // of them is told apart from silence, and none unkeys a working key
      // early. The timeout is what bounds them all.
      ptt.key(radio);
      async.elapse(pttTimeout - const Duration(seconds: 1));
      expect(ptt.held.value, isTrue);
      async.elapse(pttTimeout);
      expect(radio.sent, [true, false]);
    });
  });

  test('keying one radio first unkeys the other: one transmitter at a time', () {
    fakeAsync((async) {
      final other = _FakePtt();
      ptt.key(radio);
      ptt.key(other);
      expect(radio.sent, [true, false]);
      expect(other.sent, [true]);
      expect(ptt.heldOn(other), isTrue);
      expect(ptt.heldOn(radio), isFalse);
      // The other radio's TX reports are not about this key.
      ptt.onTransmitting(radio, true);
      ptt.onTransmitting(radio, false);
      expect(ptt.held.value, isTrue);
    });
  });

  test('a key held on a session that closes is forgotten, and not sent anywhere', () {
    fakeAsync((async) {
      ptt.key(radio);
      // A reconnect: the old session's teardown unkeys the radio itself.
      ptt.forget(radio);
      expect(ptt.held.value, isFalse);
      // An unkey here would go to a closed connection, and cost the operator
      // a second press to talk.
      expect(ptt.release(), isFalse);
      final replacement = _FakePtt();
      ptt.key(replacement);
      expect(radio.sent, [true]);
      expect(replacement.sent, [true], reason: 'the first key after a reconnect goes out');
      // And the old key's timeout does not cut the new one short.
      async.elapse(pttTimeout - const Duration(seconds: 1));
      expect(replacement.sent, [true]);
    });
  });

  test('closing some other session leaves the key alone', () {
    fakeAsync((async) {
      ptt.key(radio);
      ptt.forget(_FakePtt());
      expect(ptt.held.value, isTrue);
    });
  });

  test('release says whether there was a key to drop', () {
    fakeAsync((async) {
      // Escape keeps its usual meaning in the logging fields when it had
      // nothing to stop.
      expect(ptt.release(), isFalse);
      expect(radio.sent, isEmpty);
      ptt.key(radio);
      expect(ptt.release(), isTrue);
      expect(radio.sent, [true, false]);
    });
  });

  group('ownership', () {
    final client = Object(), otherClient = Object();

    test("a client's unkey drops only its own key: never the operator's over, nor another client's", () {
      fakeAsync((async) {
        ptt.key(radio);
        expect(ptt.release(owner: client), isFalse);
        ptt.release();
        ptt.key(radio, owner: otherClient);
        expect(ptt.release(owner: client), isFalse);
        expect(ptt.release(owner: otherClient), isTrue);
        expect(radio.sent, [true, false, true, false]);
      });
    });

    test("a client's key dropped some other way is no longer its own to drop", () {
      fakeAsync((async) {
        ptt.key(radio, owner: client);
        ptt.release(); // Escape
        ptt.key(radio); // and the operator keys
        expect(ptt.release(owner: client), isFalse, reason: "a client disconnecting must not end the operator's over");
        expect(ptt.held.value, isTrue);
      });
    });

    test('a client may not key while anyone else holds the key, on any radio', () {
      fakeAsync((async) {
        final other = _FakePtt();
        ptt.key(other);
        expect(ptt.key(radio, owner: client), isFalse, reason: "keying would end the operator's over on the other radio");
        expect(other.sent, [true]);
        ptt.release();

        ptt.key(radio, owner: otherClient);
        expect(ptt.key(radio, owner: client), isFalse, reason: "taking it over, this client's unkey would end the other's transmission");
        expect(ptt.owner, otherClient);
        expect(radio.sent, [true]);
      });
    });

    test("the operator keying over a client's key takes it, with the operator's timeout from then", () {
      fakeAsync((async) {
        ptt.key(radio, owner: client, timeout: const Duration(minutes: 3));
        ptt.key(radio);
        expect(ptt.owner, isNull);
        expect(ptt.release(owner: client), isFalse, reason: "the client's unkey must not end the operator's over");
        async.elapse(pttTimeout);
        expect(radio.sent, [true, false]);
      });
    });

    test('a key that throws reports that it did not go out', () {
      radio.onSet = (_) => throw StateError('port closed');
      expect(ptt.key(radio, owner: client), isFalse, reason: 'a client told OK believes it is on the air');
      expect(ptt.held.value, isFalse);
    });
  });

  group('talking through HaLo', () {
    // The operator speaks into the station's microphone, not the radio's:
    // keyed plainly, the radio sends its own mic, which nobody is speaking
    // into. A CAT server client keys for a digital-mode program that sends
    // its own DAX audio, which HaLo's stream would take the place of.
    late _FakeTalk talk;
    setUp(() => talk = _FakeTalk());

    test("the operator's key and its release go through the microphone", () {
      fakeAsync((async) {
        expect(ptt.key(talk), isTrue);
        ptt.release();
        expect(talk.talked, [true, false]);
        expect(talk.sent, isEmpty);
      });
    });

    test("a client's key keys the radio plainly, and comes off the same way", () {
      fakeAsync((async) {
        final client = Object();
        expect(ptt.key(talk, owner: client), isTrue);
        ptt.release(owner: client);
        expect(talk.sent, [true, false]);
        expect(talk.talked, isEmpty);
      });
    });

    // Keyed plainly for the program, the radio would carry the program's
    // audio, or its own mic, under the operator's key.
    test("the operator taking a client's key talks through the microphone; one the microphone cannot carry drops it", () {
      fakeAsync((async) {
        expect(ptt.key(talk, owner: Object()), isTrue);
        expect(ptt.key(talk), isTrue);
        expect(talk.talked, [true]);
        ptt.release();
        expect(talk.talked, [true, false]);

        expect(ptt.key(talk, owner: Object()), isTrue);
        talk.refuse = true;
        expect(ptt.key(talk), isFalse);
        expect(ptt.held.value, isFalse);
        expect(talk.sent.last, isFalse, reason: "the program's key comes off");
      });
    });

    test('a key the microphone cannot carry keys nothing, and holds no key', () {
      fakeAsync((async) {
        talk.refuse = true;
        expect(ptt.key(talk), isFalse);
        expect(ptt.held.value, isFalse);
        expect(talk.sent, isEmpty, reason: "never the radio's own mic instead");
        expect(ptt.release(), isFalse, reason: 'nothing to unkey');
      });
    });
  });
}
