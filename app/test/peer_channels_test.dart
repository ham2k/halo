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
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/location_service.dart';
import 'package:ham2k_logger/services/peer/peer_channels.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/peer/peer_remote_radios.dart';
import 'package:ham2k_logger/services/peer/serial_claims.dart';
import 'package:ham2k_logger/services/peer/peer_service.dart';
import 'package:ham2k_logger/services/peer/peer_station_radios.dart';
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

/// This device's station, as the bridge sees it — a stub, deliberately, so
/// these tests keep running two REAL `RadioService`s over real sockets and
/// prove the origin/echo discipline rather than restate `CatService`.
///
/// `vfoA` stands in for the offered radio, which is what `CatService` does
/// for `radio1` too: reports come from it and a peer's tune goes back
/// through it, so a request honored here takes the same `user`-origin funnel
/// a local keystroke does.
class _FakeStation extends ChangeNotifier implements PeerStationRadios {
  _FakeStation(this.radio) {
    radio.addListener(notifyListeners);
  }

  final RadioService radio;

  /// The radio this device offers, or null when it offers none. Set to null
  /// to say the rig disconnected — that is the only thing withdrawing an
  /// offer means.
  String? offeredId;
  String offeredName = 'Rig';

  /// Connects or drops this device's rig. Null is the disconnect: an offer
  /// only ever names radios whose link is up.
  void setOffered(String? id) {
    offeredId = id;
    notifyListeners();
  }

  /// What `CatService.setRemoteRadio1` does after storing the pick.
  void notifyPick() => notifyListeners();

  /// Every offer this station was told about, so a test can watch the names
  /// a stored pick shows being kept current.
  final List<({String deviceId, String deviceName, List<PeerRadioOffer> radios})> notedOffers = [];

  @override
  void noteOffer(String deviceId, String deviceName, List<PeerRadioOffer> radios) =>
      notedOffers.add((deviceId: deviceId, deviceName: deviceName, radios: radios));

  @override
  PeerRadioSelection? remoteRadio1;

  /// Every tune request this station was asked to honor, refused ones
  /// included — the refusals are what several of these tests assert on.
  final List<String> tuneRequests = [];

  @override
  List<PeerRadioOffer> get offeredRadios =>
      [if (offeredId case final id?) PeerRadioOffer(id: id, name: offeredName)];

  @override
  VfoReading? vfoForOfferedRadio(String radioId) {
    if (offeredId != radioId) return null;
    return VfoReading(freqKHz: radio.vfoA.freq, mode: radio.vfoA.mode);
  }

  @override
  void tuneOfferedRadio(String radioId, {double? freqKHz, String? mode}) {
    tuneRequests.add(radioId);
    if (offeredId != radioId) return;
    radio.setVfo('vfoA', freq: freqKHz, mode: mode);
  }

