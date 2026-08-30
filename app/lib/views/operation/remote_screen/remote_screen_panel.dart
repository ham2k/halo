// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One pane showing a screen, application or window shared by another of the
// operator's devices (HALO-369).
//
// The subscription is held by the PANE, not by the layout: a pane behind
// another dock tab is mounted but not looked at, and a stream that kept
// running for it would cost the far device a capture and this one a share of
// the network for a picture nobody can see. `DockPaneVisibility` and the app
// lifecycle together decide, exactly as the Website and Spots panes do.
//
// A pane never goes blank. A peer that leaves, a source withdrawn, a media
// link that drops — each keeps the last frame and writes the reason over it,
// because a blank pane and a broken feature are indistinguishable.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../../i18n/strings.g.dart';
import '../../../services/panel_service.dart';
import '../../../services/peer/peer_screen_views.dart';

/// The descriptor half of every placement id (`remoteScreen#1`). Shared with
/// the registration: a rename reaching only one of them routes every placed
/// pane to the missing-panel fallback.
const String remoteScreenPanelId = 'remoteScreen';

/// Stores `<peerDeviceId>/<sourceId>` — see [PeerScreenTarget].
const String remoteScreenTargetKey = 'target';

/// How the operator framed the picture: 1.0 fits it to the pane, larger
/// crops in, and the offset re-centres what is left.
///
/// DECLARED in the panel's `formFields` even though nothing renders them —
/// `PanelService.forgetInstanceConfig` forgets only declared fields, so an
/// undeclared zoom would outlive the pane that set it and be inherited by
/// whatever is placed in that slot next.
const String remoteScreenZoomKey = 'zoom';

/// How many pixels across this pane may ask a producer to spend on it.
///
/// Per PANE rather than per device: what a picture is worth costs the far
/// device's encoder and this one's link, and an operator watching a rig's
/// display in a small pane and a whole desktop in a large one is making two
/// different bargains. Zooming in spends the budget on a smaller region
/// rather than raising it, so this is a bandwidth choice, not a zoom one.
const String remoteScreenDetailKey = 'detail';

/// The budgets offered, and the one a pane that has never been told gets —
/// which is what every pane asked for unconditionally before there was a
/// choice.
const List<int> remoteScreenDetailChoices = [1280, 1920, 2560];
const int remoteScreenDetailDefault = 1280;
const String remoteScreenPanXKey = 'panX';
const String remoteScreenPanYKey = 'panY';

/// A zoom this close to a snap point takes it. Loose enough to land on by
/// hand with a scroll wheel, tight enough not to fight a deliberate framing
/// just past it.
const double _snapTolerance = 0.04;

/// The form action that opens the picker. Handled in `showPanelSettings`,
/// which supplies `onAction` for native panels only.
const String remoteScreenChooseMethod = 'chooseRemoteScreen';

class RemoteScreenPanel extends StatefulWidget {
  /// The PLACEMENT's id (`remoteScreen#1`), never the descriptor's — config
  /// is stored under it, so two panes handed the same one would show the
  /// same screen and fight over the title.
  final String panelId;

  final PanelService panels;
  final PeerScreenViews views;

  /// Names the tab after the source, so several remote panes are told apart.
  final ValueChanged<String?>? onTitle;

  /// Opens the source picker and stores the answer. Supplied by the host,
  /// which is the side that can reach the config write.
  final VoidCallback? onChooseSource;

  /// Persists the framing the operator settled on. Same reason as
  /// [onChooseSource]: the write goes through the host's services.
  final void Function(double zoom, Offset pan)? onSaveView;

  const RemoteScreenPanel({
    super.key,
    required this.panelId,
    required this.panels,
    required this.views,
    this.onTitle,
    this.onChooseSource,
    this.onSaveView,
  });

  @override
  State<RemoteScreenPanel> createState() => _RemoteScreenPanelState();
}

class _RemoteScreenPanelState extends State<RemoteScreenPanel> with WidgetsBindingObserver {
  Map<String, dynamic> _config = const {};
  int _configRevision = 0;
  bool _dockVisible = true;
  bool _appVisible = true;

