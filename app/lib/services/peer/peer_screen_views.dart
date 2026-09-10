// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The viewer half of screen sharing (HALO-369): what this device's peers are
// offering, and the ones it is actually watching.
//
// Mirror image of `PeerScreens`, and it earns its own class rather than a
// second role inside that one: a device is routinely both at once, and the
// two halves share no state beyond the peer link. What they DO share is the
// discipline — a stream runs only while a pane is asking for it, because the
// cost of one that keeps running lands on the other device's GPU and on the
// operator's network.
//
// Every panel that wants a screen registers under its own id; several panes
// showing the same source cost one subscription and one media link.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import '../error_reporting_service.dart';
import 'peer_link_types.dart';
import 'peer_screens.dart';
import 'peer_service.dart';

/// This device, standing in for a peer in the catalog a pane picks from.
///
/// A device sharing to itself is not a curiosity: an operator running WSJT-X
/// beside the log wants it in a pane on the same screen, and building that
/// as a second mechanism would mean a second set of bugs. It is the same
/// offer, the same watcher registry and the same frames — only the socket
/// between them is missing, because there is no network between a device and
/// itself.
///
/// Not a device id, and it cannot collide with one: a peer device id is a
/// UUID.
const String localScreenPeerId = 'local';

/// Where a view stands, for a pane that has to say something to the operator
/// rather than sit blank.
enum PeerScreenViewStatus {
  /// Asked, nothing back yet.
  connecting,

  /// Frames are arriving.
  live,

  /// The producer said no. [PeerScreenView.refusal] carries which reason.
  refused,

  /// The peer is not connected — carried out of range, switched off, or on
  /// Bluetooth, where screen sharing does not run.
  peerUnreachable,
}

/// One thing this device is watching.
class PeerScreenView {
  final String peerDeviceId;
  final String sourceId;
  final PeerScreenViewStatus status;

  /// The producer's machine-readable reason: `notOffered`, `noLan`,
  /// `noListener`. Null unless [status] is refused.
  final String? refusal;

  final PeerScreenFrame? frame;

  /// Whether frames are being dropped on the way here often enough to be
  /// worth saying. Still LIVE — the picture is current, just intermittent —
  /// which is why the pane marks it differently from a stalled one.
  final bool degraded;

  const PeerScreenView({
    required this.peerDeviceId,
    required this.sourceId,
    required this.status,
    this.refusal,
    this.frame,
    this.degraded = false,
  });

  /// [refusal] is tied to [status] rather than carried forward: a view that
  /// goes refused → live would otherwise keep the old reason, and the first
  /// caller to show one beside a live frame reads a stale explanation. The
  /// frame IS carried forward, deliberately — the last picture is what a
  /// pane keeps when things go wrong.
  PeerScreenView _with({
    PeerScreenViewStatus? status,
    String? refusal,
    PeerScreenFrame? frame,
    bool? degraded,
  }) {
    final nextStatus = status ?? this.status;
    return PeerScreenView(
      peerDeviceId: peerDeviceId,
      sourceId: sourceId,
      status: nextStatus,
      refusal: nextStatus == PeerScreenViewStatus.refused ? (refusal ?? this.refusal) : null,
      frame: frame ?? this.frame,
      // Only a live view can be degraded: a stalled one has its own reason
      // to show, and two notices about the same pane would contradict.
      degraded: nextStatus == PeerScreenViewStatus.live && (degraded ?? this.degraded),
    );
  }
}

/// A source on a particular peer — what a panel stores, as one string.
///
/// One string because that is what per-placement panel config holds, and
/// splitting on the FIRST slash is safe: a device id never contains one, and
/// a source id may (a window title does not reach the id, but nothing here
/// should depend on that).
class PeerScreenTarget {
  final String peerDeviceId;
  final String sourceId;

  const PeerScreenTarget(this.peerDeviceId, this.sourceId);

  String encode() => '$peerDeviceId/$sourceId';

  static PeerScreenTarget? decode(String? raw) {
    if (raw == null) return null;
    final slash = raw.indexOf('/');
    if (slash <= 0 || slash == raw.length - 1) return null;
    return PeerScreenTarget(raw.substring(0, slash), raw.substring(slash + 1));
  }

  @override
  bool operator ==(Object other) =>
      other is PeerScreenTarget && other.peerDeviceId == peerDeviceId && other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(peerDeviceId, sourceId);
}

/// What one pane is actually looking at, and how finely.
///
/// [maxWidth] is pixels across the CROP, so a pane asks for the same number
/// of them however far it is zoomed in — the zoom shrinks the region those
/// pixels are spent on.
///
/// [fullWidth] is what to ask for when the crop cannot be had: a producer
/// on a build that predates cropping ignores the rect and serves the width
/// across the WHOLE source, which for a zoomed pane is a fraction of the
/// detail it asked for. The pane works this one out because the trade is
/// its own — it knows both how far it is zoomed and how much of the link it
/// may spend. Equal to [maxWidth] whenever there is no crop.
///
/// A record, for its structural equality: the whole point is comparing what
/// a pane wants now against what it wanted a moment ago without a rebuild
/// counting as a change.
typedef PeerScreenDemand = ({int maxWidth, int fullWidth, PeerScreenCrop? crop});

class PeerScreenViews extends ChangeNotifier {
  PeerScreenViews({
    required this.peers,
    this.screens,
    this.localName = 'This device',
    this.maxWidth = 1280,
    this.fps = 10,
  }) {
    final producer = screens;
    if (producer != null) {
      // The producer's own stills land in ITS notifier, and the picker
      // listens only to this one — so a local thumbnail arriving has to
      // reach here or the tile never redraws.
      producer.addListener(_onProducerChanged);
      _localFrames = producer.localFrames.listen(_onLocalFrame);
      _localRefusals = producer.localRefusals.listen(
        (refusal) => onRefused(localScreenPeerId, refusal.$1, refusal.$2),
      );
    }
  }

