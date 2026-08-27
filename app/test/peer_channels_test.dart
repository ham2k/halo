// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The ephemeral channel end to end (HALO-334): two real services on an
// in-memory LAN segment (`peer_network_fakes.dart`), PeerChannels routing
// GPS between them. The sender's location is a
// fake with a settable fix — a VM test has no GPS to grant — but the
// receiver's LocationService is REAL, so what these prove is the whole
// inbound path: wire → session gate → router → the fallback layer consumers
// actually read.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/location_service.dart';
import 'package:ham2k_logger/services/peer/peer_channels.dart';
import 'package:ham2k_logger/services/peer/peer_service.dart';
import 'package:ham2k_logger/services/radio_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/peer/peer_drafts.dart';

import 'peer_network_fakes.dart';

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

Position fixAt(double lat, double lon) => Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// A device whose GPS the test controls. `startIfPermitted` succeeds without
/// an OS, and the fix is whatever the test set — the OUTBOUND half of the
/// channel exercised without hardware, while receivers stay real.
class _FakeGpsLocation extends LocationService {
  Position? _fix;
  int startCalls = 0;
  int stopCalls = 0;

  /// When set, [startIfPermitted] waits on it — the real thing awaits a
  /// platform-channel permission check, and the interleavings that matter
  /// all live inside that window.
  Completer<bool>? gate;

  void setFix(Position? fix) {
    _fix = fix;
    notifyListeners();
  }

  @override
  Future<bool> startIfPermitted() async {
    startCalls++;
    final gate = this.gate;
    if (gate != null) return gate.future;
    return true;
  }

  @override
  void stop() => stopCalls++;

  @override
  LocationStatus get status => _fix != null ? LocationStatus.available : LocationStatus.unknown;

  @override
  Position? get position => _fix;

  @override
  bool get positionIsFromPeer => false;
}

class _Device {
  _Device(this.deviceId, this.name, FakeHost host,
      {LocationService? locationOverride, required SharedPreferences prefs, bool ownsRadio = false}) {
    db = HaLoDatabase(NativeDatabase.memory());
    outbox = PeerOutbox(db);
    operations = OperationsRepository(db, onChange: outbox.notifyChanged);
    qsos = QsosRepository(db, onChange: outbox.notifyChanged);
    location = locationOverride ?? LocationService();
    // The REAL RadioService, no-delay writes: the bridge's whole claim is
    // that it rides the origin/echo discipline this class already carries.
    radio = RadioService(prefs, writeDelay: Duration.zero);
    hasRadio = ownsRadio;
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
    drafts = PeerDrafts(peers: service);
    channels = PeerChannels(
      peers: service,
      location: location,
      radio: radio,
      drafts: drafts,
      hasLocalRadio: () => hasRadio,
      radioIsLive: () => hasRadio && radioLive,
    );
  }

  late final RadioService radio;
  bool hasRadio = false;

  /// The designated rig's link state, as `CatService` would answer it.
  bool radioLive = true;

  final String deviceId;
  final String name;
  late final HaLoDatabase db;
  late final PeerOutbox outbox;
  late final OperationsRepository operations;
  late final QsosRepository qsos;
  late final LocationService location;
  late final PeerService service;
  late final PeerDrafts drafts;
  late final PeerChannels channels;

  Future<void> dispose() async {
    channels.dispose();
    await service.setEnabled(false);
    service.dispose();
    await db.close();
  }
}

