// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// When the map moves for the QSO in the logging panel. Picking a logged QSO,
// or putting it down, is one deliberate act, so the map answers it at once —
// and the pick comes from the logging panel's selection, not from the
// call-info, which drops out under three letters and arrives in pieces as
// lookups land. Typing a call — new, or into the QSO already picked — makes a
// new guess per keystroke, so the map waits for the location to hold still:
// a camera that chased every guess would swing across the world while the
// operator types.

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show GridLocation, greatCirclePoints, gridToLocation;
import 'package:ham2k_logger/views/map/map_highlight_camera.dart';
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart';

/// Records what the follower asks of the camera.
class _RecordingCamera extends MapZoomController {
  final calls = <Object>[];

  @override
  void fitTo(List<GridLocation> points) => calls.add(points);

  @override
  void refit() => calls.add('refit');
}

const _here = [GridLocation(40, -74)];
const _there = [GridLocation(51, 0)];

void main() {
  group('MapHighlightCamera', () {
    test('picking a logged QSO frames where it was logged, at once', () {
      fakeAsync((async) {
        final camera = _RecordingCamera();
        final follower = MapHighlightCamera(camera)..follow();
        async.flushTimers();
        camera.calls.clear();
        // The live guess is still the call typed before the pick.
        follower.follow(picked: 'qso-1', pickedPoints: _here, typed: _there);
        async.flushTimers();
        expect(async.elapsed, Duration.zero, reason: 'no wait for a deliberate pick');
        expect(camera.calls, [_here]);
      });
    });

    test('each pick frames at once, back and forth', () {
      fakeAsync((async) {
        final camera = _RecordingCamera();
        final follower = MapHighlightCamera(camera)..follow(picked: 'qso-1', pickedPoints: _here, typed: _here);
        follower.follow(picked: 'qso-2', pickedPoints: _there);
        async.flushTimers();
        follower.follow(picked: 'qso-1', pickedPoints: _here, typed: _here);
        async.flushTimers();
        expect(async.elapsed, Duration.zero);
        expect(camera.calls, [_there, _here]);
      });
    });

    test('putting a pick down returns to the whole log at once', () {
      fakeAsync((async) {
        final camera = _RecordingCamera();
        final follower = MapHighlightCamera(camera)..follow(picked: 'qso-1', pickedPoints: _here, typed: _here);
        follower.follow();
        async.flushTimers();
        expect(async.elapsed, Duration.zero);
        expect(camera.calls, ['refit']);
      });
    });

    test('a pick with nowhere to frame returns to the whole log at once', () {
      // Waiting for a location that may never come would leave the map on
      // the previous QSO, with nothing highlighted there.
      fakeAsync((async) {
        final camera = _RecordingCamera();
        final follower = MapHighlightCamera(camera)..follow(picked: 'qso-1', pickedPoints: _here, typed: _here);
        follower.follow(picked: 'qso-2');
        async.flushTimers();
        expect(camera.calls, ['refit']);
      });
    });

    test('a call being typed is framed only once its location holds still', () {
      fakeAsync((async) {
        final camera = _RecordingCamera();
        final follower = MapHighlightCamera(camera)..follow();
        async.flushTimers();
        camera.calls.clear();
        follower.follow(typed: _here);
        async.elapse(const Duration(milliseconds: 1500));
        follower.follow(typed: _there);
        async.elapse(const Duration(milliseconds: 1500));
        expect(camera.calls, isEmpty, reason: 'each new guess restarts the wait');

        async.elapse(MapHighlightCamera.composingDelay);
        expect(camera.calls, [_there], reason: 'only the guess that held still is framed');
      });
    });

    test('typing into a picked QSO waits, and a call cut short falls back to the pick, not the whole log', () {
      fakeAsync((async) {
        final camera = _RecordingCamera();
        final follower = MapHighlightCamera(camera)..follow(picked: 'qso-1', pickedPoints: _here, typed: _here);
        async.flushTimers();
        camera.calls.clear();

        follower.follow(picked: 'qso-1', pickedPoints: _here, typed: _there);
        async.elapse(const Duration(milliseconds: 1500));
        expect(camera.calls, isEmpty, reason: 'a keystroke, not a pick');
        // Under three letters there is no call-info at all.
        follower.follow(picked: 'qso-1', pickedPoints: _here);
        async.elapse(const Duration(seconds: 5));
        expect(camera.calls, isNot(contains('refit')), reason: 'the QSO is still picked');
        expect(camera.calls.last, _here);
      });
    });

    test('the same highlight again does not restart the wait or move the camera', () {
      fakeAsync((async) {
        final camera = _RecordingCamera();
        final follower = MapHighlightCamera(camera)..follow();
        async.flushTimers();
        camera.calls.clear();
        follower.follow(typed: _here);
        async.elapse(const Duration(milliseconds: 1500));
        // A rebuild for anything else — a QSO logged elsewhere, a settings
        // change — hands over an equal list, not the same one.
        follower.follow(typed: [..._here]);
        async.elapse(const Duration(milliseconds: 500));
        expect(camera.calls, [_here]);

        follower.follow(typed: [..._here]);
        async.elapse(const Duration(seconds: 5));
        expect(camera.calls, [_here]);
      });
    });

    test('clearing a call being typed returns to the whole log after the same wait', () {
      fakeAsync((async) {
        final camera = _RecordingCamera();
        final follower = MapHighlightCamera(camera)..follow(typed: _here);
        async.flushTimers();
        camera.calls.clear();
        follower.follow();
        async.elapse(const Duration(milliseconds: 1500));
        expect(camera.calls, isEmpty, reason: 'a guess that drops out mid-call is a keystroke too');
        async.elapse(const Duration(milliseconds: 500));
        expect(camera.calls, ['refit']);
      });
    });

    test('a pane coming into sight frames what is current at once', () {
      fakeAsync((async) {
        final camera = _RecordingCamera();
        final follower = MapHighlightCamera(camera)..follow(typed: _here);
        async.flushTimers();
        follower.hidden();
        // Picked and put down again while out of sight: the camera is still
        // on the call it last framed.
        follower.follow();
        async.flushTimers();
        expect(async.elapsed, Duration.zero);
        expect(camera.calls, [_here, 'refit']);
      });
    });

    test('coming back into sight on the same pick frames it as edited, not as logged', () {
      // Edited while the pane was hidden: the highlight sits where the edit
      // put it, and a camera on the logged spot would leave it off-screen.
      fakeAsync((async) {
        final camera = _RecordingCamera();
        final follower = MapHighlightCamera(camera)..follow(picked: 'qso-1', pickedPoints: _here, typed: _here);
        async.flushTimers();
        follower.hidden();
        follower.follow(picked: 'qso-1', pickedPoints: _here, typed: _there);
        async.flushTimers();
        expect(async.elapsed, Duration.zero);
        expect(camera.calls, [_here, _there]);
      });
    });

    test('hiding the pane drops a pending move', () {
      // A hidden map may have no size, and a fit into it does nothing.
      fakeAsync((async) {
        final camera = _RecordingCamera();
        final follower = MapHighlightCamera(camera)..follow();
        async.flushTimers();
        camera.calls.clear();
        follower.follow(typed: _here);
        follower.hidden();
        async.elapse(const Duration(seconds: 5));
        expect(camera.calls, isEmpty);
      });
    });

    test('a pending move dies with the pane', () {
      fakeAsync((async) {
        final camera = _RecordingCamera();
        final follower = MapHighlightCamera(camera)..follow();
        async.flushTimers();
        camera.calls.clear();
        follower.follow(typed: _here);
        follower.dispose();
        async.elapse(const Duration(seconds: 5));
        expect(camera.calls, isEmpty);
      });
    });
  });

  // A backend that comes up after the request has only the controller to
  // ask: without the memory, a QSO picked while the map is still loading is
  // lost to the map's own first fit.
  test('the controller remembers the last framing until a refit', () {
    final controller = MapZoomController();
    expect(controller.lastFit, isNull);
    controller.fitTo(_here);
    expect(controller.lastFit, _here, reason: 'remembered with no backend attached to take it');
    controller.refit();
    expect(controller.lastFit, isNull, reason: 'a refit hands the camera back to the markers');
  });

  group('highlightFitPoints', () {
    MapMarkerData marker(GridLocation at) => MapMarkerData(
      id: 'current',
      latitude: at.latitude,
      longitude: at.longitude,
      label: 'X',
      kind: MapMarkerKind.qso,
      color: Colors.red,
      strokeColor: Colors.black,
      highlight: true,
    );

    test('nothing highlighted frames nothing', () {
      expect(highlightFitPoints((markers: [], lines: [])), isNull);
    });

    test('with no line, the marker alone', () {
      expect(highlightFitPoints((markers: [marker(_here.single)], lines: [])), _here);
    });

    // Japan to California crosses the antimeridian, so the arc arrives as two
    // segments, one ending at +180 and the next starting at -180. Framed with
    // its longitudes as given, it spans the whole world instead of the Pacific.
    test('an arc across the antimeridian frames as one span', () {
      final japan = gridToLocation('PM95')!, california = gridToLocation('CM87')!;
      final segments = greatCirclePoints(japan, california);
      expect(segments, hasLength(2), reason: 'the fixture must cross the antimeridian, or this test cannot fail');

      final points = highlightFitPoints((
        markers: [marker(california)],
        lines: [for (var i = 0; i < segments.length; i++) MapLineData(id: 'current/$i', points: segments[i], color: Colors.red, highlight: true)],
      ))!;
      final longitudes = points.map((p) => p.longitude);
      final span = longitudes.reduce((a, b) => a > b ? a : b) - longitudes.reduce((a, b) => a < b ? a : b);
      expect(span, lessThan(180), reason: 'the Pacific, not the world');
      for (var i = 1; i < points.length; i++) {
        expect((points[i].longitude - points[i - 1].longitude).abs(), lessThan(180), reason: 'no jump between neighbours');
      }
    });
  });
}
