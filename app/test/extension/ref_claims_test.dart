// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two forms a manifest's `hooks` list uses to claim a reference, and the
// ranking between them (HALO-559). A per-event QSO party publishes its own
// type and answers for the legacy `{type: 'qp', ref: 'NY'}` every operation
// logged before the split still carries. Nothing is rewritten — the operation
// stays as the operator logged it — so `ref:qp/ny` has to be a claim the
// matcher can act on, and has to beat a claim on the bare family.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_info.dart';

/// The shape a per-event party ships: its own type, plus the legacy family
/// qualified by the code that party used to be filed under.
const _nyqpHooks = ['activity', 'scoring', 'ref:ny-qso-party', 'ref:qp/ny'];

/// The bundled extension the split replaced: every party under one type.
const _bundledQpHooks = ['activity', 'scoring', 'ref:qp'];

ExtensionInfo _info(String key, List<String> hooks) => ExtensionInfo(key: key, file: 'index.js', core: false, name: key, hooks: hooks);

void main() {
  group('refClaimOf', () {
    test('tells the two forms apart, and folds the prefix', () {
      expect(refClaimOf('ref:ny-qso-party'), (type: 'ny-qso-party', code: null));
      expect(refClaimOf('ref:qp/NY'), (type: 'qp', code: 'ny'));
    });

    test('a non-ref category, and a malformed entry, claim nothing', () {
      expect(refClaimOf('activity'), isNull);
      expect(refClaimOf('ref:'), isNull);
      // Half an entry is not a claim: `ref:/ny` names no type and `ref:qp/`
      // no prefix, and reading either as the plain form would silently widen
      // the claim to every reference of that type.
      expect(refClaimOf('ref:/ny'), isNull);
      expect(refClaimOf('ref:qp/'), isNull);
    });
  });

  group('refClaimStrength', () {
    test('a plain claim answers for every code of its type, at strength zero', () {
      expect(refClaimStrength(_nyqpHooks, type: 'ny-qso-party'), 0);
      expect(refClaimStrength(_nyqpHooks, type: 'ny-qso-party', code: 'anything'), 0);
      expect(refClaimStrength(_bundledQpHooks, type: 'qp', code: 'TX'), 0);
    });

    test('a qualified claim answers for the codes under its prefix, at its length', () {
      expect(refClaimStrength(_nyqpHooks, type: 'qp', code: 'NY'), 2);
      expect(refClaimStrength(_nyqpHooks, type: 'qp', code: 'ny'), 2);
      // A prefix, not an equality: the codes under one type are a family, and
      // a claim on a type nobody owns any more has to cover what an operator
      // qualified further under it.
      expect(refClaimStrength(_nyqpHooks, type: 'qp', code: 'NY-ALB'), 2);
    });

    test('a qualified claim answers for nothing else', () {
      // The trap: fifty parties all declare `ref:qp/<their own>`, so a
      // qualified claim read as a plain one would make every one of them
      // answer for every other one's references.
      expect(refClaimStrength(_nyqpHooks, type: 'qp', code: 'TX'), isNull);
      // And a reference with no code at all matches no prefix — there is
      // nothing for one to begin with.
      expect(refClaimStrength(_nyqpHooks, type: 'qp'), isNull);
      expect(refClaimStrength(_nyqpHooks, type: 'txqp', code: 'TX'), isNull);
    });

    test('the strongest of several claims on one type is the one reported', () {
      // An extension may narrow its own family. What it claims for `NY` is
      // the precise entry, not the broad one it also declares.
      const both = ['ref:qp', 'ref:qp/ny'];
      expect(refClaimStrength(both, type: 'qp', code: 'NY'), 2);
      expect(refClaimStrength(both, type: 'qp', code: 'TX'), 0);
    });

    test('hooksClaimRef is the same question without the ranking', () {
      expect(hooksClaimRef(_nyqpHooks, type: 'qp', code: 'NY'), isTrue);
      expect(hooksClaimRef(_nyqpHooks, type: 'qp', code: 'TX'), isFalse);
    });
  });

  group('extensionsDeclaringRefs', () {
    test('the longest prefix leads, so the party beats the family', () {
      // The whole point of the ranking. Both answer for `{type: 'qp',
      // ref: 'NY'}` — the bundled extension because it owns every party, the
      // New York one because it named this reference. Offered in that order,
      // the operator installs fifty parties to get one.
      final ranked = extensionsDeclaringRefs([_info('qp', _bundledQpHooks), _info('ham2k-nyqp', _nyqpHooks)], [(type: 'qp', code: 'NY')]);
      expect(ranked.map((i) => i.key), ['ham2k-nyqp', 'qp']);
    });

    test('a party that did not name this reference is not offered for it', () {
      const txqpHooks = ['activity', 'ref:txqp', 'ref:qp/tx'];
      final ranked = extensionsDeclaringRefs([_info('ham2k-txqp', txqpHooks), _info('ham2k-nyqp', _nyqpHooks)], [(type: 'qp', code: 'NY')]);
      expect(ranked.map((i) => i.key), ['ham2k-nyqp']);
    });

    test('an extension is offered once, ranked by its best claim', () {
      // Two unhandled references, one extension answering both — precisely
      // for one, broadly for the other. Ranked by the broad claim it would
      // sit under a party that answers nothing as well.
      final ranked = extensionsDeclaringRefs([_info('ham2k-nyqp', _nyqpHooks)], [(type: 'ny-qso-party', code: null), (type: 'qp', code: 'NY')]);
      expect(ranked.map((i) => i.key), ['ham2k-nyqp']);
    });

    test('nothing claimed, nothing offered', () {
      expect(extensionsDeclaringRefs([_info('ham2k-nyqp', _nyqpHooks)], const []), isEmpty);
      expect(extensionsDeclaringRefs([_info('ham2k-nyqp', _nyqpHooks)], [(type: 'pota', code: 'US-0001')]), isEmpty);
    });
  });
}
