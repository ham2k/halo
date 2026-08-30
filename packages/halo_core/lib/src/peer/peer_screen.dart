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

/// The part of a source a viewer wants, as fractions of the source's own
/// width and height.
///
/// Normalized rather than pixels because the viewer never learns the
/// source's real dimensions — it sees a frame that has already been scaled
/// down, and a rect in those coordinates would mean something different on
/// the next set of terms.
///
/// A crop is what makes zooming SHARPER rather than merely bigger: the
/// producer spends its whole pixel budget on the region asked for, so the
/// bytes on the wire stay flat while the detail rises with the zoom.
class PeerScreenCrop {
  /// The whole source. The default everywhere, and the value a producer that
  /// has never heard of cropping behaves as.
  static const full = PeerScreenCrop(left: 0, top: 0, width: 1, height: 1);

  /// Smaller than this and a single pixel of pan would rewrite the terms;
  /// it is also about the point past which nothing is left to sharpen.
  static const double minSize = 0.02;

  final double left;
  final double top;
  final double width;
  final double height;

  const PeerScreenCrop({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// Clamped into the source and never inverted, so a caller may hand over
  /// whatever its pan arithmetic produced — an off-screen rect is an
  /// ordinary consequence of panning, not a fault.
  factory PeerScreenCrop.clamped({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final w = width.isFinite ? width.clamp(minSize, 1.0).toDouble() : 1.0;
    final h = height.isFinite ? height.clamp(minSize, 1.0).toDouble() : 1.0;
    return PeerScreenCrop(
      left: left.isFinite ? left.clamp(0.0, 1.0 - w).toDouble() : 0.0,
      top: top.isFinite ? top.clamp(0.0, 1.0 - h).toDouble() : 0.0,
      width: w,
      height: h,
    );
  }

  bool get isFull => width >= 1.0 && height >= 1.0;

  double get right => left + width;
  double get bottom => top + height;

  /// The smallest crop holding both — what a producer serving two viewers of
  /// one source must capture. Being generous costs resolution; serving only
  /// one of the two rects would leave the other viewer looking at a picture
  /// of somewhere else.
  PeerScreenCrop union(PeerScreenCrop other) {
    if (isFull || other.isFull) return full;
    final l = left < other.left ? left : other.left;
    final t = top < other.top ? top : other.top;
    final r = right > other.right ? right : other.right;
    final b = bottom > other.bottom ? bottom : other.bottom;
    return PeerScreenCrop.clamped(left: l, top: t, width: r - l, height: b - t);
  }

  List<double> toJson() => [left, top, width, height];

  /// Whether [raw] is a rect this build can read — four finite numbers, or
  /// nothing at all.
  ///
  /// Kept apart from [from], which answers null for a malformed rect and for
  /// the whole source alike. That conflation is right where a crop is being
  /// ASKED for: an unreadable ask means the whole source, which is what a
  /// viewer gets anyway. It is wrong on a frame, where the rect says where
  /// to draw the picture — read as "no crop", a cropped frame is stretched
  /// across the pane and re-fits the framing to itself.
  static bool isReadable(Object? raw) =>
      raw == null ||
      (raw is List && raw.length == 4 && raw.every((v) => v is num && v.isFinite));

  /// Null for anything malformed OR for the whole source, so a caller can
  /// treat "no crop" and "crop of everything" as the one case they are.
  static PeerScreenCrop? from(Object? raw) {
    if (raw is! List || raw.length != 4) return null;
    final values = [
      for (final value in raw) value is num ? value.toDouble() : double.nan,
    ];
    if (values.any((v) => !v.isFinite)) return null;
    final crop = PeerScreenCrop.clamped(
      left: values[0],
      top: values[1],
      width: values[2],
      height: values[3],
    );
    return crop.isFull ? null : crop;
  }

  @override
  bool operator ==(Object other) =>
      other is PeerScreenCrop &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'PeerScreenCrop($left, $top, $width, $height)';
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
  /// the header holds a handful of short fields.
  static const int maxHeaderBytes = 4096;

  final String sourceId;
  final int width;
  final int height;
  final int sequence;

  /// The image encoding — `jpeg` today. Carried so a producer sending
  /// something else is recognised and refused rather than rendered as
  /// garbage.
  final String format;

  /// Which part of the source this frame shows, when it is not all of it.
  ///
  /// Carried because a viewer that has just panned is still receiving frames
  /// captured for where it was a moment ago, and only the rect a frame was
  /// taken for says where to draw it. Null means the whole source — what
  /// every producer predating cropping sends, and what this one sends
  /// whenever no viewer has asked for less.
  final PeerScreenCrop? crop;

  final Uint8List image;

  const PeerScreenFrame({
    required this.sourceId,
    required this.width,
    required this.height,
    required this.sequence,
    required this.format,
    required this.image,
    this.crop,
  });

  Uint8List encode() {
    final header = utf8.encode(jsonEncode({
      'src': sourceId,
      'w': width,
      'h': height,
      'seq': sequence,
      'fmt': format,
      if (crop != null && !crop!.isFull) 'crop': crop!.toJson(),
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

    // A crop that is THERE and unreadable is not the same as one that is
    // absent. Drawn as a full frame, a cropped picture is stretched across
    // the pane and re-fits the whole framing to itself — a wrong picture,
    // convincingly. Refusing it costs a frame and routes through the same
    // "unreadable from this peer" report every other malformed frame does.
    final rawCrop = header['crop'];
    if (!PeerScreenCrop.isReadable(rawCrop)) return null;

    final format = header['fmt'];
    return PeerScreenFrame(
      sourceId: sourceId,
      width: width,
      height: height,
      sequence: sequence,
      format: format is String && format.isNotEmpty ? format : 'jpeg',
      crop: PeerScreenCrop.from(rawCrop),
      // A frame whose image is empty is still well-formed — the viewer shows
      // what it last had rather than treating the whole frame as corrupt.
      image: Uint8List.fromList(raw.sublist(3 + headerLength)),
    );
  }

  /// Whether the first byte of [raw] could begin a frame rather than a JSON
  /// envelope. Not a decode — cheap enough for a socket handler to use as a
  /// discriminator before committing to either reader.
  static bool looksLikeFrame(List<int> raw) => raw.isNotEmpty && raw[0] == formatVersion;

  /// This frame's sequence number, reading the header and nothing else.
  static int? sequenceOf(List<int> raw) => (_header(raw)?['seq'] as num?)?.toInt();

  /// Both of the fields a producer needs to route and pace a frame, from ONE
  /// read of the header. Reading them separately parses and copies the header
  /// twice per frame, per watcher — against the whole point of not unpacking
  /// a frame that is about to be forwarded unchanged.
  static ({String sourceId, int sequence})? routingOf(List<int> raw) {
    final header = _header(raw);
    if (header == null) return null;
    final sourceId = header['src'];
    final sequence = (header['seq'] as num?)?.toInt();
    if (sourceId is! String || sourceId.isEmpty || sequence == null) return null;
    return (sourceId: sourceId, sequence: sequence);
  }

  /// Which source [raw] came from, reading the header and nothing else.
  ///
  /// A producer routing a frame to whoever subscribed needs the id and not
  /// the picture; [decode] would copy every image byte out of the buffer it
  /// is about to forward unchanged, ten times a second per viewer.
  static String? sourceIdOf(List<int> raw) {
    final id = _header(raw)?['src'];
    return id is String && id.isNotEmpty ? id : null;
  }

  static Map<Object?, Object?>? _header(List<int> raw) {
    if (raw.length < 3 || raw[0] != formatVersion) return null;
    final headerLength = (raw[1] << 8) | raw[2];
    if (headerLength == 0 || headerLength > maxHeaderBytes) return null;
    if (raw.length < 3 + headerLength) return null;
    try {
      final header = jsonDecode(utf8.decode(raw.sublist(3, 3 + headerLength)));
      return header is Map ? header : null;
    } catch (_) {
      return null;
    }
  }
}

/// A viewer saying which frame it has taken delivery of.
///
/// Travels back up the MEDIA link, which is bidirectional — the control link
/// carries QSO sync, CAT and position, and ten of these a second per source
/// do not belong in front of them. It also means this state dies with the
/// link that owns it, rather than needing its own cleanup.
///
/// Same layout as [PeerScreenFrame] with its own version byte, so one shape
/// of parser covers both and neither can be mistaken for the other.
class PeerScreenAck {
  static const int formatVersion = 2;

  final String sourceId;

  /// The frame's own [PeerScreenFrame.sequence]. Nothing more is needed: the
  /// producer counts what it has sent against what has come back.
  final int sequence;

  const PeerScreenAck({required this.sourceId, required this.sequence});

  Uint8List encode() {
    final header = utf8.encode(jsonEncode({'src': sourceId, 'seq': sequence}));
    final out = Uint8List(3 + header.length);
    out[0] = formatVersion;
    out[1] = (header.length >> 8) & 0xFF;
    out[2] = header.length & 0xFF;
    out.setRange(3, out.length, header);
    return out;
  }

  /// Null for anything unreadable — an ack is advisory, and one that cannot
  /// be parsed costs a frame's worth of window, never the link.
  static PeerScreenAck? decode(List<int> raw) {
    if (raw.length < 3 || raw[0] != formatVersion) return null;
    final headerLength = (raw[1] << 8) | raw[2];
    if (headerLength == 0 || headerLength > PeerScreenFrame.maxHeaderBytes) return null;
    if (raw.length < 3 + headerLength) return null;
    final Object? header;
    try {
      header = jsonDecode(utf8.decode(raw.sublist(3, 3 + headerLength)));
    } catch (_) {
      return null;
    }
    if (header is! Map) return null;
    final sourceId = header['src'];
    final sequence = (header['seq'] as num?)?.toInt();
    if (sourceId is! String || sourceId.isEmpty || sequence == null) return null;
    return PeerScreenAck(sourceId: sourceId, sequence: sequence);
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

  /// How wide the picture the viewer wants is — of the CROP, not of the
  /// source. Zooming in therefore asks for the same number of pixels spent
  /// on a smaller region, which is what makes the bytes on the wire flat in
  /// the zoom rather than square in it.
  final int maxWidth;

  final int fps;

  /// JPEG quality, 0.1–1.0. A term of the capture like the others because a
  /// zoomed viewer is looking at compression artefacts as much as at
  /// resolution, and a cropped stream can afford to spend on them.
  final double quality;

  /// The region worth spending [maxWidth] on. Null is the whole source.
  final PeerScreenCrop? crop;

  /// Whether this viewer sends [PeerScreenAck]s, and may therefore be paced.
  ///
  /// Absent means NO, and that default is load-bearing: a peer on a build
  /// that predates acking would never answer, so a producer that paced
  /// unconditionally would send a window's worth of frames and stop for
  /// good — a worse failure than the unbounded queue this exists to fix, and
  /// a silent one. An unacked subscription is served exactly as it was
  /// before any of this.
  final bool acks;

  const PeerScreenSubscription({
    required this.sourceId,
    required this.maxWidth,
    required this.fps,
    this.quality = defaultQuality,
    this.crop,
    this.acks = false,
  });

  /// What a viewer that says nothing gets — and what every build predating
  /// negotiated quality captures at, so a producer reading an old
  /// subscription and a viewer sending a new one agree.
  static const double defaultQuality = 0.6;

  Map<String, dynamic> toJson() => {
        'id': sourceId,
        'maxWidth': maxWidth,
        'fps': fps,
        if (quality != defaultQuality) 'quality': quality,
        if (crop != null && !crop!.isFull) 'crop': crop!.toJson(),
        if (acks) 'acks': true,
      };

  static PeerScreenSubscription? from(Map<String, dynamic> fields) {
    final id = fields['id'];
    if (id is! String || id.isEmpty) return null;
    return PeerScreenSubscription(
      sourceId: id,
      maxWidth: ((fields['maxWidth'] as num?)?.toInt() ?? 1280).clamp(160, 3840),
      fps: ((fields['fps'] as num?)?.toInt() ?? 10).clamp(1, 30),
      quality: ((fields['quality'] as num?)?.toDouble() ?? defaultQuality).clamp(0.1, 1.0),
      crop: PeerScreenCrop.from(fields['crop']),
      acks: fields['acks'] == true,
    );
  }

  /// By value, because a producer decides whether to restart a running
  /// capture by comparing the terms it is already serving against the ones
  /// just asked for. On identity that comparison is always "different" and
  /// every viewer that joins tears down the stream the others are watching.
  /// [crop] and [quality] ARE part of it, for the same reason [maxWidth] is:
  /// each of the three is something the native capture is configured with,
  /// and a change to any of them is a picture the running session cannot
  /// produce. [acks] is deliberately NOT part of this. Equality decides whether a
  /// running capture must restart at new terms, and how a viewer takes
  /// delivery is not a term of the capture — restarting a stream because one
  /// of two viewers acks would drop frames for the other.
  @override
  bool operator ==(Object other) =>
      other is PeerScreenSubscription &&
      other.sourceId == sourceId &&
      other.maxWidth == maxWidth &&
      other.fps == fps &&
      other.quality == quality &&
      other.crop == crop;

  @override
  int get hashCode => Object.hash(sourceId, maxWidth, fps, quality, crop);
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

  /// Whether this producer reads acknowledgements, and the viewer should
  /// therefore send them.
  ///
  /// Absent means NO, and that default is the other half of the
  /// compatibility story [PeerScreenSubscription.acks] starts. A producer
  /// that predates pacing never reads its end of the media link, and a
  /// `PeerLink`'s inbound controller is single-subscription — so acks sent
  /// to it are BUFFERED for the life of the link, ten a second per source,
  /// growing that device's heap without bound. Which is the very failure
  /// this feature exists to remove, reintroduced on the other side of the
  /// wire by the fix for it.
  final bool paced;

  /// Whether this producer honours a [PeerScreenSubscription.crop].
  ///
  /// Absent means NO, and that default is load-bearing in the same way
  /// [paced] is. A producer predating cropping ignores the rect and serves
  /// [PeerScreenSubscription.maxWidth] across the WHOLE source — and that
  /// width is the viewer's budget for the crop, a fraction of what the
  /// full picture needs. Sent to such a peer unchanged, a zoomed pane gets
  /// a blurrier picture than it had before any of this existed.
  final bool crops;

  /// The producer's own listening port. Sent explicitly because the viewer
  /// may know this peer only as the side that dialled IT, in which case it
  /// has the address from the socket and no port at all.
  final int port;

  const PeerScreenGrant({
    required this.sourceId,
    required this.ticket,
    required this.port,
    this.paced = false,
    this.crops = false,
  });

  Map<String, dynamic> toJson() => {
        'id': sourceId,
        'ticket': ticket,
        'port': port,
        if (paced) 'paced': true,
        if (crops) 'crops': true,
      };

  static PeerScreenGrant? from(Map<String, dynamic> fields) {
    final id = fields['id'];
    final ticket = fields['ticket'];
    final port = (fields['port'] as num?)?.toInt();
    if (id is! String || id.isEmpty) return null;
    if (ticket is! String || ticket.isEmpty) return null;
    if (port == null || port <= 0 || port > 65535) return null;
    return PeerScreenGrant(
      sourceId: id,
      ticket: ticket,
      port: port,
      paced: fields['paced'] == true,
      crops: fields['crops'] == true,
    );
  }
}
