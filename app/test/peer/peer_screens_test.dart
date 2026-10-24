// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Screen sharing end to end (HALO-369): two real PeerServices on one
// in-memory segment (`peer_network_fakes.dart`), real PeerChannels routing
// the offer and the subscription between them, and a second link on the
// same segment carrying the frames. The CAPTURE is faked — a VM test has no
// screen — and so is the wire, so what these prove is everything from the
// operator picking a source to the bytes arriving in a viewer's pane, with
// the machine's network having no say in it: a real beacon socket broadcasts
// to the LAN, which macOS gates behind a Local Network grant the test runner
// may not hold.
//
// The media link is the reason this is an integration test rather than a
// unit one. It is admitted by a ticket the control link handed over, dialled
// on a port the grant named, and matched on the producer by a map nothing
// else touches; every one of those is a place where two halves can agree in
// isolation and disagree over a socket.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/location_service.dart';
import 'package:ham2k_logger/services/peer/peer_channels.dart';
import 'package:ham2k_logger/services/peer/peer_link_types.dart';
import 'package:ham2k_logger/services/peer/peer_screen_views.dart';
import 'package:ham2k_logger/services/peer/peer_screens.dart';
import 'package:ham2k_logger/services/peer/peer_service.dart';
import 'package:ham2k_logger/services/screen_capture_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/error_reporting_fakes.dart';
import '../support/peer_network_fakes.dart';
import '../support/wait_for.dart';

/// A screen this device claims to have. Records what was actually started and
/// stopped, which is the only way to check the rule the whole producer is
/// built around: a source captures only while somebody is watching it.
class _FakeCapture extends ScreenCaptureService {
  _FakeCapture(this.sources);

  final List<PeerScreenSource> sources;
  final _frames = StreamController<Uint8List>.broadcast();
  final _stopped = StreamController<ScreenCaptureStopped>.broadcast();

  final List<String> started = [];
  final List<String> stopCalls = [];
  final List<int> startedWidths = [];

  /// When set, [start] throws it — macOS refusing the capture because the
  /// window went away, or Screen Recording was revoked between enumerating
  /// and streaming.
  String? failStartWith;

  @override
  Stream<Uint8List> get frames => _frames.stream;

  @override
  Stream<ScreenCaptureStopped> get stopped => _stopped.stream;

  @override
  Future<ScreenCaptureAvailability> availability() async => ScreenCaptureAvailability.available;

  @override
  Future<ScreenCapturePermission> permission() async => ScreenCapturePermission.granted;

  @override
  Future<List<PeerScreenSource>> listSources() async => sources;

  /// Held open by a test that needs to act DURING a restart — the window
  /// where the old capture session is still delivering.
  Completer<void>? startGate;

  /// The crop and the quality each capture was started at, in the order the
  /// starts happened — what a test asking whether a viewer's terms actually
  /// reached the OS reads.
  final List<PeerScreenCrop?> startedCrops = [];
  final List<double> startedQualities = [];

  @override
  Future<void> start(String sourceId, {int maxWidth = 1280, int fps = 10, double quality = 0.6, PeerScreenCrop? crop}) async {
    if (failStartWith case final message?) {
      throw ScreenCaptureException(message, code: 'capture');
    }
    if (startGate case final gate?) await gate.future;
    started.add(sourceId);
    startedWidths.add(maxWidth);
    startedCrops.add(crop);
    startedQualities.add(quality);
  }

  /// The OS ending a stream on its own — the shared window closed, or the
  /// operator revoked Screen Recording while it was running.
  void osStopped(String sourceId, String reason) => _stopped.add(ScreenCaptureStopped(sourceId, reason));

  @override
  Future<void> stop(String sourceId) async => stopCalls.add(sourceId);

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {
    await _frames.close();
    await _stopped.close();
  }

  /// A frame whose header carries no sequence — what a producer on a format
  /// this build does not know would look like on the wire.
  void emitWithoutSequence(String sourceId) {
    final header = utf8.encode('{"src":"$sourceId","w":640,"h":400,"fmt":"jpeg"}');
    _frames.add(Uint8List.fromList([1, header.length >> 8, header.length & 0xFF, ...header, 7, 7, 7]));
  }

  void emit(String sourceId, int sequence, List<int> image) {
    _frames.add(PeerScreenFrame(sourceId: sourceId, width: 640, height: 400, sequence: sequence, format: 'jpeg', image: Uint8List.fromList(image)).encode());
  }
}

/// A viewer's media link driven by hand, over a link the test dialled
/// itself: it chooses whether to acknowledge. The only way to model a viewer wedged behind a
/// congested link, which is exactly what no transport signal reveals.
class _MediaClient {
  _MediaClient(this._link, {required bool acks}) : acking = acks {
    _link.inbound.listen((bytes) {
      final frame = PeerScreenFrame.decode(bytes);
      if (frame == null) return;
      received.add(frame.sequence);
      if (garbageAcks) {
        _link.send(utf8.encode('not an acknowledgement'));
      } else if (acking) {
        _link.send(PeerScreenAck(sourceId: frame.sourceId, sequence: frame.sequence).encode());
      }
    });
  }

  final PeerLink _link;
  final List<int> received = [];

  /// Toggleable, so a test can leave a frame outstanding at a chosen moment —
  /// which is the only way to have anything stale in the producer's flow
  /// state when a capture restarts and renumbers.
  bool acking;

  /// Answers on the media link in a format this producer cannot read — a
  /// peer from a build whose ack format moved on.
  bool garbageAcks = false;

  Future<void> close() => _link.close();
}

class _Device {
  _Device(this.deviceId, this.name, this.host, {required this.settings, required List<PeerScreenSource> sources}) {
    db = HaLoDatabase(NativeDatabase.memory());
    outbox = PeerOutbox(db);
    operations = OperationsRepository(db, onChange: outbox.notifyChanged);
    qsos = QsosRepository(db, onChange: outbox.notifyChanged);
    location = LocationService();
    capture = _FakeCapture(sources);
    service = PeerService(
      db: db,
      outbox: outbox,
      operations: operations,
      qsos: qsos,
      localDeviceId: deviceId,
      localDeviceName: name,
      beaconPort: fakeBeaconPort,
      network: host.network,
    );
    screens = PeerScreens(settings: settings, peers: service, capture: capture);
    views = PeerScreenViews(peers: service);
    channels = PeerChannels(peers: service, location: location, screens: screens, views: views);
  }

  final String deviceId;
  final String name;
  final FakeHost host;
  final SettingsService settings;
  late final HaLoDatabase db;
  late final PeerOutbox outbox;
  late final OperationsRepository operations;
  late final QsosRepository qsos;
  late final LocationService location;
  late final _FakeCapture capture;
  late final PeerService service;
  late final PeerScreens screens;
  late final PeerScreenViews views;
  late final PeerChannels channels;

  Future<void> dispose() async {
    channels.dispose();
    views.dispose();
    screens.dispose();
    await service.setEnabled(false);
    service.dispose();
    await db.close();
  }
}

