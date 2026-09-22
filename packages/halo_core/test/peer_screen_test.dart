// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The screen-frame wire format (HALO-369). The producer that writes these
// bytes is Swift (macos/Runner/ScreenCaptureChannel.swift, `wireFrame`) and
// nothing type-checks the two against each other, so what is pinned here is
// the FORMAT — byte order, field widths, and every way a malformed buffer
// can arrive off a socket without taking the link down with it.

import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

PeerScreenFrame _frame({
  String sourceId = 'display:1',
  int width = 1280,
  int height = 800,
  int sequence = 7,
  String format = 'jpeg',
  List<int> image = const [0xFF, 0xD8, 0xFF, 0xE0, 0x00],
}) => PeerScreenFrame(sourceId: sourceId, width: width, height: height, sequence: sequence, format: format, image: Uint8List.fromList(image));

void main() {
  group('PeerScreenFrame round trip', () {
    test('carries every field across', () {
      final decoded = PeerScreenFrame.decode(_frame().encode())!;
      expect(decoded.sourceId, 'display:1');
      expect(decoded.width, 1280);
      expect(decoded.height, 800);
      expect(decoded.sequence, 7);
      expect(decoded.format, 'jpeg');
      expect(decoded.image, [0xFF, 0xD8, 0xFF, 0xE0, 0x00]);
    });

    test('a header past 255 bytes survives, because the length is two bytes', () {
      // A window source's name is the app plus the window title, and a real
      // title runs long — a browser tab, a file path. With a single-byte
      // length this frame decodes against the wrong offset and every pixel
      // after it is garbage, which is invisible in a round trip built from
      // short ids.
      final longId = 'window:${'9' * 400}';
      final encoded = _frame(sourceId: longId).encode();
      expect(encoded[1], greaterThan(0), reason: 'the high byte must carry');
      final decoded = PeerScreenFrame.decode(encoded)!;
      expect(decoded.sourceId, longId);
      expect(decoded.image, [0xFF, 0xD8, 0xFF, 0xE0, 0x00]);
    });

    test('an image of zero bytes is well formed', () {
      // SCK delivers frames whose pixels have not changed; a producer that
      // ever forwards one must not have it read as corruption, because the
      // viewer's response to corruption is to drop the frame and its
      // response to an empty one is to keep what it already has.
      final decoded = PeerScreenFrame.decode(_frame(image: const []).encode())!;
      expect(decoded.image, isEmpty);
      expect(decoded.sequence, 7);
    });
  });

  group('PeerScreenFrame.decode refuses rather than throws', () {
    // Every case here arrives off a socket from a peer this build did not
    // compile. A throw would escape into the link's message handler and cost
    // the whole session; the contract is that a bad frame costs one frame.
    test('an unknown format version', () {
      final bytes = _frame().encode();
      bytes[0] = 99;
      expect(PeerScreenFrame.decode(bytes), isNull);
    });

    test('a buffer shorter than the header it declares', () {
      final bytes = _frame().encode();
      expect(PeerScreenFrame.decode(bytes.sublist(0, 5)), isNull);
    });

    test('a declared header length past the end of the buffer', () {
      final bytes = _frame().encode();
      bytes[1] = 0x0F;
      bytes[2] = 0xFF;
      expect(PeerScreenFrame.decode(bytes), isNull);
    });

    test('a header length beyond any legitimate header', () {
      final bytes = Uint8List.fromList([1, 0xFF, 0xFF, ...List.filled(70000, 0x20)]);
      expect(PeerScreenFrame.decode(bytes), isNull);
    });

    test('a header that is not JSON', () {
      final junk = utf8.encode('not json at all');
      final bytes = Uint8List.fromList([1, 0, junk.length, ...junk, 0xFF]);
      expect(PeerScreenFrame.decode(bytes), isNull);
    });

    test('a header missing the fields a viewer must have', () {
      for (final header in [
        '{"w":10,"h":10,"seq":1}', // no src
        '{"src":"display:1","h":10,"seq":1}', // no w
        '{"src":"display:1","w":10,"seq":1}', // no h
        '{"src":"display:1","w":10,"h":10}', // no seq
        '{"src":"","w":10,"h":10,"seq":1}', // blank src
        '{"src":"display:1","w":0,"h":10,"seq":1}', // zero width
      ]) {
        final encoded = utf8.encode(header);
        final bytes = Uint8List.fromList([1, encoded.length >> 8, encoded.length & 0xFF, ...encoded]);
        expect(PeerScreenFrame.decode(bytes), isNull, reason: header);
      }
    });

    test('an empty buffer', () {
      expect(PeerScreenFrame.decode(const []), isNull);
    });
  });

  group('telling a frame from an envelope', () {
    test('a PeerMessage is never mistaken for a frame', () {
      // Both formats travel between the same pair of devices. Anything that
      // ever reads from one buffer and guesses which it holds keys off this,
      // so a format version that collided with '{' would be a silent
      // cross-wiring rather than a decode failure.
      expect(PeerScreenFrame.looksLikeFrame(PeerMessage.trusted().encode()), isFalse);
      expect(PeerScreenFrame.formatVersion, isNot(utf8.encode('{').first));
    });

    test('a frame is', () {
      expect(PeerScreenFrame.looksLikeFrame(_frame().encode()), isTrue);
    });
  });

  group('PeerScreenFrame.sourceIdOf', () {
    test('agrees with a full decode', () {
      // A producer routes on this instead of decoding, to avoid copying the
      // image out of a buffer it forwards unchanged. The two readers drifting
      // apart would send one viewer another viewer's screen.
      final bytes = _frame(sourceId: 'app:org.k1jt.wsjtx').encode();
      expect(PeerScreenFrame.sourceIdOf(bytes), PeerScreenFrame.decode(bytes)!.sourceId);
    });

    test('is null for everything decode refuses', () {
      expect(PeerScreenFrame.sourceIdOf(const []), isNull);
      expect(PeerScreenFrame.sourceIdOf(PeerMessage.trusted().encode()), isNull);
      final truncated = _frame().encode().sublist(0, 4);
      expect(PeerScreenFrame.sourceIdOf(truncated), isNull);
    });
  });

  group('PeerScreenSource', () {
    test('drops only the entry it cannot read', () {
      final message = PeerMessage(PeerMessageType.screenSources, {
        'sources': [
          {'id': 'display:1', 'name': 'Built-in', 'kind': 'display'},
          {'name': 'no id at all', 'kind': 'window'},
          'not a map',
          {'id': 'app:org.k1jt.wsjtx', 'name': 'WSJT-X', 'kind': 'app'},
        ],
      });
      final sources = message.screenSourcesOrNull!;
      expect(sources.map((s) => s.id), ['display:1', 'app:org.k1jt.wsjtx']);
    });

    test('an empty offer reads as an empty list, not as absent', () {
      // An empty list is how a device says it has STOPPED sharing. A reader
      // that folded it into null would leave the viewer offering sources
      // that are gone.
      final message = PeerMessage(PeerMessageType.screenSources, {'sources': []});
      expect(message.screenSourcesOrNull, isEmpty);
      expect(PeerMessage.trusted().screenSourcesOrNull, isNull);
    });

    test('falls back rather than dropping an entry with a usable id', () {
      final source = PeerScreenSource.from({'id': 'window:12'})!;
      expect(source.name, 'window:12');
      expect(source.kind, PeerScreenSourceKind.window);
    });
  });

  group('PeerScreenSubscription', () {
    test('clamps the viewer terms instead of refusing them', () {
      // The viewer names the size and rate because it knows the pane. A
      // producer that refused an unreasonable ask would leave the pane
      // permanently blank; clamping means it always gets a stream.
      final request = PeerScreenSubscription.from({'id': 'display:1', 'maxWidth': 7680, 'fps': 240})!;
      expect(request.maxWidth, 3840);
      expect(request.fps, 30);
    });

    test('supplies defaults, but never invents a source', () {
      final request = PeerScreenSubscription.from({'id': 'display:1'})!;
      expect(request.maxWidth, 1280);
      expect(request.fps, 10);
      expect(PeerScreenSubscription.from({'maxWidth': 640}), isNull);
    });

    test('survives a round trip through a PeerMessage', () {
      const request = PeerScreenSubscription(sourceId: 'app:x', maxWidth: 800, fps: 5);
      final decoded = PeerMessage.decode(PeerMessage.screenSubscribe(request).encode())!;
      final read = decoded.screenSubscriptionOrNull!;
      expect(read.sourceId, 'app:x');
      expect(read.maxWidth, 800);
      expect(read.fps, 5);
    });

    test('carries the crop and the quality a zoomed viewer asks for', () {
      const request = PeerScreenSubscription(
        sourceId: 'app:x',
        maxWidth: 1280,
        fps: 10,
        quality: 0.8,
        crop: PeerScreenCrop(left: 0.5, top: 0.25, width: 0.25, height: 0.25),
      );
      final read = PeerMessage.decode(PeerMessage.screenSubscribe(request).encode())!.screenSubscriptionOrNull!;
      expect(read.crop, request.crop);
      expect(read.quality, 0.8);
    });

    test('a viewer that has never heard of either gets what it always got', () {
      // The producer reads both ends of this wire. A missing quality that
      // decoded as zero would encode an unreadable picture for every peer
      // on an older build.
      final old = PeerScreenSubscription.from({'id': 'display:1', 'maxWidth': 1280, 'fps': 10})!;
      expect(old.quality, PeerScreenSubscription.defaultQuality);
      expect(old.crop, isNull);
    });

    test('the terms a capture is configured with all count as terms', () {
      // Equality is what decides whether a running capture must restart.
      // A crop or a quality left out of it is a viewer asking for a
      // sharper picture and being served the old one for ever.
      const base = PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1280, fps: 10);
      expect(
        base == const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1280, fps: 10, crop: PeerScreenCrop(left: 0, top: 0, width: 0.5, height: 0.5)),
        isFalse,
      );
      expect(base == const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1280, fps: 10, quality: 0.9), isFalse);
      // Acking is how a viewer takes delivery, not a term of the capture:
      // restarting the stream because one of two viewers acks would drop
      // frames for the other.
      expect(base == const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1280, fps: 10, acks: true), isTrue);
    });
  });

  group('PeerScreenCrop', () {
    test('a crop of everything is no crop at all', () {
      // Two spellings of one thing. Left as a distinct value, the terms a
      // full-frame viewer sends stop matching the terms a running capture
      // was started at, and every subscribe restarts a stream that was
      // already serving exactly what was asked for.
      expect(PeerScreenCrop.from([0.0, 0.0, 1.0, 1.0]), isNull);
      expect(PeerScreenCrop.full.isFull, isTrue);
    });

    test('a rect panned off the edge is pulled back rather than refused', () {
      // Panning past the picture is ordinary — the viewer clamps what it
      // DRAWS, and the rect it asks for is arithmetic on the same numbers.
      final crop = PeerScreenCrop.clamped(left: 0.9, top: -0.4, width: 0.5, height: 0.5);
      expect(crop.left, closeTo(0.5, 1e-9));
      expect(crop.top, 0.0);
      expect(crop.right, lessThanOrEqualTo(1.0));
    });

    test('the union spans both viewers, and either one wanting it all wins', () {
      const topLeft = PeerScreenCrop(left: 0.0, top: 0.0, width: 0.25, height: 0.25);
      const bottomRight = PeerScreenCrop(left: 0.75, top: 0.75, width: 0.25, height: 0.25);
      final both = topLeft.union(bottomRight);
      // Two viewers zoomed into opposite corners: serving the smaller rect
      // would show one of them a picture of somewhere else entirely.
      expect(both.left, 0.0);
      expect(both.top, 0.0);
      expect(both.width, 1.0);
      expect(both.height, 1.0);
      expect(topLeft.union(PeerScreenCrop.full).isFull, isTrue);
    });

    test('a malformed rect is no crop, not a broken one', () {
      // These numbers divide into a capture's scale on the far side. A NaN
      // among them is a stream that never produces a frame, and the pane
      // cannot tell that from a peer that went away.
      expect(PeerScreenCrop.from([0.1, 0.1, double.nan, 0.5]), isNull);
      expect(PeerScreenCrop.from([0.1, 0.1, 0.5]), isNull);
      expect(PeerScreenCrop.from('half of it'), isNull);
    });
  });

  group('a cropped frame says which part it is', () {
    test('the rect survives the wire, and a full frame carries none', () {
      const crop = PeerScreenCrop(left: 0.25, top: 0.5, width: 0.25, height: 0.25);
      final decoded = PeerScreenFrame.decode(
        PeerScreenFrame(
          sourceId: 'display:1',
          width: 640,
          height: 360,
          sequence: 3,
          format: 'jpeg',
          crop: crop,
          image: Uint8List.fromList(const [1, 2, 3]),
        ).encode(),
      )!;
      // Without this the viewer draws a frame captured for where the pane
      // WAS over where it is now — the picture slides sideways for as long
      // as the far device takes to restart at the new terms.
      expect(decoded.crop, crop);
      expect(PeerScreenFrame.decode(_frame().encode())!.crop, isNull);
    });
  });

  group('PeerScreenGrant', () {
    test('survives a round trip', () {
      const grant = PeerScreenGrant(sourceId: 'display:1', ticket: 'abc123', port: 52341);
      final decoded = PeerMessage.decode(PeerMessage.screenGrant(grant).encode())!;
      final read = decoded.screenGrantOrNull!;
      expect(read.sourceId, 'display:1');
      expect(read.ticket, 'abc123');
      expect(read.port, 52341);
    });

    test('refuses a grant a viewer could not act on', () {
      // A blank ticket or a nonsense port would have the viewer dial
      // something that cannot answer and report a network failure, when what
      // actually happened is that the producer sent nonsense.
      expect(PeerScreenGrant.from({'id': 'display:1', 'ticket': '', 'port': 1}), isNull);
      expect(PeerScreenGrant.from({'id': 'display:1', 'ticket': 't', 'port': 0}), isNull);
      expect(PeerScreenGrant.from({'id': 'display:1', 'ticket': 't', 'port': 70000}), isNull);
      expect(PeerScreenGrant.from({'ticket': 't', 'port': 100}), isNull);
    });
  });

  group('the new message types stay off the version gate', () {
    test('adding them did not bump peerProtocolVersion', () {
      // Unknown types reach a peer's ephemeral channel and are ignored
      // (PeerSession._dispatch's default arm), so a build that has never
      // heard of screen sharing keeps syncing with one that has. Bumping the
      // version would instead have every older peer REFUSE the handshake.
      //
      // The pin is on the constant rather than on these types, so it also
      // catches a bump made for some other reason without one being weighed:
      // 3 is remote CAT's `radioId`, which had to bump it, and screen
      // sharing still contributes nothing.
      expect(peerProtocolVersion, 3);
    });
  });

  group('PeerScreenAck', () {
    test('survives a round trip', () {
      final decoded = PeerScreenAck.decode(const PeerScreenAck(sourceId: 'display:1', sequence: 5007).encode())!;
      expect(decoded.sourceId, 'display:1');
      expect(decoded.sequence, 5007);
    });

    test('an ack and a frame never decode as each other', () {
      // The whole reason the two share a layout but not a version byte. If
      // either could read the other, a producer would treat a frame as an
      // acknowledgement — or a viewer would try to draw one — and the
      // symptom would be a stalled stream with nothing to say why.
      final frame = PeerScreenFrame(
        sourceId: 'display:1',
        width: 8,
        height: 8,
        sequence: 3,
        format: 'jpeg',
        image: Uint8List.fromList(const [1, 2, 3]),
      ).encode();
      final ack = const PeerScreenAck(sourceId: 'display:1', sequence: 3).encode();

      expect(PeerScreenAck.decode(frame), isNull);
      expect(PeerScreenFrame.decode(ack), isNull);
      expect(PeerScreenAck.formatVersion, isNot(PeerScreenFrame.formatVersion));
    });

    test('refuses rather than throws on anything malformed', () {
      // Arrives off a socket from a build this one did not compile. A throw
      // escapes into the link's handler and costs the session.
      final good = const PeerScreenAck(sourceId: 'display:1', sequence: 3).encode();
      expect(PeerScreenAck.decode(const []), isNull);
      expect(PeerScreenAck.decode(good.sublist(0, 2)), isNull);
      final badVersion = Uint8List.fromList(good)..[0] = 99;
      expect(PeerScreenAck.decode(badVersion), isNull);
      final longHeader = Uint8List.fromList(good)
        ..[1] = 0x0F
        ..[2] = 0xFF;
      expect(PeerScreenAck.decode(longHeader), isNull);
      final junk = utf8.encode('not json');
      expect(PeerScreenAck.decode(Uint8List.fromList([2, 0, junk.length, ...junk])), isNull);
      for (final header in ['{"seq":1}', '{"src":"display:1"}', '{"src":"","seq":1}']) {
        final bytes = utf8.encode(header);
        expect(PeerScreenAck.decode(Uint8List.fromList([2, bytes.length >> 8, bytes.length & 0xFF, ...bytes])), isNull, reason: header);
      }
    });
  });

  group('the pacing capability survives the wire', () {
    test('a subscription carries its acks flag through JSON', () {
      // Everything that proves pacing engages builds a subscription in
      // process. If this field were lost in encoding — a renamed key, a
      // reader that never looks — every real viewer would be served ungated,
      // the feature would be inert in production, and nothing else in the
      // suite would notice.
      const request = PeerScreenSubscription(sourceId: 'display:1', maxWidth: 640, fps: 5, acks: true);
      final decoded = PeerScreenSubscription.from(request.toJson())!;
      expect(decoded.acks, isTrue);
      expect(decoded.sourceId, 'display:1');
    });

    test('a subscription from a build that never heard of acks reads as false', () {
      // Load-bearing: pacing a viewer that cannot answer sends one window
      // and then stops for good.
      expect(PeerScreenSubscription.from({'id': 'display:1'})!.acks, isFalse);
    });

    test('a grant carries its paced flag through JSON, and defaults to false', () {
      // The other direction. A viewer that acks a producer which never reads
      // its end of the link buffers those acks in that device's memory for
      // the life of the link.
      const grant = PeerScreenGrant(sourceId: 'display:1', ticket: 'abc', port: 5000, paced: true);
      final decoded = PeerScreenGrant.from(PeerMessage.decode(PeerMessage.screenGrant(grant).encode())!.fields)!;
      expect(decoded.paced, isTrue);
      expect(PeerScreenGrant.from({'id': 'display:1', 'ticket': 'abc', 'port': 5000})!.paced, isFalse);
    });
  });
}
