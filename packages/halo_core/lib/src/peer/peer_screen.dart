// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Screen sharing between paired devices (HALO-369): what a peer OFFERS, and
// what a frame looks like on the wire.
//
// Offers and subscriptions are ordinary [PeerMessage]s on the control link.
// Frames are not: they are packed binary on a link of their own, because a
// JSON envelope would mean base64 (a third more bytes, plus escaping) and
// because a stream of them sharing the control socket would sit in front of
// QSO sync and CAT traffic for as long as each frame takes to write.

import 'dart:convert';
import 'dart:typed_data';

/// What kind of thing a source is. On the wire as a plain string so a peer
/// running an older build reads an unknown kind as text rather than failing
/// to decode the whole offer.
abstract final class PeerScreenSourceKind {
  static const display = 'display';
  static const app = 'app';
  static const window = 'window';
}

/// One thing a peer is willing to show.
///
/// [id] is what a viewer's panel stores, so its stability across the
/// producer restarting is a property of the kind, not of this class: a
/// display keys on its hardware id and an application on its bundle id, both
/// durable, while a window keys on a handle the OS reissues every launch.
/// A stored id that no longer appears in the current offer is "the source
/// went away", never an error.
class PeerScreenSource {
  final String id;
  final String name;
  final String kind;

  const PeerScreenSource({required this.id, required this.name, required this.kind});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'kind': kind};

  /// Null for anything malformed, so one bad entry costs that entry rather
  /// than the peer's whole offer.
  static PeerScreenSource? from(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    final name = raw['name'];
    final kind = raw['kind'];
    return PeerScreenSource(
      id: id,
      name: name is String && name.isNotEmpty ? name : id,
      kind: kind is String && kind.isNotEmpty ? kind : PeerScreenSourceKind.window,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PeerScreenSource && other.id == id && other.name == name && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, name, kind);
}

/// One captured frame, as it travels.
///
/// ```
/// byte  0      format version (1)
/// bytes 1..2   header length, big-endian uint16
/// bytes 3..    header length bytes of UTF-8 JSON
/// rest         the encoded image
/// ```
///
/// The producer's native capture code packs this directly (macOS:
/// `ScreenCaptureChannel.swift`, `wireFrame`) and the bytes reach the
/// viewer's decoder without being unpacked and repacked on the way — keep
/// the two in step.
///
/// **There is deliberately no timestamp.** A sender's wall clock is not
/// comparable against the receiver's, so an "age" computed from one would be
/// wrong by the skew between two devices; the viewer stamps arrival with its
/// own clock, and [sequence] is what orders frames and detects loss.
class PeerScreenFrame {
  static const int formatVersion = 1;

  /// A header longer than this is a corrupt or hostile frame, not a big one:
  /// the header holds five short fields.
  static const int maxHeaderBytes = 4096;

  final String sourceId;
  final int width;
  final int height;
  final int sequence;

  /// The image encoding — `jpeg` today. Carried so a producer sending
  /// something else is recognised and refused rather than rendered as
  /// garbage.
  final String format;

  final Uint8List image;

  const PeerScreenFrame({
    required this.sourceId,
    required this.width,
    required this.height,
    required this.sequence,
    required this.format,
    required this.image,
  });

  Uint8List encode() {
    final header = utf8.encode(jsonEncode({
      'src': sourceId,
      'w': width,
      'h': height,
      'seq': sequence,
      'fmt': format,
    }));
    final out = Uint8List(3 + header.length + image.length);
    out[0] = formatVersion;
    out[1] = (header.length >> 8) & 0xFF;
    out[2] = header.length & 0xFF;
    out.setRange(3, 3 + header.length, header);
    out.setRange(3 + header.length, out.length, image);
    return out;
  }

  /// Null for anything this build cannot render — a version it does not
  /// know, a truncated buffer, a header that is not JSON. Same contract as
  /// [PeerMessage.decode]: a null is dropped, never fatal to the link, so
  /// one corrupt frame costs a frame.
  static PeerScreenFrame? decode(List<int> raw) {
    if (raw.length < 3 || raw[0] != formatVersion) return null;
    final headerLength = (raw[1] << 8) | raw[2];
    if (headerLength == 0 || headerLength > maxHeaderBytes) return null;
    if (raw.length < 3 + headerLength) return null;

    final Object? header;
    try {
      header = jsonDecode(utf8.decode(raw.sublist(3, 3 + headerLength)));
    } catch (_) {
      return null;
    }
    if (header is! Map) return null;

    final sourceId = header['src'];
    final width = (header['w'] as num?)?.toInt();
    final height = (header['h'] as num?)?.toInt();
    final sequence = (header['seq'] as num?)?.toInt();
    if (sourceId is! String || sourceId.isEmpty) return null;
    if (width == null || height == null || sequence == null) return null;
    if (width <= 0 || height <= 0) return null;

    final format = header['fmt'];
    return PeerScreenFrame(
      sourceId: sourceId,
      width: width,
      height: height,
      sequence: sequence,
      format: format is String && format.isNotEmpty ? format : 'jpeg',
      // A frame whose image is empty is still well-formed — the viewer shows
      // what it last had rather than treating the whole frame as corrupt.
      image: Uint8List.fromList(raw.sublist(3 + headerLength)),
    );
  }

