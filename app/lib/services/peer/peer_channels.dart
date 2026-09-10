// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Routes the peer sessions' ephemeral channel to the app services that
// produce and consume it (HALO-334). One router rather than each feature
// registering its own callback on `PeerService`: those are single slots, and
// the second feature to claim one would silently unplug the first.
//
// Everything in this file is latest-value-wins and lossy by design — a
// missed message is superseded by the next one, and a newly established
// session is caught up by a snapshot.
//
// THE CAT BRIDGE runs through `RadioService`, deliberately NOT through a
// peer-backed equipment node in the registry: everything above the
// `EquipmentSession` boundary — the `VfoOrigin` echo discipline, VFO snap,
// the logging panel — is transport-blind, so feeding `vfoA` directly
// inherits the whole tune path in both directions for the price of a few
// message handlers. The cost accepted: a remote radio has no Station-panel
// inventory row and no settings of its own.
//
// The two directions are NOT roles a device falls into. Offering and
// controlling are independent (HALO-416): this device offers every radio it
// has connected, whoever is using them, and separately follows one radio a
// peer offers if — and only if — its operator picked that one out of the
// main-VFO list. A device can do both at once, and neither happens by
// accident, which is what stands between a paired phone and a transmitter
// nobody pointed it at.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:halo_core/halo_core.dart';

import '../cat/equipment.dart';
import '../location_service.dart';
import '../radio_service.dart';
import 'peer_drafts.dart';
import 'peer_remote_radios.dart';
import 'peer_screen_views.dart';
import 'peer_screens.dart';
import 'peer_service.dart';
import 'peer_station_radios.dart';
import 'serial_claims.dart';

class PeerChannels {
  PeerChannels({
    required this.peers,
    required this.location,
    this.radio,
    this.screens,
    this.views,
    this.drafts,
    this.claims,
    this.station,
    this.remoteRadios,
  }) {
    peers.onEphemeral = _onEphemeral;
    peers.onSessionEstablished = _onSessionEstablished;
    peers.addListener(_onPeersChanged);
    location.addListener(_onLocationChanged);
    radio?.addListener(_onRadioChanged);
    station?.addListener(_onStationChanged);
    station?.keyingChanges.addListener(_onKeyingChanged);
    station?.sendPeerKeyRequest = _sendKeyRequest;
  }

  final PeerService peers;
  final LocationService location;
  final RadioService? radio;

  /// Screen sharing (HALO-369), each half optional so a build with the
  /// experiment off constructs neither and this router simply has nothing to
  /// hand those messages to.
  final PeerScreens? screens;
  final PeerScreenViews? views;

  /// Live logging state, each way (HALO-395). Optional for the same reason
  /// the screen halves are: a build with the experiment off constructs none
  /// of it, and this router then has nowhere to hand those messages — which
  /// is what keeps them from being routed at all.
  final PeerDrafts? drafts;

  /// The serial numbers held per position (HALO-476), gated with [drafts]:
  /// both are the live-logging half of peer sync.
  final SerialClaims? claims;

  /// Peers that had an established session when this last looked — the
  /// before-picture a loss is spotted against. `PeerService` reports
  /// connection changes through a single callback slot that the status bar
  /// already holds, so a second consumer reconciles rather than subscribes.
  final Set<String> _establishedPeers = {};

  /// This device's own radios, as the bridge sees them — what it offers,
  /// where those radios are sitting, how to tune one, and which peer radio
  /// its operator picked. Null for a build with no station at all, which
  /// then neither offers nor follows anything.
  ///
  /// Only CONNECTED radios are ever offered ([PeerStationRadios.offeredRadios]),
  /// and that is what keeps a tune request from moving app state on a rig
  /// that is not there and reaching the asker exactly like a confirmation
  /// from the rig — both screens then showing a frequency the radio is not
  /// on, and contacts logged against it. Nothing on the wire says staleness
  /// yet, so withdrawing the offer is the honest signal available.
  final PeerStationRadios? station;

  /// What the peers are offering, for the picker. Optional like the rest of
  /// the consumer halves: without it this router still routes offers
  /// nowhere and nothing can be picked.
  final PeerRemoteRadios? remoteRadios;