void main() {
  late FakeLan lan;
  late _FakeGpsLocation phoneGps;
  late _Device phone;
  late _Device laptop;

  setUp(() async {
    lan = FakeLan();
    phoneGps = _FakeGpsLocation();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // 'device-a' sorts lower, so the laptop dials the phone. The laptop is
    // the radio owner throughout — the park setup.
    laptop = _Device('device-a', 'Laptop', lan.host(), prefs: prefs, ownsRadio: true);
    phone = _Device('device-b', 'Phone', lan.host(), locationOverride: phoneGps, prefs: prefs);
  });

  tearDown(() async {
    await phone.dispose();
    await laptop.dispose();
  });

  Future<void> paired() async {
    await laptop.service.trust.trust('device-b', name: 'Phone');
    await phone.service.trust.trust('device-a', name: 'Laptop');
    await laptop.service.setEnabled(true);
    await phone.service.setEnabled(true);
    await waitFor('the pair to establish', () =>
        laptop.service.peers['device-b']?.session?.established ?? false);
  }

  test('the park scenario: the phone\'s fix reaches the laptop with no operation open at all', () async {
    phoneGps.setFix(fixAt(40.7, -74.0));
    await paired();

    // The establish-time snapshot carries it — the phone does not have to
    // move first, and neither side has an operation open.
    await waitFor('the fix to arrive',
        () => laptop.location.peerPositionProviderId == 'device-b');

    // And the laptop's own hardware failing is what surfaces it: this is the
    // REAL LocationService fallback path, end to end.
    await laptop.location.start();
    expect(laptop.location.status, LocationStatus.available);
    expect(laptop.location.position?.latitude, 40.7);
    expect(laptop.location.positionIsFromPeer, isTrue);
    expect(laptop.location.peerPositionDeviceName, 'Phone');
  });

  test('a moving phone keeps the laptop current', () async {
    phoneGps.setFix(fixAt(40.7, -74.0));
    await paired();
    await waitFor('the first fix', () => laptop.location.peerPositionProviderId != null);

    phoneGps.setFix(fixAt(40.8, -74.1));
    await waitFor('the moved fix to follow', () async {
      await laptop.location.start(); // idempotent past the first call
      return laptop.location.position?.latitude == 40.8;
    });
  });

  test('the provider disconnecting clears its fix instead of leaving it to go stale', () async {
    phoneGps.setFix(fixAt(40.7, -74.0));
    await paired();
    await waitFor('the fix to arrive', () => laptop.location.peerPositionProviderId == 'device-b');

    await phone.service.setEnabled(false);

    await waitFor('the fix to clear with its provider',
        () => laptop.location.peerPositionProviderId == null);
  });

  test('a served peer fix is never relayed onward', () async {
    // The laptop is displaying the phone's fix. Its own location notifies on
    // every change, and a router that broadcast whatever `position` returns
    // would bounce the phone's fix straight back — two devices doing that
    // would ping-pong one fix forever.
    phoneGps.setFix(fixAt(40.7, -74.0));
    await paired();
    await laptop.location.start();
    await waitFor('the laptop to be serving the phone\'s fix',
        () => laptop.location.positionIsFromPeer);

    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(phone.location.peerPositionProviderId, isNull,
        reason: 'the phone must never receive its own fix back as the laptop\'s');
  });

  test('a peer leaving DURING the permission check still releases the GPS', () async {
    // The permission check is a platform round trip; a session that drops
    // inside that window used to strand the listener — GPS streaming for the
    // rest of the process with no peer connected, and a stop() that ran too
    // early stripping whichever view held the stream instead.
    phoneGps.gate = Completer<bool>();
    await paired();
    await waitFor('the start to be attempted', () => phoneGps.startCalls > 0);

    // The pair drops while the check is still in flight...
    await laptop.service.setEnabled(false);
    await waitFor('the phone to notice', () => !(phone.service.peers['device-a']?.session?.established ?? false));
    expect(phoneGps.stopCalls, 0,
        reason: 'nothing to stop yet — the listener has not been taken, and an early stop would strip a view');

    // ...and then the check resolves with permission granted.
    phoneGps.gate!.complete(true);
    await waitFor('the late-landing listener to be released', () => phoneGps.stopCalls == 1);
  });

  test('the phone starts its GPS for the pair and releases it when the pair is gone', () async {
    await paired();
    await waitFor('the phone to start sharing its GPS', () => phoneGps.startCalls > 0);

    await laptop.service.setEnabled(false);
    await waitFor('the phone to release the GPS', () => phoneGps.stopCalls > 0);
  });

  group('the CAT bridge', () {
    test('the owner\'s VFO reaches the controller — snapshot first, then live', () async {
      laptop.radio.setVfo('vfoA', freq: 14285.0, mode: 'USB');
      await paired();

      await waitFor('the snapshot to land',
          () => phone.radio.vfoA.freq == 14285.0 && phone.radio.vfoA.mode == 'USB');

      laptop.radio.setVfo('vfoA', freq: 7074.0, mode: 'LSB');
      await waitFor('the live change to follow', () => phone.radio.vfoA.freq == 7074.0);
    });

    test('the controller\'s tune reaches the owner as a USER move', () async {
      await paired();

      VfoOrigin? seenOrigin;
      laptop.radio.addListener(() => seenOrigin = laptop.radio.lastVfoOrigin);
      phone.radio.setVfo('vfoA', freq: 21074.0, mode: 'USB');

      await waitFor('the tune to land on the owner', () => laptop.radio.vfoA.freq == 21074.0);
      expect(seenOrigin, VfoOrigin.user,
          reason: 'user origin is what makes CatService forward it to the real rig');
    });

    test('the three-hop loop settles instead of ping-ponging', () async {
      // Phone tunes -> owner applies as user -> owner reports back -> phone
      // applies as radio. The origin tag plus value dedupe must let that
      // settle in one round trip — a regression here tunes forever.
      laptop.radio.setVfo('vfoA', freq: 14285.0, mode: 'USB');
      await paired();
      await waitFor('the snapshot', () => phone.radio.vfoA.freq == 14285.0);

      var laptopChanges = 0;
      var phoneChanges = 0;
      laptop.radio.addListener(() => laptopChanges++);
      phone.radio.addListener(() => phoneChanges++);

      phone.radio.setVfo('vfoA', freq: 7074.0, mode: 'LSB');
      await waitFor('the round trip', () => laptop.radio.vfoA.freq == 7074.0);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(laptopChanges, 1, reason: 'the owner applies the tune once');
      expect(phoneChanges, lessThanOrEqualTo(2),
          reason: 'the phone: its own tune, at most one confirming report — never a loop');
    });

    test('a device with its OWN radio ignores a peer\'s report', () async {
      // Both sides own radios: neither is a controller, and neither display
      // may follow the other — the operator\'s own rig always wins.
      phone.hasRadio = true;
      phone.radio.setVfo('vfoA', freq: 3573.0, mode: 'LSB');
      await paired();

      laptop.radio.setVfo('vfoA', freq: 14285.0, mode: 'USB');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(phone.radio.vfoA.freq, 3573.0,
          reason: 'a report from elsewhere must never move a rig-owning device\'s VFO');
    });

    test('a controller ignores a tune request — those are for radio owners only', () async {
      // With a second controller in the pair, one phone's tune broadcast
      // reaches the other phone too. Applying it there would mark it a USER
      // move on a device with no radio, which re-forwards it — two
      // controllers ping-ponging one request forever.
      laptop.radio.setVfo('vfoA', freq: 14285.0, mode: 'USB');
      await paired();
      await waitFor('the snapshot', () => phone.radio.vfoA.freq != null);
      final before = phone.radio.vfoA.freq;

      laptop.service.broadcastEphemeral(PeerMessage.catSet(freqKHz: 1234.0, mode: 'CW'));
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(phone.radio.vfoA.freq, before,
          reason: 'only a device that OWNS a radio may honor a tune request');
    });

    test('a tune to a DISCONNECTED rig is neither applied nor confirmed', () async {
      // The rig's link is down. Honoring the request would move only the
      // owner's app state — and the report that fires from that write reaches
      // the controller exactly like a rig confirmation, so both screens show
      // a frequency the physical radio is not on and contacts logged on the
      // phone carry it into the log.
      laptop.radio.setVfo('vfoA', freq: 14285.0, mode: 'USB');
      await paired();
      await waitFor('the snapshot', () => phone.radio.vfoA.freq == 14285.0);

      laptop.radioLive = false;
      phone.radio.setVfo('vfoA', freq: 7074.0, mode: 'LSB');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(laptop.radio.vfoA.freq, 14285.0,
          reason: 'nothing may pretend a dead rig tuned');
    });

    test('an owner ignores a rogue report, so two owners cannot capture each other', () async {
      // catStatus arriving AT an owner is either a misconfigured pair or a
      // spoof: honoring it would let any trusted device rewrite what the
      // logging panel says the operator\'s own rig is doing.
      laptop.radio.setVfo('vfoA', freq: 14285.0, mode: 'USB');
      await paired();
      await waitFor('the snapshot', () => phone.radio.vfoA.freq == 14285.0);

      // The phone (no radio) sends a raw catStatus — not a catSet.
      phone.service.broadcastEphemeral(PeerMessage.catStatus(freqKHz: 1234.0, mode: 'CW'));
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(laptop.radio.vfoA.freq, 14285.0);
    });
  });

  group('live logging state', () {
    PeerQsoDraftPayload draftOf({
      String call = 'KN2X',
      List<PeerDraftFieldPayload> fields = const [PeerDraftFieldPayload(key: 'call', value: 'KN2X')],
      String position = '',
      String operatorCall = '',
      String operationUuid = 'op-1',
    }) =>
        PeerQsoDraftPayload(
          qso: {
            'their': {
              'call': call,
              'sent': '59',
              'guess': {'name': 'John', 'state': 'NY'},
            },
            'our': {'sent': '59'},
            'band': '20m',
            'mode': 'CW',
            'freq': 14025.0,
          },
          operationUuid: operationUuid,
          fields: fields,
          position: position,
          operatorCall: operatorCall,
        );

    test("a position's contact reaches the other position as it is typed", () async {
      await paired();

      phone.drafts.publishLocal(draftOf(position: '2', operatorCall: 'W2ABC'));

      await waitFor('the draft to cross', () => laptop.drafts.blocksFor('op-1').length == 1);
      final block = laptop.drafts.blocksFor('op-1').single;
      expect(block.deviceId, 'device-b');
      expect((block.draft.qso['their'] as Map)['call'], 'KN2X');
      expect(block.draft.position, '2');
      expect(block.draft.operatorCall, 'W2ABC');
      expect(block.isThisDevice, isFalse);
    });

    // The distinction the whole panel rests on. Both reports reach the DRAFT
    // reading '59' — an untouched one has its placeholder folded in — so
    // nothing but the row can say which the operator actually answered.
    test("the sender's row crosses with its labels and its answers", () async {
      await paired();

      phone.drafts.publishLocal(draftOf(fields: const [
        PeerDraftFieldPayload(key: 'call', label: 'Call', value: 'KN2X'),
        PeerDraftFieldPayload(key: 'sent', label: 'Sent', value: '599'),
        PeerDraftFieldPayload(key: 'rcvd', label: 'Rcvd', hint: '599'),
        PeerDraftFieldPayload(key: 'wfd_class', label: 'Class', value: '3A'),
      ]));

      await waitFor('the draft to cross', () => laptop.drafts.blocksFor('op-1').isNotEmpty);
      final row = laptop.drafts.blocksFor('op-1').single.draft.fields;
      expect(row.map((f) => f.key), ['call', 'sent', 'rcvd', 'wfd_class']);
      // Sent was typed; Rcvd was not and carries only what the app would send.
      expect(row[1].value, '599');
      expect(row[2].value, isEmpty);
      expect(row[2].hint, '599');
      // And a control this device has no extension for still has its name.
      expect(row.last.label, 'Class');
    });

    // A peer that arrives between two keystrokes would otherwise show an
    // empty block until the operator next typed something.
    test('a position that joins late is caught up without anyone typing', () async {
      phone.drafts.publishLocal(draftOf(position: '2'));
      await paired();

      await waitFor('the snapshot to arrive', () => laptop.drafts.blocksFor('op-1').isNotEmpty);
      expect(laptop.drafts.blocksFor('op-1').single.draft.position, '2');
    });

    // A session outlives an operation change on either side. Without the
    // draft naming its own operation, this contact would appear in a panel
    // showing something else entirely.
    test("a draft for another operation never lands in this one's panel", () async {
      await paired();

      phone.drafts.publishLocal(draftOf(operationUuid: 'op-2'));

      await waitFor('the draft to arrive at all', () => laptop.drafts.blocksFor('op-2').isNotEmpty);
      expect(laptop.drafts.blocksFor('op-1'), isEmpty);
    });

    // Half a contact on a device that is no longer here is not a state
    // anyone can act on, and leaving it up reads as a position still working
    // that station.
    test('a position that goes away takes its block with it', () async {
      await paired();
      phone.drafts.publishLocal(draftOf());
      await waitFor('the draft to cross', () => laptop.drafts.blocksFor('op-1').isNotEmpty);

      await phone.service.setEnabled(false);

      await waitFor('the block to go', () => laptop.drafts.blocksFor('op-1').isEmpty);
    });

    test('this device has a block of its own, ordered by position', () async {
      await paired();
      laptop.drafts.publishLocal(draftOf(call: 'W1AW', position: '3'));
      phone.drafts.publishLocal(draftOf(call: 'KN2X', position: '1'));

      await waitFor('both blocks', () => laptop.drafts.blocksFor('op-1').length == 2);
      final blocks = laptop.drafts.blocksFor('op-1');
      expect(blocks.map((b) => b.draft.position), ['1', '3']);
      expect(blocks.last.isThisDevice, isTrue, reason: 'position 3 is this device');
    });

    // A position with no number sorts last rather than as zero, which would
    // put it ahead of position 1.
    test('an unnumbered position sorts after the numbered ones', () async {
      await paired();
      laptop.drafts.publishLocal(draftOf(position: ''));
      phone.drafts.publishLocal(draftOf(position: '1'));

      await waitFor('both blocks', () => laptop.drafts.blocksFor('op-1').length == 2);
      expect(laptop.drafts.blocksFor('op-1').map((b) => b.draft.position), ['1', '']);
    });

    // A position that leaves the operation is gone, not blank. Its session is
    // still up, so nothing else would ever say so — and snapshotTo would keep
    // seeding the stale contact to peers connecting afterwards.
    test('a position that leaves the operation takes its block with it', () async {
      await paired();
      phone.drafts.publishLocal(draftOf());
      await waitFor('the draft to cross', () => laptop.drafts.blocksFor('op-1').isNotEmpty);

      phone.drafts.clearLocalFor('op-1');

      await waitFor('the block to go', () => laptop.drafts.blocksFor('op-1').isEmpty);
      expect(phone.drafts.localDraft, isNull);
    });

    // Distinct from leaving: an empty callsign is how a position says it just
    // logged or wiped, and it is still sitting there.
    test('a wiped contact empties the block rather than removing it', () async {
      await paired();
      phone.drafts.publishLocal(draftOf());
      await waitFor('the draft to cross', () => laptop.drafts.blocksFor('op-1').isNotEmpty);

      phone.drafts.publishLocal(draftOf(call: '', fields: const []));

      await waitFor('the wipe to cross',
          () => laptop.drafts.blocksFor('op-1').single.draft.fields.isEmpty);
      expect(laptop.drafts.blocksFor('op-1'), hasLength(1));
    });

    test('leaving an operation this device is not in leaves the block alone', () async {
      await paired();
      phone.drafts.publishLocal(draftOf());
      await waitFor('the draft to cross', () => laptop.drafts.blocksFor('op-1').isNotEmpty);

      // Opening B from inside A and popping back disposes A's view AFTER B's
      // has published; retracting here would pull a block that is correct.
      phone.drafts.clearLocalFor('op-2');

      expect(phone.drafts.localDraft, isNotNull);
      expect(laptop.drafts.blocksFor('op-1'), hasLength(1));
    });

    test('sharing turned off leaves nothing standing', () async {
      await paired();
      phone.drafts.publishLocal(draftOf());
      await waitFor('the draft to cross', () => laptop.drafts.blocksFor('op-1').isNotEmpty);

      laptop.drafts.clearLocal();

      expect(laptop.drafts.blocksFor('op-1'), isEmpty);
      expect(laptop.drafts.localDraft, isNull);
    });
  });
}
