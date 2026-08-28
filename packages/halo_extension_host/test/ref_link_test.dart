// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `linkForRef` across the four shapes it takes, through the real bundles: the
// `referenceActivity` factory, a hand-written activity handler, a contest whose
// rules are one page for the whole contest, and one whose rules belong to the
// chosen event.
//
// One host carries every key, because booting one costs ~343ms against a hook
// call's ~1.3ms and none of these hooks touch the host at all — they build a
// string from the reference and nothing else, which is the property that lets
// the operation sheet ask for a link on every refs change.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  Future<ExtensionHost> startHost() => sharedHost(
        ['wca', 'pota', 'sota', 'pga', 'cqww', 'arrl-vhf-tests'],
        onHostCall: nullHostCall,
      );

  Future<Map?> linkFor(String type, String? ref) async {
    final host = await startHost();
    final result = await host.invokeHook('ref:$type',
        method: 'linkForRef', args: {'ref': {'type': type, if (ref != null) 'ref': ref}});
    return result as Map?;
  }

  group('activities', () {
    test('a factory-built program links to the reference page, upper-cased', () async {
      // Lower case in, upper case out: the operator types what they like and
      // the program's own page is keyed by the canonical code.
      final link = await linkFor('wcaActivation', 'on-00558');
      expect(link?['url'], 'https://www.gma.rocks/zinfo.php?ref=ON-00558');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a handler answering for another program does not name its own', () async {
      // WCA registers for `ecaActivation` and `bcaActivation` too and wins
      // dispatch by registration order, so a label built from ITS program name
      // would have a screen reader announce "WCA G-00001" on an English
      // castle. The core names the row instead, which says ECA.
      for (final type in ['ecaActivation', 'bcaActivation']) {
        final link = await linkFor(type, 'G-00001');
        expect(link?['url'], 'https://www.gma.rocks/zinfo.php?ref=G-00001', reason: 'via $type');
        expect(link?['label'], isNull, reason: 'via $type');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a reference the program would not accept gets no link', () async {
      // The trap: a half-typed code still has a `ref` on it while the operator
      // is editing, and a link built from one lands on a page that cannot
      // exist. Four digits is one short of a WCA reference.
      expect(await linkFor('wcaActivation', 'ON-0055'), isNull);
      expect(await linkFor('wcaActivation', ''), isNull);
      expect(await linkFor('wcaActivation', null), isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a program with no page per reference offers no link at all', () async {
      // PGA publishes a gmina list and nothing addressable per gmina. Silence
      // is the answer, not a link into a search form — the row shows no icon.
      expect(await linkFor('pgaActivation', 'AB12'), isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('POTA and SOTA link to their own directories', () async {
      expect((await linkFor('potaActivation', 'us-0370'))?['url'], 'https://pota.app/#/park/US-0370');
      // The summit path carries the association and region as path segments,
      // so SOTA's slash goes through unescaped — percent-encoding it here
      // would 404 on a page that exists.
      expect(
        (await linkFor('sotaActivation', 've6/hc-255'))?['url'],
        'https://www.sotadata.org.uk/en/summit/VE6/HC-255',
      );
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a hunted reference links the same way an activated one does', () async {
      // Both types register the same handler; a hunter reading about the park
      // they just worked wants the same page the activator sees.
      expect((await linkFor('pota', 'US-0370'))?['url'], 'https://pota.app/#/park/US-0370');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('contests', () {
    test('a contest links to its rules, configured or not', () async {
      // A contest ref names an event rather than a place, so what there is to
      // read about it is the rules — and they are worth reading BEFORE the
      // exchange has been filled in, which is when the ref carries no value.
      expect((await linkFor('cqww', 'CQWW'))?['url'], 'https://www.cqww.com/rules.htm');
      expect((await linkFor('cqww', null))?['url'], 'https://www.cqww.com/rules.htm');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a contest family links to the chosen event\'s own rules', () async {
      // ARRL's VHF events do not share one rules document: January runs under
      // the VHF rules and the 10 GHz contest under its own.
      expect(
        (await linkFor('arrl-vhf-tests', 'ARRL-VHF-JAN'))?['url'],
        'https://contests.arrl.org/ContestRules/JanJunSep-VHF-Rules.pdf',
      );
      expect(
        (await linkFor('arrl-vhf-tests', 'ARRL-10G-AUG'))?['url'],
        'https://contests.arrl.org/ContestRules/10-GHz-Rules.pdf',
      );
      // No event picked yet: there is no one document to send them to.
      expect(await linkFor('arrl-vhf-tests', null), isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
