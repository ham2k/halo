// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The producer half of screen sharing (HALO-369): what this device offers,
// who is watching, and which captures are therefore running.
//
// One rule shapes the whole class: **a source captures only while somebody
// is watching it.** Not while the switch is on, not while it is offered —
// only while a watcher holds it. Capture costs a GPU pass, a JPEG encode and
// a Screen Recording indicator in the operator's menu bar ten times a
// second, and a device that keeps paying that for a pane nobody has open is
// indistinguishable, from the outside, from one that is quietly recording.
//
// A watcher is a peer device id, or [localViewerWatcher] for a pane on this
// very device. Both go through the same registry deliberately: a local pane
// that took a private path would prove nothing about the path peers use, and
// the capture-only-while-watched rule has to hold for it too.
//
// The picker's tiles are STILLS taken through a separate one-shot path, not
// watchers — a grid of live captures would cost more than the feature it is
// choosing for.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import '../screen_capture_service.dart';
import '../settings_service.dart';
import 'peer_link.dart';
import 'peer_service.dart';

/// How wide a frame this device will ever encode, whatever a viewer asks
/// for. A viewer names its own size (see [PeerScreenSubscription]) and this
/// is the producer's own ceiling on top of that.
///
/// It bounds the ENCODED frame, which under a crop covers only part of the
/// source — so a zoomed viewer buys detail here without buying bytes, and
/// this number stays a bound on what a frame costs to send.
const int _maxCaptureWidth = 2560;

/// A pane on THIS device, as a watcher. Not a device id, and it cannot
/// collide with one: a peer device id is a UUID, which never contains a
/// colon-prefixed word.
const String localViewerWatcher = 'local:viewer';

class PeerScreens extends ChangeNotifier {
  PeerScreens({required this.settings, required this.peers, ScreenCaptureService? capture})
      : _capture = capture ?? ScreenCaptureService() {
    _frameSubscription = _capture.frames.listen(_onFrame);
    _stoppedSubscription = _capture.stopped.listen(_onCaptureStopped);
    _mediaSubscription = peers.mediaConnections.listen(_onMediaConnection);
  }

  final SettingsService settings;
  final PeerService peers;
  final ScreenCaptureService _capture;

  StreamSubscription<Uint8List>? _frameSubscription;
  StreamSubscription<ScreenCaptureStopped>? _stoppedSubscription;
  StreamSubscription<PeerMediaConnection>? _mediaSubscription;

  /// Unredeemed tickets, ticket → the peer it was minted for. A ticket is
  /// consumed the moment a media link presents it, so a leaked one buys
  /// nothing after the peer has dialled.
  final Map<String, String> _tickets = {};

  /// One media link per PEER, not per source: a frame names its own source
  /// in its header, so a second source costs no second socket.
  final Map<String, PeerLink> _mediaLinks = {};

  final Map<String, StreamSubscription<List<int>>> _mediaAcks = {};

  /// Sequence numbers sent to a viewer and not yet acknowledged, per
  /// `<peer>/<source>`.
  ///
  /// A SET of what is outstanding, not a high-water mark differenced against
  /// an acknowledgement. Two reasons, both of which bite:
  ///
  /// A difference of raw sequences is not a count of frames in flight — a
  /// dropped frame still widens the gap, so the window tightens itself every
  /// time it is used and the effective depth is one, not [inFlightWindow].
  /// And a difference is meaningless across a capture RESTART, which begins
  /// numbering at one again: a stale high-water mark makes every real frame
  /// look already-acknowledged (pacing silently switches off) or every
  /// acknowledgement look stale (the viewer starves).
  ///
  /// Per SOURCE, not per link: one link carries every source that peer
  /// watches, and a single counter would let one struggling source starve a
  /// healthy one.
  final Map<String, Set<int>> _unacked = {};

  /// Flows whose viewer said it would acknowledge, keyed like [_unacked].
  /// Anyone else is served ungated — see [PeerScreenSubscription.acks].
  ///
  /// Per SOURCE for the same reason [_unacked] is: one peer can watch two
  /// sources from two panes, and a per-PEER flag makes the second
  /// subscription's terms silently rewrite the first one's pacing.
  final Set<String> _pacedFlows = {};

  /// Armed while a flow's window is full, cancelled the moment it drains.
  ///
  /// A TIMER, not a deadline compared on each frame: the capture emits
  /// nothing while its source is static (the native side drops every
  /// non-`.complete` buffer), so a clock sampled from frame arrivals stops
  /// being read exactly when the failure starts. A viewer that quietly
  /// stopped taking delivery of a still screen would then hold the capture
  /// open until somebody touched that screen again.
  final Map<String, Timer> _stallTimers = {};

  /// How long a flow may sit with a full window before the producer stops
  /// believing anyone is watching.
  ///
  /// Generous: a viewer on a slow link is congested, not gone, and dropping
  /// it costs a reconnect. Six seconds of a ten-a-second stream is sixty
  /// frames' worth of nothing acknowledged.
  static const Duration stallDeadline = Duration(seconds: 6);

