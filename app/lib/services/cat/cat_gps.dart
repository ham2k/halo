// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which GPS receiver places the station, if any (docs/design/cat.md § GPS
// receivers). The station's, not a radio's: one station stands in one
// place, whichever rig is on the logging panel.

part of 'cat_service.dart';

/// The pick naming the operating system's own location service rather than
/// a receiver of the station's.
const gpsSourceSystem = 'system';

/// How far a receiver's fix has to move before it replaces the one held —
/// the operating system stream's `distanceFilter`, for its reason: a new
/// position wakes every listener of the station, re-runs the nearby search
/// and goes out to paired devices, and a receiver standing still wanders a
/// few metres every second.
const gpsDistanceFilterMetres = 50.0;

/// Whether [next] is worth reporting over [held], the receiver's reading as
/// last reported: a fix gained or lost, a move past
/// [gpsDistanceFilterMetres], a MORE ACCURATE fix wherever it is, or — while
/// searching — a different satellite count, which is all a search has to say.
///
/// Accuracy counts because a receiver's first fix is often its worst, and
/// the setup sheet keeps the most accurate one it sees
/// (docs/design/locations.md): held otherwise, a cold start's 20 m would
/// stand for the session. Only strictly better, so a receiver settling
/// reports a handful of times.
bool gpsReadingSupersedes(GpsReading? held, GpsReading next) {
  if (held == null || held.hasFix != next.hasFix) return true;
  if (!next.hasFix) return next.satellites != held.satellites;
  if (next.accuracyMetres < held.accuracyMetres) return true;
  final metres = distanceOnEarthKm(GridLocation(held.latitude!, held.longitude!), GridLocation(next.latitude!, next.longitude!)) * 1000;
  return metres >= gpsDistanceFilterMetres;
}

mixin _Gps on ChangeNotifier {
  Map<String, EquipmentNode> get _nodes;
  EquipmentType? typeFor(EquipmentNode node);

  /// The operator's answer: a receiver's uuid, [gpsSourceSystem], or null
  /// when they have not given one.
  String? _gpsSource;

  /// The GPS receivers this station has, as nodes.
  List<EquipmentNode> get gpsReceiverNodes => [
    for (final node in _nodes.values)
      if (typeFor(node)?.category == kCategoryGps) node,
  ];

  /// The receiver the station is located by, or null when the operating
  /// system does it.
  ///
  /// With no answer, the station's first receiver: an operator who plugged
  /// one in and set it up wants it used, and a laptop's own answer is
  /// usually a Wi-Fi or IP estimate. The newest receiver set up is picked
  /// over any earlier answer, the operating system's included
  /// (`_gpsReceiverAdded`). A stored answer naming anything but a receiver
  /// of this station's is no answer: made the source, a node that never
  /// reports a fix would leave the station searching for good.
  String? get gpsReceiver {
    final pick = _gpsSource;
    if (pick == gpsSourceSystem) return null;
    if (_nodes[pick] case final node? when typeFor(node)?.category == kCategoryGps) return pick;
    return gpsReceiverNodes.firstOrNull?.uuid;
  }

  /// For [CatGpsSource], which as an extension cannot reach the protected
  /// notifier itself.
  void _gpsSourceChanged() => notifyListeners();
}

/// Changing the pick, and keeping only the picked receiver connected.
extension CatGpsSource on CatService {
  /// Locates the station by the receiver [uuid], or by the operating system
  /// when null — and keeps that receiver connected, and only that one.
  ///
  /// Picking a receiver is asking for it, so one the operator disconnected
  /// is connected again. The one it replaces is let go: left open, it would
  /// hold its serial port against anything else that wants the receiver
  /// (gpsd, another logger). Not as the operator's Disconnect, which picking
  /// it again would then have to undo.
  Future<void> setGpsSource(String? uuid) async {
    final pick = uuid ?? gpsSourceSystem;
    if (pick == _gpsSource) return;
    final previous = gpsReceiver;
    _gpsSource = pick;
    await _save();
    _gpsSourceChanged();
    if (previous != null && previous != gpsReceiver) unawaited(disconnect(previous, byUser: false));
    if (gpsReceiver case final picked?) {
      _runtimes[picked]?.userDisconnected = false;
      unawaited(_reconnectWithRetries(picked));
    }
  }

  /// A receiver was just set up: it places the station from now on, over
  /// any earlier answer — the operating system's too, since setting one up
  /// is the operator saying where the fix should come from — and takes over
  /// the connection from the one it replaces, as [setGpsSource] would.
  ///
  /// Connected straight away, as the receiver the station now depends on.
  /// One not yet given a port fails to connect harmlessly, and is connected
  /// once it is configured, as every automatic target is.
  void _gpsReceiverAdded(String uuid) {
    final previous = gpsReceiver;
    _gpsSource = uuid;
    if (previous != null && previous != uuid) unawaited(disconnect(previous, byUser: false));
    scheduleMicrotask(() => unawaited(_reconnectWithRetries(uuid)));
  }

  /// [uuid] is about to be removed. When it is the receiver placing the
  /// station, its pick is forgotten and whichever receiver takes over is
  /// connected — nothing else would connect it before the next launch.
  /// Removing anything else leaves the receiver alone: one that is unplugged
  /// would otherwise get a fresh burst of reconnects for every unrelated
  /// removal.
  void _gpsReceiverRemoving(String uuid) {
    if (gpsReceiver != uuid) return;
    if (_gpsSource == uuid) _gpsSource = null;
    // After the removal itself, which runs on in the same synchronous block:
    // until then [gpsReceiver] still names the node going away.
    scheduleMicrotask(() => unawaited(_reconnectWithRetries(gpsReceiver)));
  }
}
