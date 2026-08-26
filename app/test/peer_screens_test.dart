// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Screen sharing end to end (HALO-369): two real PeerServices on loopback
// sockets, real PeerChannels routing the offer and the subscription between
// them, and a real second WebSocket carrying the frames. Only the CAPTURE is
// faked — a VM test has no screen — so what these prove is everything from
// the operator picking a source to the bytes arriving in a viewer's pane.
//
// The media link is the reason this is an integration test rather than a
// unit one. It is admitted by a ticket the control link handed over, dialled
// on a port the grant named, and matched on the producer by a map nothing
// else touches; every one of those is a place where two halves can agree in
// isolation and disagree over a socket.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/location_service.dart';
import 'package:ham2k_logger/services/peer/peer_channels.dart';
import 'package:ham2k_logger/services/peer/peer_screen_views.dart';
import 'package:ham2k_logger/services/peer/peer_screens.dart';
import 'package:ham2k_logger/services/peer/peer_service.dart';
import 'package:ham2k_logger/services/screen_capture_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<int> freeUdpPort() async {
  final probe = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  probe.close();
  return port;
}

Future<void> waitFor(
  String what,
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('timed out waiting for: $what');
}

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

  @override
  Future<void> start(String sourceId, {int maxWidth = 1280, int fps = 10, double quality = 0.6}) async {
    if (failStartWith case final message?) {
      throw ScreenCaptureException(message, code: 'capture');
    }
    started.add(sourceId);
    startedWidths.add(maxWidth);
  }

  /// The OS ending a stream on its own — the shared window closed, or the
  /// operator revoked Screen Recording while it was running.
  void osStopped(String sourceId, String reason) =>
      _stopped.add(ScreenCaptureStopped(sourceId, reason));

  @override
  Future<void> stop(String sourceId) async => stopCalls.add(sourceId);

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {
    await _frames.close();
    await _stopped.close();
  }

  void emit(String sourceId, int sequence, List<int> image) {
    _frames.add(PeerScreenFrame(
      sourceId: sourceId,
      width: 640,
      height: 400,
      sequence: sequence,
      format: 'jpeg',
      image: Uint8List.fromList(image),
    ).encode());
  }
}

class _Device {
  _Device(
    this.deviceId,
    this.name,
    int beaconPort, {
    required this.settings,
    required List<PeerScreenSource> sources,
  }) {
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
      beaconPort: beaconPort,
    );
    screens = PeerScreens(settings: settings, peers: service, capture: capture);
    views = PeerScreenViews(peers: service);
    channels = PeerChannels(
      peers: service,
      location: location,
      screens: screens,
      views: views,
    );
  }

  final String deviceId;
  final String name;
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

const _display = PeerScreenSource(id: 'display:1', name: 'Built-in', kind: 'display');
const _window = PeerScreenSource(id: 'window:99', name: 'WSJT-X', kind: 'window');