  /// How many frames may be outstanding before the producer stops sending.
  ///
  /// Two, deliberately: this is a live view of somebody's screen, so being
  /// CURRENT beats being smooth. A deeper window rides out jitter by showing
  /// a picture that is already old, which is the wrong trade for watching a
  /// waterfall or a rotator.
  static const int inFlightWindow = 2;

  static String _flowKey(String watcher, String sourceId) => '$watcher/$sourceId';

  final _random = Random.secure();

  /// Peers granted a source that have not yet presented a media link.
  ///
  /// Without this a viewer that can never open one — a firewall on its side —
  /// retries forever, and each retry is answered with a fresh grant while the
  /// watcher it registered is never dropped. This device would capture,
  /// encode and discard frames for nobody, which is the one thing the class
  /// comment says it exists to prevent.
  final Map<String, Timer> _awaitingMedia = {};

  /// Generous: it spans several of a viewer's own retry rounds, so an
  /// ordinary slow dial is never mistaken for one that will not arrive.
  static const Duration mediaDeadline = Duration(seconds: 25);

  /// What a pane on this device is handed, standing in for the media link a
  /// peer would dial. Same bytes, same format — only the transport is
  /// missing, because there is no network between a device and itself.
  final _localFrames = StreamController<Uint8List>.broadcast();
  final _localRefusals = StreamController<(String sourceId, String reason)>.broadcast();

  Stream<Uint8List> get localFrames => _localFrames.stream;

  /// The local counterpart of a `screenRefuse` message.
  Stream<(String sourceId, String reason)> get localRefusals => _localRefusals.stream;

  /// Watchers per source. A source with an empty (or absent) entry is not
  /// capturing — see the class comment.
  final Map<String, Set<String>> _watchers = {};

  /// What each watcher asked for, per source and per WATCHER — not merged.
  /// Kept apart so a watcher LEAVING can lower the terms again: a merged
  /// value only ever ratchets up, and the viewer that asked for 1920 at 30
  /// would leave the capture running there forever after it closed.
  final Map<String, Map<String, PeerScreenSubscription>> _terms = {};

  ScreenCaptureAvailability _availability = ScreenCaptureAvailability.unsupportedPlatform;
  ScreenCapturePermission _permission = ScreenCapturePermission.denied;
  List<PeerScreenSource> _available = const [];
  String? _error;
  int _framesCaptured = 0;
  int _framesDropped = 0;

  /// Whether this device could ever share, and if not, which reason to show.
  ScreenCaptureAvailability get availability => _availability;

  ScreenCapturePermission get permission => _permission;

  /// Everything the OS reports, offered or not — the list the operator picks
  /// from.
  List<PeerScreenSource> get availableSources => _available;

  /// The last enumeration failure, or null. Held rather than thrown: a
  /// missing permission is a state the panel explains, not an error the app
  /// should raise a notice for (docs/design/error-reporting.md).
  String? get error => _error;

  int get framesCaptured => _framesCaptured;

  /// Frames a paced viewer was not sent because it had not caught up.
  ///
  /// Exposed because "dropped" is otherwise invisible from the outside — the
  /// producer keeps capturing, the socket stays open, and the viewer infers
  /// it only from gaps in the sequence numbers.
  int get framesDropped => _framesDropped;

  /// Sources actually on offer: what the operator picked, resolved against
  /// what the OS currently reports.
  ///
  /// A picked id the OS no longer reports is silently absent HERE while
  /// staying in settings — the application is closed, not un-chosen — so it
  /// returns to the offer when it comes back without the operator having to
  /// re-pick it.
  List<PeerScreenSource> get offeredSources {
    if (!settings.peerScreenShareEnabled) return const [];
    final picked = settings.peerSharedScreenIds.toSet();
    return [
      for (final source in _available)
        if (picked.contains(source.id)) source,
    ];
  }

  bool isWatched(String sourceId) => (_watchers[sourceId] ?? const {}).isNotEmpty;

  /// Whether [peerDeviceId] has redeemed its grant — its media link is up
  /// and frames can go. Distinct from being a watcher: a watcher is
  /// registered on the subscription, before any link exists.
  @visibleForTesting
  bool hasMediaLink(String peerDeviceId) => _mediaLinks.containsKey(peerDeviceId);

  /// Who is watching one source. Watcher ids: a peer's device id, or
  /// [localViewerWatcher] for a pane on this very device.
  Set<String> watchersOf(String sourceId) => {...?_watchers[sourceId]};

  /// Who is watching anything, for the "someone is looking at your screen"
  /// signal. The operator is entitled to know that at a glance.
  Set<String> get watchers => {
        for (final set in _watchers.values) ...set,
      };

  /// Thumbnails for the picker, and the queue that fills them.
  ///
  /// Fetched a few at a time rather than all at once: a machine has one or
  /// two displays and dozens of windows, and asking the OS for every tile
  /// together makes the picker slower to show anything, not faster.
  final Map<String, Uint8List> _thumbnails = {};
  final List<String> _thumbnailQueue = [];
  final Set<String> _thumbnailsInFlight = {};
  static const int _maxThumbnailFetches = 3;

