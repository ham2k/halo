// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a map lays over its basemap — satellite imagery, administrative
// boundaries, park facilities — the same layers maps.ham2k.net offers. The GL
// backends draw all three (map_gl_script.dart's `setOverlays`), fetching the
// boundary and facility bundles for the cells in view themselves; the OSM
// backend draws the imagery alone. Also who each of those, and the outlines,
// are credited to in the map's attribution.

import 'package:flutter/foundation.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'map_marker_data.dart' show MapShapeData;

/// Esri's World Imagery tiles, keyless, in the `{z}/{y}/{x}` order its
/// MapServer takes.
const esriImageryTiles = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
const esriImageryMaxZoom = 19;
const esriImageryAttribution = 'Powered by Esri: Esri, Vantor, Earthstar Geographics, and the GIS User Community';

/// The imagery's credit where the full one is folded away: the line Esri's
/// terms ask to stay in view.
const esriImageryCredit = 'Powered by Esri';

/// Where the bundles come from, by grid cell: `FN.geojson`, `FN20-31.geojson`
/// for regions, `FN31.geojson` for facilities.
const _regionsBase = 'https://services.ham2k.net/lookups/regions/grid/';
const _facilitiesBase = 'https://services.ham2k.net/lookups/facilities/pota/';

/// Who the boundary bundles are drawn from: services.ham2k.net's datasets of
/// kind "regions" (its scripts/areas/datasets.json), credited as
/// maps.ham2k.net credits them. A dataset added there is credited here only
/// once it is added to this list too.
const _boundariesSources = 'US Census Bureau / Statistics Canada / © Australian Bureau of Statistics';
const _facilitiesSources = '© OpenStreetMap contributors';

@immutable
class MapOverlays {
  final bool imagery;
  final bool boundaries;
  final bool facilities;

  const MapOverlays({this.imagery = false, this.boundaries = false, this.facilities = false});

  static const none = MapOverlays();

  bool get isEmpty => !imagery && !boundaries && !facilities;

  MapOverlays copyWith({bool? imagery, bool? boundaries, bool? facilities}) =>
      MapOverlays(imagery: imagery ?? this.imagery, boundaries: boundaries ?? this.boundaries, facilities: facilities ?? this.facilities);

  @override
  bool operator ==(Object other) => other is MapOverlays && other.imagery == imagery && other.boundaries == boundaries && other.facilities == facilities;

  @override
  int get hashCode => Object.hash(imagery, boundaries, facilities);
}

/// [overlays] as map_gl_script.dart's `setOverlays` takes them. [dark] is
/// whether what lies under the overlays' lines and labels is dark-toned —
/// a dark basemap, or the imagery.
Map<String, dynamic> mapOverlaysPayload(MapOverlays overlays, {required bool dark, required Translations t}) => {
  'dark': dark || overlays.imagery,
  'imagery': overlays.imagery ? {'tiles': esriImageryTiles, 'maxzoom': esriImageryMaxZoom, 'attribution': esriImageryAttribution} : null,
  'boundaries': overlays.boundaries ? {'base': _regionsBase, 'attribution': t.map.boundariesCredit(sources: _boundariesSources)} : null,
  'facilities': overlays.facilities ? {'base': _facilitiesBase, 'attribution': t.map.facilitiesCredit(sources: _facilitiesSources)} : null,
};

/// The credit for the outlines among [shapes] — each source named once — or
/// null when none of them has one. An activation radius is the program's own
/// rule drawn around its own coordinate, with nobody to credit.
String? mapOutlinesCredit(Translations t, List<MapShapeData> shapes) {
  final sources = {
    for (final shape in shapes)
      if (!shape.isActivationRadius) ?shape.sourceName,
  }.toList()..sort();
  return sources.isEmpty ? null : t.map.outlinesCredit(sources: sources.join(' / '));
}

/// The credits link's two labels, for the script's `setCreditLabels`: the
/// short line's link to every source's credit, and the way back.
Map<String, String> mapCreditLabels(Translations t) => {'more': t.map.fullCredits, 'less': t.map.fewerCredits};