  /// The frame on screen, decoded once.
  ///
  /// Decoded here rather than through `Image.memory`, which builds a fresh
  /// `MemoryImage` per frame — those key the global `ImageCache` by byte-list
  /// identity, so a stream of them fills it with unique entries and evicts
  /// continuously for as long as the pane is open. Owning the `ui.Image`
  /// means owning its disposal too.
  ui.Image? _image;

  /// Which part of the source [_image] shows — null for all of it. Read from
  /// the frame rather than from what this pane last ASKED for: the two
  /// disagree for as long as it takes the far device to restart its capture,
  /// and drawing a frame in the rect it was captured for is what keeps the
  /// picture where it belongs across that gap.
  PeerScreenCrop? _imageCrop;

  /// The source's own proportions, in its own pixels, which a cropped frame
  /// does not carry directly. Held so the framing survives a change of
  /// terms: layout is done in source space, and a pane that measured the
  /// crop instead would re-fit the picture every time the operator zoomed.
  Size? _sourceSize;

  /// The sequence number of the decode most recently STARTED. A decode whose
  /// number no longer matches lost a race to a newer frame and throws its
  /// result away — which is right for a live view, and does not depend on
  /// sequence numbers being monotonic across a producer restart.
  int? _decodingSeq;

  /// What this pane currently holds a subscription for, or null for none.
  /// A bare "subscribed" flag cannot express the case that matters: the
  /// operator CLEARING the target. That leaves nothing wanted and nothing
  /// flagged, so no unsubscribe is sent and the far device keeps capturing
  /// until this pane is disposed.
  PeerScreenTarget? _subscribedTo;

  /// Whether the operator is framing the picture rather than watching it.
  /// Gestures are live only here: outside it, a scroll over the pane belongs
  /// to whatever is scrolling around it, not to this.
  bool _adjusting = false;

  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  int _detail = remoteScreenDetailDefault;

  /// The request count this pane has already acted on — see
  /// [PeerScreenViews.requestAdjust].
  int _seenAdjustRequests = 0;

