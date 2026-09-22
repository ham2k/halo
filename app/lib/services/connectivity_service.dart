// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app's one view of connectivity: whether anything we reach over the
// INTERNET can be expected to answer right now. Everything that cares reads
// it from here — a second raw plugin subscription is a second platform
// channel doing the same work, and a second notion of "offline" is worse
// than that (docs/design/error-reporting.md decides in one place what an
// error deserves; this decides in one place whether the network is there).
//
// Two signals, one answer:
//
//  * **No route** — the OS says every interface is `none`. Cheap, instant,
//    and blind to the case the field actually produces.
//  * **Nothing answers** — the sync round, which is also the connectivity
//    probe, got no reply for [probeFailureThreshold] rounds running. This is
//    what catches a hotel Wi-Fi that resolves nothing and a router whose
//    upstream is down: both report a perfectly healthy interface.
//
//    It does NOT catch every captive portal. One that BLACKHOLES traffic
//    looks like any other dead network and is caught; one that INTERCEPTS
//    with a login page returns a valid HTTP response, which is an answer —
//    so we correctly conclude the network is reachable, and the operator
//    finds out when a request comes back as HTML instead of what they asked
//    for. Distinguishing that needs a known-content probe, which is a second
//    request and a second thing to keep true; not worth it yet.
//
// [isOffline] is the two together, and it is what the operator sees and what
// quietens errors and suspends work. The halves stay apart internally because
// they recover differently, and the detail view shows which one we are in.
//
// **Internet only.** Peer sync runs over LAN and BLE (`peer_service.dart`),
// and two devices paired on a hotspot with no upstream — the field case this
// whole feature exists for — work perfectly while this says offline. Nothing
// here may suspend peer sync or quieten its failures.
//
// Static like ErrorReportingService, and for the same reason: the readers are
// far from anything that could hand them an instance (ErrorPolicy consults it
// from inside an error handler).
//
// [isOffline] starts false. Until something has actually failed to answer,
// errors stay loud — being wrong in that direction can only make noise, never
// hide a real failure, and that matters far more now that the flag quietens a
// whole network surface rather than two error reporters.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

/// What we know about one internet-facing service, for the offline detail
/// view. Display only — nothing here decides [ConnectivityService.isOffline],
/// which the sync probe and the OS signal settle between them.
@immutable
class ServiceReachability {
  /// Stable identity, also the key the reporter updates under.
  final String id;

  /// Human-facing name, supplied already translated by the reporter.
  final String label;

  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;

  const ServiceReachability({required this.id, required this.label, this.lastSuccessAt, this.lastFailureAt});

  /// Whether its most recent word was a failure. A service that has never
  /// reported either way is not failing — it is unknown, and saying "failing"
  /// about something we have not asked is how a detail view starts lying.
  bool get isFailing {
    final failure = lastFailureAt;
    if (failure == null) return false;
    final success = lastSuccessAt;
    return success == null || failure.isAfter(success);
  }
}

class ConnectivityService {
  ConnectivityService._();

  static bool _noRoute = false;
  static bool _servicesUnreachable = false;

  /// Consecutive probe rounds that got no answer. The verdict needs
  /// [probeFailureThreshold] of them, not one: the probe is a single service,
  /// and one blip against one host is not the network going away.
  static int _probeFailures = 0;
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static final _offlineChanges = StreamController<bool>.broadcast();
  static final Map<String, ServiceReachability> _services = {};

  /// How many consecutive unanswered probes it takes to call the network
  /// down. The probe is one service (LoFi sync), so a single failure is as
  /// likely to be that host as the network — a run of them is the evidence
  /// worth acting on. Small, because the cost of waiting is a second round.
  static const probeFailureThreshold = 2;

  /// Whether the app should behave as though it has no internet: either the
  /// device has no route at all, or the probe cannot get an answer out of the
  /// one that is there. False until something says otherwise.
  static bool get isOffline => _noRoute || _servicesUnreachable;

  /// The OS half — every reported interface is `none`.
  static bool get hasNoRoute => _noRoute;

  /// The probe half — a route exists but nothing at the other end answered.
  static bool get servicesUnreachable => _servicesUnreachable;

  /// Per-service detail for the offline popover, most recently heard from
  /// first. Never feeds [isOffline].
  static List<ServiceReachability> get services {
    final all = _services.values.toList();
    all.sort((a, b) {
      final aAt = a.lastFailureAt ?? a.lastSuccessAt;
      final bAt = b.lastFailureAt ?? b.lastSuccessAt;
      if (aAt == null || bAt == null) return aAt == bAt ? 0 : (aAt == null ? 1 : -1);
      return bAt.compareTo(aAt);
    });
    return all;
  }

