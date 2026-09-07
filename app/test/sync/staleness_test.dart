// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/staleness.dart';

void main() {
  group('isBelowCodePushFloor', () {
    test('an unreadable code-push number is silent, NOT treated as zero', () {
      // The decision this whole signature exists for. `?? 0` would nag an
      // operator who is already on push 3 but whose read failed — and no
      // action available to them would make it stop, because there is nothing
      // left to install. Silence costs one missed nag; the read retries free
      // on the next launch.
      expect(
        isBelowCodePushFloor(updaterAvailable: true, resolved: false, codePush: null, floor: 3),
        isFalse,
      );
    });

    test('a RESOLVED absence of any code push is below a floor', () {
      // The target case: a fresh store download, zero pushes applied, floor 3.
      // Distinguished from the case above only by `resolved`.
      expect(
        isBelowCodePushFloor(updaterAvailable: true, resolved: true, codePush: null, floor: 3),
        isTrue,
      );
    });

    test('no updater means no code-push plane, so no floor can apply', () {
      // Web, debug and every local `flutter build`. Without this the nag could
      // fire on a developer's own machine, where no push can ever be installed.
      expect(
        isBelowCodePushFloor(updaterAvailable: false, resolved: true, codePush: null, floor: 3),
        isFalse,
      );
    });

    test('no declared floor is silent, whatever the install is running', () {
      // Declaring a floor is always an explicit act — absence must never be
      // read as "floor 1" or every install without a push would nag.
      expect(
        isBelowCodePushFloor(updaterAvailable: true, resolved: true, codePush: null, floor: null),
        isFalse,
      );
    });

    test('at or above the floor is satisfied; below it is not', () {
      bool below(int? push, int floor) =>
          isBelowCodePushFloor(updaterAvailable: true, resolved: true, codePush: push, floor: floor);
      expect(below(2, 3), isTrue);
      expect(below(3, 3), isFalse, reason: 'the floor is a minimum, not a threshold to exceed');
      expect(below(4, 3), isFalse);
    });
  });

  group('isReleaseWorthAnnouncing', () {
    test('a newer release announces; the same or older does not', () {
      expect(isReleaseWorthAnnouncing(currentVersion: '26.8.1', latest: '26.9.0', dismissed: null), isTrue);
      expect(isReleaseWorthAnnouncing(currentVersion: '26.9.0', latest: '26.9.0', dismissed: null), isFalse);
      expect(isReleaseWorthAnnouncing(currentVersion: '26.9.0', latest: '26.8.1', dismissed: null), isFalse);
    });

    test('the dismissal mark is a high-water mark, not a mute', () {
      // Dismissing 26.9.0 silences 26.9.0 forever but must NOT silence 26.9.1:
      // a mute would hide every future release behind one impatient tap.
      expect(isReleaseWorthAnnouncing(currentVersion: '26.8.1', latest: '26.9.0', dismissed: '26.9.0'), isFalse);
      expect(isReleaseWorthAnnouncing(currentVersion: '26.8.1', latest: '26.9.1', dismissed: '26.9.0'), isTrue);
    });

    test('an absent or empty latestRelease flag announces nothing', () {
      // Fails open: a flags fetch that timed out leaves this null, and the
      // right answer to "we could not ask" is silence.
      expect(isReleaseWorthAnnouncing(currentVersion: '26.8.1', latest: null, dismissed: null), isFalse);
      expect(isReleaseWorthAnnouncing(currentVersion: '26.8.1', latest: '', dismissed: null), isFalse);
    });
  });

  group('rankStaleness', () {
    test('returns exactly ONE signal even when all three are true', () {
      // The point of unifying: three mechanisms could each fire on one launch,
      // stacking two dialogs and a notice. Only the most severe is returned.
      expect(
        rankStaleness(belowCodePushFloor: true, buildExpired: true, releaseWorthAnnouncing: true),
        StalenessSignal.codePushFloor,
      );
    });

    test('the code-push floor outranks both binary signals', () {
      // Its remedy is a restart, not a download. Sending someone to fetch a
      // binary when the fix is already on the device is worse advice.
      expect(
        rankStaleness(belowCodePushFloor: true, buildExpired: true, releaseWorthAnnouncing: false),
        StalenessSignal.codePushFloor,
      );
    });

    test('an expired build outranks a merely newer release', () {
      expect(
        rankStaleness(belowCodePushFloor: false, buildExpired: true, releaseWorthAnnouncing: true),
        StalenessSignal.expiredBuild,
      );
    });

    test('nothing wrong yields no verdict', () {
      expect(
        rankStaleness(belowCodePushFloor: false, buildExpired: false, releaseWorthAnnouncing: false),
        isNull,
      );
    });

    test('the enum declaration order IS the ranking', () {
      // rankStaleness is a chain of ifs; this pins the contract the chain is
      // meant to implement, so reordering the enum without reordering the
      // chain (or vice versa) fails here rather than in the field.
      expect(StalenessSignal.values, [
        StalenessSignal.codePushFloor,
        StalenessSignal.expiredBuild,
        StalenessSignal.newerRelease,
      ]);
    });
  });

  group('tiers', () {
    test('both binary-download signals differ in tier, and that is deliberate', () {
      // Expiration interrupts (it already ships as a dialog); a newer release
      // being available is not worth interrupting a contact for.
      expect(StalenessSignal.expiredBuild.tier, StalenessTier.nag);
      expect(StalenessSignal.newerRelease.tier, StalenessTier.notice);
    });

    test('the code-push floor nags — it is the one with a same-device remedy', () {
      expect(StalenessSignal.codePushFloor.tier, StalenessTier.nag);
    });
  });

  group('mayPresentAgain', () {
    final t0 = DateTime.utc(2026, 9, 1, 12);

    test('a never-dismissed verdict is always showable', () {
      expect(mayPresentAgain(dismissedAt: null, now: t0), isTrue);
    });

    test('stays quiet for the full period, then returns', () {
      expect(mayPresentAgain(dismissedAt: t0, now: t0.add(const Duration(hours: 5, minutes: 59))), isFalse);
      expect(mayPresentAgain(dismissedAt: t0, now: t0.add(const Duration(hours: 6))), isTrue);
    });

    test('a clock that jumps backwards keeps it quiet rather than re-nagging', () {
      // Wall-clock, so a timezone change or an NTP correction can move `now`
      // backwards. The safe direction is silence: worst case the user waits.
      expect(mayPresentAgain(dismissedAt: t0, now: t0.subtract(const Duration(hours: 2))), isFalse);
    });

    test('sleeping through the period counts — the gap is wall-clock, not uptime', () {
      // A laptop closed overnight advances the clock without running a Timer.
      // Anything Timer-based would still be waiting here.
      expect(mayPresentAgain(dismissedAt: t0, now: t0.add(const Duration(days: 1))), isTrue);
    });
  });

  group('codePushFloorFor', () {
    test('reads the floor for THIS build only', () {
      // Keyed by build because Shorebird restarts its counter at 1 per
      // release: after a rebuild, two live binaries carry independent
      // counters, so build 130's floor must not reach build 131.
      const flag = {'131': 3, '130': 2};
      expect(codePushFloorFor(flag, 131), 3);
      expect(codePushFloorFor(flag, 130), 2);
      expect(codePushFloorFor(flag, 129), isNull);
    });

    test('a malformed flag yields no floor rather than throwing', () {
      // Hand-edited JSON on a server, parsed on the boot path of a field
      // logging app. Failing open means no nag; failing closed would mean one
      // bad edit nagging every install at once.
      expect(codePushFloorFor(null, 131), isNull);
      expect(codePushFloorFor('nonsense', 131), isNull);
      expect(codePushFloorFor({'131': 'abc'}, 131), isNull);
      expect(codePushFloorFor({'131': null}, 131), isNull);
    });

    test('accepts a JSON number or a quoted number, since both get hand-typed', () {
      expect(codePushFloorFor({'131': 3}, 131), 3);
      expect(codePushFloorFor({'131': '3'}, 131), 3);
      expect(codePushFloorFor({'131': 3.0}, 131), 3);
    });
  });
}