  final PeerService peers;

  /// This device's own producer, when it has one — what makes a pane here
  /// able to show a screen this same device is sharing. Null on a device
  /// that only ever views.
  final PeerScreens? screens;

  /// What this device calls itself in the picker.
  final String localName;

  StreamSubscription<Uint8List>? _localFrames;
  StreamSubscription<(String, String)>? _localRefusals;

  /// Stills of what peers offer, keyed `<peer>/<source>`. Asked for on
  /// demand by the picker, never carried on the offer itself.
  final Map<String, Uint8List> _thumbnails = {};
  final Set<String> _thumbnailsAsked = {};

  static String _thumbKey(String peerDeviceId, String sourceId) => '$peerDeviceId/$sourceId';

  /// The still for one source, wherever it lives — this device's own come
  /// straight from the producer with no message in between.
  Uint8List? thumbnailFor(String peerDeviceId, String sourceId) =>
      peerDeviceId == localScreenPeerId
          ? screens?.thumbnailFor(sourceId)
          : _thumbnails[_thumbKey(peerDeviceId, sourceId)];

  /// Asks for a still, once. Safe to call from a tile's build: it is a
  /// no-op for anything already asked for or already had.
  void requestThumbnail(String peerDeviceId, String sourceId) {
    if (peerDeviceId == localScreenPeerId) {
      screens?.requestThumbnail(sourceId);
      return;
    }
    final key = _thumbKey(peerDeviceId, sourceId);
    if (_thumbnails.containsKey(key) || !_thumbnailsAsked.add(key)) return;
    peers.sendEphemeralTo(peerDeviceId, PeerMessage.screenThumbRequest(sourceId));
  }

  /// Drops every still so the next look re-asks — what the picker's refresh
  /// does. A thumbnail is a photograph, and what it shows has moved on.
  void clearThumbnails() {
    _thumbnails.clear();
    _thumbnailsAsked.clear();
    screens?.clearThumbnails();
    notifyListeners();
  }

  /// Adjust View requests, per panel placement.
  ///
  /// A counter rather than a callback, the same seam `PanelService`'s
  /// refresh requests use and for the same reason: the asker is a settings
  /// dialog and the answerer is a pane, and neither holds the other. Framing
  /// the picture is a MODE the pane enters, so it cannot be a value the
  /// dialog simply stores.
  final Map<String, int> _adjustRequests = {};

  int adjustRequests(String panelId) => _adjustRequests[panelId] ?? 0;

  void requestAdjust(String panelId) {
    _adjustRequests[panelId] = adjustRequests(panelId) + 1;
    notifyListeners();
  }

  void onThumb(String peerDeviceId, String sourceId, Uint8List? image) {
    if (image != null) _thumbnails[_thumbKey(peerDeviceId, sourceId)] = image;
    notifyListeners();
  }

  /// What this device asks producers for when a pane has not said what it
  /// needs. A producer clamps these to what it can do, so they are a
  /// preference rather than a demand.
  final int maxWidth;
  final int fps;

  /// What each pane wants of its target. Kept per PANE, not per target: two
  /// panes on one source is the case this exists to get right, and the terms
  /// actually asked for are the ones that satisfy both.
  final Map<String, PeerScreenDemand> _demands = {};

  /// Which target each pane's demand describes. A crop only means anything
  /// against the picture it was measured on.
  final Map<String, PeerScreenTarget> _demandTargets = {};

  /// The terms last asked of each target, so a pane reporting the same thing
  /// twice — every rebuild does — costs nothing, and only a real change
  /// re-subscribes.
  final Map<PeerScreenTarget, PeerScreenSubscription> _asked = {};

  /// Pending re-subscribes, per target. Changing terms restarts the capture
  /// on the far device: a resize dragged across the screen would otherwise
  /// be a stop-and-start per frame of the drag.
  final Map<PeerScreenTarget, Timer> _retermTimers = {};

  /// Long enough to sit out a window drag, short enough that letting go of
  /// one sharpens the picture while the operator is still looking at it.
  static const Duration retermDelay = Duration(milliseconds: 400);

  /// A pane says what it is looking at. Cheap to call from a layout pass:
  /// an unchanged demand returns without touching the network.
  void setDemand(String subscriberId, PeerScreenDemand demand) {
    if (_demands[subscriberId] == demand) return;
    _demands[subscriberId] = demand;
    final target = _subscribers[subscriberId];
    // Which picture this was measured against — see [subscribe].
    if (target != null) _demandTargets[subscriberId] = target;
    if (target != null) _scheduleReterm(target);
  }

  void _scheduleReterm(PeerScreenTarget target) {
    if (_termsFor(target) == _asked[target]) {
      // Back to what is already running — a pane that zoomed in and out
      // again, or a second pane whose demand the first already covers.
      _retermTimers.remove(target)?.cancel();
      return;
    }
    _retermTimers[target]?.cancel();
    _retermTimers[target] = Timer(retermDelay, () {
      _retermTimers.remove(target);
      if (!_views.containsKey(target)) return;
      if (_termsFor(target) == _asked[target]) return;
      // The far side restarts its capture at the new terms, which numbers
      // frames from one again; a sequence that goes BACKWARDS is not loss,
      // and counted as such it would paint "struggling" over a stream that
      // just got sharper.
      _resetDeliveryStats(target);
      _ensure(target);
    });
  }

