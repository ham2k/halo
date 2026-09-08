// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two forms a manifest's `hooks` list uses to claim a reference, and the
// rewrite the qualified one exists for (HALO-559). A per-event QSO party
// publishes `nyqp` and answers for the legacy `{type: 'qp', ref: 'NY'}` every
// operation logged before the split still carries — so `ref:qp/ny` has to
// mean something the plain form cannot, and has to CHANGE the reference,
// because an offer that leaves the red row red is the failure the whole
// mechanism is here to avoid.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extension_info.dart';

/// The shape a per-event party ships: its own type, plus the legacy pair.
const _nyqpHooks = ['activity', 'scoring', 'ref:nyqp', 'ref:qp/ny'];

void main() {
  group('refClaimOf', () {
    test('tells the two forms apart, and folds the code', () {
      expect(refClaimOf('ref:nyqp'), (type: 'nyqp', code: null));
      expect(refClaimOf('ref:qp/NY'), (type: 'qp', code: 'ny'));
    });

    test('a non-ref category, and a malformed entry, claim nothing', () {
      expect(refClaimOf('activity'), isNull);
      expect(refClaimOf('ref:'), isNull);
      // Half an entry is not a claim: `ref:/ny` names no type and `ref:qp/`
      // no code, and reading either as the plain form would silently widen
      // the claim to every reference of that type.
      expect(refClaimOf('ref:/ny'), isNull);
      expect(refClaimOf('ref:qp/'), isNull);
    });
  });

  group('hooksClaimRef', () {
    test('a plain claim answers for every code of its type', () {
      expect(hooksClaimRef(_nyqpHooks, type: 'nyqp'), isTrue);
      expect(hooksClaimRef(_nyqpHooks, type: 'nyqp', code: 'anything'), isTrue);
    });

    test('a qualified claim answers only for the code it names', () {
      expect(hooksClaimRef(_nyqpHooks, type: 'qp', code: 'NY'), isTrue);
      expect(hooksClaimRef(_nyqpHooks, type: 'qp', code: 'ny'), isTrue);
      // The trap: fifty parties all declare `ref:qp/<their own>`, so a
      // qualified claim read as a plain one would make every one of them
      // answer for every other one's references.
      expect(hooksClaimRef(_nyqpHooks, type: 'qp', code: 'TX'), isFalse);
      expect(hooksClaimRef(_nyqpHooks, type: 'qp'), isFalse);
    });
  });

  group('refMigrationTargetOf', () {
    test('the one type the extension publishes is what a legacy ref becomes', () {
      expect(refMigrationTargetOf(_nyqpHooks), 'nyqp');
    });

    test('no target where a rewrite would have to guess', () {
      // Two plain entries leave the rewrite choosing between them, and none
      // leaves it nowhere to go. The build refuses both alongside a qualified
      // claim; here they simply do not migrate, since a bundle from a catalog
      // that never ran that check can still reach the app.
      expect(refMigrationTargetOf(const ['ref:pota', 'ref:potaActivation', 'ref:qp/ny']), isNull);
      expect(refMigrationTargetOf(const ['activity', 'ref:qp/ny']), isNull);
    });
  });

  group('refsMigratedBy', () {
    test('the legacy pair becomes the published type, and the setup survives', () {
      final migrated = refsMigratedBy(
        [
          {'type': 'qp', 'ref': 'NY', 'name': 'New York QSO Party', 'exchange': '59 NY', 'class': 'QRP'},
        ],
        _nyqpHooks,
      );
      // The code is gone because the type carries its meaning now; the
      // operator's own contest setup is not the migration's to throw away.
      expect(migrated, [
        {'type': 'nyqp', 'name': 'New York QSO Party', 'exchange': '59 NY', 'class': 'QRP'},
      ]);
    });

    test('another party\'s reference is left alone', () {
      expect(
        refsMigratedBy([
          {'type': 'qp', 'ref': 'TX'},
        ], _nyqpHooks),
        isNull,
      );
    });

    test('nothing to do answers null, so nothing is saved', () {
      // A save is a write to the operation and a rebuild of the sheet; one
      // per controls reload, changing nothing, is worse than none.
      expect(
        refsMigratedBy([
          {'type': 'nyqp'},
          {'type': 'pota', 'ref': 'US-0001'},
        ], _nyqpHooks),
        isNull,
      );
      expect(refsMigratedBy(const [], _nyqpHooks), isNull);
    });

    test('a reference of the target type is never duplicated — the legacy row goes', () {
      // The umbrella extension may still be installed, so an operation can
      // carry both the legacy pair and a reference already configured under
      // the new extension. They are the same activity; two of them would
      // score and export twice, and only the first is reachable from the
      // setup form.
      expect(
        refsMigratedBy([
          {'type': 'nyqp', 'exchange': '59 ONO'},
          {'type': 'qp', 'ref': 'NY', 'exchange': 'stale'},
        ], _nyqpHooks),
        [
          {'type': 'nyqp', 'exchange': '59 ONO'},
        ],
      );
    });

    test('a code that is not a string neither matches nor throws', () {
      // Refs are JSON written by extensions and by app-polo; a bare cast here
      // would take down the sheet that called it rather than skip one row.
      expect(
        refsMigratedBy([
          {'type': 'qp', 'ref': 42},
        ], _nyqpHooks),
        isNull,
      );
    });

    test('an extension claiming nothing qualified never rewrites', () {
      expect(
        refsMigratedBy([
          {'type': 'qp', 'ref': 'NY'},
        ], const ['activity', 'ref:nyqp']),
        isNull,
      );
    });
  });
}
