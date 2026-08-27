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
// inherits the whole tune path in both directions for the price of two
// message handlers. The roles are self-organizing: a device whose operator
// designated a radio (`radio1`) is the OWNER — it reports its VFO and
// honors tune requests — and a device without one is a CONTROLLER, whose
// display follows the owner and whose operator's own tunes are forwarded.
// The cost accepted: the remote radio has no Station-panel entry, and
// control engages automatically rather than by an explicit pick.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:halo_core/halo_core.dart';

import '../location_service.dart';
import '../radio_service.dart';
import 'peer_drafts.dart';
import 'peer_screen_views.dart';
import 'peer_screens.dart';
import 'peer_service.dart';

class PeerChannels {
  PeerChannels({
    required this.peers,
    required this.location,
    this.radio,
    this.screens,
    this.views,
    this.drafts,
    this.hasLocalRadio,
    this.radioIsLive,
  }) {
    peers.onEphemeral = _onEphemeral;
    peers.onSessionEstablished = _onSessionEstablished;
    peers.addListener(_onPeersChanged);
    location.addListener(_onLocationChanged);
    radio?.addListener(_onRadioChanged);
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

  /// Peers that had an established session when this last looked — the
  /// before-picture a loss is spotted against. `PeerService` reports
  /// connection changes through a single callback slot that the status bar
  /// already holds, so a second consumer reconciles rather than subscribes.
  final Set<String> _establishedPeers = {};

  /// Whether THIS device has a designated radio (`CatService.radio1`) — the
  /// role switch for the whole bridge. A callback, read fresh on every
  /// message, because the operator can designate or remove a radio while
  /// sessions are up.
  final bool Function()? hasLocalRadio;

  /// Whether the designated radio's link is actually up. Null means "same as
  /// [hasLocalRadio]" — for a caller with no connection state to offer.
  ///
  /// This gates the owner's TRAFFIC, never its role: with the rig
  /// disconnected, honoring a tune request moves only this device's app
  /// state, and the resulting report reaches the controller exactly like a
  /// rig confirmation — both screens then display a frequency the physical
  /// radio is not on, and contacts logged on the controller carry it into
  /// the log. Nothing on the wire says staleness yet, so silence is the
  /// honest signal available.
  final bool Function()? radioIsLive;

  bool get _ownsRadio => hasLocalRadio?.call() ?? false;

  bool get _radioLive => radioIsLive?.call() ?? _ownsRadio;

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

  double? _lastSentFreqKHz;
  String? _lastSentMode;

  void _onRadioChanged() {
    final radio = this.radio;
    if (radio == null) return;
    if (_ownsRadio) {
      if (_radioLive) _broadcastOwnVfo();
      return;
    }
    // A controller forwards only what its OPERATOR did. `lastVfoOrigin` is
    // meaningful exactly here, inside the notification — `radio` origin means
    // this change IS the owner's report being applied below.
    //
    // Deleting this looks safe under the tests, because `setVfo`'s value
    // dedupe breaks the simple echo loop on its own. The case it actually
    // guards cannot be ordered deterministically over real sockets: the
    // owner's rig moves BETWEEN its report and this echo of it, and the
    // stale echo — arriving as a `user` move — tunes the rig backwards
    // against the operator's own knob.
    if (radio.lastVfoOrigin != VfoOrigin.user) return;
    final vfo = radio.vfoA;
    if (vfo.freq == null && vfo.mode == null) return;
    peers.broadcastEphemeral(PeerMessage.catSet(freqKHz: vfo.freq, mode: vfo.mode));
  }

  void _broadcastOwnVfo({PeerSession? to}) {
    final vfo = radio?.vfoA;
    if (vfo == null || (vfo.freq == null && vfo.mode == null)) return;
    if (to == null) {
      if (vfo.freq == _lastSentFreqKHz && vfo.mode == _lastSentMode) return;
      _lastSentFreqKHz = vfo.freq;
      _lastSentMode = vfo.mode;
    }
    final message = PeerMessage.catStatus(freqKHz: vfo.freq, mode: vfo.mode);
    if (to != null) {
      to.sendEphemeral(message);
    } else {
      peers.broadcastEphemeral(message);
    }
  }

  void _onSessionEstablished(PeerSession session) {
    // The snapshots: latest-value state the new arrival missed. Sent to just
    // this session — the others already have it.
    _broadcastOwnFix(to: session);
    if (_ownsRadio && _radioLive) _broadcastOwnVfo(to: session);
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
    }
  }

  void _reconcileDepartedPeers() {
    if (screens == null && views == null && drafts == null) return;
    final live = <String>{
      for (final entry in peers.peers.entries)
        if (entry.value.session?.established ?? false) entry.key,
    };
    for (final gone in _establishedPeers.difference(live)) {
      unawaited(screens?.forgetPeer(gone) ?? Future<void>.value());
      views?.forgetPeer(gone);
      drafts?.forgetPeer(gone);
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
    if (message.type == PeerMessageType.catStatus) {
      // The owner's report — only a device with no radio of its own follows
      // it. One WITH a radio ignores it outright: two sources writing vfoA
      // would fight, and the operator's own rig must win (the same
      // first-to-respond rule the design settled for capability conflicts).
      final vfo = message.vfoOrNull;
      if (vfo != null && !_ownsRadio) {
        radio?.setVfo('vfoA', freq: vfo.freqKHz, mode: vfo.mode, origin: VfoOrigin.radio);
      }
      return;
    }
    if (message.type == PeerMessageType.catSet) {
      // A tune request — honored only by a radio owner, and applied as a
      // USER move so `CatService._onVfoChanged` forwards it to the rig
      // through the same funnel a local keystroke takes, echo guards
      // included. The session already refused anything untrusted.
      final vfo = message.vfoOrNull;
      if (vfo != null && _ownsRadio && _radioLive) {
        radio?.setVfo('vfoA', freq: vfo.freqKHz, mode: vfo.mode, origin: VfoOrigin.user);
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
