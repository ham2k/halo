// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The part of map_gl_script.dart's `create` that renders the map to a PNG —
// spliced into it verbatim, so it runs in the same closure and reads the
// same `map`, `flushQueued` and `styleSwapInFlight`. The other way round,
// `remove` in map_gl_script.dart sets this piece's `mapRemoved` and settles
// every `pendingSnapshots` entry, so a snapshot still waiting when the map
// is taken down fails at once rather than at its timeout.

import 'map_zoom_controller.dart' show mapSnapshotRemovedMessage, mapSnapshotTimeoutMessage, mapSnapshotTimeoutMs;

/// See map_gl_script.dart's `mapGlScript`, which includes this text whole.
const mapGlSnapshotScript =
    '''
    // Long enough for a slow link to deliver a screen of tiles at the
    // snapshot's pixel ratio; past it, the host is told rather than left
    // waiting on a map that will never settle (offline, a dead tile server).
    const SNAPSHOT_TIMEOUT_MS = $mapSnapshotTimeoutMs;

    // The snapshots waiting to read the canvas, each by its finish, and
    // whether the map has been taken down under them — which settles every
    // one at once rather than leaving the host to wait out its timeout.
    const pendingSnapshots = new Set();
    let mapRemoved = false;

    // The map as a PNG data URL, re-rendered at [pixelRatio] — the same
    // layout, labels and extent, only more pixels. Waits for 'idle' (every
    // tile in, nothing animating) and then for a frame drawn after it, since
    // a payload still queued behind the style would otherwise be missing
    // from the picture. The ratio goes back to the device's afterwards,
    // success or not: nothing else in this script overrides it.
    function takeSnapshot(pixelRatio) {
      if (mapRemoved) return Promise.reject(new Error('$mapSnapshotRemovedMessage'));
      return new Promise(function (resolve, reject) {
        let done = false;
        const timer = setTimeout(function () {
          finish(null, new Error('$mapSnapshotTimeoutMessage within ' + (SNAPSHOT_TIMEOUT_MS / 1000) + 's'));
        }, SNAPSHOT_TIMEOUT_MS);
        function finish(data, err) {
          if (done) return;
          done = true;
          clearTimeout(timer);
          pendingSnapshots.delete(finish);
          // Settled before the ratio goes back: a reset that throws must not
          // leave the host waiting on a promise nothing will settle.
          if (err) { reject(err); } else { resolve(data); }
          if (!mapRemoved) map.setPixelRatio(null);
        }
        pendingSnapshots.add(finish);
        function whenSettled() {
          if (done) return;
          // `loaded()` as well as the queue: a flush that ran in this same
          // 'idle' has handed its data to a source that is still parsing it,
          // and the frame after would be drawn without it.
          if (flushQueued || styleSwapInFlight || !map.loaded()) {
            map.once('idle', whenSettled);
            map.triggerRepaint();
            return;
          }
          map.once('render', function () {
            try { finish(map.getCanvas().toDataURL('image/png')); } catch (err) { finish(null, err); }
          });
          map.triggerRepaint();
        }
        map.setPixelRatio(pixelRatio);
        map.once('idle', whenSettled);
        map.triggerRepaint();
      });
    }

    // One at a time: each resets the pixel ratio when it is done, which
    // resizes the canvas — and clears it — under any other still waiting to
    // read it.
    let snapshotChain = Promise.resolve();
    function snapshot(pixelRatio) {
      const next = snapshotChain.then(function () { return takeSnapshot(pixelRatio); });
      snapshotChain = next.catch(function () {});
      return next;
    }
''';