  /// Edges of [isOffline] only — one event per actual transition, whichever
  /// half moved. What a caller wanting "resume now" subscribes to, rather
  /// than [changes], which fires on interface churn that changes nothing.
  static Stream<bool> get offlineChanges => _offlineChanges.stream;

  /// Installs the plugin subscription and probes the current state. Idempotent.
  /// [changesSource] and [check] are test seams for the platform channel.
  static void start({Stream<List<ConnectivityResult>>? changesSource, Future<List<ConnectivityResult>> Function()? check}) {
    if (_subscription != null) return;
    _subscription = (changesSource ?? Connectivity().onConnectivityChanged).listen(
      _onStreamEvent,
      onError: (Object e) {
        // A backend that can't be watched (no NetworkManager on Linux) costs
        // the OS half of the offline state — the probe half still works, and
        // the app stays in the loud-by-default state until it says otherwise.
        // This print is the only record: nothing subscribes to a raw
        // connectivity stream any more. The Linux backend can also throw from
        // its own async stream setup, unreachable by this onError; ErrorPolicy's
        // connectivity-backend-unavailable rule covers that leg.
        debugPrint('[connectivity] stream error: $e');
      },
    );
    (check ?? Connectivity().checkConnectivity)().then(
      (results) {
        // The probe is a snapshot from before the subscription's first event;
        // a real change that beat it here is newer and must not be clobbered.
        if (!_sawStreamEvent) _onChanged(results);
      },
      onError: (Object e) {
        debugPrint('[connectivity] initial check failed: $e');
      },
    );
  }

  static bool _sawStreamEvent = false;

  static void _onStreamEvent(List<ConnectivityResult> results) {
    _sawStreamEvent = true;
    _onChanged(results);
  }

  static void _onChanged(List<ConnectivityResult> results) {
    final was = isOffline;
    // `isNotEmpty` first: some backends emit an empty list, and `every` on
    // an empty list is true — which would read as "no route" and, since the
    // plugin only emits on CHANGE, would never be revised. An empty answer is
    // no answer, and the loud-by-default state is the right one for that.
    _noRoute = results.isNotEmpty && results.every((r) => r == ConnectivityResult.none);
    // A route appearing says nothing about whether anything answers over it —
    // that is the captive portal, and clearing the probe's verdict here would
    // declare us online the instant we joined the very network that cannot
    // reach anything. Only the probe clears the probe.
    _emitIfChanged(was);
  }

  /// What the sync probe learned. [reached] true means the service answered,
  /// whatever it answered with — a rejected registration and a server 500
  /// both prove the network is there.
  ///
  /// An answer clears BOTH halves. The OS half is a report about interfaces;
  /// an answer is a fact about the network, and a fact outranks a report. It
  /// has to: `connectivity_plus` reports `none` over some VPN adapters and on
  /// desktop configurations where traffic flows perfectly well, and with the
  /// OS half latched the app would suspend its whole network surface until
  /// the next interface change — which on a stable connection never comes.
  static void reportProbe({required bool reached}) {
    final was = isOffline;
    if (reached) {
      _probeFailures = 0;
      _servicesUnreachable = false;
      _noRoute = false;
    } else {
      _probeFailures++;
      _servicesUnreachable = _probeFailures >= probeFailureThreshold;
    }
    _emitIfChanged(was);
  }

  /// Nothing is probing any more — sync was switched off, or the engine was
  /// disposed. The verdict goes with it.
  ///
  /// Without this the last thing the probe said stands forever: an operator
  /// who goes offline and then turns sync off (an entirely reasonable "stop
  /// retrying") would keep lookups, spots and data files suspended and their
  /// errors quietened for the rest of the process, back on full coverage,
  /// with `retryNow` answering `disabled` — the one escape the UI offers,
  /// closed. No prober means UNKNOWN, and unknown reads as online here, the
  /// same loud-by-default direction as the initial state.
  static void stopProbing() {
    final was = isOffline;
    _probeFailures = 0;
    _servicesUnreachable = false;
    _emitIfChanged(was);
  }

  /// Records one service's outcome for the detail view. Pure display — a
  /// service failing here does not make the app offline, because one service
  /// being down is not the network being down.
  static void reportService(String id, {required String label, required bool reached}) {
    final now = nowUtc();
    final previous = _services[id];
    _services[id] = ServiceReachability(
      id: id,
      label: label,
      lastSuccessAt: reached ? now : previous?.lastSuccessAt,
      lastFailureAt: reached ? previous?.lastFailureAt : now,
    );
  }

  static void _emitIfChanged(bool was) {
    if (isOffline != was) _offlineChanges.add(isOffline);
  }

  @visibleForTesting
  static void resetForTesting() {
    _subscription?.cancel();
    _subscription = null;
    _sawStreamEvent = false;
    _noRoute = false;
    _servicesUnreachable = false;
    _probeFailures = 0;
    _services.clear();
  }
}