  /// The terms that satisfy every pane watching [target] — the widest size,
  /// and a crop covering all of them. Panes that have said nothing count as
  /// wanting the whole source at the default size, which is what a build
  /// before any of this asked for.
  PeerScreenSubscription _termsFor(PeerScreenTarget target) {
    var width = 0;
    var fullWidth = 0;
    PeerScreenCrop? crop;
    var full = false;
    for (final entry in _subscribers.entries) {
      if (entry.value != target) continue;
      final demand = _demands[entry.key];
      if (demand == null) {
        full = true;
        width = width > maxWidth ? width : maxWidth;
        fullWidth = fullWidth > maxWidth ? fullWidth : maxWidth;
        continue;
      }
      width = width > demand.maxWidth ? width : demand.maxWidth;
      fullWidth = fullWidth > demand.fullWidth ? fullWidth : demand.fullWidth;
      final wanted = demand.crop;
      if (wanted == null) {
        full = true;
      } else {
        crop = crop == null ? wanted : crop.union(wanted);
      }
    }
    if (width == 0) width = maxWidth;
    if (fullWidth == 0) fullWidth = width;
    // A union of two panes in opposite corners spans the whole source. That
    // is a full frame however it was arrived at, and left as a crop it would
    // be a full frame billed as a small one — the ceiling spent on every
    // pixel of the screen, at the better quality a small picture earns.
    if (full || (crop?.isFull ?? false)) crop = null;
    // A producer that does not honour a crop serves the width asked for
    // across the WHOLE source, so the rect is not worth sending — and a
    // zoomed pane would come back blurrier from such a peer than it did
    // before cropping existed.
    if (crop != null && !_croppingTargets.contains(target)) {
      crop = null;
      // Only where a grant has actually come back without the word: terms
      // are worked out before the first one arrives, and again after a LAN
      // session bounces, and calling a peer an old build on that evidence
      // sends whoever reads the console after the wrong thing.
      if (_grantedTargets.contains(target) && _droppedCropFor.add(target)) {
        // Once per target, like an unreadable frame: a mixed pair of builds
        // is otherwise a pane that will not sharpen on ONE peer, with
        // nothing anywhere saying why.
        debugPrint('[peer] ${target.peerDeviceId} does not crop — '
            '${target.sourceId} goes out at full-source terms');
      }
    }
    // Every path above that discards a crop leaves [width] measured across
    // one, which is a fraction of what the whole picture needs — a pane
    // zoomed 4× would be handed a quarter of the detail it just had because
    // a SECOND pane opened on the same source. What each pane says the whole
    // picture is worth is what goes instead.
    if (crop == null) width = fullWidth;
    return PeerScreenSubscription(
      sourceId: target.sourceId,
      // Only the wire's own bounds here: how much a pane may spend is the
      // PANE's, set in its own settings and already applied to the demand it
      // reported. Re-imposing a ceiling at this level would silently
      // override a pane the operator deliberately turned up.
      maxWidth: width.clamp(160, 3840),
      fps: fps,
      // A cropped stream is a small picture of a small region, so the bytes
      // a better encode costs are small too — and artefacts are most of what
      // a zoomed-in viewer is actually looking at.
      quality: crop == null ? PeerScreenSubscription.defaultQuality : 0.8,
      crop: crop,
      // This build answers, so the producer may pace it.
      acks: true,
    );
  }

  /// What each peer says it is offering, latest-value-wins. A peer absent
  /// from this map has not said anything; a peer present with an empty list
  /// has said it is sharing nothing, and those are different — one is
  /// silence, the other an answer.
  final Map<String, List<PeerScreenSource>> _offers = {};

  /// Which panes want which target, so a target with no panes left can be
  /// let go and several panes on one target cost one stream.
  final Map<String, PeerScreenTarget> _subscribers = {};

  final Map<PeerScreenTarget, PeerScreenView> _views = {};

  /// One media link per peer, dialled on the first grant from it.
  final Map<String, PeerLink> _mediaLinks = {};
  final Map<String, StreamSubscription<List<int>>> _mediaSubscriptions = {};

  /// Peers a dial is already in flight for — a second grant arriving while
  /// the first is connecting must not open a second socket.
  final Set<String> _dialling = {};

  /// Targets a grant has been seen for, so "this producer does not crop" is
  /// something the producer said rather than something not yet asked.
  final Set<PeerScreenTarget> _grantedTargets = {};

  /// Targets already reported as being served by a producer that does not
  /// crop, so the line is written once rather than per change of terms.
  final Set<PeerScreenTarget> _droppedCropFor = {};

  /// Targets whose grant said the producer honours a crop.
  ///
  /// Per target and not per peer, for the reason [_pacedTargets] is: a grant
  /// is per source. This device's own producer is in from the start — there
  /// is no grant on that path, and it is this very build.
  final Set<PeerScreenTarget> _croppingTargets = {};

  /// Targets whose grant said the producer reads acknowledgements.
  ///
  /// Acking one that does not is not merely wasted: a producer predating
  /// pacing never listens to its end of the media link, and a `PeerLink`'s
  /// inbound controller is single-subscription — so every ack is BUFFERED
  /// there for the life of the link. That is the unbounded growth this
  /// feature removes, handed to the other device instead.
  ///
  /// Per TARGET, matching how the producer keys its own half: a grant is per
  /// source, and one keyed per peer would let a single ungated grant stop
  /// acking every other source that peer is streaming — jamming flows it IS
  /// pacing, which it would then refuse for stalling.
  final Set<PeerScreenTarget> _pacedTargets = {};