  /// Peers waiting on a still, per source. A viewer's picker asks for these
  /// so it can show what it would be choosing, and several viewers looking
  /// at once share one capture.
  final Map<String, Set<String>> _thumbRequests = {};

  /// The still for [sourceId], if one has been fetched.
  Uint8List? thumbnailFor(String sourceId) => _thumbnails[sourceId];

  /// Asks for [sourceId]'s still if it is not already had or on its way.
  void requestThumbnail(String sourceId) {
    if (_thumbnails.containsKey(sourceId)) return;
    if (_thumbnailsInFlight.contains(sourceId) || _thumbnailQueue.contains(sourceId)) return;
    _thumbnailQueue.add(sourceId);
    _pumpThumbnails();
  }

  /// Drops every still, so the next look re-fetches. What the picker's
  /// refresh does — a thumbnail is a photograph, and the window it shows
  /// has moved on.
  void clearThumbnails() {
    _thumbnails.clear();
    _thumbnailQueue.clear();
    // Whoever was queued behind those is answered rather than dropped — a
    // viewer latches "already asked" per source and would never ask again,
    // leaving a permanently blank tile.
    for (final entry in _thumbRequests.entries) {
      for (final peerDeviceId in entry.value) {
        peers.sendEphemeralTo(peerDeviceId, PeerMessage.screenThumb(entry.key, null));
      }
    }
    _thumbRequests.clear();
    // In-flight fetches are left to land, but their answers are stale by
    // definition — dropped on arrival so the next look re-fetches, which is
    // what this method promises.
    _staleThumbnails.addAll(_thumbnailsInFlight);
    notifyListeners();
  }

  /// Fetches already in flight when [clearThumbnails] ran. Their pictures
  /// predate the refresh, so they are discarded rather than cached.
  final Set<String> _staleThumbnails = {};

  void _pumpThumbnails() {
    while (_thumbnailsInFlight.length < _maxThumbnailFetches && _thumbnailQueue.isNotEmpty) {
      final sourceId = _thumbnailQueue.removeAt(0);
      _thumbnailsInFlight.add(sourceId);
      unawaited(_capture.thumbnail(sourceId).then<Uint8List?>(
        (bytes) => bytes,
        // Anything the service did not already turn into a null — the slot
        // must come back either way. Left held, three of these stall the
        // queue for the rest of the session and every waiting peer goes
        // unanswered, with nothing on screen to say why.
        onError: (Object e) {
          debugPrint('[peer] thumbnail for $sourceId failed: $e');
          return null;
        },
      ).then((bytes) {
        _thumbnailsInFlight.remove(sourceId);
        // Re-checked on DELIVERY, not only when the request arrived: a
        // thumbnail is the picture, and the operator may have withdrawn the
        // source while this was in flight.
        final stale = _staleThumbnails.remove(sourceId);
        final stillOffered = offeredSources.any((s) => s.id == sourceId);
        if (bytes != null && stillOffered && !stale) _thumbnails[sourceId] = bytes;
        for (final peerDeviceId in _thumbRequests.remove(sourceId) ?? const <String>{}) {
          // Answered even when there is no picture: a viewer left waiting
          // cannot tell "nothing to show" from "still coming".
          peers.sendEphemeralTo(
            peerDeviceId, PeerMessage.screenThumb(sourceId, stillOffered ? bytes : null));
        }
        notifyListeners();
        _pumpThumbnails();
      }));
    }
  }

  /// Re-reads the OS's source list and announces the result if what is on
  /// offer actually changed.
  ///
  /// Nothing else populates [availableSources], and [offeredSources] is the
  /// intersection of it with what the operator picked — so without this, a
  /// device that restarts offers NOTHING until someone opens the settings
  /// panel, however many sources are ticked. It runs whenever sharing is
  /// switched on, not only when a human is looking.
  Future<void> ensureSourcesFresh() async {
    final before = offeredSources.map((s) => s.id).toList();
    await refreshSources();
    final after = offeredSources.map((s) => s.id).toList();
    if (!listEquals(before, after)) announceOffers();
  }

  /// Re-reads what the OS can offer. Cheap enough to call whenever the
  /// panel opens, and NOT called on a timer: enumeration is the call that
  /// can wedge, and a background poll of it would wedge invisibly.
  Future<void> refreshSources() async {
    // All three calls, not just the listing: availability and permission go
    // through the same platform channel and raise the same exception, and one
    // escaping here reaches the global handler as an unclassified error —
    // a "Something went wrong" notice for the very case [error] exists to
    // report quietly (docs/design/error-reporting.md).
    try {
      _availability = await _capture.availability();
      if (_availability != ScreenCaptureAvailability.available) {
        _available = const [];
        _error = null;
        notifyListeners();
        return;
      }
      _permission = await _capture.permission();
      _available = await _capture.listSources();
      _error = null;
    } on ScreenCaptureException catch (e) {
      _available = const [];
      _error = e.message;
    }
    notifyListeners();
  }

