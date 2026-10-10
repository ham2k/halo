// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The pin an operation's location wears, wherever it is shown: the setup
// sheet's location button, and the operation's own marker on both maps.
// One answer, so they can't disagree about where a location came from.

import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// The bright blue of a map app's "you are here" dot. Every GPS location
/// wears it — the operation's own, and a live fix not yet stored — so the
/// operator reads it the way they read any map.
const gpsDotColor = Color(0xFF007AFF);

/// The dot on a map: a blue disc in a thin white ring, standing off the
/// basemap on a dark glow — the convention every map app follows. Drawn
/// through the marker glyph pipeline like any other glyph marker, so no
/// backend needs a special case: the glyph is the disc itself, in the fill's
/// own blue, and the ring is the marker's stroke.
///
/// Smaller than the other glyph markers (20 against 28): it marks a point,
/// where they carry an icon that has to be read.
({IconData icon, Color fill, Color glyph, Color ring, double ringWidth, Color glow, double diameter}) get gpsMapDot =>
    (icon: MdiIcons.circle, fill: gpsDotColor, glyph: gpsDotColor, ring: Colors.white, ringWidth: 2.0, glow: const Color(0xB3000000), diameter: 20.0);

/// The glyph a GPS location shows on its filled pill: the dot in negative,
/// white on [gpsDotColor], like every other pill's white-on-color icon.
IconData get gpsPillIcon => MdiIcons.recordCircleOutline;

/// Whether [operation]'s location came from a GPS fix.
///
/// [deviceGrid] is the device's own 6-character fix, and matters only for an
/// operation stored before `gridSource` existed: those carry a 6-character
/// grid, so matching them against a fix's own displayed locator could never
/// be reliably equal, and every legacy GPS-set operation would quietly lose
/// its GPS look.
bool operationLocationIsGps(Operation operation, {String? deviceGrid}) {
  final location = operation.location;
  final gridSource =
      asQsonString(operation.data['gridSource']) ??
      ((location != null && deviceGrid != null && locationToGrid6(location.latitude, location.longitude) == deviceGrid) ? gpsGridSource : 'manual');
  return gridSource == gpsGridSource;
}

/// The icon and fill for an operation's location on its pill: the GPS dot on
/// blue for a fix, a pin on slate for a location typed or picked by hand.
({IconData icon, Color color}) operationLocationPin(Operation operation, {String? deviceGrid}) =>
    operationLocationIsGps(operation, deviceGrid: deviceGrid) ? (icon: gpsPillIcon, color: gpsDotColor) : (icon: MdiIcons.pin, color: const Color(0xFF455A64));

/// The GPS glyph pulsing while the device looks for a fix — the pill's
/// "GPS…" state.
class PulsingGpsPin extends StatefulWidget {
  final Color color;

  const PulsingGpsPin({super.key, this.color = Colors.blue});

  @override
  State<PulsingGpsPin> createState() => _PulsingGpsPinState();
}

class _PulsingGpsPinState extends State<PulsingGpsPin> with SingleTickerProviderStateMixin {
  // A repeating controller repaints the scene at the display's refresh rate
  // for as long as the pin is mounted — on the web, where a GPS fix can stay
  // pending indefinitely (unanswered permission prompt), that pegs a CPU
  // core. So the pulse winds down in phases: smooth for a few full cycles,
  // then a brief dim blip every couple of seconds (frames are only drawn
  // during the blip), then a static icon.
  static const _pulsePeriod = Duration(milliseconds: 1000);
  static const _smoothPhase = Duration(seconds: 6); // 3 full out-and-back pulses
  static const _blipInterval = Duration(seconds: 2);
  static const _blipFade = Duration(milliseconds: 250);
  static const _animationCutoff = Duration(seconds: 30);

  late final AnimationController _controller;
  late final Animation<double> _animation;
  Timer? _phaseTimer;
  Timer? _blipTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: _pulsePeriod, vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    final isTest = !kIsWeb && io.Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _controller.repeat(reverse: true);
      _phaseTimer = Timer(_smoothPhase, _startBlipPhase);
    } else {
      _controller.value = 1.0;
    }
  }

  void _startBlipPhase() {
    _controller.stop();
    _controller.animateTo(1.0, duration: _blipFade);
    _blipTimer = Timer.periodic(_blipInterval, (_) => _blip());
    _phaseTimer = Timer(_animationCutoff - _smoothPhase, _settle);
  }

  void _blip() {
    _controller.animateTo(0.35, duration: _blipFade).whenCompleteOrCancel(() {
      if (!mounted || _blipTimer == null) return;
      _controller.animateTo(1.0, duration: _blipFade);
    });
  }

  void _settle() {
    _blipTimer?.cancel();
    _blipTimer = null;
    _controller.stop();
    _controller.value = 1.0;
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    // Null (not just cancel) before disposing the controller: disposal
    // cancels an in-flight blip, which fires its whenCompleteOrCancel
    // callback synchronously while mounted is still true — the null check
    // in _blip is what stops it from touching the disposed controller.
    _blipTimer?.cancel();
    _blipTimer = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Icon(gpsPillIcon, color: widget.color),
    );
  }
}