  /// Targets given up on for stalling, and how many times.
  ///
  /// A stall says this viewer did not take delivery. Asking again is right
  /// once — a passing squeeze on the link — but a viewer that cannot keep up
  /// fails the same way every time, and each cycle costs the OTHER device a
  /// full capture stop and restart. So it stops asking and leaves the notice
  /// up for the operator.
  final Map<PeerScreenTarget, int> _stalls = {};

  /// How many times a target is re-asked after a stall before it is left
  /// alone.
  static const int _stallRetries = 2;

  /// Peers already reported as sending frames this build cannot decode.
  final Set<String> _unreadableFrom = {};

  /// The last sequence seen per target, and how many were missing from the
  /// recent past. The producer drops silently by design, so the GAPS are the
  /// only evidence this side has — and they are exact, because a sequence is
  /// stamped per captured frame rather than per sent one.
  final Map<PeerScreenTarget, int> _lastSeq = {};
  final Map<PeerScreenTarget, List<bool>> _recent = {};

  /// Frames to judge over, and how many of them may be missing before the
  /// pane says so. A brief hiccup is normal on any wireless link; this is
  /// meant to catch a viewer that is persistently behind.
  static const int _dropWindow = 40;
  static const int _dropsBeforeSaying = 12;

  /// Forgets what this target's delivery looked like.
  ///
  /// Called wherever a view stops being live. The source may keep capturing
  /// for another watcher while this one is away, so the first frame after
  /// recovery carries a large sequence jump — counted as drops, that pins the
  /// struggling notice on for a whole window of a perfectly healthy stream.
  void _resetDeliveryStats(PeerScreenTarget target) {
    _lastSeq.remove(target);
    _recent.remove(target);
  }

  /// Pending re-asks, per peer. A media link can drop while the control link
  /// stays perfectly healthy (any transient on the second socket), and
  /// nothing else re-drives the flow: the producer stops capturing when its
  /// end closes, and this end would sit on "Connecting…" until the whole
  /// peer session happened to bounce.
  final Map<String, Timer> _retries = {};

  /// Long enough not to spin against a peer that is refusing, short enough
  /// that a pane recovers from a blip while the operator is still looking
  /// at it.
  static const Duration retryDelay = Duration(seconds: 3);

  /// How long a subscribe may go unanswered before the pane says so.
  ///
  /// Nothing else bounds it: a producer with the experiment off drops the
  /// message deliberately, a build predating this feature has never heard of
  /// it, and a wedged capture answers neither grant nor refusal. All three
  /// end at "Connecting…" for the life of the session without this.
  static const Duration answerDeadline = Duration(seconds: 8);

  /// Subscribes still waiting on an answer.
  final Map<PeerScreenTarget, Timer> _awaitingAnswer = {};

  void _armAnswerDeadline(PeerScreenTarget target) {
    _awaitingAnswer.remove(target)?.cancel();
    _awaitingAnswer[target] = Timer(answerDeadline, () {
      _awaitingAnswer.remove(target);
      final view = _views[target];
      // Only while still waiting — a grant or a refusal that landed in the
      // meantime is the answer, and must not be overwritten.
      if (view == null || view.status != PeerScreenViewStatus.connecting) return;
      _views[target] = view._with(
        status: PeerScreenViewStatus.refused,
        refusal: 'noAnswer',
      );
      notifyListeners();
      _scheduleRetry(target.peerDeviceId);
    });
  }

  void _answered(PeerScreenTarget target) {
    _awaitingAnswer.remove(target)?.cancel();
    _awaitingTerms.remove(target)?.cancel();
    _termAttempts.remove(target);
  }

  /// Re-terms waiting to be answered, and how many times each has been asked.
  ///
  /// [_armAnswerDeadline] cannot cover these: it fires only on a view still
  /// CONNECTING, and a re-term happens to one that is live and staying live.
  /// A subscribe travels as an ephemeral message — best effort, unacked — so
  /// one that is dropped would otherwise leave this side believing terms are
  /// in force that the producer never heard, with `_asked` recording the
  /// intent and nothing ever asking again. What the operator sees is a pane
  /// they zoomed into that never sharpens, for the life of the session.
  final Map<PeerScreenTarget, Timer> _awaitingTerms = {};
  final Map<PeerScreenTarget, int> _termAttempts = {};

  /// Long enough for a producer to restart a capture and answer, short
  /// enough to be inside the time an operator waits before deciding the
  /// zoom did nothing.
  static const Duration termsDeadline = Duration(seconds: 5);

  /// How many times a change of terms is re-sent before this gives up and
  /// leaves the stream as it is. A producer that answers none of them is not
  /// going to answer the fourth.
  static const int termRetries = 2;

  void _armTermsDeadline(PeerScreenTarget target) {
    // A view that is not live has the connecting deadline instead, which
    // says so on the pane; two deadlines over one subscribe would race to
    // describe it.
    if (_views[target]?.status != PeerScreenViewStatus.live) return;
    _awaitingTerms.remove(target)?.cancel();
    _awaitingTerms[target] = Timer(termsDeadline, () {
      _awaitingTerms.remove(target);
      if (!_views.containsKey(target)) return;
      final attempts = (_termAttempts[target] ?? 0) + 1;
      if (attempts > termRetries) {
        _termAttempts.remove(target);
        // Forgotten rather than left standing: the terms were never
        // acknowledged, so recording them as asked would suppress the next
        // attempt too. The stream carries on at whatever it is serving.
        _asked.remove(target);
        debugPrint('[peer] ${target.peerDeviceId} never answered new terms for '
            '${target.sourceId} — leaving the stream as it is');
        return;
      }
      _termAttempts[target] = attempts;
      _ensure(target);
    });
  }

