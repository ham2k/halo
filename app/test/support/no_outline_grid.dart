// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The POTA outline bundles as a test's service graph sees them by default:
// there are none. The real service fetches from services.ham2k.net and
// caches in drift, and neither completes under `testWidgets` — a pane test
// that panned the map would hang on it. A test about the bundles hands
// `makeHaLoServices` a real OutlineGridService over a fake GeoshapeService.

import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/outline_grid_service.dart';

class NoOutlineGrid implements OutlineGridService {
  const NoOutlineGrid();

  @override
  Future<({Map<String, OutlinePieces> parks, bool settled})> piecesIn(List<String> cells) async => (parks: const <String, OutlinePieces>{}, settled: true);

  @override
  Future<OutlineParks> parksNear(GridLocation center, double radiusKm, {GridLocation? measureFrom, Set<String> known = const {}}) async =>
      (distances: const <String, double?>{}, found: const <Map<String, dynamic>>[], settled: true);

  @override
  void prefetchFor(Iterable<Map<String, dynamic>> refs) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