  /// Asks the OS for Screen Recording.
  ///
  /// macOS answers the preflight from a per-process cache, so this device
  /// keeps reporting denied until it is relaunched however the operator
  /// answers. The panel says so; there is no retry that could work.
  Future<void> requestPermission() async {
    await _capture.requestPermission();
    _permission = await _capture.permission();
    notifyListeners();
  }

  /// Registers a watcher and starts capture if this is the first one.
  ///
  /// Refuses anything not on offer — a peer that asks for a source by id
  /// gets exactly what the operator chose to share and nothing else, so a
  /// stale id from a viewer's saved panel config cannot reach an
  /// unoffered window. Returns whether it was accepted.
  Future<bool> addWatcher(String watcher, PeerScreenSubscription request) async {
    if (!offeredSources.any((s) => s.id == request.sourceId)) return false;

    final before = _mergedTerms(request.sourceId);
    _terms.putIfAbsent(request.sourceId, () => {})[watcher] = request;
    final watchers = _watchers.putIfAbsent(request.sourceId, () => <String>{});
    watchers.add(watcher);
    // Set, not merely added: a viewer that resubscribes without the flag —
    // a downgrade, or a different build answering for the same device — must
    // stop being paced rather than keep a stale promise to acknowledge.
    final flow = _flowKey(watcher, request.sourceId);
    if (request.acks) {
      _pacedFlows.add(flow);
    } else {
      _pacedFlows.remove(flow);
    }
    // A resubscribe restarts delivery: whatever was outstanding on the old
    // link will never be acknowledged, and carrying it over would leave the
    // window permanently closed.
    _forgetFlow(flow);

    // Restart when the terms moved, so a viewer joining at a larger size is
    // not served the smaller stream the first one asked for.
    final after = _mergedTerms(request.sourceId);
    if (before != after) {
      final started = await _startCapture(request.sourceId, after!);
      if (!started) {
        // The capture would not start — Screen Recording revoked, or the
        // window gone since it was enumerated. Answering true here would
        // have the viewer dial a media link that never carries a frame and
        // sit on "Connecting…" for good.
        //
        // A RESTART failing takes the existing stream with it, so anyone
        // already being served is stranded too and has to be told; dropping
        // them silently freezes their pane on its last picture, which is the
        // failure the whole class is written against. The new watcher hears
        // it from the `false` this returns.
        for (final existing in _watchers[request.sourceId] ?? const <String>{}) {
          if (existing == watcher) continue;
          _refuse(existing, request.sourceId, 'captureFailed');
        }
        _dropWatchers(request.sourceId);
        notifyListeners();
        return false;
      }
    }
    notifyListeners();
    return true;
  }

  /// Drops a watcher, stopping capture once the last one goes — and lowering
  /// the terms when a demanding one leaves behind a modest one.
  Future<void> removeWatcher(String watcher, String sourceId) async {
    final watchers = _watchers[sourceId];
    if (watchers == null || !watchers.remove(watcher)) return;
    // Here, not in [_dropWatchers]: by the time that runs the watcher is
    // already out of the set it would iterate.
    _forgetFlow(_flowKey(watcher, sourceId));
    final before = _mergedTerms(sourceId);
    _terms[sourceId]?.remove(watcher);
    if (watchers.isEmpty) {
      _dropWatchers(sourceId);
      await _capture.stop(sourceId);
    } else {
      final after = _mergedTerms(sourceId);
      if (after != null && after != before) await _startCapture(sourceId, after);
    }
    notifyListeners();
  }

  /// Everything a flow's WINDOW is made of, so no path can forget half of it
  /// and leave one that nothing will reopen.
  ///
  /// [_pacedFlows] is deliberately not here. Whether a viewer acknowledges is
  /// a property of that viewer, not of the window: a capture restart forgets
  /// what is outstanding and must NOT also forget that a still-subscribed
  /// viewer answers, or it would serve it ungated from then on.
  void _forgetFlow(String flow) {
    _unacked.remove(flow);
    _stallTimers.remove(flow)?.cancel();
  }

  void _dropWatchers(String sourceId) {
    for (final watcher in _watchers[sourceId] ?? const <String>{}) {
      _forgetFlow(_flowKey(watcher, sourceId));
    }
    _watchers.remove(sourceId);
    _terms.remove(sourceId);
  }

  /// The terms that satisfy every watcher of [sourceId] — the largest size
  /// and the fastest rate any of them asked for. Null when nobody is.
  PeerScreenSubscription? _mergedTerms(String sourceId) {
    final byWatcher = _terms[sourceId];
    if (byWatcher == null || byWatcher.isEmpty) return null;
    PeerScreenSubscription? merged;
    for (final request in byWatcher.values) {
      merged = _widest(merged, request);
    }
    return merged;
  }

  /// Drops every source [watcher] held — what a lost peer link means.
  Future<void> removeAllFor(String watcher) async {
    for (final sourceId in _watchers.keys.toList()) {
      await removeWatcher(watcher, sourceId);
    }
  }