  Map<String, List<PeerScreenSource>> get offers => Map.unmodifiable(_offers);

  PeerScreenView? viewFor(PeerScreenTarget? target) => target == null ? null : _views[target];

  /// Every source on offer anywhere, with the peer that offers it — what a
  /// panel's picker lists.
  List<(String peerDeviceId, String peerName, PeerScreenSource source)> get catalog => [
        // This device first: it is the one the operator is looking at, and
        // its sources are the ones they can check against what is actually
        // on screen.
        for (final source in screens?.offeredSources ?? const <PeerScreenSource>[])
          (localScreenPeerId, localName, source),
        for (final entry in _offers.entries)
          for (final source in entry.value)
            (entry.key, _nameOf(entry.key), source),
      ];

  String _nameOf(String peerDeviceId) {
    final name = peers.peers[peerDeviceId]?.beacon.deviceName;
    return (name == null || name.isEmpty) ? peerDeviceId : name;
  }

  /// Records a peer's offer. Called from the ephemeral router.
  void setOffer(String peerDeviceId, List<PeerScreenSource> sources) {
    _offers[peerDeviceId] = sources;
    // A source that has left the offer stops being watched now rather than
    // when its frames happen to dry up: "they stopped sharing it" and "the
    // network went quiet" look the same on a frozen pane.
    final ids = sources.map((s) => s.id).toSet();
    for (final target in _views.keys.toList()) {
      if (target.peerDeviceId == peerDeviceId && !ids.contains(target.sourceId)) {
        _views[target] = _views[target]!._with(
          status: PeerScreenViewStatus.refused,
          refusal: 'notOffered',
        );
      }
    }
    notifyListeners();
    // Anything a pane still wants and the peer now offers again is re-asked
    // for — a producer that restarted has forgotten every subscription.
    _resubscribeWanted(peerDeviceId);
  }

  /// A pane declares what it wants to see. Idempotent per [subscriberId]:
  /// pointing a pane at a different source silently drops the old one.
  void subscribe(String subscriberId, PeerScreenTarget target) {
    final previous = _subscribers[subscriberId];
    if (previous == target) return;
    _subscribers[subscriberId] = target;
    // The CROP goes with the picture it was measured against — it says which
    // part of THAT screen the pane could see, and against another one it
    // asks the far device to capture the top-left quarter of something the
    // operator has never framed. The width is about the pane and stays, so
    // a pane repointed at a similar source re-terms nothing at all.
    //
    // Against the target the demand was MEASURED for, not against the one
    // held a moment ago: a pane comes back from a dock tab having released
    // its target, and dropping the framing there would cost the extra
    // capture restart the demand is kept across a hide to avoid.
    final demand = _demands[subscriberId];
    if (demand != null && demand.crop != null && _demandTargets[subscriberId] != target) {
      _demands[subscriberId] =
          (maxWidth: demand.maxWidth, fullWidth: demand.fullWidth, crop: null);
      _demandTargets[subscriberId] = target;
    }
    if (previous != null) {
      _releaseIfUnwanted(previous);
      // Still watched by other panes, whose own terms may now be all that
      // has to be served — the mirror of what [unsubscribe] does, and
      // without it a source keeps being captured at the terms of a pane
      // that has gone somewhere else.
      if (_views.containsKey(previous)) _scheduleReterm(previous);
    }
    _ensure(target);
  }

  /// A pane stops watching — which every hide edge does, not only a pane
  /// being closed: a dock tab switched away from, the app sent to the
  /// background. The DEMAND survives that, exactly as the pane's zoom and
  /// pan do; see [forgetDemand].
  void unsubscribe(String subscriberId) {
    final target = _subscribers.remove(subscriberId);
    if (target != null) {
      _releaseIfUnwanted(target);
      // Still watched by someone else, whose own terms may now be all that
      // has to be served.
      if (_views.containsKey(target)) _scheduleReterm(target);
    }
  }

  /// The pane is gone for good. Kept apart from [unsubscribe] because a
  /// demand dropped on every hide costs two capture restarts per tab switch:
  /// the first subscribe asks for the whole source at the default size, and
  /// the pane's first layout then asks for its crop all over again.
  void forgetDemand(String subscriberId) {
    _demands.remove(subscriberId);
    _demandTargets.remove(subscriberId);
  }

  /// A peer went away. Its views keep their last frame and say why — a blank
  /// pane and a broken feature look identical, so the picture stays with the
  /// reason written over it.
  void forgetPeer(String peerDeviceId) {
    _retries.remove(peerDeviceId)?.cancel();
    _lastSeq.removeWhere((target, _) => target.peerDeviceId == peerDeviceId);
    _recent.removeWhere((target, _) => target.peerDeviceId == peerDeviceId);
    _offers.remove(peerDeviceId);
    _thumbnails.removeWhere((key, _) => key.startsWith('$peerDeviceId/'));
    _thumbnailsAsked.removeWhere((key) => key.startsWith('$peerDeviceId/'));
    unawaited(_mediaSubscriptions.remove(peerDeviceId)?.cancel());
    unawaited(_mediaLinks.remove(peerDeviceId)?.close());
    _dialling.remove(peerDeviceId);
    // The dial streak means "stuck right now". A count that spanned the
    // peer's absence would report its first failure on return as three in
    // a row — or, parked past the threshold, never report it at all.
    ErrorReportingService.recordSuccess(_dialStreakKey(peerDeviceId));
    _pacedTargets.removeWhere((target) => target.peerDeviceId == peerDeviceId);
    _croppingTargets.removeWhere((target) => target.peerDeviceId == peerDeviceId);
    _droppedCropFor.removeWhere((target) => target.peerDeviceId == peerDeviceId);
    _grantedTargets.removeWhere((target) => target.peerDeviceId == peerDeviceId);
    // Pending work for a peer that has gone. A reterm that fires afterwards
    // finds the view still there — kept, with its reason written over it —
    // re-enters [_ensure] and records terms nothing ever sent.
    for (final target in _retermTimers.keys.toList()) {
      if (target.peerDeviceId == peerDeviceId) _retermTimers.remove(target)?.cancel();
    }
    for (final target in _awaitingTerms.keys.toList()) {
      if (target.peerDeviceId == peerDeviceId) _awaitingTerms.remove(target)?.cancel();
    }
    _termAttempts.removeWhere((target, _) => target.peerDeviceId == peerDeviceId);
    _stalls.removeWhere((target, _) => target.peerDeviceId == peerDeviceId);
    for (final target in _views.keys.toList()) {
      if (target.peerDeviceId != peerDeviceId) continue;
      _views[target] = _views[target]!._with(status: PeerScreenViewStatus.peerUnreachable);
    }
    notifyListeners();
  }