  /// Whether THIS router should be holding the GPS stream open for the
  /// peers' benefit — the intent, set synchronously. Whether the listener
  /// was actually TAKEN is settled by [_startGps]'s completion, on the far
  /// side of an awaited permission check: `LocationService.start`/`stop` is
  /// reference-counted, and both an unreleased listener (GPS running forever
  /// for a peer that left mid-check) and an unbalanced stop (stripping a
  /// view's own subscription) live in that window.
  bool _sharingGps = false;

  /// Whether the listener was actually taken — what a stop must balance.
  /// Distinct from [_sharingGps] (the intent): between a start and its
  /// completion the intent is true and this is false, and stopping on the
  /// intent in that window strips someone else's subscription.
  bool _gpsHeld = false;

  /// Invalidates an in-flight [_startGps] — the `attemptSeq` pattern. Bumped
  /// whenever the intent flips off, so a start that lands late releases the
  /// listener it just took instead of leaking it.
  int _gpsAttempt = 0;

  double? _lastSentLat;
  double? _lastSentLon;

  void dispose() {
    // `==`, not `identical`: every mention of an instance method allocates a
    // fresh tear-off, so `identical` is false even against this router's own
    // handler and the unhook would never run. `==` is true for tear-offs of
    // the same method on the same receiver — and false for another router's,
    // which is the case the guard exists for.
    if (peers.onEphemeral == _onEphemeral) peers.onEphemeral = null;
    if (peers.onSessionEstablished == _onSessionEstablished) {
      peers.onSessionEstablished = null;
    }
    peers.removeListener(_onPeersChanged);
    location.removeListener(_onLocationChanged);
    radio?.removeListener(_onRadioChanged);
    station?.removeListener(_onStationChanged);
    station?.keyingChanges.removeListener(_onKeyingChanged);
    // Same `==` reasoning as the callbacks above: another router's sender
    // must survive this one's disposal.
    if (station?.sendPeerKeyRequest == _sendKeyRequest) station?.sendPeerKeyRequest = null;
    _sharingGps = false;
    // The bump makes an in-flight start's completion release what it takes;
    // the stop below balances a take that already landed.
    _gpsAttempt++;
    if (_gpsHeld) {
      _gpsHeld = false;
      location.stop();
    }
  }

  bool get _anyEstablished =>
      peers.peers.values.any((runtime) => runtime.session?.established ?? false);

  void _onPeersChanged() {
    // Start this device's GPS only while someone is there to receive it, and
    // ONLY if the OS permission is already granted — a peer connecting must
    // never pop a location prompt the operator did not invite
    // (LocationService.startIfPermitted). The operator grants permission the
    // first time they use a location feature themselves; from then on the
    // park case is automatic.
    final wanted = _anyEstablished;
    if (wanted && !_sharingGps) {
      _sharingGps = true;
      _startGps();
    } else if (!wanted && _sharingGps) {
      _sharingGps = false;
      _gpsAttempt++;
      // Stop only what was TAKEN. A start still awaiting its permission
      // check has taken nothing — a stop here would strip whichever view
      // holds the stream — and its completion releases its own take via the
      // attempt bump above.
      if (_gpsHeld) {
        _gpsHeld = false;
        location.stop();
      }
      _lastSentLat = null;
      _lastSentLon = null;
    }

    _reconcileDepartedPeers();

    // A peer that dropped must not keep standing in for this device's
    // location: its last fix could be hours old by the time anyone looks.
    final providerId = location.peerPositionProviderId;
    if (providerId != null) {
      final providing = peers.peers[providerId]?.session;
      if (providing == null || !providing.established) {
        location.setPeerPosition(null, deviceId: providerId);
      }
    }
  }

  void _startGps() {
    final attempt = ++_gpsAttempt;
    unawaited(location.startIfPermitted().then((started) {
      if (!started) {
        // Permission missing. Clear the intent only if nothing newer set it
        // again — a grant-then-reconnect in the window must not be undone.
        if (attempt == _gpsAttempt) _sharingGps = false;
        return;
      }
      if (attempt != _gpsAttempt) {
        // The peer left (or this router was disposed) while the check was in
        // flight. The listener WAS taken — release exactly it.
        location.stop();
        return;
      }
      _gpsHeld = true;
    }));
  }

  void _onLocationChanged() {
    _broadcastOwnFix();
  }