void main() {
  late int beaconPort;
  late SettingsService settings;
  late _Device shack;
  late _Device tablet;

  setUp(() async {
    beaconPort = await freeUdpPort();
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
    // 'device-a' sorts lower, so the tablet dials the shack machine. Only the
    // shack machine has screens; the tablet is a pure viewer, which is the
    // real deployment.
    tablet = _Device('device-a', 'Tablet', beaconPort, settings: settings, sources: const []);
    shack = _Device('device-b', 'Shack PC', beaconPort, settings: settings, sources: const [_display, _window]);
  });

  tearDown(() async {
    await shack.dispose();
    await tablet.dispose();
  });

  Future<void> paired() async {
    await shack.service.trust.trust('device-a', name: 'Tablet');
    await tablet.service.trust.trust('device-b', name: 'Shack PC');
    await shack.service.setEnabled(true);
    await tablet.service.setEnabled(true);
    await waitFor('both sessions established', () =>
        (shack.service.peers['device-a']?.session?.established ?? false) &&
        (tablet.service.peers['device-b']?.session?.established ?? false));
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

    await waitFor('the tablet hears the offer',
        () => tablet.views.offers['device-b']?.length == 1);
    expect(tablet.views.catalog.single.$3.name, 'Built-in');
    expect(tablet.views.catalog.single.$2, 'Shack PC');

    tablet.views.subscribe('remoteScreen#1', const PeerScreenTarget('device-b', 'display:1'));

    // Capture starts on the far side because a pane asked — never because
    // the switch is on.
    await waitFor('the shack machine starts capturing', () => shack.capture.started.isNotEmpty);
    expect(shack.capture.started, ['display:1']);

    // The media link is a second socket the viewer dials on a ticket the
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
    expect(shack.capture.stopCalls, isEmpty,
        reason: 'the second pane is still watching');

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
    await waitFor('refused', () =>
        tablet.views.viewFor(const PeerScreenTarget('device-b', 'window:99'))?.status ==
        PeerScreenViewStatus.refused);
    expect(
      tablet.views.viewFor(const PeerScreenTarget('device-b', 'window:99'))!.refusal,
      'notOffered',
    );
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

    await waitFor('the viewer is told', () =>
        tablet.views.viewFor(const PeerScreenTarget('device-b', 'window:99'))?.status ==
        PeerScreenViewStatus.refused);
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
    await waitFor('the tablet notices', () =>
        tablet.views.viewFor(target)?.status == PeerScreenViewStatus.peerUnreachable);
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

    await waitFor('the tablet is told, with nobody having opened settings',
        () => tablet.views.offers['device-b']?.length == 1);
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
    await waitFor('refused', () =>
        tablet.views.viewFor(target)?.status == PeerScreenViewStatus.refused);
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
    await waitFor('the viewer is told', () =>
        tablet.views.viewFor(target)?.status == PeerScreenViewStatus.refused);
    expect(tablet.views.viewFor(target)!.refusal, 'stopped');
  });

  test('a demanding viewer leaving lowers the terms again', () async {
    // Merged terms that only ratchet up leave the capture running at the
    // widest, fastest thing anyone ever asked for — the producer goes on
    // paying for a stream nobody wants.
    await paired();
    await sharing([_display.id]);
    await shack.screens.addWatcher(
        'preview', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 480, fps: 5));
    await shack.screens.addWatcher(
        'big', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1920, fps: 30));
    expect(shack.capture.startedWidths.last, 1920);

    await shack.screens.removeWatcher('big', 'display:1');
    expect(shack.capture.startedWidths.last, 480,
        reason: 'the surviving watcher only ever asked for 480');
    expect(shack.screens.isWatched('display:1'), isTrue);
  });

  test('a dropped media link recovers on its own', () async {
    // The control link stays perfectly healthy while the media socket goes;
    // nothing else re-drives the flow, so without a retry the pane sits on
    // "Connecting…" until the whole peer session happens to bounce.
    await paired();
    await sharing([_display.id]);
    await waitFor('offered', () => tablet.views.offers['device-b']?.isNotEmpty ?? false);

    const target = PeerScreenTarget('device-b', 'display:1');
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
      return tablet.views.viewFor(target)?.status == PeerScreenViewStatus.live &&
          shack.capture.started.length >= 2;
    }, timeout: PeerScreenViews.retryDelay * 4);
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
      return tablet.views.viewFor(one)?.status == PeerScreenViewStatus.live &&
          tablet.views.viewFor(two)?.status == PeerScreenViewStatus.live;
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
    await shack.screens.addWatcher(
        'big', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 1920, fps: 30));

    await waitFor('the viewer already being served is told', () =>
        tablet.views.viewFor(target)?.status == PeerScreenViewStatus.refused);
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
    await waitFor('and the capture stops with it',
        () => shack.capture.stopCalls.contains('display:1'));
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

  test('un-sharing a source a LOCAL pane is watching tells it, and re-sharing brings it back',
      () async {
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
    await waitFor('the local pane is told', () =>
        local.viewFor(target)?.status == PeerScreenViewStatus.refused);
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
    final deaf = PeerScreenViews(peers: tablet.service, screens: null, localName: 'Tablet');
    addTearDown(deaf.dispose);
    // The shack machine's router has no producer, exactly as a build with
    // the experiment off would.
    shack.channels.dispose();
    PeerChannels(peers: shack.service, location: shack.location);

    const target = PeerScreenTarget('device-b', 'display:1');
    deaf.subscribe('remoteScreen#1', target);
    await waitFor('it stops waiting and says why', () =>
        deaf.viewFor(target)?.status == PeerScreenViewStatus.refused,
        timeout: PeerScreenViews.answerDeadline * 3);
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
    await shack.screens.handleSubscribe(
        'device-a', const PeerScreenSubscription(sourceId: 'display:1', maxWidth: 640, fps: 5));
    expect(shack.capture.started, contains('display:1'));

    await waitFor('the producer gives up on it',
        () => shack.capture.stopCalls.contains('display:1'),
        timeout: PeerScreens.mediaDeadline * 2);
    expect(shack.screens.isWatched('display:1'), isFalse);
    // The deadline is deliberately longer than a viewer's retry round, so
    // this test outlives the framework's own 30s default.
  }, timeout: const Timeout(Duration(seconds: 90)));
}