  /// Stops everything. Called when the switch goes off, when the experiment
  /// goes off, and on the way down — the operator turning sharing off must
  /// mean the capture stops now, not when the last viewer happens to close
  /// a pane.
  Future<void> stopAll() async {
    for (final subscription in _mediaAcks.values) {
      unawaited(subscription.cancel());
    }
    _mediaAcks.clear();
    _unacked.clear();
    _pacedFlows.clear();
    for (final timer in _stallTimers.values) {
      timer.cancel();
    }
    _stallTimers.clear();
    // Told before dropped. A peer learns from the empty offer below, but a
    // pane on THIS device reads `offeredSources` directly and has no such
    // message — it would keep a frozen picture that looks exactly like a
    // live one, which is the failure this class is written against.
    for (final entry in _watchers.entries) {
      for (final watcher in entry.value) {
        _refuse(watcher, entry.key, 'stopped');
      }
    }
    _watchers.clear();
    _terms.clear();
    _tickets.clear();
    for (final link in _mediaLinks.values) {
      unawaited(link.close());
    }
    _mediaLinks.clear();
    await _capture.stopAll();
    // Said out loud, so a viewer's pane reports the source withdrawn rather
    // than freezing on the last frame and calling it a network problem.
    announceOffers();
    notifyListeners();
  }

  /// Reconciles running captures against what is still on offer. Called
  /// after the operator changes the picked set: un-picking a source that
  /// someone is watching must stop it, or "shared" would mean nothing.
  Future<void> applyOffers() async {
    final offered = offeredSources.map((s) => s.id).toSet();
    for (final sourceId in _watchers.keys.toList()) {
      if (!offered.contains(sourceId)) {
        for (final watcher in _watchers[sourceId] ?? const <String>{}) {
          _refuse(watcher, sourceId, 'stopped');
        }
        _dropWatchers(sourceId);
        await _capture.stop(sourceId);
      }
    }
    announceOffers();
    notifyListeners();
  }

  // MARK: - Serving a peer

  /// Answers a peer's [PeerMessageType.screenSubscribe].
  ///
  /// Refuses over Bluetooth without trying: a media link is a second
  /// WebSocket, which a BLE peer has no way to open, and pushing frames down
  /// the BLE conduit instead would block sync and CAT behind them for tens
  /// of seconds each.
  Future<void> handleSubscribe(String peerDeviceId, PeerScreenSubscription request) async {
    if (!peers.hasLanSession(peerDeviceId)) {
      _refuse(peerDeviceId, request.sourceId, 'noLan');
      return;
    }
    final port = peers.linkServerPort;
    if (port == null) {
      // This device never bound a listening socket (a firewall prompt the
      // operator dismissed). It can still dial out, so peer sync looks fine
      // — but nothing can dial back, and a viewer left waiting on a media
      // link that will never connect deserves to be told.
      _refuse(peerDeviceId, request.sourceId, 'noListener');
      return;
    }
    final offered = offeredSources.any((s) => s.id == request.sourceId);
    final accepted = await addWatcher(peerDeviceId, request);
    if (!accepted) {
      _refuse(peerDeviceId, request.sourceId, offered ? 'captureFailed' : 'notOffered');
      return;
    }

    if (!_mediaLinks.containsKey(peerDeviceId)) _armMediaDeadline(peerDeviceId);
    final ticket = _ticketFor(peerDeviceId);
    peers.sendEphemeralTo(
      peerDeviceId,
      PeerMessage.screenGrant(
        PeerScreenGrant(
            sourceId: request.sourceId,
            ticket: ticket,
            port: port,
            paced: true,
            crops: true),
      ),
    );
  }

  /// Answers a peer's [PeerMessageType.screenThumbRequest].
  ///
  /// Gated on the offer exactly as a subscription is, and for a stronger
  /// reason: a thumbnail IS the picture. A source the operator did not pick
  /// must not answer one, or the offer would mean nothing.
  Future<void> handleThumbRequest(String peerDeviceId, String sourceId) async {
    if (!offeredSources.any((s) => s.id == sourceId)) {
      peers.sendEphemeralTo(peerDeviceId, PeerMessage.screenThumb(sourceId, null));
      return;
    }
    final cached = _thumbnails[sourceId];
    if (cached != null) {
      peers.sendEphemeralTo(peerDeviceId, PeerMessage.screenThumb(sourceId, cached));
      return;
    }
    _thumbRequests.putIfAbsent(sourceId, () => {}).add(peerDeviceId);
    requestThumbnail(sourceId);
  }

  void handleUnsubscribe(String peerDeviceId, String sourceId) {
    unawaited(removeWatcher(peerDeviceId, sourceId));
  }