  void _broadcastOwnFix({PeerSession? to}) {
    // Never relay: a fix this device is merely displaying on a peer's behalf
    // is not this device's to share, and two devices both relaying would
    // bounce one fix between them forever.
    if (location.positionIsFromPeer) return;
    if (location.status != LocationStatus.available) return;
    final position = location.position;
    if (position == null) return;

    if (to == null) {
      // The stream's own 50 m distance filter throttles real movement; this
      // dedupe is for the notifications that carry no new fix at all.
      if (position.latitude == _lastSentLat && position.longitude == _lastSentLon) return;
      _lastSentLat = position.latitude;
      _lastSentLon = position.longitude;
    }

    final message = PeerMessage.position(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      atMillis: position.timestamp.millisecondsSinceEpoch,
    );
    if (to != null) {
      to.sendEphemeral(message);
    } else {
      peers.broadcastEphemeral(message);
    }
  }

  /// The last offer and the last VFO reported for each radio, so an
  /// unchanged station is silent. Latest-value-wins does not mean chatty:
  /// `_onStationChanged` fires on every reading from every rig.
  ///
  /// A snapshot to one arriving session records here too, even though it went
  /// to that session alone. What these hold is what every ESTABLISHED peer
  /// has, and a snapshot is precisely what brings the new arrival up to it —
  /// leaving them behind instead would let the next real change match the
  /// stale entry and be deduped into silence, which is a withdrawal nobody
  /// ever hears.
  List<PeerRadioOffer> _lastOffered = const [];
  final Map<String, VfoReading> _lastSentVfo = {};

  /// Where every peer's radios were last heard to be, keyed
  /// `deviceId/radioId` — including the ones nobody picked.
  ///
  /// Kept because a `catStatus` is sent when the far rig MOVES, and picking
  /// a radio is not the rig moving. Without this, choosing one on a pair
  /// that is already up leaves `vfoA` on whatever the last local rig put
  /// there until somebody physically turns a knob — and QSOs logged in that
  /// window carry a frequency nothing is on. The local path has no such gap:
  /// every reading from `radio1` is written through, so switching between
  /// two local rigs corrects itself on the next poll.
  final Map<String, VfoReading> _peerVfos = {};

  /// The pick as of the last station notification, so a CHANGE of pick can be
  /// told from the notifications the station sends on every reading. Applying
  /// the cached VFO on all of them would overwrite what the operator is
  /// typing.
  PeerRadioSelection? _appliedSelection;

  /// This device's own equipment moved — a radio connected or dropped, one of
  /// them reported where it is sitting, or its operator picked a different
  /// Main VFO.
  void _onStationChanged() {
    _announceOffers();
    _reportOfferedVfos();
    // Keying as well, not only on [_onKeyingChanged]: a radio that connects
    // after the session established gets its offer here and nothing else, so
    // a controller picking it would see no speed, no memory names and no
    // measured lengths until that station happened to key something. Deduped,
    // so the usual case — a reading from a rig nobody is keying — sends
    // nothing.
    _reportKeying();
    _followNewSelection();
  }

  void _followNewSelection() {
    final selection = station?.followedPeerRadio;
    if (selection == _appliedSelection) return;
    _appliedSelection = selection;
    if (selection == null) return;
    final vfo = _peerVfos['${selection.deviceId}/${selection.radioId}'];
    if (vfo == null) return;
    radio?.setVfo('vfoA', freq: vfo.freqKHz, mode: vfo.mode, origin: VfoOrigin.radio);
  }

  void _announceOffers({PeerSession? to}) {
    final station = this.station;
    if (station == null) return;
    final offers = station.offeredRadios;
    if (to == null && listEquals(offers, _lastOffered)) return;
    _lastOffered = offers;
    // A radio that stopped being offered forgets what it last reported, so
    // re-offering it re-states where it is instead of being deduped into
    // silence against a value the controller never heard.
    final ids = {for (final offer in offers) offer.id};
    _lastSentVfo.removeWhere((id, _) => !ids.contains(id));
    _lastSentKeying.removeWhere((id, _) => !ids.contains(id));
    final message = PeerMessage.catOffer(offers);
    if (to != null) {
      to.sendEphemeral(message);
    } else {
      peers.broadcastEphemeral(message);
    }
  }