  PeerScreenTarget? get _target =>
      PeerScreenTarget.decode(_config[remoteScreenTargetKey] as String?);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.panels.addListener(_onCatalogChanged);
    widget.views.addListener(_onViewsChanged);
    _configRevision = widget.panels.configRevision(widget.panelId);
    _seenAdjustRequests = widget.views.adjustRequests(widget.panelId);
    unawaited(_loadConfig());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.panels.removeListener(_onCatalogChanged);
    widget.views.removeListener(_onViewsChanged);
    // Unconditional: this pane's interest ends with it, and the far device
    // stops capturing once the last pane watching a source lets go.
    widget.views.unsubscribe(widget.panelId);
    // Here and not in `unsubscribe`, which every hide edge calls: what this
    // pane was looking at outlives a dock tab switch, exactly as its zoom
    // and pan do.
    widget.views.forgetDemand(widget.panelId);
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dockVisible = DockPaneVisibility.of(context);
    _syncSubscription();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    if (visible == _appVisible) return;
    _appVisible = visible;
    _syncSubscription();
  }

  @override
  void didUpdateWidget(RemoteScreenPanel old) {
    super.didUpdateWidget(old);
    if (old.panels != widget.panels) {
      old.panels.removeListener(_onCatalogChanged);
      widget.panels.addListener(_onCatalogChanged);
    }
    if (old.views != widget.views) {
      old.views.removeListener(_onViewsChanged);
      widget.views.addListener(_onViewsChanged);
    }
    if (old.panelId != widget.panelId) {
      old.views.unsubscribe(old.panelId);
      old.views.forgetDemand(old.panelId);
      _subscribedTo = null;
      _decodingSeq = null;
      _configRevision = widget.panels.configRevision(widget.panelId);
      unawaited(_loadConfig());
    }
  }

  void _onCatalogChanged() {
    final revision = widget.panels.configRevision(widget.panelId);
    if (revision == _configRevision) return;
    _configRevision = revision;
    unawaited(_loadConfig());
  }

  void _onViewsChanged() {
    if (!mounted) return;
    // The catalog usually resolves AFTER the config does — a peer's offer
    // arrives seconds into the session — and it notifies `views`, not
    // `panels`. Without this the tab keeps the raw source id it fell back to
    // at load for the rest of the session.
    final title = _titleFor(_target);
    if (title != _publishedTitle) _publishTitle();
    final requests = widget.views.adjustRequests(widget.panelId);
    if (requests != _seenAdjustRequests) {
      _seenAdjustRequests = requests;
      // Only ever turns it ON. Leaving the mode is the Done button's job,
      // and a settings dialog opened while framing must not cancel it.
      if (!_adjusting) setState(() => _adjusting = true);
    }
    final frame = widget.views.viewFor(_target)?.frame;
    if (frame != null && frame.sequence != _decodingSeq) {
      _decodingSeq = frame.sequence;
      unawaited(_decodeFrame(frame));
    }
    setState(() {});
  }

  Future<void> _decodeFrame(PeerScreenFrame frame) async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(frame.image);
      final next = await codec.getNextFrame();
      // A newer frame started decoding while this one was in flight, or the
      // pane went away. Either way this image is nobody's, and an undisposed
      // ui.Image is a real leak.
      if (!mounted || _decodingSeq != frame.sequence) {
        next.image.dispose();
        return;
      }
      final crop = frame.crop;
      final measured = Size(
        next.image.width / (crop?.width ?? 1.0),
        next.image.height / (crop?.height ?? 1.0),
      );
      setState(() {
        _image?.dispose();
        _image = next.image;
        _imageCrop = crop;
        _sourceSize = _steadySize(measured);
      });
    } catch (_) {
      // One frame that will not decode is one frame. The pane keeps what it
      // has rather than blanking.
    } finally {
      codec?.dispose();
    }
  }

  Future<void> _loadConfig() async {
    final panel = widget.panels[widget.panelId];
    if (panel == null) return;
    final config = await widget.panels.configFor(panel);
    if (!mounted) return;
    final was = _target;
    setState(() {
      _config = config;
      if (_target != was) {
        // A pane pointed somewhere else keeps nothing of where it was. The
        // last frame is a picture of another screen, and drawn in the crop
        // rect it arrived with it is a small tile of one floating in the
        // pane until the first new frame lands.
        _image?.dispose();
        _image = null;
        _imageCrop = null;
        _sourceSize = null;
        _decodingSeq = null;
      }
      _zoom = ((config[remoteScreenZoomKey] as num?)?.toDouble() ?? 1.0).clamp(_minZoom, _maxZoom);
      _pan = Offset(
        (config[remoteScreenPanXKey] as num?)?.toDouble() ?? 0,
        (config[remoteScreenPanYKey] as num?)?.toDouble() ?? 0,
      );
      _detail = ((config[remoteScreenDetailKey] as num?)?.toInt() ?? remoteScreenDetailDefault)
          .clamp(320, 3840);
    });
    _syncSubscription();
    _publishTitle();
  }

  /// The one place the subscription is turned on or off. Called from every
  /// edge that can change the answer, and idempotent, so none of them has to
  /// know what the others did.
  void _syncSubscription() {
    final target = _target;
    final wanted = (_dockVisible && _appVisible) ? target : null;
    if (wanted == _subscribedTo) return;
    _subscribedTo = wanted;
    if (wanted == null) {
      widget.views.unsubscribe(widget.panelId);
    } else {
      widget.views.subscribe(widget.panelId, wanted);
    }
  }

  /// Names the tab, never from `didChangeDependencies` or `build`.
  ///
  /// The callback reaches the dock host's own `setState`, and both of those
  /// run inside the frame's build scope — a title change from there throws
  /// "setState() called during build". The Website and Clock panes call it
  /// only from their async config load for the same reason; a pane-visibility
  /// change is the extra edge this one has, so it defers to the next frame.
  String? _publishedTitle;

  void _publishTitle() {
    final onTitle = widget.onTitle;
    if (onTitle == null) return;
    final title = _titleFor(_target);
    _publishedTitle = title;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onTitle(title);
    });
  }

  String? _titleFor(PeerScreenTarget? target) {
    if (target == null) return null;
    for (final (peerDeviceId, peerName, source) in widget.views.catalog) {
      if (peerDeviceId == target.peerDeviceId && source.id == target.sourceId) {
        return '$peerName — ${source.name}';
      }
    }
    // The peer is away, or has stopped offering it. Its own id is the only
    // honest label left, and is better than a tab that renames itself to
    // nothing the moment the network hiccups.
    return target.sourceId;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout.panels;
    final target = _target;

    if (target == null) {
      return _Message(
        icon: MdiIcons.monitorShare,
        text: t.remoteScreenUnset,
        action: widget.onChooseSource,
        actionLabel: t.remoteScreenChoose,
      );
    }

    final view = widget.views.viewFor(target);
    final image = _image;

    final notice = switch (view?.status) {
      null || PeerScreenViewStatus.connecting => t.remoteScreenConnecting,
      PeerScreenViewStatus.peerUnreachable => t.remoteScreenPeerAway,
      // Every reason the producer can send has a line here. Left to the
      // fallback, "the window closed" and "it needs Screen Recording
      // permission" both read as "that device wouldn't share this screen",
      // which sends the operator to the wrong device's settings.
      PeerScreenViewStatus.refused => switch (view?.refusal) {
          'notOffered' => t.remoteScreenNotOffered,
          'noListener' => t.remoteScreenNoListener,
          'noLan' => t.remoteScreenNoLan,
          'stopped' => t.remoteScreenStopped,
          'captureFailed' => t.remoteScreenCaptureFailed,
          'noAnswer' => t.remoteScreenNoAnswer,
          'noMedia' => t.remoteScreenNoMedia,
          'stalled' => t.remoteScreenStalled,
          _ => t.remoteScreenRefused,
        },
      // Live and keeping up. A live view that is NOT keeping up says so
      // below, but never through this — a notice here dims the picture, and
      // a struggling stream is current, just intermittent.
      PeerScreenViewStatus.live => null,
    };
    final degraded = view?.degraded ?? false;

    if (image == null) {
      // The picker is offered here too, not only on an unset pane: a source
      // that has gone away is exactly when an operator wants to point this
      // somewhere else, and on a narrow layout this may be the only route to
      // it they have.
      return _Message(
        icon: MdiIcons.monitorShare,
        text: notice ?? t.remoteScreenConnecting,
        action: widget.onChooseSource,
        actionLabel: t.remoteScreenChoose,
      );
    }

    return _viewport(context, image, notice, view?.status, degraded);
  }

  /// Roughly the height the Done button and zoom pill occupy, so a notice
  /// clears them rather than landing under them.
  static const double _adjustChromeHeight = 56;

  /// Off the network is not the same as told no: the first is worth chasing
  /// on the network, the second is a decision the other device made.
  static IconData _noticeIcon(PeerScreenViewStatus? status) => switch (status) {
        PeerScreenViewStatus.refused => MdiIcons.monitorOff,
        _ => MdiIcons.lanDisconnect,
      };

  static const double _minZoom = 0.25;
  static const double _maxZoom = 8.0;

  /// The picture, framed by the operator, with the adjust-mode chrome over
  /// it when they are framing it.
  Widget _viewport(BuildContext context, ui.Image image, String? notice,
      PeerScreenViewStatus? status, bool degraded) {
    final t = context.t.operation.layout.panels;
    final theme = Theme.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final paneWidth = constraints.maxWidth;
      final paneHeight = constraints.maxHeight;
      // The SOURCE's size, not the frame's: under a crop the frame is a
      // piece of it, and fitting the pane to that piece would jump the
      // framing every time the terms changed.
      final source = _sourceSize ?? Size(image.width.toDouble(), image.height.toDouble());
      final imageWidth = source.width;
      final imageHeight = source.height;

      // 1.0 IS "contain" — the scale below is a multiplier on top of what
      // BoxFit.contain already did, so a fresh pane needs no arithmetic and
      // an unset config renders exactly as it did before any of this.
      final contain = math.min(paneWidth / imageWidth, paneHeight / imageHeight);
      final cover = math.max(paneWidth / imageWidth, paneHeight / imageHeight);
      // The OTHER dimension matching the pane. At 1.0 one of them does; at
      // this, the other does — which is the whole of "snap when the shared
      // screen matches the width or the height".
      final coverZoom = contain <= 0 ? 1.0 : cover / contain;

      final shownWidth = imageWidth * contain * _zoom;
      final shownHeight = imageHeight * contain * _zoom;
      // Panning past the picture's own edge would drag it out of the pane
      // and leave the operator looking at nothing.
      final maxPanX = math.max(0.0, (shownWidth - paneWidth) / 2);
      final maxPanY = math.max(0.0, (shownHeight - paneHeight) / 2);
      final pan = Offset(
        _pan.dx.clamp(-maxPanX, maxPanX),
        _pan.dy.clamp(-maxPanY, maxPanY),
      );

      // What this pane is actually looking at, told to the producer so its
      // pixel budget is spent there. Reported from the layout because this
      // is where the pane's size, the zoom and the pan are all known at
      // once; `setDemand` is a no-op for a demand that has not changed, and
      // a rebuild is not a change.
      widget.views.setDemand(
        widget.panelId,
        _demandFor(
          paneWidth: paneWidth,
          paneHeight: paneHeight,
          shownWidth: shownWidth,
          shownHeight: shownHeight,
          pan: pan,
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
        ),
      );

      final crop = _imageCrop;
      final picture = ClipRect(
        child: Center(
          child: Transform.translate(
            offset: pan,
            child: Transform.scale(
              scale: _zoom,
              // A box the size of the whole SOURCE, with the frame drawn in
              // its own rect inside it. At full-source terms that is the
              // whole box and the result is what BoxFit.contain drew before
              // any of this; under a crop it is what keeps a frame captured
              // for where the pane WAS from sliding over where it is now.
              child: SizedBox(
                width: imageWidth * contain,
                height: imageHeight * contain,
                child: crop == null
                    ? RawImage(image: image, fit: BoxFit.fill)
                    : Stack(children: [
                        Positioned(
                          left: crop.left * imageWidth * contain,
                          top: crop.top * imageHeight * contain,
                          width: crop.width * imageWidth * contain,
                          height: crop.height * imageHeight * contain,
                          child: RawImage(image: image, fit: BoxFit.fill),
                        ),
                      ]),
              ),
            ),
          ),
        ),
      );

      return Stack(
        fit: StackFit.expand,
        children: [
          if (!_adjusting)
            picture
          else
            // Gestures only while adjusting: a scroll over a pane that is
            // merely being watched belongs to whatever scrolls around it.
            Listener(
              // A mouse wheel.
              onPointerSignal: (event) {
                if (event is! PointerScrollEvent) return;
                // Exponential, so a notch is the same proportional step
                // wherever the zoom already is.
                _setZoom(_zoom * math.exp(-event.scrollDelta.dy / 300), coverZoom);
              },
              // A trackpad's two-finger scroll, which macOS does NOT deliver
              // as a scroll signal — it arrives as a pan/zoom sequence, and
              // a plain pan recognizer swallows it and drags the picture.
              // That is why the drag below excludes trackpads rather than
              // taking every device: scrolling has to zoom on both.
              onPointerPanZoomUpdate: (event) {
                if (event.scale != 1.0) {
                  // A real pinch says its own scale outright.
                  _setZoom(_zoom * (1 + (event.scale - 1) * 0.5), coverZoom);
                } else {
                  _setZoom(_zoom * math.exp(event.panDelta.dy / 300), coverZoom);
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                supportedDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                  PointerDeviceKind.unknown,
                },
                onPanUpdate: (details) => setState(() => _pan = pan + details.delta),
                child: picture,
              ),
            ),
          // Dimmed, not blanked. What is on screen is still the last thing
          // that device showed, and it is often exactly what the operator
          // opened the pane to see — but a live picture and a frozen one
          // must not look the same, or a stalled pane reads as a quiet one.
          // IgnorePointer, because a ColoredBox hit-tests OPAQUE: over the
          // picture it would swallow every scroll, pinch and drag — on
          // exactly the dimmed, frozen pane an operator most wants to zoom
          // into, with nothing to explain why Adjust View does nothing.
          if (notice != null)
            IgnorePointer(
              child: Container(color: theme.colorScheme.scrim.withValues(alpha: 0.45)),
            ),
          // No scrim for this one: the picture IS current, so dimming it
          // would say the opposite of what is true. Stalled and struggling
          // must not look the same.
          if (notice == null && degraded)
            Positioned(
              left: 0,
              right: 0,
              bottom: Space.md +
                  PaneSafeArea.bottomOf(context) +
                  (_adjusting ? _adjustChromeHeight : 0),
              child: Center(child: _NoticePill(icon: MdiIcons.wifiStrength2, text: t.remoteScreenDegraded)),
            ),
          if (notice != null)
            Positioned(
              left: 0,
              right: 0,
              // Clear of the adjust-mode chrome, which owns this corner.
              bottom: Space.md +
                  PaneSafeArea.bottomOf(context) +
                  (_adjusting ? _adjustChromeHeight : 0),
              child: Center(child: _NoticePill(icon: _noticeIcon(status), text: notice)),
            ),
          if (_adjusting) ...[
            // Same pill the map uses, in the same corner.
            Positioned(
              bottom: Space.md + PaneSafeArea.bottomOf(context),
              left: Space.md + PaneSafeArea.leftOf(context),
              child: _ZoomButtons(
                onIn: () => _setZoom(_zoom * 1.25, coverZoom),
                onOut: () => _setZoom(_zoom / 1.25, coverZoom),
              ),
            ),
            Positioned(
              bottom: Space.md + PaneSafeArea.bottomOf(context),
              left: 0,
              right: 0,
              child: Center(
                child: FilledButton.icon(
                  onPressed: _finishAdjusting,
                  icon: Icon(MdiIcons.check),
                  label: Text(t.remoteScreenAdjustDone),
                ),
              ),
            ),
          ],
        ],
      );
    });
  }

  /// The measured source size, or the one already held when the two differ
  /// by less than a pixel or two.
  ///
  /// Both ends round: the producer rounds its configuration, then rounds the
  /// cropped region to whole pixels, so dividing a frame's size back by its
  /// crop lands a hair either side of the truth and moves with every change
  /// of terms. That feeds the layout, which feeds the demand, which can
  /// cross a quantization step and ask for terms again — a capture stop and
  /// start on the far device, every few hundred milliseconds, with the
  /// resulting frame loss forgiven each time as a fresh stream.
  Size _steadySize(Size measured) {
    final held = _sourceSize;
    if (held == null) return measured;
    const slack = 2.0;
    final same = (held.width - measured.width).abs() <= slack &&
        (held.height - measured.height).abs() <= slack;
    return same ? held : measured;
  }

  /// The crop grid, in fractions of the source. Coarse on purpose: every
  /// change of terms restarts the far device's capture, and a rect taken
  /// straight from the layout would move on a pixel of resize.
  static const double _cropSteps = 32;

  /// Rounded outwards onto [_cropSteps], which is also where the margin
  /// around what is strictly visible comes from — up to a step of it on
  /// each side, so small movements land inside the rect already being
  /// captured instead of asking for a new one.
  static double _snapOut(double fraction, {required bool up}) {
    final stepped = up ? (fraction * _cropSteps).ceil() : (fraction * _cropSteps).floor();
    return (stepped / _cropSteps).clamp(0.0, 1.0);
  }

  /// What to ask the producer for, given how the picture is framed right now.
  ///
  /// The pane asks for pixels across WHAT IT CAN SEE. Zooming in therefore
  /// buys detail rather than bandwidth: the same frame budget lands on a
  /// smaller region of the source, which is the whole of why a zoomed pane
  /// is sharp rather than merely bigger.
  PeerScreenDemand _demandFor({
    required double paneWidth,
    required double paneHeight,
    required double shownWidth,
    required double shownHeight,
    required Offset pan,
    required double pixelRatio,
  }) {
    if (shownWidth <= 0 || shownHeight <= 0) {
      // Quantized like every other answer, and never zero: a pane collapsed
      // to nothing — a dock split dragged shut, a first layout pass —
      // otherwise asks for a 160-px capture, and the merge takes the widest
      // ask, so ONE collapsed pane would drop the stream every other watcher
      // of that source is looking at.
      final width = _quantizeWidth(paneWidth * pixelRatio);
      return (maxWidth: width, fullWidth: width, crop: null);
    }
    final visibleW = (paneWidth / shownWidth).clamp(0.0, 1.0);
    final visibleH = (paneHeight / shownHeight).clamp(0.0, 1.0);
    // Where the pane's centre falls on the source: the pan slides the
    // picture, so what is under the middle of the pane moves the other way.
    final centreX = 0.5 - pan.dx / shownWidth;
    final centreY = 0.5 - pan.dy / shownHeight;

    final left = _snapOut(centreX - visibleW / 2, up: false);
    final top = _snapOut(centreY - visibleH / 2, up: false);
    final right = _snapOut(centreX + visibleW / 2, up: true);
    final bottom = _snapOut(centreY + visibleH / 2, up: true);

    // Never while framing: the operator is panning and zooming, so the
    // region wanted changes with every gesture, and each change would stop
    // and restart the far device's capture. The whole picture is also what
    // they need in front of them to frame it.
    final crop = (_adjusting || (right - left >= 1.0 && bottom - top >= 1.0))
        ? null
        : PeerScreenCrop.clamped(
            left: left, top: top, width: right - left, height: bottom - top);

    final across = (crop?.width ?? 1.0) * shownWidth * pixelRatio;
    return (
      maxWidth: _quantizeWidth(across),
      // What the same picture costs from a producer that cannot crop: the
      // whole source at the resolution this pane's slice of it needs,
      // which its budget then caps. That cap is the point — a pane does not
      // spend four times its budget because the other device is on an
      // older build; it settles for the picture it used to get.
      fullWidth: _quantizeWidth(shownWidth * pixelRatio),
      crop: crop,
    );
  }

  /// Widths asked for in steps, for the reason the crop is: a pane resized
  /// by a pixel must not cost the far device a capture restart. Rounded UP,
  /// so a step never asks for less than the pane can show.
  int _quantizeWidth(double pixels) {
    const step = 160;
    if (!pixels.isFinite || pixels <= 0) return step * 2;
    return (((pixels / step).ceil()) * step).clamp(320, _detail);
  }

  /// Applies a new zoom, snapping to the two framings worth landing on
  /// exactly: the picture fitted to the pane, and the picture filling it.
  /// Without the snap those are unreachable by hand — a wheel notch steps
  /// straight past a single value.
  void _setZoom(double next, double coverZoom) {
    var zoom = next.clamp(_minZoom, _maxZoom);
    for (final snap in [1.0, coverZoom]) {
      if ((zoom - snap).abs() <= snap * _snapTolerance) {
        zoom = snap;
        break;
      }
    }
    if (zoom == _zoom) return;
    setState(() => _zoom = zoom);
  }

  void _finishAdjusting() {
    setState(() => _adjusting = false);
    // Written on the way out rather than on every wheel notch: this is panel
    // config, and each write is a settings commit plus a catalog
    // notification.
    widget.onSaveView?.call(_zoom, _pan);
  }
}