/// What a test that waits out a deadline shortens it to, on the device under
/// test only. Each such test asserts that the deadline eventually fires,
/// which a late timer cannot falsify; a short deadline anywhere else is one a
/// loaded machine can trip (docs/design/time.md §7).
const _waitedOut = Duration(milliseconds: 500);

const _display = PeerScreenSource(id: 'display:1', name: 'Built-in', kind: 'display');
const _window = PeerScreenSource(id: 'window:99', name: 'WSJT-X', kind: 'window');

/// A media link from [viewer] to [producer], dialled by hand exactly the way
/// `PeerScreenViews._dialMedia` does it — through the viewer's own network,
/// to the address the VIEWER's service heard the producer's beacon from. Over
/// loopback both addresses would be the same string and a swap would go
/// unnoticed; the segment keys its listeners by address, so a dial to the
/// wrong one finds nothing.
Future<PeerLink> _dialMedia(_Device viewer, _Device producer, PeerScreenGrant grant) {
  // A peer first heard as an INBOUND session has a runtime with no address
  // until its beacon lands, and `paired()` waits on sessions, not beacons —
  // which production answers with `peerUnreachable` and a retry, and a
  // bare null-check would answer with a stack trace.
  final address = viewer.service.peers[producer.deviceId]?.beacon.address;
  expect(address, isNotNull, reason: 'the viewer has not heard the producer\'s beacon yet');
  return viewer.service.network.dial(address!, grant.port, mediaTicket: grant.ticket);
}