  void _reportOfferedVfos({PeerSession? to}) {
    final station = this.station;
    if (station == null) return;
    for (final offer in station.offeredRadios) {
      final vfo = station.vfoForOfferedRadio(offer.id);
      if (vfo == null || vfo.isEmpty) continue;
      if (to == null && _lastSentVfo[offer.id] == vfo) continue;
      _lastSentVfo[offer.id] = vfo;
      final message = PeerMessage.catStatus(radioId: offer.id, freqKHz: vfo.freqKHz, mode: vfo.mode);
      if (to != null) {
        to.sendEphemeral(message);
      } else {
        peers.broadcastEphemeral(message);
      }
    }
  }

  /// What this device's own radios are keying, so a peer driving one can
  /// watch its message go out. Broadcast like [_reportOfferedVfos] and read
  /// by the one controller that picked the radio — a status nobody picked
  /// costs a reader one comparison.
  ///
  /// Deduped per radio like [_reportOfferedVfos], against the whole encoded
  /// status: keying changes fire on every character a WinKeyer echoes, and
  /// each message carries the memory labels, their lengths and the message's
  /// whole per-character timeline. A status identical to the last one says
  /// nothing new — and over the BLE gateway, says it expensively.
  void _reportKeying({PeerSession? to}) {
    final station = this.station;
    if (station == null) return;
    for (final offer in station.offeredRadios) {
      final status = station.keyStatusForOfferedRadio(offer.id);
      if (status == null) continue;
      final message = PeerMessage.keyStatus(status);
      final encoded = jsonEncode(message.fields);
      if (to == null && _lastSentKeying[offer.id] == encoded) continue;
      _lastSentKeying[offer.id] = encoded;
      if (to != null) {
        to.sendEphemeral(message);
      } else {
        peers.broadcastEphemeral(message);
      }
    }
  }

  /// The last keying status sent for each radio, encoded — see
  /// [_reportKeying]. Cleared with the offer for the same reason
  /// [_lastSentVfo] is: a radio that stopped being offered must re-state what
  /// it is doing rather than be deduped against a value no controller heard.
  final Map<String, String> _lastSentKeying = {};

  void _onKeyingChanged() => _reportKeying();

  /// This device's operator asked for something to be keyed on the radio
  /// they picked. Addressed to that peer alone, never broadcast: a keying
  /// request is a transmitter, and the only device that may act on this one
  /// is the one whose radio was chosen.
  void _sendKeyRequest(PeerKeyRequestPayload request) {
    final selection = station?.followedPeerRadio;
    if (selection == null || selection.radioId != request.radioId) return;
    peers.peers[selection.deviceId]?.session?.sendEphemeral(PeerMessage.keySet(request));
  }

  /// This device's `vfoA` moved. Forwarded only when its operator picked a
  /// peer's radio to drive, and only to that peer.
  void _onRadioChanged() {
    final radio = this.radio;
    final selection = station?.followedPeerRadio;
    if (radio == null || selection == null) return;
    // Only what this OPERATOR did. `lastVfoOrigin` is meaningful exactly
    // here, inside the notification — `radio` origin means this change IS
    // the far side's report being applied below.
    //
    // Deleting this looks safe under the tests, because `setVfo`'s value
    // dedupe breaks the simple echo loop on its own. The case it actually
    // guards cannot be ordered deterministically over real sockets: the far
    // rig moves BETWEEN its report and this echo of it, and the stale echo —
    // arriving as a `user` move — tunes the rig backwards against the
    // operator's own knob.
    if (radio.lastVfoOrigin != VfoOrigin.user) return;
    final vfo = radio.vfoA;
    if (vfo.freq == null && vfo.mode == null) return;
    final session = peers.peers[selection.deviceId]?.session;
    if (session == null) return;
    session.sendEphemeral(
        PeerMessage.catSet(radioId: selection.radioId, freqKHz: vfo.freq, mode: vfo.mode));
  }