  /// A peer came back. Everything a pane still wants is asked for again.
  void onPeerAvailable(String peerDeviceId) {
    _retries.remove(peerDeviceId)?.cancel();
    _resubscribeWanted(peerDeviceId);
  }

  /// Re-asks [peerDeviceId] for whatever panes still want, once, after
  /// [retryDelay]. Idempotent: a second call while one is pending does not
  /// stack a second timer.
  void _scheduleRetry(String peerDeviceId) {
    if (_retries.containsKey(peerDeviceId)) return;
    if (!_subscribers.values.any((t) => t.peerDeviceId == peerDeviceId)) return;
    _retries[peerDeviceId] = Timer(retryDelay, () {
      _retries.remove(peerDeviceId);
      if (!peers.hasLanSession(peerDeviceId)) return;
      _resubscribeWanted(peerDeviceId);
    });
  }

  // MARK: - Control messages

  void onGrant(String peerDeviceId, PeerScreenGrant grant) {
    final target = PeerScreenTarget(peerDeviceId, grant.sourceId);
    _answered(target);
    if (grant.paced) {
      _pacedTargets.add(target);
    } else {
      _pacedTargets.remove(target);
    }
    // Either way a reterm, because the terms now in force were worked out
    // before this peer had said which it was. Upwards it buys a pane its
    // rect; downwards it takes back a crop-scoped width the producer would
    // otherwise spread across the whole source — and `_asked` already holds
    // those terms, so nothing else would ever revisit them.
    _grantedTargets.add(target);
    if (grant.crops ? _croppingTargets.add(target) : _croppingTargets.remove(target)) {
      _scheduleReterm(target);
    }
    final existing = _views[target];
    // A grant for a view already LIVE is the answer to a change of terms —
    // the far device is restarting its capture to serve a sharper picture,
    // and the frames resume in a fraction of a second. Marking that
    // "Connecting…" would dim and label a working pane every time the
    // operator zoomed. Same rule as [_ensure], for the same reason.
    _views[target] = existing == null
        ? _blank(target)
        : (existing.status == PeerScreenViewStatus.live
            ? existing
            : existing._with(status: PeerScreenViewStatus.connecting));
    notifyListeners();
    // Frames arrive on the media link, which is per peer — a grant for a
    // second source from a peer already connected needs no new socket.
    if (_mediaLinks.containsKey(peerDeviceId) || _dialling.contains(peerDeviceId)) return;
    unawaited(_dialMedia(peerDeviceId, grant));
  }

  void onRefused(String peerDeviceId, String sourceId, String? reason) {
    final target = PeerScreenTarget(peerDeviceId, sourceId);
    _answered(target);
    _resetDeliveryStats(target);
    _views[target] = (_views[target] ?? _blank(target))._with(
      status: PeerScreenViewStatus.refused,
      refusal: reason ?? 'refused',
    );
    notifyListeners();
    // A capture that stopped or failed to start is a passing condition — the
    // window reopens, the permission is granted — unlike being told the
    // source is not offered, which only the operator can change. Asking
    // again is what makes those recover on their own.
    if (reason == 'stalled') {
      final attempts = _stalls.update(target, (n) => n + 1, ifAbsent: () => 1);
      if (attempts <= _stallRetries) _scheduleRetry(peerDeviceId);
      return;
    }
    if (reason == 'stopped' || reason == 'captureFailed') _scheduleRetry(peerDeviceId);
  }

  // MARK: - Internals

  PeerScreenView _blank(PeerScreenTarget target) => PeerScreenView(
        peerDeviceId: target.peerDeviceId,
        sourceId: target.sourceId,
        status: PeerScreenViewStatus.connecting,
      );