  /// Everything a peer held, and its media link. What a lost session means.
  Future<void> forgetPeer(String peerDeviceId) async {
    _awaitingMedia.remove(peerDeviceId)?.cancel();
    unawaited(_mediaAcks.remove(peerDeviceId)?.cancel());
    _pacedFlows.removeWhere((key) => key.startsWith('$peerDeviceId/'));
    _forgetFlowsOf(peerDeviceId);
    _tickets.removeWhere((_, owner) => owner == peerDeviceId);
    for (final waiting in _thumbRequests.values) {
      waiting.remove(peerDeviceId);
    }
    final link = _mediaLinks.remove(peerDeviceId);
    if (link != null) await link.close();
    await removeAllFor(peerDeviceId);
  }

  /// Tells [peerDeviceId] — or every LAN peer, when it is null — what is on
  /// offer. An EMPTY list is sent as readily as a full one: it is how this
  /// device says it has stopped sharing.
  void announceOffers({String? to}) {
    final message = PeerMessage.screenSources(offeredSources);
    if (to != null) {
      peers.sendEphemeralTo(to, message);
      return;
    }
    for (final deviceId in peers.peers.keys) {
      peers.sendEphemeralTo(deviceId, message);
    }
  }

  void _refuse(String peerDeviceId, String sourceId, String reason) {
    // Answered rather than ignored: a viewer whose request vanishes cannot
    // tell a refusal from a peer that is simply slow, and would sit on a
    // blank pane indefinitely. A pane on this device is owed the same
    // answer, and has no session to hear it on.
    if (peerDeviceId == localViewerWatcher) {
      if (!_localRefusals.isClosed) _localRefusals.add((sourceId, reason));
      return;
    }
    peers.sendEphemeralTo(peerDeviceId, PeerMessage.screenRefuse(sourceId, reason));
  }

  /// The ticket to grant [peerDeviceId] — the one already outstanding for
  /// it, or a fresh one.
  ///
  /// REUSED, never replaced. Two subscribes racing the dial is the ordinary
  /// case (two panes on one peer, or the resubscribe that a session
  /// establishing triggers), and the viewer dials exactly once — so a second
  /// mint that invalidated the first would have it dial a ticket the
  /// producer no longer knows, be refused, and retry into the same race for
  /// good. One per peer also keeps this from accumulating bearer tokens: it
  /// is consumed when a link presents it, and dropped with the peer.
  String _ticketFor(String peerDeviceId) {
    for (final entry in _tickets.entries) {
      if (entry.value == peerDeviceId) return entry.key;
    }
    return _mintTicket(peerDeviceId);
  }

  String _mintTicket(String peerDeviceId) {
    // 128 bits from a secure source. It admits a socket that carries no
    // hello, so it is the only thing standing between a media link and
    // whatever else is on this network segment — and unlike the control
    // link's trust, it cannot fall back on the operator confirming anything.
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final ticket = base64Url.encode(bytes);
    _tickets[ticket] = peerDeviceId;
    return ticket;
  }

  void _armMediaDeadline(String peerDeviceId) {
    _awaitingMedia.remove(peerDeviceId)?.cancel();
    _awaitingMedia[peerDeviceId] = Timer(mediaDeadline, () {
      _awaitingMedia.remove(peerDeviceId);
      if (_mediaLinks.containsKey(peerDeviceId)) return;
      for (final entry in _watchers.entries) {
        if (entry.value.contains(peerDeviceId)) _refuse(peerDeviceId, entry.key, 'noMedia');
      }
      unawaited(removeAllFor(peerDeviceId));
    });
  }

  void _onMediaConnection(PeerMediaConnection connection) {
    // Consumed on presentation, whether or not it is good: a ticket that
    // survived a failed match would be a token an attacker could keep
    // guessing against.
    final peerDeviceId = _tickets.remove(connection.ticket);
    if (peerDeviceId == null || !peers.hasLanSession(peerDeviceId)) {
      debugPrint('[peer] refused a media link presenting an unknown ticket');
      unawaited(connection.link.close());
      return;
    }
    _awaitingMedia.remove(peerDeviceId)?.cancel();
    unawaited(_mediaAcks.remove(peerDeviceId)?.cancel());
    // Whatever was outstanding went down with the link it was written to.
    // A half-open socket accepts writes that reach nobody, so those frames
    // are charged to a window no acknowledgement can ever reopen — and the
    // replacement link would be sent nothing at all.
    _forgetFlowsOf(peerDeviceId);
    unawaited(_mediaLinks.remove(peerDeviceId)?.close());
    _mediaLinks[peerDeviceId] = connection.link;
    // The producer has never read from this socket before. Everything
    // arriving on it is an acknowledgement.
    _mediaAcks[peerDeviceId] = connection.link.inbound.listen(
      (bytes) => _onAck(peerDeviceId, bytes),
      onError: (Object e) => debugPrint('[peer] media link from $peerDeviceId errored: $e'),
      cancelOnError: false,
    );
    unawaited(connection.link.closed.then((_) {
      // Only if it is still THIS link: a peer that redialled has already
      // replaced it, and tearing its watchers down on the old one's close
      // would kill the view that just came back.
      if (_mediaLinks[peerDeviceId] != connection.link) return;
      _mediaLinks.remove(peerDeviceId);
      unawaited(_mediaAcks.remove(peerDeviceId)?.cancel());
      unawaited(removeAllFor(peerDeviceId));
    }));
    notifyListeners();
  }

