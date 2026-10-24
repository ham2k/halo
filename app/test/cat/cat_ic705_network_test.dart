// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The IC-705 WiFi type and the packets underneath it.
//
// The byte vectors here are the corrections a wfview capture settled — each
// one a bug app-polo shipped, and each one silent on the wire rather than
// loud. They are pinned because rediscovering them costs a bench session
// with the radio, which is what it cost the first time.
//
// The other half is credential handling: the radio's password must never
// reach the SharedPreferences blob that equipment config lives in.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/icom_civ_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/poll_config.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/transports/icom_network_protocol.dart';
import 'package:ham2k_logger/services/cat/transports/icom_network_transport.dart';
import 'package:ham2k_logger/services/cat/transports/icom_network_transport_io.dart' show IcomLoginTimeout, IcomLoginRejected, IcomCredentialsMissing;
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the protocol corrections', () {
    test('the stream request names OUR ports, not the radio\'s', () {
      final packet = buildRequestStreams(
        local: 0xc2fc0000,
        remote: 0x6186d21b,
        innerSeq: 0x32,
        authId: [1, 2, 3, 4, 5, 6],
        a8ReplyId: List.filled(16, 0),
        username: 'op',
        ourSerialPort: 0xe2ed,
        ourAudioPort: 0xe0be,
        audioSampleRate: icomAudioSampleRate,
        txBufferMs: icomTxBufferMs,
        deviceName: 'IC-705',
      );

      expect(packet.length, 144);
      // app-polo put 50002/50003 here — the RADIO's own ports — which told
      // the radio to send CI-V to itself. That one substitution is the whole
      // "stream alive, no payload" symptom.
      expect(packet.sublist(124, 128), [0, 0, 0xe2, 0xed]);
      expect(packet.sublist(128, 132), [0, 0, 0xe0, 0xbe]);
      expect(packet.sublist(124, 128), isNot([0, 0, 0xc3, 0x52]), reason: 'not 50002');
    });

    test('the capabilities packet gives the token and the radio\'s name, at the IC-705\'s offsets', () {
      // Laid out as an IC-705's: its own length, type 0, the token at 66, a
      // zero-padded 32-byte name at 82, the audio device's name at 114, the
      // CI-V address at 148. The name is what the stream request sends back,
      // so a name read one byte off, or with its padding, would be a request
      // the radio may not recognise.
      List<int> capabilities(int length, {int? header}) => [
        ...le32(header ?? length),
        0,
        0,
        ...List.filled(60, 0x11),
        ...List.generate(16, (i) => i + 1),
        ...'IC-9700'.codeUnits,
        ...List.filled(25, 0),
        ...'ICOM_VAUDIO'.codeUnits,
        ...List.filled(21, 0),
        0x07,
        0x07,
        0xa2,
        ...List.filled(length - 149, 0x07),
      ];
      final read = readRadioCapabilities(capabilities(168))!;
      expect(read.token, List.generate(16, (i) => i + 1));
      expect(read.name, 'IC-9700');
      expect(read.civAddress, 0xa2);
      // Longer than the one radio captured, and saying so in its own header —
      // `a8 00 00 00` is the length 168, so a match on those bytes would
      // ignore it and time the connect out on a radio nobody has seen.
      expect(readRadioCapabilities(capabilities(270))?.name, 'IC-9700');
      expect(readRadioCapabilities(capabilities(270, header: 168)), isNull, reason: 'a header that disagrees is not this packet');
      expect(readRadioCapabilities(capabilities(168).sublist(0, 167)), isNull);
      expect(readRadioCapabilities([...capabilities(168)]..[4] = 0x01), isNull, reason: 'not type 0');
    });

    test('the radio name fills a 32-byte field, whatever its length', () {
      List<int> withName(String name) => buildRequestStreams(
        local: 1,
        remote: 2,
        innerSeq: 0,
        authId: List.filled(6, 0),
        a8ReplyId: List.filled(16, 0),
        username: 'op',
        ourSerialPort: 1000,
        ourAudioPort: 1001,
        audioSampleRate: icomAudioSampleRate,
        txBufferMs: icomTxBufferMs,
        deviceName: name,
      );
      // Padded as `8 - length` plus a fixed 24, a name past eight characters
      // throws; one that grew the packet would shift the ports the radio
      // reads at fixed offsets.
      final long = withName('IC-7300MK2');
      expect(long.length, 144);
      expect(long.sublist(64, 74), 'IC-7300MK2'.codeUnits);
      expect(long.sublist(74, 96), everyElement(0));
      expect(long.sublist(124, 128), [0, 0, 0x03, 0xe8]);
      // The IC-705's own bytes are what a capture proved, and stay so.
      expect(withName('IC-705').sublist(64, 96), [...'IC-705'.codeUnits, ...List.filled(26, 0)]);
    });

    test('the audio fields are populated, because zeroes are rejected', () {
      final packet = buildRequestStreams(
        local: 1,
        remote: 2,
        innerSeq: 0,
        authId: List.filled(6, 0),
        a8ReplyId: List.filled(16, 0),
        username: 'op',
        ourSerialPort: 1000,
        ourAudioPort: 1001,
        audioSampleRate: icomAudioSampleRate,
        txBufferMs: icomTxBufferMs,
        deviceName: 'IC-705',
      );
      // 48000 = 0xBB80. Zeroed, the radio answers 0x50 with 0xffff.
      expect(packet.sublist(116, 120), [0, 0, 0xbb, 0x80]);
      expect(packet.sublist(120, 124), [0, 0, 0xbb, 0x80]);
      expect(icomAudioSampleRate, 48000);
    });

    test('the retransmit key survives the 16-bit sequence wrap', () {
      // The wire sequence number is 16 bits and a retransmit request quotes it
      // back as 16 bits, so the map key must be the SAME value. These were
      // computed in two places and drifted: the wire got `counter & 0xFFFF`
      // while the map was keyed on the raw counter. Past 65535 every lookup
      // missed — permanently and silently, about 1h49m into a session at ten
      // idles a second, which is inside one activation.
      //
      // Round-tripping through the real stamper and the real reader is the
      // point: a test that recomputed the mask would pass against the bug.
      for (final counter in [0, 1, 255, 256, 65534, 65535, 65536, 65537, 131071, 131072]) {
        final stamped = icomStampSequence(List<int>.filled(16, 0), counter);
        expect(icomReadSequence(stamped.packet), stamped.key, reason: 'counter $counter: the key must equal what the radio quotes back');
        expect(stamped.key, lessThanOrEqualTo(0xFFFF));
      }

      // The specific failure: 65536 wraps to 0 on the wire, and the key must
      // follow it there rather than staying at 65536.
      final wrapped = icomStampSequence(List<int>.filled(16, 0), 65536);
      expect(wrapped.key, 0);
      expect(wrapped.packet[6], 0);
      expect(wrapped.packet[7], 0);

      // Short input is rejected rather than throwing a RangeError out of a
      // UDP receive handler: these are public helpers parsing network input.
      expect(icomReadSequence(List<int>.filled(4, 0)), -1, reason: 'a truncated datagram must be ignorable, not fatal');
      expect(() => icomStampSequence(List<int>.filled(4, 0), 1), throwsArgumentError);

      // And it still stamps the bytes the radio actually reads.
      final ordinary = icomStampSequence(List<int>.filled(16, 0), 0x1234);
      expect(ordinary.packet[6], 0x34, reason: 'low byte first');
      expect(ordinary.packet[7], 0x12);
      expect(ordinary.key, 0x1234);
    });

    group('the 0x18 range retransmit request', () {
      List<int> request(List<List<int>> pairs) {
        final b = List<int>.filled(16, 0, growable: true);
        b[0] = 0x18;
        b[4] = 0x01;
        for (final p in pairs) {
          b.addAll([p[0] & 0xFF, p[0] >> 8, p[1] & 0xFF, p[1] >> 8]);
        }
        return b;
      }

      test('a pair is inclusive at both ends', () {
        expect(
          icomRetransmitRange(
            request([
              [7, 10],
            ]),
            limit: 128,
          ),
          [7, 8, 9, 10],
        );
      });

      test('several pairs are all asked for', () {
        expect(
          icomRetransmitRange(
            request([
              [1, 2],
              [9, 9],
            ]),
            limit: 128,
          ),
          [1, 2, 9],
        );
      });

      test('a reversed pair contributes nothing', () {
        // Not because anything checks for it — `seq <= to` is simply false from
        // the start. Worth pinning anyway: rewriting the loop with `!=` or a
        // computed count would turn (5, 3) into a run past 65535.
        expect(
          icomRetransmitRange(
            request([
              [5, 3],
              [4, 4],
            ]),
            limit: 128,
          ),
          [4],
        );
      });

      test('a trailing partial pair is ignored, not read past the end', () {
        final b = request([
          [1, 1],
        ])..addAll([0x02, 0x00]); // two bytes: half a pair
        expect(icomRetransmitRange(b, limit: 128), [1]);
      });

      test('ONE oversized datagram cannot make us flood the network', () {
        // The finding this bound exists for. A 1500-byte packet carries 371
        // pairs; before the limit was applied to the TOTAL rather than to each
        // pair, answering it meant up to ~47,800 packets emitted synchronously
        // inside a socket callback — a ~30,000x amplification off a single
        // inbound datagram, from any host that could reach our port.
        final flood = request(List.generate(371, (i) => [0, 0xFFFF]));
        expect(flood.length, greaterThan(1400), reason: 'not actually an oversized packet');

        final asked = icomRetransmitRange(flood, limit: 128);

        expect(asked.length, 128, reason: 'a single datagram got past the bound');
      });

      test('the bound counts across pairs, not within each one', () {
        // Two pairs of 100 each are 200 sequence numbers; a per-pair bound
        // would wave both through.
        final asked = icomRetransmitRange(
          request([
            [0, 99],
            [200, 299],
          ]),
          limit: 128,
        );
        expect(asked.length, 128);
      });
    });

    test('a mid-session 0x50 is decoded as the radio ending the session', () {
      // The same readStreamAnswer the handshake uses, now also read by a
      // STANDING listener — because every handshake listener removes itself on
      // first match, so after connect() nothing consumed an 0x50 at all and
      // the radio's "I dropped you" went in the bin. `onLost` could not cover
      // it either: any inbound datagram resets it and the radio keeps pinging
      // at ~100ms, so the only thing that ever noticed was the 30-second stale
      // flag. Half a minute of a connected row with a frozen frequency.
      List<int> notice({required int m, required int b64}) {
        final b = List<int>.filled(80, 0);
        b[0] = 0x50;
        b[20] = 0x02;
        b[48] = b[49] = b[50] = m;
        b[64] = b64;
        b[66] = 0xc3;
        b[67] = 0x52;
        b[70] = 0xc3;
        b[71] = 0x53;
        return b;
      }

      // The two the standing branch acts on.
      expect(readStreamAnswer(notice(m: 0xff, b64: 0x00)), IcomStreamAnswer.authFailed);
      expect(readStreamAnswer(notice(m: 0x00, b64: 0x01)), IcomStreamAnswer.radioDisconnected);

      // And the one it must NOT act on: a healthy accepted answer arriving
      // mid-session must not tear the connection down.
      expect(readStreamAnswer(notice(m: 0x00, b64: 0x00)), IcomStreamAnswer.accepted);
    });

    test('the stream answer is read as a positive test, not a hunt for 0xffff', () {
      // Two earlier versions of this guard looked for 0xffff — first at
      // offsets 56..57, then at the port echo at 66/70 — and treated "not
      // found" as success. Both were wrong the same way: no radio has ever
      // been observed sending 0xffff, while an AUTH FAILURE carries zeros at
      // 66..71 and sailed through as accepted. We would then send the
      // serial-open into a stream the radio never opened.
      //
      // The discriminator is bytes 48..50 plus byte 64 (kappanhang, MIT).
      List<int> answer({int m = 0x00, int b64 = 0x00}) {
        final b = List<int>.filled(80, 0);
        b[0] = 0x50;
        b[20] = 0x02;
        b[48] = b[49] = b[50] = m;
        b[64] = b64;
        b[66] = 0xc3;
        b[67] = 0x52; // the radio's serial port echo, 50002
        b[70] = 0xc3;
        b[71] = 0x53; // and audio, 50003
        return b;
      }

      // Exactly what all three accepted answers in the reference capture look like.
      expect(readStreamAnswer(answer()), IcomStreamAnswer.accepted);
      expect(readStreamAnswer(answer(m: 0xff)), IcomStreamAnswer.authFailed);
      expect(readStreamAnswer(answer(b64: 0x01)), IcomStreamAnswer.radioDisconnected);

      // THE BUG: an auth failure has zeros at the port echo, so any guard
      // keyed on 0xffff there reports success. This must not.
      final authFail = answer(m: 0xff)
        ..[66] = 0
        ..[67] = 0
        ..[70] = 0
        ..[71] = 0;
      expect(readStreamAnswer(authFail), isNot(IcomStreamAnswer.accepted), reason: 'zeros at the port echo must not read as acceptance');

      // An answer we do not recognise is a failure, never optimism.
      expect(readStreamAnswer(answer(m: 0x7f)), IcomStreamAnswer.unknown);
      expect(readStreamAnswer(answer(b64: 0x99)), IcomStreamAnswer.unknown);
      expect(readStreamAnswer(List<int>.filled(40, 0)), IcomStreamAnswer.unknown, reason: 'a short packet must not crash or be accepted');

      // The port echo is corroboration: a header that says "accepted" while
      // the serial echo is zero or 0xffff is not something we understand, and
      // must not be rounded up to success. Replacing the old 0xffff hunt with
      // the 48..50 discriminator briefly dropped this check entirely.
      final noEcho = answer()
        ..[66] = 0
        ..[67] = 0;
      expect(readStreamAnswer(noEcho), IcomStreamAnswer.unknown, reason: 'accepted-looking header with no serial port echoed back');
      final refusedEcho = answer()
        ..[66] = 0xff
        ..[67] = 0xff;
      expect(readStreamAnswer(refusedEcho), IcomStreamAnswer.unknown, reason: '0xffff in the serial echo is not an acceptance');
    });

    test('CI-V datagram and payload lengths use their full width', () {
      // The datagram length is LE32 and the CI-V length LE16; both were written
      // as one byte with the high bytes hardcoded zero. Byte-identical for
      // everything we send today, silent corruption past 234 bytes.
      final short = buildCivData(1, 2, 3, [0xfe, 0xfe, 0xa4, 0xe1, 0x03, 0xfd]);
      expect(short.length, 0x15 + 6);
      expect(short.sublist(0, 4), [0x1b, 0, 0, 0], reason: 'LE32 of 27');
      expect(short[17], 6, reason: 'LE16 low byte of the CI-V length');
      expect(short[18], 0, reason: 'LE16 high byte');
      // isCivData still recognises it — the receive side must not regress.
      expect(isCivData(short), isTrue);

      // The case that used to corrupt: a 300-byte CI-V payload.
      final long = buildCivData(1, 2, 3, List.filled(300, 0x00));
      expect(long.length, 0x15 + 300);
      expect(long.sublist(0, 4), [0x41, 0x01, 0, 0], reason: 'LE32 of 321 (0x141), not 0x41 alone');
      expect(long[17], 300 & 0xFF);
      expect(long[18], 300 >> 8, reason: 'the high byte that used to be hardcoded 0');
    });

    test('the login answer is matched without pinning the radio\'s sequence counter', () {
      // Bytes 6..7 of a radio->client packet are the RADIO's monotonic outer
      // sequence counter. We used to require 0x0001 there. All three login
      // answers in the reference capture carry 0x0002 — the radio's idle timer
      // fires between pkt4 and the answer whenever it is slow to answer pkt6 —
      // so every one of them would have been silently discarded, timed out
      // after 3s, and reported as "the radio may still be holding a previous
      // session". A race, presenting as a stateful radio bug.
      List<int> loginAnswer(int seqLo, int seqHi) => [
        0x60, 0x00, 0x00, 0x00, 0x00, 0x00, seqLo, seqHi, //
        0xe3, 0x83, 0xf0, 0xa4, 0xcc, 0xee, 0x00, 0x00, //
        ...List.filled(80, 0),
      ];

      // isLoginAnswer is the predicate login() itself passes to _expect. Do
      // NOT restate the condition here: the first version of this test did,
      // and passed cleanly with the bug reinstated in the transport.
      const matches = isLoginAnswer;

      // 0x0002 is what the radio actually sent, every time, in the capture.
      expect(matches(loginAnswer(0x02, 0x00)), isTrue, reason: 'the real captured value');
      expect(matches(loginAnswer(0x01, 0x00)), isTrue, reason: 'the value we used to require');
      // And any later counter value, because it is a counter.
      expect(matches(loginAnswer(0x09, 0x00)), isTrue);
      expect(matches(loginAnswer(0x00, 0x01)), isTrue, reason: 'past 255, high byte set');

      // Still discriminating: wrong type, or wrong length, must not match.
      expect(matches([0xa8, 0, 0, 0, 0, 0, 0x02, 0, ...List.filled(88, 0)]), isFalse);
      expect(matches(loginAnswer(0x02, 0x00).sublist(0, 80)), isFalse);
    });

    test('the logout acknowledgement is told apart from our own logout request', () {
      // Both directions are the same 64-byte auth packet. These two are real,
      // lifted off a packet capture of a working client tearing a session down
      // (docs/design/ic705-teardown.md); they differ at offset 20 and nowhere
      // else structurally. If that offset drifts, logout() stops seeing the
      // answer, silently goes back to firing and hoping, and the rapid-
      // reconnect failure comes back with no visible cause.
      final ack = <int>[
        0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf4, 0x00, //
        0xe3, 0x83, 0xf0, 0xa4, 0xcc, 0xee, 0x00, 0x00, //
        0x00, 0x00, 0x00, 0x30, 0x02, 0x01, 0x00, 0x33, //
        ...List.filled(40, 0),
      ];
      final request = <int>[
        0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1d, 0x00, //
        0x67, 0xd4, 0x00, 0x00, 0xdd, 0x25, 0xda, 0xf6, //
        0x00, 0x00, 0x00, 0x30, 0x01, 0x01, 0x00, 0x33, //
        ...List.filled(40, 0),
      ];

      expect(ack.length, 64);
      expect(isLogoutAck(ack), isTrue);
      // The one that matters: our own outgoing logout must NOT match, or
      // _expect completes on the echo of our own send and we never wait.
      expect(isLogoutAck(request), isFalse);
      // And the packet we build for that request really is the shape above.
      final built = buildAuth(local: 0x67d40000, remote: 0xdd25daf6, innerSeq: 1, magic: 0x01, authId: [1, 2, 3, 4, 5, 6]);
      expect(built.length, 64);
      expect(built[20], 0x01);
      expect(isLogoutAck(built), isFalse);
    });

    test('the serial-open magic is 0x04', () {
      // polo sent 0x05; its removal commit credits a wrong magic byte as a
      // bug it found on hardware and then destroyed with the files.
      expect(icomSerialOpenMagic, 0x04);
      expect(buildSerialOpen(1, 2, 0, magic: icomSerialOpenMagic).last, 0x04);
    });

    test('the network CI-V controller address is 0xE1', () {
      // Not the 0xE0 a PC conventionally uses on a wire — polo's other lost
      // hardware fix. A wrong address is silent: the radio just ignores it.
      expect(icomNetworkControllerAddress, 0xE1);
    });

    test('a logout is a 0x40 auth with magic 0x01', () {
      // Without this the radio keeps the login and refuses every later one.
      // polo had no logout at all, which is the whole of its "inconsistent
      // run to run".
      final packet = buildAuth(local: 1, remote: 2, innerSeq: 9, magic: 0x01, authId: List.filled(6, 7));
      expect(packet.length, 64);
      expect(packet[0], 0x40);
      expect(packet[20], 0x01, reason: 'request');
      expect(packet[21], 0x01, reason: 'magic 0x01 = logout');
    });

    test('the passcode is a reversible substitution, exactly 16 bytes', () {
      // Not a hash. Sixteen bytes, zero-padded, silently truncating beyond.
      expect(passcode('op').length, 16);
      expect(passcode('').every((b) => b == 0), isTrue);
      expect(passcode('abcdefghijklmnopqrstuvwxyz').length, 16);
      // Same input, same output — it is deterministic, not salted.
      expect(passcode('hello'), passcode('hello'));
    });

    test('a CI-V payload is wrapped with its length and unwrapped again', () {
      final civ = [0xFE, 0xFE, 0xA4, 0xE1, 0x03, 0xFD];
      final packet = buildCivData(1, 2, 0, civ);
      expect(isCivData(packet), isTrue);
      expect(unwrapCiv(packet), civ);
    });
  });

  group('the equipment type', () {
    final type = EquipmentRegistry().typeFor('ic705-network')!;

    test('rides the Icom network transport', () {
      expect(type.transportKey, IcomNetworkTransport.transportKey);
      expect(type.category, kCategoryTransceiver);
    });

    test('asks for host, the radio\'s two ports, username and password — the password as a secret', () {
      final elements = type.configElements();
      // Fields only: the form also carries a divider and the troubleshooting
      // note, which have no key and ask the operator for nothing.
      expect(
        [
          for (final e in elements)
            if (e['type'] == 'field') e['key'],
        ],
        ['host', 'controlPort', 'serialPort', 'username', 'password', telemetryIntervalConfigKey, pollIntervalConfigKey],
      );
      final password = elements.firstWhere((e) => e['key'] == 'password');
      expect(password['fieldType'], 'secret', reason: 'obscured in the editor');
    });

    test('a missing host or username is refused in the editor', () {
      // A blank username fails at login with a timeout that reads as a
      // network fault, so it is caught before the socket opens.
      expect(type.validate({'host': '10.0.0.1', 'username': 'op'}), isNull);
      expect(type.validate({'host': '', 'username': 'op'}), isNotNull);
      expect(type.validate({'host': '10.0.0.1', 'username': ''}), isNotNull);
    });

    // Each is the radio's own menu setting, and a port forward moves it too.
    // A port out of range is caught here; left to the socket it fails as a
    // timeout that reads as a radio that is off.
    test('a port outside 1-65535 is refused in the editor', () {
      final ok = {'host': '10.0.0.1', 'username': 'op'};
      expect(type.validate({...ok, 'controlPort': 50101, 'serialPort': 50102}), isNull);
      expect(type.validate({...ok, 'controlPort': 0}), isNotNull);
      expect(type.validate({...ok, 'serialPort': 70000}), isNotNull);
      expect(type.validate({...ok, 'serialPort': 'abc'}), isNotNull);
    });

    test('a port the operator typed is never swapped for a guess', () {
      // The editor stores a number field it cannot parse — "5001-", or one
      // cleared — as null, and "50.002" in a locale with a decimal point
      // as 50.002. Taking the first as the factory port, or the second as
      // port 50, connects somewhere the operator never asked for, and the
      // silence that follows reads as a radio that is off.
      final ok = {'host': '10.0.0.1', 'username': 'op'};
      expect(type.validate({...ok, 'controlPort': null}), isNotNull);
      expect(type.validate({...ok, 'serialPort': ''}), isNotNull);
      expect(type.validate({...ok, 'controlPort': 50.002}), isNotNull);
      expect(type.validate({...ok, 'controlPort': 50101.0, 'serialPort': 50102}), isNull);
    });

    test('the same port for control and serial is refused', () {
      // The serial session would open on the control port, and the radio
      // answers it with silence.
      final ok = {'host': '10.0.0.1', 'username': 'op'};
      expect(type.validate({...ok, 'controlPort': 50101, 'serialPort': 50101}), isNotNull);
      expect(type.validate({...ok, 'controlPort': icomSerialPort}), isNotNull, reason: 'against the factory serial port it falls back to');
    });

    test('a node saved without ports connects on the radio\'s factory ports', () {
      // Every node saved before the fields existed holds neither, and it
      // has always connected on 50001/50002. Reading the absence as 0
      // would leave each of them unable to connect at all.
      final saved = {'host': '10.0.0.9', 'username': 'op', 'password': 'pw'};
      expect(type.validate(saved), isNull);
      final target = type.targetFor(saved);
      expect([target['controlPort'], target['serialPort']], [icomControlPort, icomSerialPort]);
    });

    test('the list row names a control port only when it is not the factory one', () {
      // Two radios behind one router differ only in their forwarded ports,
      // and rows that read the same cannot be told apart.
      expect(type.describeTarget({'host': 'home.example.net', 'controlPort': 50101}), 'home.example.net:50101');
      expect(type.describeTarget({'host': '10.0.0.9', 'controlPort': icomControlPort}), '10.0.0.9');
    });

    test('the list row shows only the host — A4 is a network protocol constant, not the operator\'s to see', () {
      // Unlike the CI-V serial pairing (where the address really is the user's
      // setting, and belongs in the row — see cat_icom_civ_test.dart), this
      // pairing hardcodes civAddress via `overrides`. A CI-V suffix here
      // would be reporting a fixed RS-BA1 fact back to the operator as if
      // it were something they configured.
      expect(type.describeTarget({'host': '10.0.0.9', 'username': 'op'}), '10.0.0.9');
    });
  });

  group('a driver\'s account of itself', () {
    late SettingsService settings;
    late CatService cat;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
      cat = CatService(settings);
    });

    tearDown(() => cat.dispose());

    test('a status transition drops the previous connection\'s diagnostic', () {
      // Connect and disconnect build a FRESH EquipmentState rather than
      // copyWith-ing the old one, and that is what keeps a note about a
      // connection that is gone off the row. Nothing else clears it.
      const carried = EquipmentState(status: EquipmentStatus.connected, diagnostic: 'IF mode offset 21 (learned)');
      expect(
        carried.copyWith(stale: true).diagnostic,
        'IF mode offset 21 (learned)',
        reason: 'a stale link is the same connection, still saying the same thing',
      );
      expect(const EquipmentState(status: EquipmentStatus.disconnected).diagnostic, isNull);
    });

    test('an explicit null clears the note, and saying nothing keeps it', () {
      // `??` cannot tell "clear this" from "I did not mention it", which is
      // the whole reason clearDiagnostic is a separate flag. Invert them and
      // a driver could never take back something it had reported.
      const said = EquipmentState(diagnostic: 'IF mode offset 15 declared, radio says 21');

      expect(said.copyWith(stale: true).diagnostic, isNotNull, reason: 'not mentioned, so kept');
      expect(said.copyWith(clearDiagnostic: true).diagnostic, isNull, reason: 'explicitly taken back');
      expect(said.copyWith(diagnostic: 'something else').diagnostic, 'something else');
    });

    test('a node nobody has connected has nothing to say', () {
      expect(cat.stateFor('no-such-node').diagnostic, isNull);
    });
  });

  group('the radio password never reaches the prefs blob', () {
    late SettingsService settings;
    late CatService cat;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      settings = SettingsService(prefs, secureStorage: FakeSecureStorage());
      cat = CatService(settings);
    });

    tearDown(() => cat.dispose());

    test('the password goes to the keychain and out of the stored config', () async {
      final node = await cat.addNode(typeKey: 'ic705-network', config: {'host': '10.0.0.9', 'username': 'op', 'password': 'hunter2'});

      // What the editor collected minus the secret.
      expect(cat.nodes.single.config['host'], '10.0.0.9');
      expect(cat.nodes.single.config.containsKey('password'), isFalse);

      // And nothing resembling it in the JSON that actually gets persisted.
      expect(settings.stationEquipment.toString(), isNot(contains('hunter2')));
      expect(await settings.equipmentSecret(node.uuid, 'password'), 'hunter2');
    });

    // The whole group above asks the question of a node whose OWN pairing
    // declares the secret. These three ask it of a node bound to a pairing
    // that does not — which is reachable the moment one radio offers two
    // transports, because the editor renders both variants' fields at once
    // and submits every value regardless of which transport is selected.
    //
    // Mutation check: scope any of the three back to the node's own pairing
    // (`_secretFieldsFor(node.typeKey)`) and the matching test fails.
    group('a pairing with no secrets of its own still holds the line', () {
      test('a password submitted on the serial pairing never reaches the blob', () async {
        // Exactly what the editor produces when the operator types the radio
        // password and then switches Connection to USB serial before saving.
        final node = await cat.addNode(
          typeKey: 'ic705-serial',
          config: {'port': '/dev/cu.usbserial', 'civAddress': 'A4', 'username': 'op', 'password': 'hunter2'},
        );

        expect(
          cat.nodes.single.config.containsKey('password'),
          isFalse,
          reason: 'SerialTransport declares no secretFields, but the value is still a credential',
        );
        expect(settings.stationEquipment.toString(), isNot(contains('hunter2')), reason: 'a radio password in the plain prefs JSON');
        // Not dropped either — switching back to WiFi has to find it.
        expect(await settings.equipmentSecret(node.uuid, 'password'), 'hunter2');
        // And what the pairing genuinely needs is untouched.
        expect(cat.nodes.single.config['port'], '/dev/cu.usbserial');
      });

      test('the placeholder still shows for a secret the current pairing does not declare', () async {
        final node = await cat.addNode(typeKey: 'ic705-network', config: {'host': '10.0.0.9', 'username': 'op', 'password': 'hunter2'});
        // The operator moves the same radio onto its USB cable.
        await cat.updateNode(cat.nodes.single.copyWith(typeKey: 'ic705-serial'));

        // Switching back must not present an empty box beside a password that
        // is still in force: an untouched save submits empty, which
        // _stashSecrets reads as "unchanged", so the stored one keeps working.
        expect(await cat.storedSecretFields(node.uuid), {'password'});
      });

      test('removing a re-typed node still takes its password with it', () async {
        final node = await cat.addNode(typeKey: 'ic705-network', config: {'host': '10.0.0.9', 'username': 'op', 'password': 'hunter2'});
        await cat.updateNode(cat.nodes.single.copyWith(typeKey: 'ic705-serial'));

        await cat.removeNode(node.uuid);

        expect(
          await settings.equipmentSecret(node.uuid, 'password'),
          isNull,
          reason: 'the node is gone and nothing left can name the field that held its password',
        );
      });
    });

    test('the editor can tell a password exists without being given it', () async {
      final node = await cat.addNode(typeKey: 'ic705-network', config: {'host': '10.0.0.9', 'username': 'op', 'password': 'hunter2'});

      // The editor renders a placeholder from THIS, so it must report which
      // fields are populated and nothing else. Returning the value — even to
      // a caller that only wanted a boolean — would put the secret into a
      // form whose values are written back on save, and the field's show/hide
      // eye would then reveal it.
      final stored = await cat.storedSecretFields(node.uuid);
      expect(stored, {'password'});
      expect(stored.toString(), isNot(contains('hunter2')));

      // A node with no secret stored reports nothing, so the Add flow and a
      // never-configured radio show a plain empty field.
      final bare = await cat.addNode(typeKey: 'ic705-network', config: {'host': '10.0.0.11', 'username': 'op'});
      expect(await cat.storedSecretFields(bare.uuid), isEmpty);

      // And a type with no secrets at all never reports one.
      final serial = await cat.addNode(typeKey: 'ft891-serial', config: {'port': '/dev/null'});
      expect(await cat.storedSecretFields(serial.uuid), isEmpty);

      // An unknown uuid must not throw — the editor may outlive a removal.
      expect(await cat.storedSecretFields('no-such-node'), isEmpty);
    });

    // NOTE: the "placeholder must never become the value" contract is pinned
    // in settings_view_station_test.dart ('a stored password shows as a hint
    // in the editor, never as a value'), because it is a property of the
    // WIDGET — that station_panel writes 'placeholder' and not 'value' — and
    // no service-level test can see it. A test that lived here and asserted
    // updateNode with a hardcoded empty password merely restated the case
    // below while claiming to guard the placeholder, and would have stayed
    // green through exactly the mutation that overwrites a real password with
    // bullets. It was removed rather than left as false assurance.

    test('saving the editor without retyping the password keeps it', () async {
      final node = await cat.addNode(typeKey: 'ic705-network', config: {'host': '10.0.0.9', 'username': 'op', 'password': 'hunter2'});

      // The editor shows secrets blank; an empty value means "unchanged",
      // not "clear it" — otherwise every unrelated edit silently unpairs
      // the radio.
      await cat.updateNode(cat.nodes.single.copyWith(config: {'host': '10.0.0.10', 'username': 'op', 'password': ''}));

      expect(cat.nodes.single.config['host'], '10.0.0.10');
      expect(await settings.equipmentSecret(node.uuid, 'password'), 'hunter2');
    });

    test('removing the node takes its password with it', () async {
      final node = await cat.addNode(typeKey: 'ic705-network', config: {'host': '10.0.0.9', 'username': 'op', 'password': 'hunter2'});
      await cat.removeNode(node.uuid);

      // The keychain entry outlives the prefs blob unless it is deleted.
      expect(await settings.equipmentSecret(node.uuid, 'password'), isNull);
    });

    test('a node with no credentials is refused before a socket opens', () async {
      final node = await cat.addNode(typeKey: 'ic705-network', config: {'host': '10.0.0.9'});
      await cat.connect(node.uuid);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.error);
    });
  });

  test('a keychain that refuses the password fails the save, loudly', () async {
    // Neither silent option is acceptable: dropping the secret loses the
    // password behind a save that looked like it worked, and keeping it in
    // the config writes a password into the plain prefs blob the user has
    // every reason to think it is NOT in. So the save fails instead.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsService(prefs, secureStorage: FakeSecureStorage(failWrites: true));
    final cat = CatService(settings);
    addTearDown(cat.dispose);

    await expectLater(
      cat.addNode(typeKey: 'ic705-network', config: {'host': '10.0.0.9', 'username': 'op', 'password': 'hunter2'}),
      throwsA(isA<EquipmentSecretNotStored>()),
    );

    // And above all, the password is not sitting in the prefs blob.
    expect(settings.stationEquipment.toString(), isNot(contains('hunter2')));
  });

  test('the editor explains the silence this transport actually produces', () {
    // The failure mode is a handshake that succeeds and a login that is
    // ignored. Every remedy is something the operator does at the radio or to
    // another program, which makes the editor the place to say it.
    final type = EquipmentRegistry().typeFor('ic705-network')!;
    final note = type.configElements().firstWhere((e) => e['type'] == 'markdown');
    final text = note['text'] as String;
    expect(text, contains('wfview'), reason: 'the other client that holds the one session');
    expect(text, contains('WLAN'), reason: 'the reliable way to clear a held session');

    // This used to require "Retype the password" FIRST, because the rejection
    // path was inherited untested and a stale credential could not be told
    // apart from a busy radio. Confirmed on hardware: a wrong password is
    // refused explicitly. So the copy now rules the password OUT instead of
    // leading with it, and this asserts that it says so.
    expect(
      text,
      contains('refused explicitly'),
      reason:
          'a wrong password is confirmed to produce a refusal, not silence, so the '
          'operator should not be sent to re-check it when they see a timeout',
    );

    // Speculative advice that was built on a bug that was ours. If any of it
    // comes back, this fails.
    expect(text, isNot(contains('Wait about a minute')));
    expect(text, isNot(contains('prolong')));
    expect(text, isNot(contains('releases it more slowly')));
  });

  test('a login timeout names checks the operator can act on, not a guess', () {
    // This test used to REQUIRE the message to say the radio was "holding a
    // previous session" and to advise waiting. That diagnosis was wrong: the
    // cause was our own login-answer matcher pinning the radio's sequence
    // counter, and this message is what sent everyone to investigate the
    // radio instead.
    final message = const IcomLoginTimeout().toString();

    // Actionable: the one thing that genuinely produces a silent login now.
    expect(message, contains('other program'));

    // And NOT the password. It cannot cause this path — empty throws
    // IcomCredentialsMissing before a packet goes out, wrong produces
    // IcomLoginRejected — so naming it here sends the operator to retype a
    // correct password, and directly contradicts the troubleshooting note in
    // the same editor, which tells them the password is not the problem.
    // This test previously REQUIRED the contradiction.
    expect(message, isNot(contains('password')));

    // And the speculation must not come back. If a future change reinstates
    // it, this fails rather than quietly re-misleading people.
    expect(message, isNot(contains('holding a previous session')));
    expect(message, isNot(contains('wait a few seconds')));
  });

  test('a refused credential is distinct from a timeout', () {
    // Retrying fixes one and never fixes the other, so they must not read
    // the same.
    expect(const IcomLoginRejected().toString(), contains('rejected'));
    expect(const IcomCredentialsMissing().toString(), contains('required'));
  });

  test('the registry offers every model\'s every variant over seven transports', () {
    final registry = EquipmentRegistry();
    expect(registry.typeFor('ic705-network')?.key, 'ic705-network');
    // Derived from the models, so a variant added to one has to appear here
    // without anything else being edited — including the placeholder every
    // real transceiver gains.
    expect(registry.types, hasLength(150));
    expect(registry.models, hasLength(56));
    expect(registry.transports.keys, containsAll(['tcp', 'serial', 'bluetoothSerial', 'bleSerial', 'icom-network', 'k4-remote', 'placeholder']));
  });

  // A wrong CI-V address is answered with silence. Each network entry has
  // to address the radio its serial entry ships for — and on a LAN radio,
  // whose CI-V ADDRESS is in its menu, let the operator change it.
  test('every Icom network entry addresses its own radio, on its factory ports', () {
    final registry = EquipmentRegistry();
    final networked = registry.types.where((type) => type.transportKey == IcomNetworkTransport.transportKey);
    expect(networked.map((type) => type.model.key), unorderedEquals(['ic705', 'ic7300mk2', 'ic7610', 'ic7760', 'ic9700', 'ic905', 'ic7850', 'ic7851']));
    for (final type in networked) {
      final serial = registry.typeFor('${type.model.key}-serial')!;
      final config = type.driverConfig({...type.defaultConfig, 'host': '10.0.0.9', 'username': 'op'});
      expect(config['civAddress'], serial.defaultConfig['civAddress'], reason: type.key);
      expect(config['civControllerAddress'], icomNetworkControllerAddress, reason: type.key);
      expect([type.defaultConfig['controlPort'], type.defaultConfig['serialPort']], [icomControlPort, icomSerialPort], reason: type.key);
      if (type.key == 'ic705-network') continue;
      final fields = [for (final e in type.configElements()) e['key']];
      expect(fields, contains('civAddress'), reason: type.key);
    }
  });

  group('what the driver is told, versus what the user typed', () {
    final type = EquipmentRegistry().typeFor('ic705-network')!;

    test('the network controller address is injected, not asked for', () {
      // 0xE1, not the 0xE0 a PC uses on a CI-V wire. The bench tool that
      // achieved the verified exchange used 0xE1; nothing in the app ever
      // set it, so every in-app connection spoke 0xE0 — and a wrong CI-V
      // address is SILENT, the radio simply ignores the frames. It is a
      // fact about the transport, so the type supplies it.
      final driverConfig = type.driverConfig({'host': '10.0.0.9', 'username': 'op'});
      expect(driverConfig['civControllerAddress'], icomNetworkControllerAddress);
      expect(driverConfig['civControllerAddress'], 0xE1);

      // And the user is never asked for it.
      expect([for (final e in type.configElements()) e['key']], isNot(contains('civControllerAddress')));
    });

    test('a session built from it addresses the radio as 0xE1', () {
      final sink = _CountingSink();
      final session = const IcomCivDriver().createSession(sink, type.driverConfig({'host': '10.0.0.9', 'username': 'op'})) as IcomCivSession;
      expect(session.controllerAddress, 0xE1);

      // Which is what ends up in the `from` byte on the wire.
      session.setFrequency(14074);
      expect(sink.sent.single[3], 0xE1);
    });

    test('a type declares its own secrets, rather than the manager naming it', () {
      // A manager that asked "is this the IC-705 type?" would write the
      // NEXT type's password into the plain prefs blob, silently.
      expect(type.secretFields, {'password'});
      expect(EquipmentRegistry().typeFor('icom-generic-serial')!.secretFields, isEmpty);
      expect(EquipmentRegistry().typeFor('ft891-serial')!.secretFields, isEmpty);
    });
  });
}

class _CountingSink implements EquipmentSink {
  final problems = <String?>[];
  List<EquipmentChannel> channels = const [];
  final sent = <List<int>>[];
  @override
  void send(List<int> bytes) => sent.add(bytes);
  @override
  void report(VfoReading reading) {}
  @override
  void reportPower(num watts) {}

  final txReports = <bool>[];
  final meterReports = <(RadioMeter, num)>[];
  @override
  void reportTransmitting(bool transmitting) => txReports.add(transmitting);
  @override
  void reportMeter(RadioMeter meter, num value) => meterReports.add((meter, value));

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
  void reportProblem(String? message) => problems.add(message);

  @override
  void reportChannels(List<EquipmentChannel> channels) => this.channels = channels;

  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}
