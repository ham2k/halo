// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The reporter is the map backends' one path into ErrorReportingService,
// and what matters is what it keeps OUT: map errors repeat (every pan
// retries the same tiles, every rebuild re-fails the same style), and
// without the session throttle a single broken style would flood the crash
// backend with identical events. The offline stamp matters the same way —
// it is captured at arrival, which is what lets ErrorPolicy quieten a
// field operation's fetch failures without a runtime dependency.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/services/connectivity_service.dart';
import 'package:ham2k_logger/services/error_policy.dart';
import 'package:ham2k_logger/services/error_reporting_backend.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/map_error_reporter.dart';

class _RecordingBackend implements ErrorReportingBackend {
  final exceptions = <(Object, String?)>[];

  @override
  Future<bool> run(FutureOr<void> Function() startBody) async {
    await startBody();
    return true;
  }

  @override
  void captureException(Object error, StackTrace? stackTrace, {String? context}) {
    exceptions.add((error, context));
  }

  @override
  void updateUserContext({String? callsign, String? accountId}) {}

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void captureDiagnostic({required String title, required String body}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingBackend backend;

  setUp(() async {
    ErrorReportingService.resetForTesting();
    MapErrorReporter.resetForTesting();
    ConnectivityService.resetForTesting();
    backend = _RecordingBackend();
    await ErrorReportingService.run(() {}, backend: backend);
  });

  tearDown(() {
    ErrorReportingService.resetForTesting();
    MapErrorReporter.resetForTesting();
    ConnectivityService.resetForTesting();
  });

  test('a repeated message uploads once', () {
    // A broken style re-fails on every rebuild; each repeat carries no new
    // information, and unthrottled they would bury the crashes worth reading.
    for (var i = 0; i < 5; i++) {
      MapErrorReporter.report(backend: 'web', kind: 'gl-error', message: 'Unauthorized');
    }
    expect(backend.exceptions, hasLength(1));
    expect(backend.exceptions.single.$2, 'map-web');
  });

  test('distinct messages per kind cap at maxPerKind', () {
    // Online tile errors can differ only by URL — one upload per tile would
    // defeat the throttle while saying the same thing.
    for (var i = 0; i < MapErrorReporter.maxPerKind + 3; i++) {
      MapErrorReporter.report(backend: 'osm', kind: 'tile-load', message: 'tile $i failed');
    }
    expect(backend.exceptions, hasLength(MapErrorReporter.maxPerKind));
  });

  test('a different kind gets its own budget', () {
    // The cap must not let a noisy kind (tile-load) starve the first report
    // of a distinct failure class (style-timeout) — that first report is
    // the whole evidence a "why is my map blank" report gets.
    for (var i = 0; i < MapErrorReporter.maxPerKind; i++) {
      MapErrorReporter.report(backend: 'web', kind: 'gl-error', message: 'error $i');
    }
    MapErrorReporter.report(backend: 'web', kind: 'style-timeout', message: 'style never loaded');
    expect(backend.exceptions.last.$1.toString(), contains('style-timeout'));
  });

  test('the error is stamped with connectivity at arrival', () async {
    // Stamped at construction, not at classification: an error raised
    // offline stays quiet even if the device is back online by the time
    // ErrorPolicy looks at it.
    final changes = StreamController<List<ConnectivityResult>>();
    ConnectivityService.start(
      changesSource: changes.stream,
      check: () async => [ConnectivityResult.none],
    );
    await Future<void>.delayed(Duration.zero);
    expect(ConnectivityService.isOffline, isTrue);

    MapErrorReporter.report(backend: 'web', kind: 'gl-error', message: 'Failed to fetch');
    // Held past the connectivity flip below: a rule reading the LIVE
    // connectivity instead of the error's own stamp would classify this
    // as an online error once the device is back on wifi.
    final offlineError = MapError(backend: 'web', kind: 'gl-error', message: 'Failed to fetch');
    changes.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(ConnectivityService.isOffline, isFalse);
    expect(ErrorPolicy.decide(offlineError).rule?.id, 'map-offline');

    // Offline at arrival → logOnly → never reached the backend.
    expect(backend.exceptions, isEmpty);

    // The same message re-raised online is fresh evidence, not a repeat:
    // the offline occurrence must not have consumed its upload budget.
    MapErrorReporter.report(backend: 'web', kind: 'gl-error', message: 'Failed to fetch');
    expect(backend.exceptions, hasLength(1));
    await changes.close();
  });
}