  /// Returns whether the capture is actually running. The caller must not
  /// grant a viewer anything on a false — see [addWatcher].
  Future<bool> _startCapture(String sourceId, PeerScreenSubscription terms) async {
    try {
      await _capture.start(
        sourceId,
        maxWidth: terms.maxWidth.clamp(160, _maxCaptureWidth),
        fps: terms.fps,
        quality: terms.quality,
        crop: terms.crop,
      );
      // A restart builds a new capture session, which numbers its frames from
      // one again — so anything outstanding against the OLD numbering can
      // never be matched, for any watcher, not merely the one that triggered
      // this.
      //
      // AFTER the start, not before: the old session's teardown is
      // asynchronous on the native side, and a frame already in its encode
      // pipeline still arrives here. Cleared first, that straggler is charged
      // into the fresh window with a sequence the new numbering will never
      // reach, and the flow runs at half depth — or shut — for good.
      for (final watcher in _watchers[sourceId] ?? const <String>{}) {
        _forgetFlow(_flowKey(watcher, sourceId));
      }
      _error = null;
      return true;
    } on ScreenCaptureException catch (e) {
      _error = e.message;
      return false;
    }
  }

  void _onFrame(Uint8List frame) {
    // ONE header read for both fields. A frame missing either is dropped
    // rather than sent: every viewer would fail to decode it anyway, and
    // sending it would ALSO bypass the window — restoring the unbounded
    // socket queue this exists to remove, with nothing counting it.
    final routing = PeerScreenFrame.routingOf(frame);
    if (routing == null) {
      if (_unroutableCaptures.add('?')) {
        debugPrint('[peer] a captured frame has no source or sequence — dropped');
      }
      return;
    }
    final sourceId = routing.sourceId;
    _framesCaptured++;
    final watchers = _watchers[sourceId];
    if (watchers == null || watchers.isEmpty) return;

    for (final watcher in watchers) {
      if (watcher == localViewerWatcher) {
        if (!_localFrames.isClosed) _localFrames.add(frame);
        continue;
      }
      // No link yet means the peer has been granted and has not dialled.
      // Dropping is right: a live view wants the next frame, not a queue of
      // stale ones replayed at it the moment it connects.
      //
      // Checked BEFORE the window is charged. Counting a frame as sent when
      // there was nothing to send it on leaves the window closed against an
      // acknowledgement that can never come, and the viewer is starved from
      // the moment it finally connects.
      final link = _mediaLinks[watcher];
      if (link == null) continue;

      // Paced only for a viewer that said it would answer. Left ungated, a
      // peer on an older build would take a window's worth and then never be
      // sent another frame.
      final key = _flowKey(watcher, sourceId);
      if (_pacedFlows.contains(key)) {
        final outstanding = _unacked[key] ??= <int>{};
        // A sequence below what is already outstanding is the first frame of
        // a RESTARTED capture, which numbers from one again. Whatever the old
        // session left behind can never be acknowledged now, so it goes —
        // otherwise the window stays partly, or wholly, shut for good.
        if (outstanding.any((sent) => sent > routing.sequence)) outstanding.clear();
        if (outstanding.length >= inFlightWindow) {
          // Dropped, not queued. What is captured next is always a better
          // thing to send than what was skipped, and the viewer sees the gap
          // in the sequence numbers without being told.
          _framesDropped++;
          continue;
        }
        outstanding.add(routing.sequence);
        _armStall(watcher, sourceId, key);
      }
      link.send(frame);
    }

    // Deliberately no notifyListeners: nothing on THIS device draws a
    // captured frame, so a rebuild per frame would be ten a second per
    // running source for no visible change. Watcher-set changes notify from
    // where they happen.
  }

  void _onAck(String peerDeviceId, List<int> bytes) {
    final ack = PeerScreenAck.decode(bytes);
    if (ack == null) {
      // The producer reads nothing else on this socket, so bytes that are not
      // an acknowledgement mean a peer whose ack format this build cannot
      // read. Pacing it would jam every one of its flows at the window and
      // then refuse them for stalling — the operator told the link is slow
      // when the real answer is that the two builds disagree. So it is served
      // UNGATED from here, exactly as a peer that never acks at all: the
      // picture keeps working, and the queue it risks is the one that was
      // there before pacing existed.
      if (_unreadableAcksFrom.add(peerDeviceId)) {
        debugPrint('[peer] unreadable media-link message from $peerDeviceId'
            ' — a newer format? serving it ungated');
      }
      _pacedFlows.removeWhere((key) => key.startsWith('$peerDeviceId/'));
      _forgetFlowsOf(peerDeviceId);
      return;
    }
    final key = _flowKey(peerDeviceId, ack.sourceId);
    // Everything up to and including the acknowledged frame, which makes a
    // reordered or coalesced acknowledgement harmless WITHIN a capture
    // session. Across a restart it is looser — a late ack for an old, high
    // sequence would clear the new session's low ones too — which is why the
    // charge site drops the old numbering the moment it sees a lower one.
    final outstanding = _unacked[key];
    if (outstanding == null) return;
    outstanding.removeWhere((sequence) => sequence <= ack.sequence);
    if (outstanding.length < inFlightWindow) _stallTimers.remove(key)?.cancel();
  }

