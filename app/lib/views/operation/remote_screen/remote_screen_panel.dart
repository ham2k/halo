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
      setState(() {
        _image?.dispose();
        _image = next.image;
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
    setState(() {
      _config = config;
      _zoom = ((config[remoteScreenZoomKey] as num?)?.toDouble() ?? 1.0).clamp(_minZoom, _maxZoom);
      _pan = Offset(
        (config[remoteScreenPanXKey] as num?)?.toDouble() ?? 0,
        (config[remoteScreenPanYKey] as num?)?.toDouble() ?? 0,
      );
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
          _ => t.remoteScreenRefused,
        },
      PeerScreenViewStatus.live => null,
    };

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

    return _viewport(context, image, notice, view?.status);
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
  Widget _viewport(
      BuildContext context, ui.Image image, String? notice, PeerScreenViewStatus? status) {
    final t = context.t.operation.layout.panels;
    final theme = Theme.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      final paneWidth = constraints.maxWidth;
      final paneHeight = constraints.maxHeight;
      final imageWidth = image.width.toDouble();
      final imageHeight = image.height.toDouble();

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

      final picture = ClipRect(
        child: Transform.translate(
          offset: pan,
          child: Transform.scale(
            scale: _zoom,
            child: RawImage(image: image, fit: BoxFit.contain),
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
          if (notice != null)
            Positioned(
              left: 0,
              right: 0,
              // Clear of the adjust-mode chrome, which owns this corner.
              bottom: Space.md +
                  PaneSafeArea.bottomOf(context) +
                  (_adjusting ? _adjustChromeHeight : 0),
              child: Center(
                child: Material(
                  color: theme.colorScheme.surface.withValues(alpha: 0.9),
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Space.lg, vertical: Space.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_noticeIcon(status), size: 18),
                        const SizedBox(width: Space.md),
                        // The reason stays beside the glyph. "Off the
                        // network" and "they stopped sharing it" both freeze
                        // the picture, and an icon alone cannot tell an
                        // operator which of the two to go and fix.
                        Flexible(
                          child: Text(notice, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
