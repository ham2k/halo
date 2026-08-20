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
/// attempting a compatibility range: the population is one operator's own
/// devices, and "refuse and say so" is a better failure than two devices
/// silently disagreeing about what a field means.
///
/// v2: sessions bind to the paired DEVICE, not to one operation.
/// `hello.operationUuid` became optional, [sharing] moves an established
/// session between operations in place, and the sync messages name their
/// operation explicitly. A v1 peer would read an omitted `operationUuid` as
/// a malformed hello and an `events` batch without knowing which cursor it
/// belongs to — both are misreads of existing fields, which is exactly what
/// this constant exists to be bumped for.
const int peerProtocolVersion = 2;

/// Message types. `t` on every envelope.
abstract final class PeerMessageType {
  /// Opens the session, both directions, unprompted: version, who I am, and
  /// which operation I am sharing right now, if any.
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

  /// The sender's shared operation changed — to another operation, or to
  /// none. What moves an ESTABLISHED session between operations without
  /// tearing it down: the pair stays connected for ephemeral traffic, and
  /// the durable sync engages only while both sides share the same one.
  static const sharing = 'sharing';

  /// Ephemeral, latest-value-wins, never persisted (HALO-310's data-class
  /// model): the sender's current GPS fix. A missed one costs nothing — the
  /// next fix supersedes it, and a newly established session is sent a
  /// snapshot.
  static const position = 'position';

  /// Ephemeral: the sender's designated radio as it stands — frequency and
  /// mode only. Power and rig staleness do NOT cross yet, so a controller
  /// holds the last value it heard when the far rig goes away, exactly as
  /// the owner's own panel does.
  static const catStatus = 'catStatus';

  /// A request to tune the SENDER OF catStatus's radio. Honored only from a
  /// trusted, established peer — this is the message that makes the
  /// no-authentication posture (header above) load-bearing, and why it must
  /// never ride a transport that admits anyone but the operator's own
  /// paired devices.
  static const catSet = 'catSet';
}

