// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The part of map_gl_script.dart's `create` that tells the host where the
// camera is and which way it faces — spliced into it verbatim, so it runs in
// the same closure and reads the same `map` and `report`.

/// See map_gl_script.dart's `mapGlScript`, which includes this text whole.
const mapGlCameraScript = '''
    // Where the camera came to rest, for a host that fetches more as the map
    // closes in or moves on (the Activities map's outlines and the references
    // around its centre). 'moveend' covers a fit, a flyTo and a drag alike;
    // 'load' covers a map that never moves.
    function reportCamera() {
      const center = map.getCenter();
      const bounds = map.getBounds();
      report('camera', JSON.stringify({
        latitude: center.lat, longitude: wrapLongitude(center.lng), zoom: map.getZoom(),
        south: bounds.getSouth(), west: bounds.getWest(), north: bounds.getNorth(), east: bounds.getEast(),
      }));
    }
    map.on('load', reportCamera);
    map.on('moveend', reportCamera);

    // Which way the map faces, for the host's compass button: at most once a
    // frame while the map turns or tilts, which fires its events faster than
    // a bridge should carry them. Read when the frame comes round, so the
    // last report of a turn is where it ended.
    let orientationFrame = 0;
    function reportOrientation() {
      if (orientationFrame) return;
      orientationFrame = requestAnimationFrame(function () {
        orientationFrame = 0;
        report('orientation', map.getBearing() + ',' + map.getPitch());
      });
    }
    map.on('rotate', reportOrientation);
    map.on('pitch', reportOrientation);
''';
