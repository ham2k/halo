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
// and anything on the same network segment can claim any id it has seen —
// the `PeerBeacon` broadcasts that id in the clear, so observing one to replay is
// trivial. The stakes are physical, not only data: a trusted peer can tune
// the addressee's rig ([catSet]), so a device that spoofs a confirmed id on
// the segment can move a real transmitter's VFO. That is an accepted v1 limit
// for a LAN of the operator's own devices, NOT a design to extend to the
// server relay or to an untrusted network. Binding trust to a key the peer
// must prove it holds is what [peerProtocolVersion] exists to be bumped for.

import 'dart:convert';
import 'dart:typed_data';

import 'peer_screen.dart';

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
/// Adding a FIELD does not qualify either, for the same reason: a peer that
/// does not know `acct` reads a hello without it, which is exactly what an
/// account-less device sends, and falls back to the narrower behaviour.
///
/// v2: sessions bind to the paired DEVICE, not to one operation.
/// `hello.operationUuid` became optional, [sharing] moves an established
/// session between operations in place, and the sync messages name their
/// operation explicitly. A v1 peer would read an omitted `operationUuid` as
/// a malformed hello and an `events` batch without knowing which cursor it
/// belongs to — both are misreads of existing fields, which is exactly what
/// this constant exists to be bumped for.
///
/// v3: a remote radio is CHOSEN. [catOffer] lists what a device is willing
/// to have driven and [catStatus]/[catSet] name which radio they are about,
/// where before the pair worked it out from who happened to have a radio
/// designated. The added field is what forces the bump, against the rule
/// stated above: a v2 controller is any radio-less older build, and it
/// broadcasts `catSet` on its operator's every tune with no selection
/// behind it at all. A v3 owner reading that as a request for its `radio1`
/// would hand a transmitter to a device nobody pointed at it — the fallback
/// is wider than the new behaviour, not narrower.
const int peerProtocolVersion = 3;

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

  /// Ephemeral, latest-value-wins: every radio this device is willing to
  /// have driven from elsewhere, as [PeerRadioOffer]s. Broadcast when the
  /// set changes and snapshotted to a session as it establishes, the same
  /// shape as [position] and [screenSources].
  ///
  /// An empty list is a real state and the one that MUST arrive: it is how
  /// a device says its last radio went away, and a controller that treats
  /// it as "nothing to update" keeps a departed rig in its picker.
  ///
  /// This is what an operator picks from. The `cat` capability in [hello]
  /// crosses once per session and names no radio, so it stays a hint for
  /// the Peers panel and is not what the picker reads.
  static const catOffer = 'catOffer';

  /// Ephemeral: where one of the sender's radios is sitting — frequency and
  /// mode only. Power and rig staleness do NOT cross yet, so a controller
  /// holds the last value it heard when the far rig goes away, exactly as
  /// the owner's own panel does.
  static const catStatus = 'catStatus';

  /// A request to tune one of the addressee's radios. Honored only from a
  /// trusted, established peer, and only for a radio that peer is currently
  /// offering — this is the message that makes the no-authentication
  /// posture (header above) load-bearing, and why it must never ride a
  /// transport that admits anyone but the operator's own paired devices.
  static const catSet = 'catSet';

  /// Ephemeral, latest-value-wins: every screen, application and window this
  /// device is currently willing to show (HALO-369). Broadcast when the set
  /// changes and snapshotted to a session as it establishes, the same shape
  /// as [position] — a viewer that missed one is corrected by the next.
  ///
  /// An empty list is a real state and the one that MUST arrive: it is how
  /// a device says it has stopped sharing, and a viewer that treats it as
  /// "nothing to update" keeps offering sources that are gone.
  static const screenSources = 'screenSources';

  /// A viewer asking for one source, at a size and rate of its choosing.
  static const screenSubscribe = 'screenSubscribe';

  /// A viewer letting go of one source. Not required for correctness — the
  /// media link closing says the same thing — but it lets the producer stop
  /// capturing on the pane being closed rather than on a socket timeout.
  static const screenUnsubscribe = 'screenUnsubscribe';

  /// The producer accepting a [screenSubscribe]: where to collect the
  /// frames, and the one-time ticket that admits the media link.
  static const screenGrant = 'screenGrant';

  /// The producer declining, with a reason the viewer can show. A pane that
  /// says why it is empty is the whole point of sending this rather than
  /// letting the request go unanswered.
  static const screenRefuse = 'screenRefuse';

  /// "Send me one still of this source, so I can show the operator what
  /// they would be picking." Answered with [screenThumb].
  ///
  /// On demand and one at a time rather than carried on the offer: a picture
  /// per source would put tens of kilobytes each into a message that is
  /// broadcast whenever anything changes, for sources nobody is looking at.
  static const screenThumbRequest = 'screenThumbRequest';

  /// One still, base64 in JSON — the picker shows a handful on demand, which
  /// is not the traffic the binary media link exists for. An answer with no
  /// image is a real answer: the source has gone, or is not offered.
  static const screenThumb = 'screenThumb';

  /// Ephemeral, latest-value-wins: the contact the sender is composing right
  /// now, so every operating position sharing an operation can be seen at
  /// once. Never persisted and never logged — this is the QSO BEFORE it is a
  /// QSO, and the durable path for a logged one is the outbox, not this.
  ///
  /// A draft with no callsign is a real state and must arrive: it is how a
  /// position says it has just logged or wiped, and a viewer that treats it
  /// as "nothing to update" leaves the last contact on screen indefinitely.
  static const qsoDraft = 'qsoDraft';
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
    String? accountTag,
    List<String> capabilities = const [],
  }) =>
      PeerMessage(PeerMessageType.hello, {
        'v': peerProtocolVersion,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'operationUuid': ?operationUuid,
        'acct': ?accountTag,
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

  /// The contact this device is composing. [qso] is sent as-is apart from
  /// `lookups`, which is dropped: it is the bulky raw evidence behind
  /// `their.guess`, nothing on the receiving end reads it, and it would ride
  /// the wire on every keystroke that changed anything.
  /// [left] says this device has stopped being a position in [operationUuid]
  /// — the operator closed it. Distinct from a draft with an empty callsign,
  /// which means they just logged or wiped and are still sitting there: one
  /// removes the block, the other keeps it and empties it.
  static PeerMessage qsoDraft({
    required Map<String, dynamic> qso,
    required String operationUuid,
    List<PeerDraftFieldPayload> fields = const [],
    String position = '',
    String operatorCall = '',
    bool left = false,
  }) {
    final their = qso['their'];
    return PeerMessage(PeerMessageType.qsoDraft, {
      'qso': {
        ...qso,
        if (their is Map) 'their': {...their}..remove('lookups'),
      },
      'opUuid': operationUuid,
      if (left) 'left': true,
      'fields': [for (final field in fields) field.toJson()],
      if (position.isNotEmpty) 'pos': position,
      if (operatorCall.isNotEmpty) 'oper': operatorCall,
    });
  }

  /// Null unless this is a well-formed [PeerMessageType.qsoDraft].
  ///
  /// A draft carrying no callsign is well-formed — that is how a position
  /// says it just logged or wiped (see [PeerMessageType.qsoDraft]) — so the
  /// only thing rejected here is a `qso` that is not an object at all.
  PeerQsoDraftPayload? get qsoDraftOrNull {
    if (type != PeerMessageType.qsoDraft) return null;
    final qso = fields['qso'];
    final operationUuid = fields['opUuid'];
    // A draft that names no operation is refused rather than shown against
    // whatever the reader happens to have open: the two devices may well be
    // in different operations, and a contact attributed to the wrong one is
    // worse than a block that never appears.
    if (qso is! Map || operationUuid is! String || operationUuid.isEmpty) return null;
    final row = this.fields['fields'];
    return PeerQsoDraftPayload(
      qso: qso.cast<String, dynamic>(),
      operationUuid: operationUuid,
      // Malformed entries are dropped one at a time rather than costing the
      // draft: this list crossed a network from a build whose row may hold
      // controls this one has never heard of, and a block missing one field
      // still says what the position is working.
      fields: row is List
          ? [for (final raw in row) if (PeerDraftFieldPayload.from(raw) case final field?) field]
          : const [],
      position: this.fields['pos'] is String ? this.fields['pos'] as String : '',
      operatorCall: this.fields['oper'] is String ? this.fields['oper'] as String : '',
      left: this.fields['left'] == true,
    );
  }

  static PeerMessage catOffer(List<PeerRadioOffer> radios) =>
      PeerMessage(PeerMessageType.catOffer, {'radios': [for (final r in radios) r.toJson()]});

  /// Null unless this is a [PeerMessageType.catOffer]. An EMPTY list is a
  /// valid answer and must be distinguishable from "not that message" —
  /// see [PeerMessageType.catOffer].
  List<PeerRadioOffer>? get catOffersOrNull {
    if (type != PeerMessageType.catOffer) return null;
    final raw = fields['radios'];
    if (raw is! List) return const [];
    return [for (final entry in raw) ?PeerRadioOffer.from(entry)];
  }

  static PeerMessage catStatus({required String radioId, double? freqKHz, String? mode}) =>
      PeerMessage(PeerMessageType.catStatus, {'radioId': radioId, 'freqKHz': ?freqKHz, 'mode': ?mode});

  static PeerMessage catSet({required String radioId, double? freqKHz, String? mode}) =>
      PeerMessage(PeerMessageType.catSet, {'radioId': radioId, 'freqKHz': ?freqKHz, 'mode': ?mode});

  /// Null unless this is a well-formed [PeerMessageType.catStatus] or
  /// [PeerMessageType.catSet] — one reader for both, since they carry the
  /// same VFO shape and differ only in direction.
  ///
  /// A message naming no radio is malformed, not a message about "the"
  /// radio. Both sides of a v3 pair always name one, so the only sender
  /// that omits it is one this build must not act for at all.
  PeerVfoPayload? get vfoOrNull {
    if (type != PeerMessageType.catStatus && type != PeerMessageType.catSet) return null;
    final radioId = fields['radioId'];
    if (radioId is! String || radioId.isEmpty) return null;
    final freqKHz = (fields['freqKHz'] as num?)?.toDouble();
    final mode = fields['mode'];
    if (freqKHz == null && mode is! String) return null;
    if (freqKHz != null && (freqKHz <= 0 || !freqKHz.isFinite)) return null;
    return PeerVfoPayload(
      radioId: radioId,
      freqKHz: freqKHz,
      mode: mode is String && mode.isNotEmpty ? mode : null,
    );
  }

  static PeerMessage screenSources(List<PeerScreenSource> sources) => PeerMessage(
      PeerMessageType.screenSources, {'sources': [for (final s in sources) s.toJson()]});

  static PeerMessage screenSubscribe(PeerScreenSubscription request) =>
      PeerMessage(PeerMessageType.screenSubscribe, request.toJson());

  static PeerMessage screenUnsubscribe(String sourceId) =>
      PeerMessage(PeerMessageType.screenUnsubscribe, {'id': sourceId});

  static PeerMessage screenGrant(PeerScreenGrant grant) =>
      PeerMessage(PeerMessageType.screenGrant, grant.toJson());

  static PeerMessage screenRefuse(String sourceId, String reason) =>
      PeerMessage(PeerMessageType.screenRefuse, {'id': sourceId, 'reason': reason});

  static PeerMessage screenThumbRequest(String sourceId) =>
      PeerMessage(PeerMessageType.screenThumbRequest, {'id': sourceId});

  /// [image] null means "nothing to show" — see [PeerMessageType.screenThumb].
  static PeerMessage screenThumb(String sourceId, List<int>? image) => PeerMessage(
      PeerMessageType.screenThumb,
      {'id': sourceId, if (image != null && image.isNotEmpty) 'jpeg': base64Encode(image)});

  /// The still a [PeerMessageType.screenThumb] carries, or null when it
  /// carries none — which is a real answer, not a malformed message.
  Uint8List? get screenThumbOrNull {
    if (type != PeerMessageType.screenThumb) return null;
    final encoded = fields['jpeg'];
    if (encoded is! String || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  /// Null unless this is a [PeerMessageType.screenSources]. An EMPTY list is
  /// a valid answer and must be distinguishable from "not that message" —
  /// which is why this returns null rather than a bare list for the latter.
  List<PeerScreenSource>? get screenSourcesOrNull {
    if (type != PeerMessageType.screenSources) return null;
    final raw = fields['sources'];
    if (raw is! List) return const [];
    return [
      for (final entry in raw) ?PeerScreenSource.from(entry),
    ];
  }

  /// Null unless this is a well-formed [PeerMessageType.screenSubscribe].
  PeerScreenSubscription? get screenSubscriptionOrNull =>
      type == PeerMessageType.screenSubscribe ? PeerScreenSubscription.from(fields) : null;

  /// Null unless this is a well-formed [PeerMessageType.screenGrant].
  PeerScreenGrant? get screenGrantOrNull =>
      type == PeerMessageType.screenGrant ? PeerScreenGrant.from(fields) : null;

  /// The source a [PeerMessageType.screenUnsubscribe] or
  /// [PeerMessageType.screenRefuse] names.
  String? get screenSourceId {
    final value = fields['id'];
    return value is String && value.isNotEmpty ? value : null;
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
    final accountTag = fields['acct'];
    return PeerHello(
      protocolVersion: version,
      deviceId: deviceId,
      deviceName: (fields['deviceName'] as String?) ?? '',
      operationUuid: operationUuid,
      // Blank is absent: an empty tag must never compare equal to another
      // empty one, or two account-less devices would read as one account.
      accountTag: accountTag is String && accountTag.isNotEmpty ? accountTag : null,
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

  /// An opaque, stable stand-in for the cloud account this device is signed
  /// in to, or null when it is signed in to none. Only ever COMPARED, never
  /// resolved back to an account: the app layer decides what it is derived
  /// from, and the hello crosses before trust, so it must not carry anything
  /// worth reading off the wire.
  ///
  /// Null never matches null. Two devices with no account cannot show they
  /// belong to one operator, and treating them as if they had would let any
  /// account-less pair share everything.
  final String? accountTag;

  /// Self-declared feature offers (`gps`, `cat`) — what the Peers panel
  /// shows and the CAT picker keys off. Advisory: honoring a capability is
  /// still gated on trust, never on this list.
  final List<String> capabilities;

  const PeerHello({
    required this.protocolVersion,
    required this.deviceId,
    required this.deviceName,
    this.operationUuid,
    this.accountTag,
    this.capabilities = const [],
  });

  /// Whether [other] is signed in to the same account as this device. False
  /// whenever either side has none — see [accountTag].
  bool sameAccountAs(String? localAccountTag) =>
      localAccountTag != null && localAccountTag.isNotEmpty && localAccountTag == accountTag;
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

/// What one operating position is composing, as its peers see it.
///
/// [qso] is the draft in the app's usual QSON shape, so a reader pulls
/// `their.call`, `our.sent` and the rest out of it exactly as it would from a
/// logged contact — and reads a lookup's answer from `their.guess` by the
/// same `AnnotatedCallInfo` convention the logging panel itself follows.
///
/// [fields] is the sender's main logging row, in the order THEIR operator
/// sees it — labels included, so a contest exchange this reader's own build
/// would not know how to name still renders under the name its extension gave
/// it. It also carries the one distinction the draft cannot: a report the
/// operator left alone arrives with an empty value and its placeholder as the
/// hint, where the draft has already folded the placeholder in and a default
/// `59` is indistinguishable from a typed one.
///
/// [position] is the sender's multi-station number (`localData
/// ['multiIdentifier']`), empty when it has none, and [operatorCall] is who is
/// at that device's key. Both are device-local, which is precisely why they
/// travel: no amount of reading the shared operation would recover them.
///
/// [operationUuid] is the operation the draft belongs to, and the reason a
/// reader can trust what it shows. A session outlives an operation change on
/// either side, so without it a peer that switched operations would leave its
/// last contact sitting in a panel that means something else entirely.
class PeerQsoDraftPayload {
  final Map<String, dynamic> qso;
  final String operationUuid;
  final List<PeerDraftFieldPayload> fields;
  final String position;
  final String operatorCall;

  /// The sender has left this operation and is no longer a position in it —
  /// its block goes, rather than going blank. See [PeerMessage.qsoDraft].
  final bool left;

  const PeerQsoDraftPayload({
    required this.qso,
    required this.operationUuid,
    this.fields = const [],
    this.position = '',
    this.operatorCall = '',
    this.left = false,
  });
}

/// One control from the sender's main logging row.
///
/// [value] is what the operator typed, [hint] the suggestion standing in while
/// they have not — a lookup's answer for a grid or state, an extension's
/// placeholder for an exchange, the report the app would send. A reader draws
/// a value as the operator's own and a hint as the app's, which is the whole
/// reason both travel rather than one resolved string.
class PeerDraftFieldPayload {
  final String key;
  final String label;
  final String value;
  final String? hint;

  const PeerDraftFieldPayload({
    required this.key,
    this.label = '',
    this.value = '',
    this.hint,
  });

  Map<String, dynamic> toJson() => {
        'k': key,
        if (label.isNotEmpty) 'l': label,
        if (value.isNotEmpty) 'v': value,
        if (hint != null && hint!.isNotEmpty) 'h': hint,
      };

  /// Null for anything without a key — a control nothing can be said about,
  /// which is not worth a slot in somebody's row.
  static PeerDraftFieldPayload? from(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['k'];
    if (key is! String || key.isEmpty) return null;
    return PeerDraftFieldPayload(
      key: key,
      label: raw['l'] is String ? raw['l'] as String : '',
      value: raw['v'] is String ? raw['v'] as String : '',
      hint: raw['h'] is String ? raw['h'] as String : null,
    );
  }
}

/// A VFO on the wire — a radio owner's report (`catStatus`) or a
/// controller's request (`catSet`). Frequencies are kHz with decimals, the
/// app-wide convention past the driver boundary (docs/design/cat.md), and
/// [mode] is already concrete: SSB is resolved to USB/LSB before anything
/// reaches a radio, so nothing here re-litigates it.
class PeerVfoPayload {
  /// Which of the sender's (for a report) or the addressee's (for a request)
  /// radios this is about — a [PeerRadioOffer.id].
  final String radioId;
  final double? freqKHz;
  final String? mode;

  const PeerVfoPayload({required this.radioId, this.freqKHz, this.mode});
}

/// One radio a peer is willing to have driven.
///
/// [id] is the offering device's own node uuid, and a controller stores it
/// alongside that device's id. Its stability across the owner restarting is
/// what makes a remembered selection re-engage by itself; an id that no
/// longer appears in the current offer is "that radio went away", never an
/// error.
class PeerRadioOffer {
  final String id;
  final String name;

  const PeerRadioOffer({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  /// Null for anything malformed, so one bad entry costs that entry rather
  /// than the peer's whole offer.
  static PeerRadioOffer? from(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    final name = raw['name'];
    return PeerRadioOffer(id: id, name: name is String && name.isNotEmpty ? name : id);
  }

  @override
  bool operator ==(Object other) => other is PeerRadioOffer && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
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