  void _ensure(PeerScreenTarget target) {
    final existing = _views[target];
    // Asking again means this is CONNECTING again — anything else leaves a
    // view stuck on the reason it was last refused for, which re-enters here
    // on the next notification and asks again, and notifies again. A live
    // view is left alone: it is already receiving, and blanking its notice
    // would flicker for nothing.
    _views[target] = existing == null
        ? _blank(target)
        : (existing.status == PeerScreenViewStatus.live
            ? existing
            : existing._with(status: PeerScreenViewStatus.connecting));
    if (target.peerDeviceId == localScreenPeerId) {
      // No grant, no ticket, no dial — the producer is right here. It still
      // goes through addWatcher, so this pane counts toward the rule that a
      // source captures only while somebody is watching it.
      // No grant on this path — the producer is this same build, so it
      // honours a crop by construction.
      _croppingTargets.add(target);
      final producer = screens;
      if (producer == null) {
        _views[target] = _views[target]!._with(
          status: PeerScreenViewStatus.refused, refusal: 'notOffered');
        notifyListeners();
        return;
      }
      unawaited(producer
          .addWatcher(localViewerWatcher, _recordTerms(target))
          .then((accepted) {
        if (!accepted) onRefused(localScreenPeerId, target.sourceId, 'notOffered');
      }));
      notifyListeners();
      return;
    }
    if (!peers.hasLanSession(target.peerDeviceId)) {
      _views[target] = _views[target]!._with(status: PeerScreenViewStatus.peerUnreachable);
      notifyListeners();
      return;
    }
    peers.sendEphemeralTo(
      target.peerDeviceId,
      PeerMessage.screenSubscribe(_recordTerms(target)),
    );
    _armAnswerDeadline(target);
    _armTermsDeadline(target);
    notifyListeners();
  }

  /// The terms for [target], remembered as the ones now asked for. Every
  /// path that sends a subscribe goes through here, so a re-subscribe for
  /// some other reason — a peer reappearing, a media link recovering — also
  /// settles the question of what is currently being asked for.
  PeerScreenSubscription _recordTerms(PeerScreenTarget target) {
    final terms = _termsFor(target);
    _asked[target] = terms;
    _retermTimers.remove(target)?.cancel();
    return terms;
  }

  void _resubscribeWanted(String peerDeviceId) {
    for (final target in _subscribers.values.toSet()) {
      if (target.peerDeviceId == peerDeviceId) _ensure(target);
    }
  }

  void _releaseIfUnwanted(PeerScreenTarget target) {
    if (_subscribers.values.contains(target)) return;
    _views.remove(target);
    _resetDeliveryStats(target);
    _asked.remove(target);
    _retermTimers.remove(target)?.cancel();
    _awaitingTerms.remove(target)?.cancel();
    _termAttempts.remove(target);
    // [_croppingTargets] deliberately SURVIVES: it is a fact about the
    // producer, not about the subscription that learned it, and it stops
    // being true only when that peer goes away or its next grant says
    // otherwise. Forgotten here, every pane reopened on a source it was
    // already watching asks for the whole picture, is granted, and then
    // asks again for its crop — the second capture restart this feature
    // spends its debounce avoiding.
    if (target.peerDeviceId == localScreenPeerId) {
      unawaited(screens?.removeWatcher(localViewerWatcher, target.sourceId) ?? Future<void>.value());
      notifyListeners();
      return;
    }
    peers.sendEphemeralTo(target.peerDeviceId, PeerMessage.screenUnsubscribe(target.sourceId));
    // The media link stays: it is per peer, and another pane may still be
    // watching a different source on the same one. It closes with the peer.
    notifyListeners();
  }

  /// The failure streak one peer's media dials report under.
  @visibleForTesting
  static String dialStreakKey(String peerDeviceId) => _dialStreakKey(peerDeviceId);

  static String _dialStreakKey(String peerDeviceId) => 'peer-media-dial:$peerDeviceId';

  Future<void> _dialMedia(String peerDeviceId, PeerScreenGrant grant) async {
    final address = peers.peers[peerDeviceId]?.beacon.address;
    if (address == null) {
      // A peer this device only ever heard as an INBOUND link has a runtime
      // synthesized with no address and no port (`PeerService._onSession`),
      // and the grant's port is useless without one. Ordinarily its beacon
      // fills those in a second or two — so this says so and re-asks, rather
      // than returning silently and leaving the pane at "Connecting…" for as
      // long as the app runs.
      for (final target in _views.keys.toList()) {
        if (target.peerDeviceId != peerDeviceId) continue;
        _views[target] = _views[target]!._with(status: PeerScreenViewStatus.peerUnreachable);
      }
      notifyListeners();
      _scheduleRetry(peerDeviceId);
      return;
    }
    _dialling.add(peerDeviceId);
    final PeerLink link;
    try {
      // ONLY the dial. With the bookkeeping below inside this, a throw there
      // would report a network failure while leaving the socket it just
      // opened in `_mediaLinks` — after which every future grant is
      // suppressed and the pane says "not connected" forever, holding a live
      // connection to a device that is.
      link = await peers.network.dial(address, grant.port, mediaTicket: grant.ticket);
    } catch (e, st) {
      debugPrint('[peer] media link to $peerDeviceId failed: $e');
      // Wrapped for the report only: the policy needs to know the exception
      // came from a dial (`peer-media-unreachable`). Through the streak,
      // because the retry below fires every few seconds while the pane is
      // open.
      ErrorReportingService.reportIfRepeated(_dialStreakKey(peerDeviceId),
          PeerMediaDialFailure(peerDeviceId, e), st,
          context: 'PeerScreenViews:dialMedia');
      for (final target in _views.keys.toList()) {
        if (target.peerDeviceId != peerDeviceId) continue;
        _views[target] = _views[target]!._with(status: PeerScreenViewStatus.peerUnreachable);
        _resetDeliveryStats(target);
      }
      notifyListeners();
      _scheduleRetry(peerDeviceId);
      _dialling.remove(peerDeviceId);
      return;
    }
    _dialling.remove(peerDeviceId);
    ErrorReportingService.recordSuccess(_dialStreakKey(peerDeviceId));

    // The peer may have gone while this was dialling. Installing the link
    // now would leave one nothing tears down, and suppress every later dial.
    if (!peers.hasLanSession(peerDeviceId)) {
      unawaited(link.close());
      return;
    }
    {
      _mediaLinks[peerDeviceId] = link;
      _mediaSubscriptions[peerDeviceId] = link.inbound.listen(
        (bytes) => _onFrameBytes(peerDeviceId, bytes),
        // The only place a media-transport error is observable — the link
        // forwards socket errors here and nowhere else.
        onError: (Object e) => debugPrint('[peer] media link from $peerDeviceId errored: $e'),
        cancelOnError: false,
      );
      unawaited(link.closed.then((_) {
        if (_mediaLinks[peerDeviceId] != link) return;
        _mediaLinks.remove(peerDeviceId);
        unawaited(_mediaSubscriptions.remove(peerDeviceId)?.cancel());
        for (final target in _views.keys.toList()) {
          if (target.peerDeviceId != peerDeviceId) continue;
          _views[target] = _views[target]!._with(status: PeerScreenViewStatus.connecting);
          _resetDeliveryStats(target);
        }
        notifyListeners();
        // The producer stopped capturing when its end of this closed, so
        // nothing is coming without a fresh subscribe.
        _scheduleRetry(peerDeviceId);
      }));
    }
  }