  void _onSessionEstablished(PeerSession session) {
    // The snapshots: latest-value state the new arrival missed. Sent to just
    // this session — the others already have it.
    _broadcastOwnFix(to: session);
    _announceOffers(to: session);
    _reportOfferedVfos(to: session);
    // Including what is keying right now: a controller that engages
    // mid-message otherwise shows a quiet strip over a transmitter that is
    // on the air, and hears nothing more about it until the NEXT message.
    _reportKeying(to: session);
    final peerDeviceId = session.peer?.deviceId;
    if (peerDeviceId != null) {
      _establishedPeers.add(peerDeviceId);
      // The offer is latest-value-wins like the rest, so an arrival that
      // missed the last announcement is caught up here rather than waiting
      // for the operator to change something.
      screens?.announceOffers(to: peerDeviceId);
      // And anything a pane on THIS device still wants from that peer is
      // asked for again — a producer that restarted remembers no
      // subscriptions.
      views?.onPeerAvailable(peerDeviceId);
      // A peer that arrives between two keystrokes would otherwise show an
      // empty block for this device until the operator next types.
      drafts?.snapshotTo(session);
      // Same reasoning for the numbers this device is holding: a position
      // that arrives mid-contact must skip them from its first keystroke.
      claims?.peerEstablished(peerDeviceId);
    }
  }

  void _reconcileDepartedPeers() {
    if (screens == null && views == null && drafts == null && remoteRadios == null && station == null) {
      return;
    }
    final live = <String>{
      for (final entry in peers.peers.entries)
        if (entry.value.session?.established ?? false) entry.key,
    };
    for (final gone in _establishedPeers.difference(live)) {
      unawaited(screens?.forgetPeer(gone) ?? Future<void>.value());
      views?.forgetPeer(gone);
      drafts?.forgetPeer(gone);
      claims?.forgetPeer(gone);
      // The selection itself is NOT cleared — a peer walking away must not
      // undo the operator's pick (`PeerStationRadios.followedPeerRadio`). What goes is
      // only what it is offering, so the picker says unavailable rather
      // than listing a radio nobody can reach.
      remoteRadios?.forgetPeer(gone);
      // Nor what it could be asked to KEY: a strip left showing that peer's
      // last message, over buttons addressing a device that is not there,
      // is worse than a strip that has gone quiet.
      station?.forgetPeerRadios(gone);
      _peerVfos.removeWhere((key, _) => key.startsWith('$gone/'));
    }
    _establishedPeers
      ..clear()
      ..addAll(live);
  }

  /// Returns whether [message] belonged to screen sharing — true even when
  /// neither half is constructed, so a build with the experiment off drops
  /// these quietly instead of logging every one as unhandled.
  bool _handleScreenMessage(String peerDeviceId, PeerMessage message) {
    switch (message.type) {
      case PeerMessageType.screenSources:
        final sources = message.screenSourcesOrNull;
        if (sources != null) views?.setOffer(peerDeviceId, sources);
        return true;
      case PeerMessageType.screenSubscribe:
        final request = message.screenSubscriptionOrNull;
        if (request != null) {
          unawaited(screens?.handleSubscribe(peerDeviceId, request) ?? Future<void>.value());
        }
        return true;
      case PeerMessageType.screenUnsubscribe:
        final sourceId = message.screenSourceId;
        if (sourceId != null) screens?.handleUnsubscribe(peerDeviceId, sourceId);
        return true;
      case PeerMessageType.screenGrant:
        final grant = message.screenGrantOrNull;
        if (grant != null) views?.onGrant(peerDeviceId, grant);
        return true;
      case PeerMessageType.screenRefuse:
        final sourceId = message.screenSourceId;
        if (sourceId != null) views?.onRefused(peerDeviceId, sourceId, message.reason);
        return true;
      case PeerMessageType.screenThumbRequest:
        final sourceId = message.screenSourceId;
        if (sourceId != null) {
          unawaited(screens?.handleThumbRequest(peerDeviceId, sourceId) ?? Future<void>.value());
        }
        return true;
      case PeerMessageType.screenThumb:
        final sourceId = message.screenSourceId;
        if (sourceId != null) views?.onThumb(peerDeviceId, sourceId, message.screenThumbOrNull);
        return true;
      default:
        return false;
    }
  }