/// Why a session was refused. On the wire so the far side can SAY why to its
/// own operator — a peer that silently disappears is indistinguishable from
/// one that was never there.
abstract final class PeerRefusal {
  static const protocolVersion = 'protocolVersion';
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
    String? operationUuid,
    List<String> capabilities = const [],
  }) =>
      PeerMessage(PeerMessageType.hello, {
        'v': peerProtocolVersion,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'operationUuid': ?operationUuid,
        if (capabilities.isNotEmpty) 'caps': capabilities,
      });

  /// Null means "sharing nothing now" — a real state, not an error.
  static PeerMessage sharing(String? operationUuid) => PeerMessage(
      PeerMessageType.sharing, {'operationUuid': ?operationUuid});

  static PeerMessage trusted() => const PeerMessage(PeerMessageType.trusted);

  static PeerMessage refuse(String reason) => PeerMessage(PeerMessageType.refuse, {'reason': reason});

  /// The sync messages each name their operation. A session outlives any one
  /// operation now, so "the shared operation" is a moving target: a batch
  /// still in flight when [sharing] moves the session must land against the
  /// cursor it was requested for, never whichever operation is current by
  /// the time it arrives.
  static PeerMessage catchUp(String operationUuid, int sinceSeq) =>
      PeerMessage(PeerMessageType.catchUp, {'operationUuid': operationUuid, 'sinceSeq': sinceSeq});

  /// [events] entries are `{seq, kind, data}` — `kind` naming which
  /// repository's `mergeFromPeer` applies `data`, exactly as `PeerEvents`
  /// stores them.
  static PeerMessage eventsBatch(String operationUuid, List<Map<String, dynamic>> events,
          {required bool hasMore}) =>
      PeerMessage(
          PeerMessageType.events, {'operationUuid': operationUuid, 'events': events, 'hasMore': hasMore});

  static PeerMessage ack(String operationUuid, int seq) =>
      PeerMessage(PeerMessageType.ack, {'operationUuid': operationUuid, 'seq': seq});

  static PeerMessage position({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    required int atMillis,
  }) =>
      PeerMessage(PeerMessageType.position, {
        'lat': latitude,
        'lon': longitude,
        'acc': ?accuracyMeters,
        'at': atMillis,
      });

  /// Null unless this is a well-formed [PeerMessageType.position].
  PeerPositionPayload? get positionOrNull {
    if (type != PeerMessageType.position) return null;
    final lat = (fields['lat'] as num?)?.toDouble();
    final lon = (fields['lon'] as num?)?.toDouble();
    final at = (fields['at'] as num?)?.toInt();
    if (lat == null || lon == null || at == null) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return PeerPositionPayload(
      latitude: lat,
      longitude: lon,
      accuracyMeters: (fields['acc'] as num?)?.toDouble(),
      atMillis: at,
    );
  }

  static PeerMessage catStatus({double? freqKHz, String? mode}) =>
      PeerMessage(PeerMessageType.catStatus, {'freqKHz': ?freqKHz, 'mode': ?mode});

  static PeerMessage catSet({double? freqKHz, String? mode}) =>
      PeerMessage(PeerMessageType.catSet, {'freqKHz': ?freqKHz, 'mode': ?mode});

  /// Null unless this is a well-formed [PeerMessageType.catStatus] or
  /// [PeerMessageType.catSet] — one reader for both, since they carry the
  /// same VFO shape and differ only in direction.
  PeerVfoPayload? get vfoOrNull {
    if (type != PeerMessageType.catStatus && type != PeerMessageType.catSet) return null;
    final freqKHz = (fields['freqKHz'] as num?)?.toDouble();
    final mode = fields['mode'];
    if (freqKHz == null && mode is! String) return null;
    if (freqKHz != null && (freqKHz <= 0 || !freqKHz.isFinite)) return null;
    return PeerVfoPayload(freqKHz: freqKHz, mode: mode is String && mode.isNotEmpty ? mode : null);
  }

  int? get intSeq => (fields['seq'] as num?)?.toInt();
  int? get intSinceSeq => (fields['sinceSeq'] as num?)?.toInt();
  bool get hasMore => fields['hasMore'] == true;
  String? get reason => fields['reason'] as String?;

  /// Null both when absent and when blank: an empty operation uuid means
  /// nothing anywhere else in the app, so it must not mean something here.
  String? get operationUuid {
    final value = fields['operationUuid'];
    return value is String && value.isNotEmpty ? value : null;
  }

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
    if (version == null || deviceId is! String || deviceId.isEmpty) return null;
    final caps = fields['caps'];
    return PeerHello(
      protocolVersion: version,
      deviceId: deviceId,
      deviceName: (fields['deviceName'] as String?) ?? '',
      operationUuid: operationUuid,
      capabilities: caps is List ? caps.whereType<String>().toList() : const [],
    );
  }
}

class PeerHello {
  final int protocolVersion;
  final String deviceId;

  /// Self-asserted, for display only — never key anything off this.
  final String deviceName;

  /// What the peer was sharing when it said hello — its CURRENT sharing
  /// arrives via [PeerMessageType.sharing] and lives on the session, so
  /// nothing but the session's own bookkeeping should read this. Null when
  /// it had nothing open.
  final String? operationUuid;

  /// Self-declared feature offers (`gps`, `cat`) — what the Peers panel
  /// shows and the CAT picker keys off. Advisory: honoring a capability is
  /// still gated on trust, never on this list.
  final List<String> capabilities;

  const PeerHello({
    required this.protocolVersion,
    required this.deviceId,
    required this.deviceName,
    this.operationUuid,
    this.capabilities = const [],
  });
}

/// A peer's GPS fix. [atMillis] is the SENDER's real wall clock at the fix —
/// display it as an age with the usual cross-device-skew salt, never compare
/// it against the local clock for anything load-bearing.
class PeerPositionPayload {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final int atMillis;

  const PeerPositionPayload({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    required this.atMillis,
  });
}

/// A VFO on the wire — a radio owner's report (`catStatus`) or a
/// controller's request (`catSet`). Frequencies are kHz with decimals, the
/// app-wide convention past the driver boundary (docs/design/cat.md), and
/// [mode] is already concrete: SSB is resolved to USB/LSB before anything
/// reaches a radio, so nothing here re-litigates it.
class PeerVfoPayload {
  final double? freqKHz;
  final String? mode;

  const PeerVfoPayload({this.freqKHz, this.mode});
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