  /// This device's own offer moved.
  ///
  /// A peer's offer arrives as a message and runs through [setOffer]; a local
  /// one is simply read off the producer, so nothing would otherwise notice a
  /// source coming BACK — and `subscribe` early-returns on an unchanged
  /// target, leaving the pane refused until it is re-pointed or rebuilt.
  void _onProducerChanged() {
    final producer = screens;
    if (producer != null) {
      final offered = producer.offeredSources.map((s) => s.id).toSet();
      for (final target in _views.keys.toList()) {
        if (target.peerDeviceId != localScreenPeerId) continue;
        if (_views[target]!.status != PeerScreenViewStatus.refused) continue;
        if (offered.contains(target.sourceId)) _ensure(target);
      }
    }
    notifyListeners();
  }

  void _onLocalFrame(Uint8List frame) => _onFrameBytes(localScreenPeerId, frame);

  void _onFrameBytes(String peerDeviceId, List<int> bytes) {
    // Acknowledged from the HEADER, ahead of everything that can drop this
    // frame. Taking delivery is flow control, not rendering: a frame this
    // build cannot draw is still one it received, and two undrawable frames
    // in a row would otherwise shut the producer's window for good, with
    // nothing left arriving to reopen it.
    final routing = PeerScreenFrame.routingOf(bytes);
    if (routing != null) {
      final acked = PeerScreenTarget(peerDeviceId, routing.sourceId);
      if (_pacedTargets.contains(acked)) {
        _mediaLinks[peerDeviceId]?.send(
            PeerScreenAck(sourceId: routing.sourceId, sequence: routing.sequence).encode());
      }
      // Delivery resumed, so whatever stalled it has passed. Without this a
      // pane that recovers twice over a long session is left un-retryable
      // for the rest of it.
      _stalls.remove(acked);
    }

    final frame = PeerScreenFrame.decode(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
    if (frame == null) {
      // Once per peer, not per frame: a producer sending a format this build
      // cannot read drops EVERY frame, and a saturated link with a pane on
      // "Connecting…" is otherwise indistinguishable from a dead one.
      if (_unreadableFrom.add(peerDeviceId)) {
        debugPrint('[peer] unreadable screen frame from $peerDeviceId — a newer format?');
      }
      return;
    }
    final target = PeerScreenTarget(peerDeviceId, frame.sourceId);
    // A frame for something nothing is watching is dropped rather than
    // stored: it is a race with an unsubscribe, and holding it would keep a
    // picture of someone's screen for a pane that has gone.
    if (!_views.containsKey(target)) return;
    // The backstop for the resets at each way OUT of live. The source may
    // keep capturing for another watcher while this one is away, so the
    // first frame after any absence carries a large jump — counted as drops,
    // that pins the struggling notice on a healthy stream. Reading the
    // status on the way back in is the one place a status transition added
    // later cannot forget.
    if (_views[target]!.status != PeerScreenViewStatus.live) _resetDeliveryStats(target);

    final previous = _lastSeq[target];
    _lastSeq[target] = frame.sequence;
    final missed = (previous == null || frame.sequence <= previous)
        ? 0
        : frame.sequence - previous - 1;
    final recent = _recent.putIfAbsent(target, () => <bool>[])
      ..addAll(List<bool>.filled(missed.clamp(0, _dropWindow), true))
      ..add(false);
    if (recent.length > _dropWindow) {
      recent.removeRange(0, recent.length - _dropWindow);
    }
    final dropped = recent.where((wasDropped) => wasDropped).length;

    _views[target] = _views[target]!._with(
      status: PeerScreenViewStatus.live,
      frame: frame,
      degraded: dropped >= _dropsBeforeSaying,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    for (final timer in _awaitingAnswer.values) {
      timer.cancel();
    }
    _awaitingAnswer.clear();
    for (final timer in _retermTimers.values) {
      timer.cancel();
    }
    _retermTimers.clear();
    for (final timer in _awaitingTerms.values) {
      timer.cancel();
    }
    _awaitingTerms.clear();
    screens?.removeListener(_onProducerChanged);
    unawaited(_localFrames?.cancel());
    unawaited(_localRefusals?.cancel());
    for (final retry in _retries.values) {
      retry.cancel();
    }
    _retries.clear();
    for (final subscription in _mediaSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    for (final link in _mediaLinks.values) {
      unawaited(link.close());
    }
    _mediaSubscriptions.clear();
    _mediaLinks.clear();
    super.dispose();
  }
}