  /// Peers already reported as sending something unreadable on the media
  /// link. Once each, not once per message.
  final Set<String> _unreadableAcksFrom = {};

  /// Captures that carried no usable header. Reported once, not once a frame.
  final Set<String> _unroutableCaptures = {};

  /// Starts the clock on a flow whose window has just filled, and stops
  /// pacing it if the clock runs out.
  ///
  /// This is the one state pacing made possible: before it, a healthy link
  /// could not stop delivering. Now it can — both sockets open, capture
  /// running, nothing moving — and a viewer cannot tell that from a screen
  /// nobody is touching. So the producer, the side that knows it is holding
  /// frames it cannot send, says so and frees the capture.
  void _armStall(String watcher, String sourceId, String key) {
    if ((_unacked[key]?.length ?? 0) < inFlightWindow) return;
    if (_stallTimers.containsKey(key)) return;
    _stallTimers[key] = Timer(stallDeadline, () {
      _stallTimers.remove(key);
      debugPrint('[peer] $watcher stopped taking $sourceId — giving up on it');
      _refuse(watcher, sourceId, 'stalled');
      unawaited(removeWatcher(watcher, sourceId));
    });
  }

  /// Every window this peer held. Its acknowledgements can no longer arrive,
  /// so nothing else would ever reopen them.
  void _forgetFlowsOf(String peerDeviceId) {
    final prefix = '$peerDeviceId/';
    _unacked.removeWhere((key, _) => key.startsWith(prefix));
    _stallTimers.removeWhere((key, timer) {
      if (!key.startsWith(prefix)) return false;
      timer.cancel();
      return true;
    });
  }

  void _onCaptureStopped(ScreenCaptureStopped stopped) {
    // The OS ended it — the window closed, or the operator revoked Screen
    // Recording. Every watcher is TOLD before being dropped: a viewer left
    // holding a source that will never produce another frame freezes on its
    // last picture, which is the exact "a frozen pane and a broken network
    // look identical" failure this class exists to avoid.
    for (final watcher in _watchers[stopped.sourceId] ?? const <String>{}) {
      _refuse(watcher, stopped.sourceId, 'stopped');
    }
    _dropWatchers(stopped.sourceId);
    // NOT [_error]: a window closing is ordinary, and parking it there
    // leaves a red alert row in the settings panel that nothing clears until
    // the next successful listing.
    debugPrint('[peer] capture of ${stopped.sourceId} ended: ${stopped.reason}');
    notifyListeners();
  }

  /// The terms that satisfy both watchers — the larger size, the faster
  /// rate, the better quality and a crop covering both. Being generous costs
  /// the producer; being stingy would leave one viewer with a stream it
  /// cannot read.
  ///
  /// The crop is a UNION and not the smaller rect: two viewers zoomed into
  /// opposite corners must each see their own corner, and the one thing that
  /// serves both is the region spanning them. It costs the zoomed-in viewer
  /// the sharpness it asked for, which is the only part of this a second
  /// watcher can take away.
  static PeerScreenSubscription _widest(PeerScreenSubscription? a, PeerScreenSubscription b) {
    if (a == null) return b;
    final aCrop = a.crop ?? PeerScreenCrop.full;
    final bCrop = b.crop ?? PeerScreenCrop.full;
    final crop = aCrop.union(bCrop);
    final quality = a.quality > b.quality ? a.quality : b.quality;
    return PeerScreenSubscription(
      sourceId: b.sourceId,
      maxWidth: a.maxWidth > b.maxWidth ? a.maxWidth : b.maxWidth,
      fps: a.fps > b.fps ? a.fps : b.fps,
      // A union that covers everything is a full frame, and the extra
      // quality a viewer asked for on the strength of a small picture is
      // not owed on a whole screen — that is bandwidth neither of them
      // asked for.
      quality: crop.isFull ? PeerScreenSubscription.defaultQuality : quality,
      crop: crop.isFull ? null : crop,
    );
  }

  @override
  void dispose() {
    unawaited(_frameSubscription?.cancel());
    unawaited(_stoppedSubscription?.cancel());
    unawaited(_mediaSubscription?.cancel());
    for (final link in _mediaLinks.values) {
      unawaited(link.close());
    }
    _mediaLinks.clear();
    _tickets.clear();
    for (final timer in _awaitingMedia.values) {
      timer.cancel();
    }
    _awaitingMedia.clear();
    for (final subscription in _mediaAcks.values) {
      unawaited(subscription.cancel());
    }
    _mediaAcks.clear();
    for (final timer in _stallTimers.values) {
      timer.cancel();
    }
    _stallTimers.clear();
    unawaited(_localFrames.close());
    unawaited(_localRefusals.close());
    unawaited(_capture.dispose());
    super.dispose();
  }
}