void main() {
  late FakeLan lan;
  late SettingsService settings;
  late _Device shack;
  late _Device tablet;

  setUp(() async {
    // Streaks are process-wide and keyed by peer device id, which every
    // test here shares.
    ErrorReportingService.resetFailureStreaks();
    lan = FakeLan();
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
    // 'device-a' sorts lower, so the tablet dials the shack machine. Only the
    // shack machine has screens; the tablet is a pure viewer, which is the
    // real deployment.
    tablet = _Device('device-a', 'Tablet', lan.host(), settings: settings, sources: const []);
    shack = _Device('device-b', 'Shack PC', lan.host(), settings: settings, sources: const [_display, _window]);
  });

  tearDown(() async {
    await shack.dispose();
    // BETWEEN the two disposes, not after both: closing one end of a link
    // closes the other, so once the tablet is down too, a media link the
    // producer forgot is closed by the viewer's own teardown and nothing is
    // left to count. Here only the producer has gone, so an open link is
    // one `PeerScreens.dispose` left behind. (The viewer's own close is not
    // provable this way — whichever device goes first closes everything —
    // and neither socket nor server counter sees a media link at all.)
    expect(lan.openLinks, 0, reason: 'the producer left a media link open');
    await tablet.dispose();
    // Over a segment no later bind can fail, so a dispose that stopped
    // releasing its beacon socket or link server would look exactly like
    // one that did — the counters are the only evidence.
    expect(lan.openSockets, 0, reason: 'a beacon socket outlived its device');
    expect(lan.openLinkServers, 0, reason: 'a link server outlived its device');
  });

  Future<void> paired() async {
    await shack.service.trust.trust('device-a', name: 'Tablet');
    await tablet.service.trust.trust('device-b', name: 'Shack PC');
    // The tablet first: it is the side that dials, so the shack machine's
    // first beacon must land on a tablet already listening. The other way
    // round that beacon goes to nobody and the dial waits a whole announce
    // interval for the next one — in every test in this file.
    await tablet.service.setEnabled(true);
    await shack.service.setEnabled(true);
    await waitFor(
      'both sessions established',
      () => (shack.service.peers['device-a']?.session?.established ?? false) && (tablet.service.peers['device-b']?.session?.established ?? false),
    );
  }

  /// The shack machine sharing [ids].
  ///
  /// Through `ensureSourcesFresh`, which is what `updatePeerSharing` calls —
  /// NOT `refreshSources` + `announceOffers` by hand. Hand-driving those is
  /// what hid the bug where a relaunched device offered nothing at all until
  /// somebody opened the settings panel.
  Future<void> sharing(List<String> ids) async {
    await settings.setPeerScreenShareEnabled(true);
    await settings.setPeerSharedScreenIds(ids);
    await shack.screens.ensureSourcesFresh();
  }

  test('a shared screen reaches a pane on another device, frames and all', () async {
    await paired();
    await sharing([_display.id]);

    await waitFor('the tablet hears the offer', () => tablet.views.offers['device-b']?.length == 1);
    expect(tablet.views.catalog.single.$3.name, 'Built-in');
    expect(tablet.views.catalog.single.$2, 'Shack PC');

    tablet.views.subscribe('remoteScreen#1', const PeerScreenTarget('device-b', 'display:1'));

    // Capture starts on the far side because a pane asked — never because
    // the switch is on.
    await waitFor('the shack machine starts capturing', () => shack.capture.started.isNotEmpty);
    expect(shack.capture.started, ['display:1']);

    // The media link is a second link the viewer dials on a ticket the
    // control link handed over. Nothing below arrives until it is up.
    shack.capture.emit('display:1', 1, [1, 2, 3, 4]);
    await waitFor('a frame lands in the tablet\'s view', () {
      shack.capture.emit('display:1', 2, [1, 2, 3, 4]);
      return tablet.views.viewFor(const PeerScreenTarget('device-b', 'display:1'))?.frame != null;
    });

    final view = tablet.views.viewFor(const PeerScreenTarget('device-b', 'display:1'))!;
    expect(view.status, PeerScreenViewStatus.live);
    expect(view.frame!.image, [1, 2, 3, 4]);
    expect(view.frame!.width, 640);
  });

  test('the last pane closing stops the far capture', () async {
    // The rule the producer is built around. Without it a device keeps
    // paying a GPU pass and a Screen Recording indicator ten times a second
    // for a pane nobody has open.
    await paired();
    await sharing([_display.id]);
    await waitFor('offer heard', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    tablet.views.subscribe('remoteScreen#1', const PeerScreenTarget('device-b', 'display:1'));
    await waitFor('capturing', () => shack.capture.started.isNotEmpty);

    tablet.views.unsubscribe('remoteScreen#1');
    await waitFor('capture stopped', () => shack.capture.stopCalls.contains('display:1'));
    expect(shack.screens.isWatched('display:1'), isFalse);
  });

  test('two panes on one source cost one capture, and it survives the first closing', () async {
    await paired();
    await sharing([_display.id]);
    await waitFor('offer heard', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', target);
    await waitFor('capturing', () => shack.capture.started.isNotEmpty);
    tablet.views.subscribe('remoteScreen#2', target);

    tablet.views.unsubscribe('remoteScreen#1');
    // A moment for an unsubscribe that should not happen to cross the wire.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(shack.capture.stopCalls, isEmpty, reason: 'the second pane is still watching');

    tablet.views.unsubscribe('remoteScreen#2');
    await waitFor('capture stopped', () => shack.capture.stopCalls.contains('display:1'));
  });

  test('a source the operator did not pick is refused, not served', () async {
    // The security property. A viewer's saved panel config outlives the
    // producer's choices, so a stale id must not reach a window that is
    // merely capturable.
    await paired();
    await sharing([_display.id]);
    await waitFor('offer heard', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    tablet.views.subscribe('remoteScreen#1', const PeerScreenTarget('device-b', 'window:99'));
    await waitFor('refused', () => tablet.views.viewFor(const PeerScreenTarget('device-b', 'window:99'))?.status == PeerScreenViewStatus.refused);
    expect(tablet.views.viewFor(const PeerScreenTarget('device-b', 'window:99'))!.refusal, 'notOffered');
    expect(shack.capture.started, isEmpty, reason: 'nothing may capture for a refused request');
  });

  test('withdrawing a source tells the viewer, rather than letting frames dry up', () async {
    // A frozen pane and a network problem look identical. The producer says
    // so out loud so the pane can write the reason over its last picture.
    await paired();
    await sharing([_display.id, _window.id]);
    await waitFor('both offered', () => tablet.views.offers['device-b']?.length == 2);

    tablet.views.subscribe('remoteScreen#1', const PeerScreenTarget('device-b', 'window:99'));
    await waitFor('capturing', () => shack.capture.started.contains('window:99'));

    await settings.setPeerSharedScreenIds([_display.id]);
    await shack.screens.applyOffers();

    await waitFor('the viewer is told', () => tablet.views.viewFor(const PeerScreenTarget('device-b', 'window:99'))?.status == PeerScreenViewStatus.refused);
    expect(shack.capture.stopCalls, contains('window:99'));
  });

  test('turning the switch off withdraws everything, in one announcement', () async {
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    await settings.setPeerScreenShareEnabled(false);
    await shack.screens.stopAll();

    // An EMPTY offer, not silence: a viewer that read "no message" as "no
    // change" would keep listing a source that is gone.
    await waitFor('the offer is emptied', () => tablet.views.offers['device-b']?.isEmpty ?? false);
  });

  test('a media link the transport breaks on is uploaded, through the streak', () async {
    // The retry runs every few seconds for as long as the pane is open, so
    // the report goes through the failure streak: what this pins is that
    // the bug is uploaded at all, that it is the streak reporting it (a
    // plain `report` would upload on the first dial and every retry after),
    // and that a dial that succeeds closes the episode. Firing once per
    // episode is the streak's own contract, proven where it lives.
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(() async {
      await paired();
      await sharing([_display.id]);
      await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);
      const target = PeerScreenTarget('device-b', 'display:1');

      tablet.views.retryDelay = _waitedOut;
      tablet.host.dialFailure = StateError('the dialler lost its own state');
      tablet.views.subscribe('remoteScreen#1', target);
      await waitFor('the bug reaches the backend', () => backend.exceptions.isNotEmpty);
      final reported = backend.exceptions.single;
      expect(reported.error, isA<PeerMediaDialFailure>().having((f) => f.peerDeviceId, 'peer', 'device-b').having((f) => f.cause, 'cause', isA<StateError>()));
      expect(reported.context, contains('failed 3 times in a row'));
      expect(tablet.views.viewFor(target)!.status, PeerScreenViewStatus.peerUnreachable);

      // The next dial succeeds, which is what closes the episode: a later
      // failure starts a new count instead of never reaching the threshold.
      tablet.host.dialFailure = null;
      await waitFor('the link comes up', () => shack.screens.hasMediaLink('device-a'));
      expect(ErrorReportingService.failureStreak(PeerScreenViews.dialStreakKey('device-b')), 0);
    }, backend: backend);
  });

  test('a peer going away leaves the pane its last picture and a reason', () async {
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', target);
    await waitFor('a frame lands', () {
      shack.capture.emit('display:1', 1, [9, 9, 9]);
      return tablet.views.viewFor(target)?.frame != null;
    });

    await shack.service.setEnabled(false);
    await waitFor('the tablet notices', () => tablet.views.viewFor(target)?.status == PeerScreenViewStatus.peerUnreachable);
    // The picture stays. It is still the last thing that device showed, and
    // blanking it would lose exactly what the operator opened the pane for.
    expect(tablet.views.viewFor(target)!.frame!.image, [9, 9, 9]);
  });

  test('a device that has only just started up still announces what it shares', () async {
    // The relaunch case. Nothing but `ensureSourcesFresh` populates the OS
    // source list, and what a device OFFERS is that list intersected with
    // what the operator ticked — so a build that only refreshed when the
    // settings panel opened announced an empty offer after every restart,
    // and every saved pane was refused `notOffered` until the operator
    // unticked and reticked a source.
    await settings.setPeerScreenShareEnabled(true);
    await settings.setPeerSharedScreenIds([_display.id]);
    await paired();
    await shack.screens.ensureSourcesFresh();

    await waitFor('the tablet is told, with nobody having opened settings', () => tablet.views.offers['device-b']?.length == 1);
  });

  test('a capture that will not start is refused, not granted', () async {
    // Otherwise the viewer dials a media link that never carries a frame and
    // sits on "Connecting…" for good, when the producer knew at the moment
    // it answered.
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);
    shack.capture.failStartWith = 'Screen Recording is not allowed';

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', target);
    await waitFor('refused', () => tablet.views.viewFor(target)?.status == PeerScreenViewStatus.refused);
    expect(tablet.views.viewFor(target)!.refusal, 'captureFailed');
    expect(shack.screens.isWatched('display:1'), isFalse);
  });

  test('the OS ending a capture is reported, not left to look like a bad network', () async {
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', target);
    await waitFor('capturing', () => shack.capture.started.isNotEmpty);

    shack.capture.osStopped('display:1', 'The window was closed');
    await waitFor('the viewer is told', () => tablet.views.viewFor(target)?.status == PeerScreenViewStatus.refused);
    expect(tablet.views.viewFor(target)!.refusal, 'stopped');
  });

  test('a demanding viewer leaving lowers the terms again', () async {
    // Merged terms that only ratchet up leave the capture running at the
    // widest, fastest thing anyone ever asked for — the producer goes on
    // paying for a stream nobody wants.
    await paired();
    await sharing([_display.id]);
    await shack.screens.addWatcher('preview', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 480, fps: 5));
    await shack.screens.addWatcher('big', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1920, fps: 30));
    expect(shack.capture.startedWidths.last, 1920);

    await shack.screens.removeWatcher('big', 'display:1');
    expect(shack.capture.startedWidths.last, 480, reason: 'the surviving watcher only ever asked for 480');
    expect(shack.screens.isWatched('display:1'), isTrue);
  });

  test('a zoomed pane is served its own corner, at the same cost', () async {
    // The whole point of the crop: the pane asks for the pixels it can
    // SHOW, so zooming in spends the same frame budget on a smaller region
    // instead of asking for a bigger frame. Without it, zoom is an upscale
    // of an already-downscaled JPEG and no amount of link is any help.
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', target);
    await waitFor('capturing', () => shack.capture.started.isNotEmpty);
    expect(shack.capture.startedCrops.last, isNull, reason: 'a pane at rest wants all of it');

    tablet.views.setDemand('remoteScreen#1', (maxWidth: 1280, fullWidth: 1280, crop: const PeerScreenCrop(left: 0.5, top: 0.5, width: 0.25, height: 0.25)));
    await waitFor('the crop reaches the OS', () => shack.capture.startedCrops.last != null);
    expect(shack.capture.startedCrops.last!.left, 0.5);
    expect(shack.capture.startedWidths.last, 1280, reason: 'the same pixels, spent on a quarter of the picture');
    expect(shack.capture.startedQualities.last, greaterThan(0.6), reason: 'a small picture can afford a better encode, and zoom shows artefacts');
  });

  test('a pane repeating what it already asked for costs nothing', () async {
    // Every change of terms stops and restarts the far device's capture,
    // dropping frames for everyone watching. A demand recomputed on each
    // layout pass — which is where it comes from — must not be a change.
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', target);
    await waitFor('capturing', () => shack.capture.started.isNotEmpty);
    final starts = shack.capture.started.length;

    for (var i = 0; i < 5; i++) {
      tablet.views.setDemand('remoteScreen#1', (maxWidth: 1280, fullWidth: 1280, crop: null));
    }
    await Future<void>.delayed(PeerScreenViews.retermDelay * 3);
    expect(shack.capture.started.length, starts, reason: 'the terms never actually changed');
  });

  test('two viewers on one source are served a region covering both', () async {
    // A crop is not merged like a size: taking the smaller rect would show
    // one of the two a picture of somewhere else entirely. The zoomed-in
    // viewer loses sharpness, which is the only part a second watcher can
    // take away.
    await paired();
    await sharing([_display.id]);
    await shack.screens.addWatcher(
      'left',
      const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1280, fps: 10, crop: PeerScreenCrop(left: 0, top: 0, width: 0.25, height: 0.25)),
    );
    expect(shack.capture.startedCrops.last!.width, 0.25);

    await shack.screens.addWatcher(
      'right',
      const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1280, fps: 10, crop: PeerScreenCrop(left: 0.75, top: 0.75, width: 0.25, height: 0.25)),
    );
    expect(shack.capture.startedCrops.last, isNull, reason: 'opposite corners span the whole source');

    await shack.screens.removeWatcher('right', 'display:1');
    expect(shack.capture.startedCrops.last!.width, 0.25, reason: 'the surviving watcher gets its own corner back');
  });

  test('a peer that cannot crop is asked for the whole picture instead', () async {
    // Its grant says nothing about crops, so it is a build that ignores the
    // rect and serves the width asked for across the WHOLE source. That
    // width is a budget for a quarter of the screen — sent as it stands, a
    // zoomed pane comes back blurrier than it was before cropping existed.
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', target);
    await waitFor('capturing', () => shack.capture.started.isNotEmpty);
    // Undo what the real grant established, so this stands for a producer
    // from a build that predates the crop.
    tablet.views.onGrant('device-b', const PeerScreenGrant(sourceId: 'display:1', ticket: 'x', port: 1, paced: true));

    tablet.views.setDemand('remoteScreen#1', (
      maxWidth: 640,
      // What this pane says the same picture is worth from a producer that
      // cannot crop — its own budget, not four times it.
      fullWidth: 1920,
      crop: const PeerScreenCrop(left: 0.5, top: 0.5, width: 0.25, height: 0.25),
    ));
    await waitFor('the terms are converted', () => shack.capture.startedWidths.last != 1280);
    expect(shack.capture.startedCrops.last, isNull, reason: 'it would be ignored anyway');
    expect(shack.capture.startedWidths.last, 1920, reason: "the pane's own answer for a peer that cannot crop");
  });

  test('a pane hidden and shown again does not re-negotiate from scratch', () async {
    // Every hide edge unsubscribes — a dock tab switched away from, the app
    // backgrounded. A demand dropped there costs two capture restarts on the
    // way back: the whole source at the default size, then the pane's own
    // crop 400ms later.
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', target);
    await waitFor('capturing', () => shack.capture.started.isNotEmpty);
    tablet.views.setDemand('remoteScreen#1', (maxWidth: 1280, fullWidth: 1280, crop: const PeerScreenCrop(left: 0.25, top: 0.25, width: 0.5, height: 0.5)));
    await waitFor('the crop reaches the OS', () => shack.capture.startedCrops.last != null);

    tablet.views.unsubscribe('remoteScreen#1');
    await waitFor('the capture stops', () => shack.capture.stopCalls.isNotEmpty);
    tablet.views.subscribe('remoteScreen#1', target);
    await waitFor('capturing again', () => shack.capture.startedCrops.length > 2);
    expect(shack.capture.startedCrops.last?.width, 0.5, reason: 'the pane is looking at what it was looking at');
  });

  test('a second pane does not cost the zoomed one its detail', () async {
    // The union of a crop and the whole source IS the whole source, and the
    // width that came with the crop was a budget for a quarter of the
    // picture. Spent across all of it, the pane that was zoomed in loses
    // three quarters of the detail it had a second earlier — because
    // somebody opened a second pane.
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', target);
    await waitFor('capturing', () => shack.capture.started.isNotEmpty);
    tablet.views.setDemand('remoteScreen#1', (maxWidth: 1280, fullWidth: 2560, crop: const PeerScreenCrop(left: 0.5, top: 0.5, width: 0.25, height: 0.25)));
    await waitFor('zoomed in', () => shack.capture.startedCrops.last != null);

    tablet.views.subscribe('remoteScreen#2', target);
    tablet.views.setDemand('remoteScreen#2', (maxWidth: 1280, fullWidth: 1280, crop: null));
    await waitFor('the crop is given up', () => shack.capture.startedCrops.last == null);
    expect(shack.capture.startedWidths.last, 2560, reason: 'the zoomed pane still needs that many pixels across the screen');
    expect(shack.capture.startedQualities.last, 0.6, reason: 'a whole screen is not owed the quality a small picture earns');
  });

  test('a pane pointed somewhere else takes no crop with it', () async {
    // A crop says which part of THAT picture the pane could see. Carried to
    // another source it asks the far device to capture the top-left quarter
    // of something the operator never framed, and the first frame arrives as
    // a quarter-size tile in the corner of the pane.
    await paired();
    await sharing([_display.id, _window.id]);
    await waitFor('offered', () => (tablet.views.offers['device-b']?.length ?? 0) > 1);

    const first = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', first);
    await waitFor('capturing', () => shack.capture.started.isNotEmpty);
    tablet.views.setDemand('remoteScreen#1', (maxWidth: 1280, fullWidth: 2560, crop: const PeerScreenCrop(left: 0, top: 0, width: 0.25, height: 0.25)));
    await waitFor('zoomed in', () => shack.capture.startedCrops.last != null);

    tablet.views.subscribe('remoteScreen#1', PeerScreenTarget('device-b', _window.id));
    await waitFor('the other source starts', () => shack.capture.started.last == _window.id);
    expect(shack.capture.startedCrops.last, isNull, reason: 'nothing has framed this picture yet');
  });

  test('a dropped media link recovers on its own', () async {
    // The control link stays perfectly healthy while the media socket goes;
    // nothing else re-drives the flow, so without a retry the pane sits on
    // "Connecting…" until the whole peer session happens to bounce.
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.retryDelay = _waitedOut;
    tablet.views.subscribe('remoteScreen#1', target);
    await waitFor('the first frame', () {
      shack.capture.emit('display:1', 1, [1]);
      return tablet.views.viewFor(target)?.status == PeerScreenViewStatus.live;
    });

    // Drops the media link and the producer's watchers, leaving the control
    // session up — exactly what a transient on the second socket looks like.
    await shack.screens.forgetPeer('device-a');
    await waitFor('the far capture stopped', () => shack.capture.stopCalls.contains('display:1'));

    await waitFor('it comes back without anyone touching anything', () {
      shack.capture.emit('display:1', 2, [2]);
      return tablet.views.viewFor(target)?.status == PeerScreenViewStatus.live && shack.capture.started.length >= 2;
    });
  });

  test('two panes on one peer, both asking before the link is up, both connect', () async {
    // The ordinary case, not a corner: a session establishing re-asks for
    // everything at once, so two subscribes routinely race the single dial
    // the viewer makes. A producer that re-minted its ticket per subscribe
    // would invalidate the one being dialled with, refuse the link, and
    // retry into the same race for good.
    await paired();
    await sharing([_display.id, _window.id]);
    await waitFor('both offered', () => tablet.views.offers['device-b']?.length == 2);

    const one = PeerScreenTarget('device-b', 'display:1');
    const two = PeerScreenTarget('device-b', 'window:99');
    tablet.views.subscribe('remoteScreen#1', one);
    tablet.views.subscribe('remoteScreen#2', two);

    await waitFor('both panes go live', () {
      shack.capture.emit('display:1', 1, [1]);
      shack.capture.emit('window:99', 1, [2]);
      return tablet.views.viewFor(one)?.status == PeerScreenViewStatus.live && tablet.views.viewFor(two)?.status == PeerScreenViewStatus.live;
    });
    expect(tablet.views.viewFor(two)!.frame!.image, [2]);
  });

  test('a restart that fails tells the viewer it was already serving', () async {
    // A second, more demanding watcher raises the merged terms, so the
    // capture restarts — and the restart takes the running stream with it.
    // Dropping the original viewer silently freezes its pane on the last
    // picture with no explanation.
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', target);
    await waitFor('live', () {
      shack.capture.emit('display:1', 1, [1]);
      return tablet.views.viewFor(target)?.status == PeerScreenViewStatus.live;
    });

    shack.capture.failStartWith = 'The window was closed';
    await shack.screens.addWatcher('big', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1920, fps: 30));

    await waitFor('the viewer already being served is told', () => tablet.views.viewFor(target)?.status == PeerScreenViewStatus.refused);
    expect(tablet.views.viewFor(target)!.refusal, 'captureFailed');
  });

  test('a device can watch a screen it is sharing itself', () async {
    // No peer, no grant, no ticket, no socket — but the same offer, the same
    // watcher registry and the same frames, so the capture-only-while-watched
    // rule holds for a local pane exactly as it does for a remote one.
    final local = PeerScreenViews(peers: shack.service, screens: shack.screens, localName: 'Mac');
    addTearDown(local.dispose);
    await sharing([_display.id]);

    expect(local.catalog.single.$1, localScreenPeerId);
    expect(local.catalog.single.$2, 'Mac');
    expect(local.catalog.single.$3.id, 'display:1');

    const target = PeerScreenTarget(localScreenPeerId, 'display:1');
    local.subscribe('remoteScreen#1', target);
    await waitFor('the local capture starts', () => shack.capture.started.isNotEmpty);

    await waitFor('a frame reaches the local pane', () {
      shack.capture.emit('display:1', 1, [7, 7, 7]);
      return local.viewFor(target)?.status == PeerScreenViewStatus.live;
    });
    expect(local.viewFor(target)!.frame!.image, [7, 7, 7]);

    local.unsubscribe('remoteScreen#1');
    await waitFor('and the capture stops with it', () => shack.capture.stopCalls.contains('display:1'));
  });

  test('a local pane asking for something unshared is refused, not left waiting', () async {
    final local = PeerScreenViews(peers: shack.service, screens: shack.screens, localName: 'Mac');
    addTearDown(local.dispose);
    await sharing([_display.id]);

    const target = PeerScreenTarget(localScreenPeerId, 'window:99');
    local.subscribe('remoteScreen#1', target);
    await waitFor('refused', () => local.viewFor(target)?.status == PeerScreenViewStatus.refused);
    expect(shack.capture.started, isEmpty);
  });

  test('un-sharing a source a LOCAL pane is watching tells it, and re-sharing brings it back', () async {
    // The peer path is covered above by the offer broadcast. A pane on this
    // very device reads the offer straight off the producer and hears no
    // message, so without an explicit refusal it keeps a frozen picture that
    // looks exactly like a live one — and never recovers, because
    // `subscribe` early-returns on an unchanged target.
    final local = PeerScreenViews(peers: shack.service, screens: shack.screens, localName: 'Mac');
    addTearDown(local.dispose);
    await sharing([_display.id]);

    const target = PeerScreenTarget(localScreenPeerId, 'display:1');
    local.subscribe('remoteScreen#1', target);
    await waitFor('live', () {
      shack.capture.emit('display:1', 1, [1]);
      return local.viewFor(target)?.status == PeerScreenViewStatus.live;
    });

    await settings.setPeerSharedScreenIds(const []);
    await shack.screens.applyOffers();
    await waitFor('the local pane is told', () => local.viewFor(target)?.status == PeerScreenViewStatus.refused);
    expect(local.viewFor(target)!.refusal, 'stopped');

    await sharing([_display.id]);
    await waitFor('and it comes back on its own', () {
      shack.capture.emit('display:1', 2, [2]);
      return local.viewFor(target)?.status == PeerScreenViewStatus.live;
    });
  });

  test('a subscribe nobody answers gives up and says so', () async {
    // The dogfooding case: the other device has the experiment off, so its
    // router drops the message deliberately and nothing on this side would
    // otherwise ever stop waiting.
    await paired();
    final deaf = PeerScreenViews(peers: tablet.service, screens: null, localName: 'Tablet')..answerDeadline = _waitedOut;
    addTearDown(deaf.dispose);
    // The shack machine's router has no producer, exactly as a build with
    // the experiment off would.
    shack.channels.dispose();
    PeerChannels(peers: shack.service, location: shack.location);

    const target = PeerScreenTarget('device-b', 'display:1');
    deaf.subscribe('remoteScreen#1', target);
    await waitFor('it stops waiting and says why', () => deaf.viewFor(target)?.status == PeerScreenViewStatus.refused);
    expect(deaf.viewFor(target)!.refusal, 'noAnswer');
  });

  test('a grant nobody redeems stops the capture instead of running forever', () async {
    // A viewer that can never open the media link retries forever, and each
    // retry is answered with a fresh grant. Without a deadline the producer
    // captures, encodes and discards frames for nobody.
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    // The tablet stops listening, so the grant it is about to be sent is
    // never acted on and no media link is ever opened — a viewer behind a
    // firewall, as far as this device can tell.
    tablet.channels.dispose();
    shack.screens.mediaDeadline = _waitedOut;
    await shack.screens.handleSubscribe('device-a', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 640, fps: 5));
    expect(shack.capture.started, contains('display:1'));

    await waitFor('the producer gives up on it', () => shack.capture.stopCalls.contains('display:1'));
    expect(shack.screens.isWatched('display:1'), isFalse);
  });

  test('a viewer that takes frames but never acknowledges stops being sent them', () async {
    // The whole point. Without a window a viewer that falls behind takes
    // frames into an unbounded socket queue and the producer's heap grows for
    // as long as it stays behind — `dart:io` reports nothing about a sink's
    // depth, and neither add() nor addStream() pushes back.
    await paired();
    await sharing([_display.id]);

    // A hand-rolled viewer: it dials the media link itself and reads
    // frames, but never sends an ack. That is a viewer wedged behind a
    // congested link, which is the case no transport signal can reveal.
    PeerScreenGrant? grant;
    tablet.channels.dispose();
    tablet.service.onEphemeral = (peer, message) {
      grant ??= message.screenGrantOrNull;
    };

    await shack.screens.handleSubscribe('device-a', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 640, fps: 5, acks: true));
    await waitFor('the grant arrives', () => grant != null);

    final media = await _dialMedia(tablet, shack, grant!);
    addTearDown(media.close);
    final received = <int>[];
    media.inbound.listen((bytes) {
      final seq = PeerScreenFrame.decode(bytes)?.sequence;
      if (seq != null) received.add(seq);
    });
    await waitFor('the producer sees the media link', () => shack.screens.hasMediaLink('device-a'));

    // Numbered from 5000, as a capture that has been running a while is.
    // Starting at one would make the count of frames in flight and the
    // highest sequence outstanding the SAME number, and this assertion could
    // not tell a correct window from one that differences raw sequences.
    for (var seq = 5000; seq < 5040; seq++) {
      shack.capture.emit('display:1', seq, [seq & 0xFF]);
    }
    await waitFor('the producer starts dropping', () => shack.screens.framesDropped > 0);

    // EXACTLY the window, not merely bounded by it.
    expect(received.length, PeerScreens.inFlightWindow);
    expect(shack.screens.framesDropped, greaterThan(20));
    // Capture is untouched: pacing gates DELIVERY, and other watchers of the
    // same source must not pay for this one falling behind.
    expect(shack.screens.isWatched('display:1'), isTrue);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a viewer that never says it acks is served ungated', () async {
    // Compatibility, and why `acks` defaults to false. A peer on a build that
    // predates this never answers, so pacing it unconditionally would send a
    // window's worth and then stop for good — a worse failure than the queue
    // this exists to fix, and a silent one.
    await paired();
    await sharing([_display.id]);

    PeerScreenGrant? grant;
    tablet.channels.dispose();
    tablet.service.onEphemeral = (peer, message) => grant ??= message.screenGrantOrNull;

    // Subscribes the way an older build does: no `acks` field at all.
    await shack.screens.handleSubscribe('device-a', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 640, fps: 5));
    await waitFor('the grant arrives', () => grant != null);

    final media = await _dialMedia(tablet, shack, grant!);
    addTearDown(media.close);
    var received = 0;
    media.inbound.listen((_) => received++);
    await waitFor('the producer sees the media link', () => shack.screens.hasMediaLink('device-a'));

    for (var seq = 1; seq < 30; seq++) {
      shack.capture.emit('display:1', seq, [seq & 0xFF]);
    }
    await waitFor('everything reaches it', () => received >= 25);
    expect(shack.screens.framesDropped, 0, reason: 'an unacking viewer must not be throttled into silence');
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('an acking viewer keeps receiving, and says nothing while it keeps up', () async {
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', target);

    var seq = 0;
    await waitFor('frames keep arriving past the window', () {
      shack.capture.emit('display:1', ++seq, [seq & 0xFF]);
      final view = tablet.views.viewFor(target);
      // Past the window means the acks are genuinely reopening it: without
      // them delivery would have stopped at PeerScreens.inFlightWindow.
      return (view?.frame?.sequence ?? 0) > PeerScreens.inFlightWindow + 3;
    });
    expect(tablet.views.viewFor(target)!.degraded, isFalse, reason: 'a viewer that is keeping up has nothing to report');
  });

  /// Subscribes as a bare media client, bypassing the tablet's own viewer.
  Future<_MediaClient> rawViewer(_Device shackDevice, _Device viewerDevice, {required String sourceId, required bool acks, required bool declareAcks}) async {
    PeerScreenGrant? grant;
    viewerDevice.channels.dispose();
    viewerDevice.service.onEphemeral = (peer, message) => grant ??= message.screenGrantOrNull;
    await shackDevice.screens.handleSubscribe(viewerDevice.deviceId, PeerScreenSubscription(sourceId: sourceId, maxWidth: 640, fps: 5, acks: declareAcks));
    await waitFor('the grant arrives', () => grant != null);
    final link = await _dialMedia(viewerDevice, shackDevice, grant!);
    final client = _MediaClient(link, acks: acks);
    addTearDown(client.close);
    await waitFor('the producer sees the media link', () => shackDevice.screens.hasMediaLink(viewerDevice.deviceId));
    return client;
  }

  test('pacing works on a capture whose sequence numbers do not start at one', () async {
    // A high-water mark differenced against an acknowledgement is not a count
    // of frames in flight. Against a real capture — which has been running
    // and is numbering in the thousands — the very first frame charges the
    // window by its ABSOLUTE sequence, and everything after it is dropped
    // until that one frame happens to be acknowledged.
    await paired();
    await sharing([_display.id]);
    final viewer = await rawViewer(shack, tablet, sourceId: _display.id, acks: true, declareAcks: true);

    for (var i = 0; i < 30; i++) {
      shack.capture.emit('display:1', 5000 + i, [i & 0xFF]);
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    await waitFor('frames keep flowing', () => viewer.received.length > 10);
    expect(viewer.received.first, 5000);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a capture restart renumbers, and delivery survives it', () async {
    // Every restart builds a new capture session, which numbers from one
    // again. Flow state left over from the old numbering makes each new frame
    // look already acknowledged — pacing silently off, the unbounded queue
    // back — or every acknowledgement look stale, which starves the viewer.
    await paired();
    await sharing([_display.id]);
    final viewer = await rawViewer(shack, tablet, sourceId: _display.id, acks: true, declareAcks: true);

    for (var i = 0; i < 8; i++) {
      shack.capture.emit('display:1', 5000 + i, [i & 0xFF]);
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    await waitFor('the first session is flowing', () => viewer.received.isNotEmpty);
    final beforeRestart = viewer.received.length;

    // A second, more demanding watcher raises the merged terms, which is what
    // restarts the capture.
    await shack.screens.addWatcher('other', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1920, fps: 30));
    expect(shack.capture.started.length, greaterThan(1));

    for (var i = 1; i < 20; i++) {
      shack.capture.emit('display:1', i, [i & 0xFF]);
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    await waitFor('the renumbered session reaches the same viewer', () => viewer.received.length > beforeRestart + 3);
    expect(viewer.received.last, lessThan(100), reason: 'these are the new session\'s numbers');
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a restart clears what the old numbering left outstanding', () async {
    // The sharp half of a renumbering restart. An acknowledgement for frame 3
    // cannot clear an outstanding entry for frame 5007, so anything left over
    // holds the window shut against every frame the new session produces —
    // and the viewer never retries, because nothing about its link is wrong.
    await paired();
    await sharing([_display.id]);
    final viewer = await rawViewer(shack, tablet, sourceId: _display.id, acks: true, declareAcks: true);

    for (var i = 0; i < 4; i++) {
      shack.capture.emit('display:1', 5000 + i, [i]);
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    await waitFor('flowing', () => viewer.received.isNotEmpty);

    // Go quiet, then leave the window full of old-numbered frames.
    viewer.acking = false;
    for (var i = 10; i < 20; i++) {
      shack.capture.emit('display:1', 5000 + i, [i]);
    }
    await waitFor('the window is full of the old session', () => shack.screens.framesDropped > 0);
    final beforeRestart = viewer.received.length;
    viewer.acking = true;

    // Terms change, so the capture restarts and numbers from one again.
    await shack.screens.addWatcher('other', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1920, fps: 30));

    for (var i = 1; i < 20; i++) {
      shack.capture.emit('display:1', i, [i & 0xFF]);
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    await waitFor('the new session still reaches it', () => viewer.received.length > beforeRestart);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a replaced media link is not starved by what the old one was charged', () async {
    // A half-open socket accepts writes that reach nobody. Those frames are
    // charged to a window no acknowledgement can ever reopen, so without
    // clearing the flow on replacement the NEW link is sent nothing at all —
    // and the viewer never retries, because as far as it knows its link is up.
    await paired();
    await sharing([_display.id]);
    final deaf = await rawViewer(shack, tablet, sourceId: _display.id, acks: false, declareAcks: true);

    for (var i = 1; i <= 10; i++) {
      shack.capture.emit('display:1', i, [i]);
    }
    await waitFor('the window closes against the silent viewer', () => shack.screens.framesDropped > 0);
    await deaf.close();
    // Let the producer see the close before resubscribing: its teardown is
    // asynchronous, and a subscribe that overtakes it would have the old
    // link's cleanup wipe the new watcher.
    await waitFor('the producer notices the close', () => shack.screens.watchers.isEmpty);

    // The same peer dials again — its retry, or a reconnect.
    final fresh = await rawViewer(shack, tablet, sourceId: _display.id, acks: true, declareAcks: true);
    for (var i = 20; i < 30; i++) {
      shack.capture.emit('display:1', i, [i & 0xFF]);
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    await waitFor('the replacement is served', () => fresh.received.isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a viewer that is missing frames says so, and stops saying it once they arrive again', () async {
    // The other half of "says nothing while it keeps up". Pacing DROPS
    // frames by design, so the notice is what tells the operator that the
    // picture they are watching is not the one on the other screen — and a
    // test that only ever asserts isFalse passes just as well against a
    // build that can never raise it at all.
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', target);

    // Emitted from inside the wait: frames captured before the media link is
    // up have nothing to be sent on, and are dropped rather than queued.
    var seq = 1000;
    await waitFor('the first frame lands', () {
      shack.capture.emit('display:1', ++seq, [seq & 0xFF]);
      return tablet.views.viewFor(target)?.frame != null;
    });

    // Gaps wider than the notice threshold — what a paced producer leaves
    // behind when a viewer cannot keep up, or a congested link swallows.
    await waitFor('the notice goes up', () {
      seq += 100;
      shack.capture.emit('display:1', seq, [seq & 0xFF]);
      return tablet.views.viewFor(target)!.degraded;
    });

    // And comes down: the drop window is a RECENT-history window, so a
    // stream that recovers must clear the notice rather than wear it for the
    // rest of the session.
    await waitFor('the notice comes down', () {
      shack.capture.emit('display:1', ++seq, [seq & 0xFF]);
      return !tablet.views.viewFor(target)!.degraded;
    }, timeout: const Duration(seconds: 40));
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a viewer that takes delivery of nothing is given up on rather than paced forever', () async {
    // The state this change creates: both sockets healthy, capture running,
    // window shut against a viewer that declared it acks and then never did.
    // Nothing on the viewer can tell that from a screen nobody is touching —
    // a static source legitimately sends nothing — so the producer, the only
    // side that knows it is holding frames it cannot send, has to say so.
    await paired();
    await sharing([_display.id]);
    shack.screens.stallDeadline = _waitedOut;
    final deaf = await rawViewer(shack, tablet, sourceId: _display.id, acks: false, declareAcks: true);
    // Installed after rawViewer, which takes the same hook to catch the grant.
    final refusals = <String>[];
    tablet.service.onEphemeral = (peer, message) {
      if (message.type == PeerMessageType.screenRefuse) refusals.add(message.reason ?? '');
    };

    var seq = 0;
    await waitFor('the producer gives up and says why', () {
      shack.capture.emit('display:1', ++seq, [seq & 0xFF]);
      return refusals.contains('stalled');
    });
    // Freeing the capture is the point: a source held open for a viewer that
    // is not watching it costs the operator's machine for nothing.
    expect(shack.screens.watchers, isEmpty);
    expect(deaf.received, isNotEmpty, reason: 'it was served before it went quiet');
  });

  test('a viewer told the producer does not read acks sends none', () async {
    // The compatibility half, from the viewer's side. A producer that
    // predates pacing never listens to its end of the media link, and a
    // PeerLink's inbound controller is single-subscription — so acks sent to
    // one are buffered in ITS memory for the life of the link, ten a second
    // per source. Acking unconditionally would move the unbounded queue this
    // change removes onto the other device.
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    // Grants reach the viewer with `paced` cleared, the way an older
    // producer's would. Everything else is the real path.
    tablet.channels.dispose();
    tablet.service.onEphemeral = (peer, message) {
      final grant = message.screenGrantOrNull;
      if (grant != null) {
        tablet.views.onGrant(peer, PeerScreenGrant(sourceId: grant.sourceId, ticket: grant.ticket, port: grant.port));
      }
    };

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.subscribe('remoteScreen#1', target);
    var seq = 0;
    await waitFor('the producer runs out of window for want of acks', () {
      shack.capture.emit('display:1', ++seq, [seq & 0xFF]);
      return shack.screens.framesDropped > 0;
    });
    expect(tablet.views.viewFor(target)?.frame, isNotNull, reason: 'the window it did get through is not the failure being caught');
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a viewer that stops taking delivery is given up on even while the screen sits still', () async {
    // The capture emits nothing while its source is static — the native side
    // drops every non-complete buffer — so a deadline compared on each frame
    // stops being read at exactly the moment the failure starts. A viewer
    // that goes quiet in front of a still screen would hold that capture open
    // until somebody happened to touch it.
    await paired();
    await sharing([_display.id]);
    shack.screens.stallDeadline = _waitedOut;
    final refusals = <String>[];
    final deaf = await rawViewer(shack, tablet, sourceId: _display.id, acks: false, declareAcks: true);
    tablet.service.onEphemeral = (peer, message) {
      if (message.type == PeerMessageType.screenRefuse) refusals.add(message.reason ?? '');
    };

    var seq = 0;
    await waitFor('the window shuts', () {
      shack.capture.emit('display:1', ++seq, [seq & 0xFF]);
      return shack.screens.framesDropped > 0;
    });

    // The screen now sits still: nothing more is captured, ever.
    final capturedWhenQuiet = shack.screens.framesCaptured;
    await waitFor('the producer gives up anyway', () => refusals.contains('stalled'));
    expect(shack.screens.framesCaptured, capturedWhenQuiet, reason: 'nothing may have been captured — that is the whole point');
    expect(shack.screens.watchers, isEmpty);
    expect(deaf.received, isNotEmpty);
  });

  test('a frame from the old capture session does not shut the new one out', () async {
    // A restart stops the old session asynchronously on the native side, so a
    // frame already in its encode pipeline still arrives. Charged into the
    // fresh window with the OLD numbering, it can never be acknowledged: the
    // flow runs at half depth, or shut, for the rest of the session — the
    // exact failure the unacked SET is designed to prevent.
    await paired();
    await sharing([_display.id]);
    final viewer = await rawViewer(shack, tablet, sourceId: _display.id, acks: true, declareAcks: true);

    for (var i = 0; i < 3; i++) {
      shack.capture.emit('display:1', 5000 + i, [i]);
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    await waitFor('flowing', () => viewer.received.isNotEmpty);

    // Terms change, so the capture restarts — and stragglers land mid-restart,
    // unacknowledged, which is the state that outlives the old session.
    final gate = Completer<void>();
    shack.capture.startGate = gate;
    viewer.acking = false;
    final restarted = shack.screens.addWatcher('other', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1920, fps: 30));
    for (var i = 20; i < 24; i++) {
      shack.capture.emit('display:1', 5000 + i, [i]);
    }
    await waitFor('the stragglers are charged to the window', () => shack.screens.framesDropped > 0);
    gate.complete();
    shack.capture.startGate = null;
    await restarted;
    viewer.acking = true;

    final beforeRenumber = viewer.received.length;
    for (var i = 1; i < 12; i++) {
      shack.capture.emit('display:1', i, [i & 0xFF]);
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    await waitFor('the renumbered session flows at full depth', () => viewer.received.length > beforeRenumber + 5);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a capture with no usable header is dropped, never sent past the window', () async {
    // Sending it would be worse than useless: every viewer fails to decode
    // it, AND an unroutable frame cannot be charged to any window — so it
    // would travel ungated, restoring the unbounded socket queue with
    // nothing counting it.
    await paired();
    await sharing([_display.id]);
    final viewer = await rawViewer(shack, tablet, sourceId: _display.id, acks: true, declareAcks: true);

    for (var i = 0; i < 20; i++) {
      shack.capture.emitWithoutSequence('display:1');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(viewer.received, isEmpty);
    expect(shack.screens.framesCaptured, 0, reason: 'nothing usable was captured');

    shack.capture.emit('display:1', 1, [1]);
    await waitFor('a usable frame still gets through', () => viewer.received.isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a peer whose acks this build cannot read is served ungated, not refused', () async {
    // A version skew in the ack format is not congestion. Pacing such a peer
    // jams every one of its flows and then refuses them for stalling, so the
    // operator is told the link is slow when the real answer is that the two
    // builds disagree — and no amount of moving closer to the router helps.
    await paired();
    await sharing([_display.id]);
    final refusals = <String>[];
    final viewer = await rawViewer(shack, tablet, sourceId: _display.id, acks: false, declareAcks: true);
    viewer.garbageAcks = true;
    tablet.service.onEphemeral = (peer, message) {
      if (message.type == PeerMessageType.screenRefuse) refusals.add(message.reason ?? '');
    };

    var seq = 0;
    await waitFor('it keeps receiving well past the window', () {
      shack.capture.emit('display:1', ++seq, [seq & 0xFF]);
      return viewer.received.length > PeerScreens.inFlightWindow + 10;
    }, timeout: PeerScreens.defaultStallDeadline + const Duration(seconds: 20));
    expect(refusals, isEmpty, reason: 'a build mismatch must not be reported as a slow link');
    expect(shack.screens.watchers, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('a pane re-asks after a stall, but not forever', () async {
    // Each re-ask costs the OTHER device a full capture stop and restart. A
    // viewer that cannot keep up fails the same way every time, so an
    // unbounded retry drives someone else's machine in a loop — with the
    // Screen Recording indicator blinking in their menu bar — that nothing
    // on this device counts.
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
    tablet.views.retryDelay = _waitedOut;
    tablet.views.subscribe('remoteScreen#1', target);
    await waitFor('the producer is serving it', () => shack.screens.watchers.isNotEmpty);

    for (var attempt = 1; attempt <= 2; attempt++) {
      await shack.screens.removeWatcher('device-a', 'display:1');
      tablet.views.onRefused('device-b', 'display:1', 'stalled');
      await waitFor('re-asked after stall $attempt', () => shack.screens.watchers.isNotEmpty);
    }

    await shack.screens.removeWatcher('device-a', 'display:1');
    tablet.views.onRefused('device-b', 'display:1', 'stalled');
    // Waiting well past the retry rather than just past it: this asserts
    // something has NOT happened, so a timer that merely ran late would hide
    // a re-ask rather than expose one (time.md §7).
    await Future<void>.delayed(_waitedOut * 4);
    expect(shack.screens.watchers, isEmpty, reason: 'it stops asking and leaves the notice up');
    expect(tablet.views.viewFor(target)!.refusal, 'stalled');
  });

  test('a straggler that lands after the restart is cleared by the renumbering', () async {
    // Ordering the flow reset after the capture starts covers the frames
    // already in the old session's encode pipeline at that moment, but the
    // native teardown is asynchronous and unbounded — one can arrive later
    // still. Two of them shut the window against a session whose numbering
    // can never reach them, and no acknowledgement will ever reopen it.
    await paired();
    await sharing([_display.id]);
    final viewer = await rawViewer(shack, tablet, sourceId: _display.id, acks: true, declareAcks: true);
    shack.capture.emit('display:1', 5000, [1]);
    await waitFor('flowing', () => viewer.received.isNotEmpty);

    await shack.screens.addWatcher('other', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1920, fps: 30));

    // Late stragglers, unacknowledged: the window is now shut on numbers the
    // restarted session will not produce for another eight minutes.
    viewer.acking = false;
    for (var i = 0; i < PeerScreens.inFlightWindow; i++) {
      shack.capture.emit('display:1', 5100 + i, [i]);
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    viewer.acking = true;

    final beforeRenumber = viewer.received.length;
    for (var i = 1; i < 12; i++) {
      shack.capture.emit('display:1', i, [i & 0xFF]);
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    await waitFor('the renumbered session is served', () => viewer.received.length > beforeRenumber + 5);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