  void _onEphemeral(String peerDeviceId, PeerMessage message) {
    if (message.type == PeerMessageType.catOffer) {
      final radios = message.catOffersOrNull;
      if (radios != null) {
        final deviceName = peers.peers[peerDeviceId]?.beacon.deviceName ?? peerDeviceId;
        remoteRadios?.setOffers(peerDeviceId, deviceName, radios);
        // The station hears it too, so a pick can keep the names it shows
        // while the peer is away up to date. This is the only place a fresh
        // one arrives without the operator picking again.
        station?.noteOffer(peerDeviceId, deviceName, radios);
      }
      return;
    }
    if (message.type == PeerMessageType.catStatus) {
      // Where one of that peer's radios is sitting — followed only when it
      // is the radio this device's operator picked. Every other report is
      // dropped, sender included: a device offering radios hears its own
      // pair's reports, and two sources writing `vfoA` fight.
      final vfo = message.vfoOrNull;
      if (vfo == null) return;
      // Remembered whether or not it is the picked one: the establish-time
      // snapshot is the only time most of these are heard, and a radio
      // picked afterwards has to have something to show. See [_peerVfos].
      _peerVfos['$peerDeviceId/${vfo.radioId}'] =
          VfoReading(freqKHz: vfo.freqKHz, mode: vfo.mode);
      if (station?.followedPeerRadio?.matches(peerDeviceId, vfo.radioId) ?? false) {
        _appliedSelection = station?.followedPeerRadio;
        radio?.setVfo('vfoA', freq: vfo.freqKHz, mode: vfo.mode, origin: VfoOrigin.radio);
      }
      return;
    }
    if (message.type == PeerMessageType.catSet) {
      // A tune request for one of THIS device's radios. The station honors
      // it only for a radio it is currently offering, and puts it through
      // the same funnel and echo guards a local operator's tune takes. The
      // session already refused anything untrusted.
      final vfo = message.vfoOrNull;
      if (vfo != null) {
        station?.tuneOfferedRadio(vfo.radioId, freqKHz: vfo.freqKHz, mode: vfo.mode);
      }
      return;
    }
    if (message.type == PeerMessageType.keyStatus) {
      // What one of that peer's radios is keying — applied only for the
      // radio this operator picked, which the station decides. Dropped for
      // every other, sender included: a device that offers radios hears its
      // own controllers' reports of them.
      final status = message.keyStatusOrNull;
      if (status != null) station?.notePeerKeyStatus(peerDeviceId, status);
      return;
    }
    if (message.type == PeerMessageType.keySet) {
      // A keying request for one of THIS device's radios, honored only for a
      // radio it is currently offering and through the same funnel a local
      // function key takes. The session already refused anything untrusted;
      // this is where that trust becomes RF.
      final request = message.keyRequestOrNull;
      if (request == null) {
        // Reported rather than dropped in silence: a build that renames a
        // field lands here, and every message would go quiet with no sign of
        // why — on the one feature whose failure is a dead function key.
        debugPrint('[peer] unreadable keySet from $peerDeviceId');
      } else {
        station?.handleKeyRequest(request);
      }
      return;
    }
    if (message.type == PeerMessageType.qsoDraft) {
      final draft = message.qsoDraftOrNull;
      if (draft == null) {
        // Reported rather than dropped in silence: this arm is what a build
        // that renames or rewraps the payload lands in, and every draft from
        // that peer would vanish behind a panel saying nobody is there.
        debugPrint('[peer] unreadable qsoDraft from $peerDeviceId');
      } else if (draft.left) {
        drafts?.forgetPeer(peerDeviceId);
      } else {
        drafts?.onDraft(peerDeviceId, draft);
      }
      return;
    }
    if (message.type == PeerMessageType.serialClaims) {
      final payload = message.serialClaimsOrNull;
      if (payload == null) {
        debugPrint('[peer] unreadable serialClaims from $peerDeviceId');
      } else {
        claims?.onPeerClaims(peerDeviceId, payload);
      }
      return;
    }
    if (_handleScreenMessage(peerDeviceId, message)) return;

    final fix = message.positionOrNull;
    if (fix != null) {
      final peerName = peers.peers[peerDeviceId]?.beacon.deviceName;
      location.setPeerPosition(
        Position(
          latitude: fix.latitude,
          longitude: fix.longitude,
          // The SENDER's clock at the fix — display-grade only, never
          // compared against the local clock (PeerPositionPayload's doc).
          timestamp: DateTime.fromMillisecondsSinceEpoch(fix.atMillis),
          accuracy: fix.accuracyMeters ?? 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
        deviceId: peerDeviceId,
        deviceName: (peerName == null || peerName.isEmpty) ? peerDeviceId : peerName,
      );
      return;
    }
    debugPrint('[peer] unhandled ephemeral ${message.type} from $peerDeviceId');
  }
}