/// The map's zoom pill, in the map's own shape: one card, a hairline between
/// the two actions, clipped so each button's ripple stays inside the corners.
class _ZoomButtons extends StatelessWidget {
  final VoidCallback onIn;
  final VoidCallback onOut;

  const _ZoomButtons({required this.onIn, required this.onOut});

  @override
  Widget build(BuildContext context) {
    final t = context.t.operation.layout.panels;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(MdiIcons.plus, semanticLabel: t.remoteScreenZoomIn),
            onPressed: onIn,
          ),
          Divider(height: 1, thickness: 1, color: theme.dividerColor),
          IconButton(
            icon: Icon(MdiIcons.minus, semanticLabel: t.remoteScreenZoomOut),
            onPressed: onOut,
          ),
        ],
      ),
    );
  }
}

/// The badge a pane wears when it has something to say about itself. The
/// reason stays beside the glyph: several different conditions freeze or
/// interrupt the picture, and an icon alone cannot tell an operator which of
/// them to go and fix.
class _NoticePill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _NoticePill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.9),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: Space.md),
            Flexible(child: Text(text, style: theme.textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? action;
  final String? actionLabel;

  const _Message({required this.icon, required this.text, this.action, this.actionLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: Space.md),
            Text(text, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: Space.md),
              FilledButton.tonal(onPressed: action, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