  @override
  void dispose() {
    radio.removeListener(notifyListeners);
    super.dispose();
  }
}

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
    station = _FakeStation(radio);
    if (ownsRadio) station.offeredId = radioId;
    remoteRadios = PeerRemoteRadios();
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
    claims = SerialClaims(
      localDeviceId: deviceId,
      peek: (_, __) async => 1,
      livePeers: () => [for (final id in service.peers.keys) if (service.hasLanSession(id)) id],
      send: service.sendEphemeralTo,
    );
    channels = PeerChannels(
      peers: service,
      location: location,
      radio: radio,
      drafts: drafts,
      claims: claims,
      station: station,
      remoteRadios: remoteRadios,
    );
  }

  late final RadioService radio;
  late final _FakeStation station;
  late final PeerRemoteRadios remoteRadios;

  /// What this device calls its own rig on the wire. Distinct per device so
  /// a test can prove a report is matched against the DEVICE as well as the
  /// radio — two stations may well number their nodes the same way.
  String get radioId => 'rig-$deviceId';

  /// Points this device's `vfoA` at [owner]'s rig, the way the operator
  /// picking it out of the main-VFO list does. Call
  /// `station.notifyPick()` after it to stand in for the panel's write,
  /// which notifies; setting the field alone is the pre-pairing setup every
  /// other test wants.
  void control(_Device owner) => station.remoteRadio1 =
      PeerRadioSelection(deviceId: owner.deviceId, radioId: owner.radioId);

  final String deviceId;
  final String name;
  late final HaLoDatabase db;
  late final PeerOutbox outbox;
  late final OperationsRepository operations;
  late final QsosRepository qsos;
  late final LocationService location;
  late final PeerService service;
  late final PeerDrafts drafts;
  late final SerialClaims claims;
  late final PeerChannels channels;

  Future<void> dispose() async {
    channels.dispose();
    station.dispose();
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
  late SharedPreferences prefs;

  setUp(() async {
    lan = FakeLan();
    phoneGps = _FakeGpsLocation();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
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
    test('a peer\'s offer reaches the picker — snapshot first, then live', () async {
      await paired();

      await waitFor('the establish-time snapshot',
          () => phone.remoteRadios.find('device-a', laptop.radioId) != null);
      expect(phone.remoteRadios.all.single.deviceName, 'Laptop');

      // The rig drops. An EMPTY offer is the message that says so, and a
      // picker that treated it as "nothing to update" would keep listing a
      // radio nobody can reach.
      laptop.station.setOffered(null);
      await waitFor('the withdrawal', () => phone.remoteRadios.all.isEmpty);
    });

    test('the picked radio\'s VFO reaches the controller — snapshot first, then live', () async {
      phone.control(laptop);
      laptop.radio.setVfo('vfoA', freq: 14285.0, mode: 'USB');
      await paired();

      await waitFor('the snapshot to land',
          () => phone.radio.vfoA.freq == 14285.0 && phone.radio.vfoA.mode == 'USB');

      laptop.radio.setVfo('vfoA', freq: 7074.0, mode: 'LSB');
      await waitFor('the live change to follow', () => phone.radio.vfoA.freq == 7074.0);
    });

    test('a report nobody picked moves nothing', () async {
      // THE POINT OF THE EXPLICIT PICK. The phone has no radio of its own
      // and is trusted by the laptop — under the derived roles this bridge
      // started with, that alone made it follow. Now the pick is what
      // decides, and there is none.
      laptop.radio.setVfo('vfoA', freq: 14285.0, mode: 'USB');
      await paired();
      await waitFor('the offer, so the report has certainly been sent too',
          () => phone.remoteRadios.all.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(phone.radio.vfoA.freq, isNull,
          reason: 'a radio-less device follows the radio its operator picked, not any it hears');
    });

    test('a report for the RIGHT device but the wrong radio moves nothing', () async {
      // A shack with two rigs offers both, and the operator picked one. Node
      // uuids are unique within a station but the pair is not one station,
      // so matching on the device alone would follow the wrong rig here and
      // any peer's rig in the test above.
      phone.station.remoteRadio1 =
          const PeerRadioSelection(deviceId: 'device-a', radioId: 'rig-the-other-one');
      laptop.radio.setVfo('vfoA', freq: 14285.0, mode: 'USB');
      await paired();
      await waitFor('the offer', () => phone.remoteRadios.all.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(phone.radio.vfoA.freq, isNull);
    });

    test('the controller\'s tune reaches the picked radio as a USER move', () async {
      phone.control(laptop);
      await paired();

      VfoOrigin? seenOrigin;
      laptop.radio.addListener(() => seenOrigin = laptop.radio.lastVfoOrigin);
      phone.radio.setVfo('vfoA', freq: 21074.0, mode: 'USB');

      await waitFor('the tune to land on the owner', () => laptop.radio.vfoA.freq == 21074.0);
      expect(seenOrigin, VfoOrigin.user,
          reason: 'user origin is what makes CatService forward it to the real rig');
    });

    test('a tune goes only to the peer whose radio was picked', () async {
      // Addressed, not broadcast — and the shape that makes the difference
      // is a station RESTORED onto a second machine, which brings the first
      // one's node uuids with it. A broadcast tune names only the radio, so
      // the clone answers it too: one operator's dial moves a rig in someone
      // else's shack, and nothing anywhere says it happened.
      final clone = _Device('device-c', 'Spare Laptop', lan.host(), prefs: prefs, ownsRadio: true);
      addTearDown(clone.dispose);
      clone.station.setOffered(laptop.radioId);
      await clone.service.trust.trust('device-b', name: 'Phone');
      await phone.service.trust.trust('device-c', name: 'Spare Laptop');

      phone.control(laptop);
      await paired();
      await clone.service.setEnabled(true);
      await waitFor('the clone to join too',
          () => phone.service.peers['device-c']?.session?.established ?? false);

      phone.radio.setVfo('vfoA', freq: 21074.0, mode: 'USB');
      await waitFor('the tune to land on the picked radio',
          () => laptop.radio.vfoA.freq == 21074.0);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(clone.station.tuneRequests, isEmpty,
          reason: 'a device nobody picked was asked to move its rig');
      expect(clone.radio.vfoA.freq, isNull);
    });

    test('a tune for a radio this device does not offer is refused', () async {
      // The station is asked — the router does not pre-filter — and refuses.
      // Reaching the rig would mean any trusted device could move a radio by
      // naming a uuid, which is the whole gate.
      phone.control(laptop);
      await paired();
      await waitFor('the offer', () => phone.remoteRadios.all.isNotEmpty);
      laptop.radio.setVfo('vfoA', freq: 14285.0, mode: 'USB');
      await waitFor('the report', () => phone.radio.vfoA.freq == 14285.0);

      phone.service.broadcastEphemeral(
          PeerMessage.catSet(radioId: 'rig-nobody-has', freqKHz: 1234.0, mode: 'CW'));
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(laptop.station.tuneRequests, contains('rig-nobody-has'));
      expect(laptop.radio.vfoA.freq, 14285.0);
    });

    test('the three-hop loop settles instead of ping-ponging', () async {
      // Phone tunes -> owner applies as user -> owner reports back -> phone
      // applies as radio. The origin tag plus value dedupe must let that
      // settle in one round trip — a regression here tunes forever.
      phone.control(laptop);
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

    test('offering a radio does not make this device follow anyone', () async {
      // Both devices offer a rig and neither picked the other's. Following
      // would mean two sources writing one `vfoA`, and the operator's own
      // rig must win.
      phone.station.offeredId = phone.radioId;
      phone.radio.setVfo('vfoA', freq: 3573.0, mode: 'LSB');
      await paired();

      laptop.radio.setVfo('vfoA', freq: 14285.0, mode: 'USB');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(phone.radio.vfoA.freq, 3573.0,
          reason: 'a report from elsewhere must never move a rig-owning device\'s VFO');
    });

    test('a DISCONNECTED rig is neither offered nor tunable', () async {
      // Withdrawing the offer is how a dead link is said on the wire.
      // Honoring a request anyway would move only the owner's app state, and
      // the report that fires from that write reaches the controller exactly
      // like a rig confirmation — both screens showing a frequency the
      // physical radio is not on, and contacts logged on the phone carrying
      // it into the log.
      phone.control(laptop);
      laptop.radio.setVfo('vfoA', freq: 14285.0, mode: 'USB');
      await paired();
      await waitFor('the snapshot', () => phone.radio.vfoA.freq == 14285.0);

      laptop.station.setOffered(null);
      await waitFor('the withdrawal to reach the phone', () => phone.remoteRadios.all.isEmpty);

      phone.radio.setVfo('vfoA', freq: 7074.0, mode: 'LSB');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(laptop.radio.vfoA.freq, 14285.0, reason: 'nothing may pretend a dead rig tuned');
    });

    test('picking a radio on a pair that is ALREADY up shows where it is', () async {
      // A `catStatus` is sent when the far rig MOVES, and picking a radio is
      // not the rig moving. Every other test here picks before pairing, so
      // the establish snapshot covers them — this is the ordinary one: the
      // sessions are up, the operator opens the panel and chooses. Without
      // the remembered report, `vfoA` sits on whatever the last local radio
      // left there until somebody physically turns a knob, and QSOs logged
      // in that window carry a frequency nothing is on.
      laptop.radio.setVfo('vfoA', freq: 14285.0, mode: 'USB');
      await paired();
      await waitFor('the offer', () => phone.remoteRadios.all.isNotEmpty);
      expect(phone.radio.vfoA.freq, isNull, reason: 'nothing picked yet');

      phone.control(laptop);
      phone.station.notifyPick();

      await waitFor('the picked radio to show where it is',
          () => phone.radio.vfoA.freq == 14285.0 && phone.radio.vfoA.mode == 'USB');
    });

    test('a peer walking away leaves the pick alone', () async {
      // The offer goes, the SELECTION stays: it is the operator's, and a
      // pick that erased itself on a dropped link would be gone before they
      // looked up — with the panel silently back on a local radio.
      phone.control(laptop);
      await paired();
      await waitFor('the offer', () => phone.remoteRadios.all.isNotEmpty);

      await laptop.service.setEnabled(false);
      await waitFor('the offer to be forgotten', () => phone.remoteRadios.all.isEmpty);

      expect(phone.station.remoteRadio1?.radioId, laptop.radioId);
    });
  });

  group('the picker\'s values and offers', () {
    test('a pick survives the round trip through one dropdown value', () async {
      // The value has to carry enough to rebuild the pick, because a menu's
      // items are captured when it OPENS: the offer a tapped item was built
      // from may be gone by the time it is tapped, and a picker that looked
      // the pick up again would then drop it on the floor while the dropdown
      // had already adopted a value naming no item.
      const pick = PeerRadioSelection(deviceId: 'device-a', radioId: 'rig-1');
      expect(peerRadioSelectionFromValue(peerRadioValue(pick)), pick);
    });

    test('a local node\'s uuid is not a pick', () async {
      // Both halves are uuids and they share one list, so telling them apart
      // is the whole job of the prefix.
      expect(peerRadioSelectionFromValue('9f0c-a-plain-node-uuid'), isNull);
      expect(peerRadioSelectionFromValue(null), isNull);
    });

    test('a value with a half missing names nothing', () async {
      expect(peerRadioSelectionFromValue('peer:device-a'), isNull);
      expect(peerRadioSelectionFromValue('peer:device-a:'), isNull);
      expect(peerRadioSelectionFromValue('peer::rig-1'), isNull);
    });

    test('duplicate radio ids in one offer collapse to one entry', () async {
      // Where a peer's data becomes widget identity: two menu entries sharing
      // a value trip the picker's "exactly one matching item" assertion the
      // moment one of them is the selected one. A sender iterating its own
      // uuid-keyed map cannot produce this, which is exactly why nothing else
      // would catch a sender that is not.
      final radios = PeerRemoteRadios();
      radios.setOffers('device-a', 'Laptop', const [
        PeerRadioOffer(id: 'rig-1', name: 'IC-705'),
        PeerRadioOffer(id: 'rig-1', name: 'IC-705 again'),
      ]);

      expect(radios.all, hasLength(1));
      expect(radios.all.single.radio.name, 'IC-705', reason: 'the first one wins');
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

  group('serial claims (HALO-476)', () {
    const descriptor = SequenceDescriptor(refType: 'cqwpx', field: 'ourSerial', key: 'cqwpx/serial');
    final request = descriptor.requestFor(Qso(uuid: '', operationUuid: 'op-1', data: const {'band': '20m'}));

    test('a number held on one device is skipped on the other — live, then by snapshot', () async {
      await paired();
      expect(await laptop.claims.claim('op-1', request), 1);
      // Whether the laptop's claim has landed yet or crosses the phone's own,
      // the phone ends up on 2 — the two cases are the two halves of §5.8.1.
      expect(await phone.claims.claim('op-1', request), 2);
      await waitFor('the claim to arrive', () => phone.claims.peerClaimsFor('op-1', request.label)['device-a']?.contains(1) ?? false);
      await waitFor('the phone\'s claim to arrive', () => laptop.claims.peerClaimsFor('op-1', request.label)['device-b']?.contains(2) ?? false);

      // The phone drops: its hold stays on the laptop's books (its operator
      // may be mid-contact). It wipes while away and comes back: the
      // establish-time snapshot says so, and the laptop's hold reaches it
      // the same way, with no keystroke to wait for.
      await phone.service.setEnabled(false);
      await waitFor('the pair to drop', () => !(laptop.service.peers['device-b']?.session?.established ?? false));
      expect(laptop.claims.peerClaimsFor('op-1', request.label), {'device-b': {2}}, reason: 'a dropped peer still holds its number');
      phone.claims.release('op-1');
      await phone.service.setEnabled(true);
      await waitFor('the pair to re-establish', () => phone.service.peers['device-a']?.session?.established ?? false);
      await waitFor('the snapshot to arrive', () => phone.claims.peerClaimsFor('op-1', request.label)['device-a']?.contains(1) ?? false);
      await waitFor('the phone\'s empty snapshot to arrive', () => laptop.claims.peerClaimsFor('op-1', request.label).isEmpty);
    });
  });
}
