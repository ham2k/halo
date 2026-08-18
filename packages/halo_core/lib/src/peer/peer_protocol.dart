// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The wire format every peer transport carries (HALO-310) — LAN today, BLE
// and a server relay later. Exactly one [PeerMessage] per link message: the
// link owns framing (see [PeerLink]), so nothing here deals in byte
// boundaries or length prefixes.
//
// SECURITY, STATED PLAINLY. This protocol authenticates nothing. A peer is
// admitted on the strength of the [PeerHello.deviceId] it claims plus the
// operator having confirmed that id once (trust-on-first-use, `PeerTrust`),
// and anything on the same network segment can claim any id it has seen.
// That is an accepted v1 limit for a LAN of the operator's own devices, NOT
// a design to extend to the server relay or to an untrusted network. Binding
// trust to a key the peer must prove it holds is what [peerProtocolVersion]
// exists to be bumped for.

import 'dart:convert';

/// Bumped whenever a change would make a peer running an older version
/// MISREAD something this one sends. Adding a new message type does not
/// qualify — unknown types are ignored (see [PeerMessage.decode]) — but
/// changing the meaning of an existing field does.
///
/// The handshake refuses a peer whose version differs at all, rather than
/// attempting a compatibility range: there is exactly one version in the
/// wild today, and "refuse and say so" is a better failure than two devices
/// silently disagreeing about what a field means.
const int peerProtocolVersion = 1;

/// Message types. `t` on every envelope.
abstract final class PeerMessageType {
  /// Opens the session, both directions, unprompted: version, who I am, and
  /// which operation I am offering to share.
  static const hello = 'hello';

  /// "I have decided you may send me data." Sent once this side either
  /// already trusted the peer or the operator has just confirmed it. Data
  /// only flows once BOTH sides have sent this — see `PeerSession`.
  static const trusted = 'trusted';

  /// Terminal: this side will not proceed, with a machine-readable reason.
  static const refuse = 'refuse';

  /// "Send me your outbox after `sinceSeq`."
  static const catchUp = 'catchUp';

  /// A batch of the sender's own outbox rows.
  static const events = 'events';

  /// "I durably applied everything through `seq`."
  static const ack = 'ack';
}

/// Why a session was refused. On the wire so the far side can SAY why to its
/// own operator — a peer that silently disappears is indistinguishable from
/// one that was never there.
abstract final class PeerRefusal {
  static const protocolVersion = 'protocolVersion';
  static const differentOperation = 'differentOperation';
  static const sameDevice = 'sameDevice';
  static const notTrusted = 'notTrusted';
}

/// One decoded envelope. Deliberately a thin typed view over a JSON map
/// rather than a sealed hierarchy, matching how the rest of the core treats
/// QSON and sync payloads: the map IS the record, the class just gives
/// callers a safe way in.
class PeerMessage {
  final String type;
  final Map<String, dynamic> fields;

  const PeerMessage(this.type, [this.fields = const {}]);

  List<int> encode() => utf8.encode(jsonEncode({'t': type, ...fields}));

  /// Returns null for anything this build cannot act on — malformed bytes,
  /// non-JSON, a JSON value that isn't an object, or a missing/blank type.
  /// A null is always ignorable: the caller drops the message rather than
  /// tearing the session down, so one corrupt frame (or a newer peer's
  /// unknown message type) never costs a working link.
  static PeerMessage? decode(List<int> bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final fields = decoded.cast<String, dynamic>();
    final type = fields.remove('t');
    if (type is! String || type.isEmpty) return null;
    return PeerMessage(type, fields);
  }

  static PeerMessage hello({
    required String deviceId,
    required String deviceName,
    required String operationUuid,
  }) =>
      PeerMessage(PeerMessageType.hello, {
        'v': peerProtocolVersion,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'operationUuid': operationUuid,
      });

  static PeerMessage trusted() => const PeerMessage(PeerMessageType.trusted);

  static PeerMessage refuse(String reason) => PeerMessage(PeerMessageType.refuse, {'reason': reason});

  static PeerMessage catchUp(int sinceSeq) => PeerMessage(PeerMessageType.catchUp, {'sinceSeq': sinceSeq});

  /// [events] entries are `{seq, kind, data}` — `kind` naming which
  /// repository's `mergeFromPeer` applies `data`, exactly as `PeerEvents`
  /// stores them.
  static PeerMessage eventsBatch(List<Map<String, dynamic>> events, {required bool hasMore}) =>
      PeerMessage(PeerMessageType.events, {'events': events, 'hasMore': hasMore});

  static PeerMessage ack(int seq) => PeerMessage(PeerMessageType.ack, {'seq': seq});

  int? get intSeq => (fields['seq'] as num?)?.toInt();
  int? get intSinceSeq => (fields['sinceSeq'] as num?)?.toInt();
  bool get hasMore => fields['hasMore'] == true;
  String? get reason => fields['reason'] as String?;

  /// The `events` payload, with anything malformed dropped rather than
  /// throwing — a peer that sends one unreadable entry should cost that
  /// entry, not the batch.
  List<PeerEventPayload> get events {
    final raw = fields['events'];
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (PeerEventPayload.from(entry) case final payload?) payload,
    ];
  }

  /// Null unless this is a well-formed [PeerMessageType.hello].
  PeerHello? get helloOrNull {
    if (type != PeerMessageType.hello) return null;
    final version = (fields['v'] as num?)?.toInt();
    final deviceId = fields['deviceId'];
    final operationUuid = fields['operationUuid'];
    if (version == null || deviceId is! String || deviceId.isEmpty) return null;
    if (operationUuid is! String || operationUuid.isEmpty) return null;
    return PeerHello(
      protocolVersion: version,
      deviceId: deviceId,
      deviceName: (fields['deviceName'] as String?) ?? '',
      operationUuid: operationUuid,
    );
  }
}

class PeerHello {
  final int protocolVersion;
  final String deviceId;

  /// Self-asserted, for display only — never key anything off this.
  final String deviceName;
  final String operationUuid;

  const PeerHello({
    required this.protocolVersion,
    required this.deviceId,
    required this.deviceName,
    required this.operationUuid,
  });
}

/// One outbox row in flight.
class PeerEventPayload {
  final int seq;
  final String kind;
  final Map<String, dynamic> data;

  const PeerEventPayload({required this.seq, required this.kind, required this.data});

  Map<String, dynamic> toJson() => {'seq': seq, 'kind': kind, 'data': data};

  static PeerEventPayload? from(Object? raw) {
    if (raw is! Map) return null;
    final seq = (raw['seq'] as num?)?.toInt();
    final kind = raw['kind'];
    final data = raw['data'];
    if (seq == null || kind is! String || data is! Map) return null;
    return PeerEventPayload(seq: seq, kind: kind, data: data.cast<String, dynamic>());
  }
}

/// Values of `PeerEvents.kind` / [PeerEventPayload.kind].
abstract final class PeerEventKind {
  static const operation = 'operation';
  static const qso = 'qso';
}