  /// Whether the first byte of [raw] could begin a frame rather than a JSON
  /// envelope. Not a decode — cheap enough for a socket handler to use as a
  /// discriminator before committing to either reader.
  static bool looksLikeFrame(List<int> raw) => raw.isNotEmpty && raw[0] == formatVersion;

  /// Which source [raw] came from, reading the header and nothing else.
  ///
  /// A producer routing a frame to whoever subscribed needs the id and not
  /// the picture; [decode] would copy every image byte out of the buffer it
  /// is about to forward unchanged, ten times a second per viewer.
  static String? sourceIdOf(List<int> raw) {
    if (raw.length < 3 || raw[0] != formatVersion) return null;
    final headerLength = (raw[1] << 8) | raw[2];
    if (headerLength == 0 || headerLength > maxHeaderBytes) return null;
    if (raw.length < 3 + headerLength) return null;
    try {
      final header = jsonDecode(utf8.decode(raw.sublist(3, 3 + headerLength)));
      if (header is! Map) return null;
      final id = header['src'];
      return id is String && id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }
}

/// A viewer's request for one source, and the terms it wants it on.
///
/// Both bounds are the VIEWER's to choose because it is the one that knows
/// how large the pane is and how much of the link it is willing to spend;
/// the producer clamps them to what it can actually do, so a viewer asking
/// for 4K at 60fps gets a working stream rather than a refusal.
class PeerScreenSubscription {
  final String sourceId;
  final int maxWidth;
  final int fps;

  const PeerScreenSubscription({required this.sourceId, required this.maxWidth, required this.fps});

  Map<String, dynamic> toJson() => {'id': sourceId, 'maxWidth': maxWidth, 'fps': fps};

  static PeerScreenSubscription? from(Map<String, dynamic> fields) {
    final id = fields['id'];
    if (id is! String || id.isEmpty) return null;
    return PeerScreenSubscription(
      sourceId: id,
      maxWidth: ((fields['maxWidth'] as num?)?.toInt() ?? 1280).clamp(160, 3840),
      fps: ((fields['fps'] as num?)?.toInt() ?? 10).clamp(1, 30),
    );
  }

  /// By value, because a producer decides whether to restart a running
  /// capture by comparing the terms it is already serving against the ones
  /// just asked for. On identity that comparison is always "different" and
  /// every viewer that joins tears down the stream the others are watching.
  @override
  bool operator ==(Object other) =>
      other is PeerScreenSubscription &&
      other.sourceId == sourceId &&
      other.maxWidth == maxWidth &&
      other.fps == fps;

  @override
  int get hashCode => Object.hash(sourceId, maxWidth, fps);
}

/// The producer's answer to a subscription: where to collect the frames.
///
/// The ticket is a one-time bearer token for exactly one (peer, source)
/// pair. It exists because the media link carries no `hello` and therefore
/// cannot be admitted the way the control link is — the control link, which
/// IS trusted and established, is what hands it over. It does not make the
/// media link authenticated in any sense the control link is not; it makes
/// it no WEAKER, which is the whole requirement.
class PeerScreenGrant {
  final String sourceId;
  final String ticket;

  /// The producer's own listening port. Sent explicitly because the viewer
  /// may know this peer only as the side that dialled IT, in which case it
  /// has the address from the socket and no port at all.
  final int port;

  const PeerScreenGrant({required this.sourceId, required this.ticket, required this.port});

  Map<String, dynamic> toJson() => {'id': sourceId, 'ticket': ticket, 'port': port};

  static PeerScreenGrant? from(Map<String, dynamic> fields) {
    final id = fields['id'];
    final ticket = fields['ticket'];
    final port = (fields['port'] as num?)?.toInt();
    if (id is! String || id.isEmpty) return null;
    if (ticket is! String || ticket.isEmpty) return null;
    if (port == null || port <= 0 || port > 65535) return null;
    return PeerScreenGrant(sourceId: id, ticket: ticket, port: port);
  }
}
