// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The batched ref-hook calls: a list of references crosses the bridge once,
// and each reference still gets its own answer.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

import '../support/halo_test_support.dart';

/// `pota` decorates and links whatever code it is asked about; `sota`'s
/// program is down.
FakeExtensionHost _host() => FakeExtensionHost({
  'ref:pota:null:decorateRef': (Object? args) => {...((args! as Map)['ref'] as Map), 'name': 'Park ${((args as Map)['ref'] as Map)['ref']}'},
  'ref:sota:null:decorateRef': ExtensionHostException('SOTA is down'),
  'ref:pota:null:linkForRef': (Object? args) => {'url': 'https://pota.app/#/park/${((args! as Map)['ref'] as Map)['ref']}'},
  'ref:sota:null:linkForRef': ExtensionHostException('SOTA is down'),
  'ref:pota:null:geojsonUrlForRef': null,
  'ref:sota:null:geojsonUrlForRef': ExtensionHostException('SOTA is down'),
  'ref:pota:null:suggestOperationTitle': (Object? args) => {'at': ((args! as Map)['ref'] as Map)['ref']},
});

void main() {
  test('every reference crosses in ONE batch, and comes back in order', () async {
    // A loop awaiting one crossing per reference waits out every program's
    // latency in turn — a fifty-park import behind fifty budgets.
    final host = _host();
    final extensions = ExtensionServiceWithFakeHost(host);

    final decorated = await extensions.decorateRefs([
      for (var i = 0; i < 50; i++) {'type': 'pota', 'ref': 'US-$i'},
    ]);

    expect(host.batches, hasLength(1));
    expect(host.batches.single, hasLength(50));
    expect([for (final ref in decorated) ref['name']], [for (var i = 0; i < 50; i++) 'Park US-$i']);
  });

  test('a program that fails costs its own reference the answer, and no other', () async {
    final extensions = ExtensionServiceWithFakeHost(_host());
    final summit = {'type': 'sota', 'ref': 'W2/GC-116'};

    final decorated = await extensions.decorateRefs([
      summit,
      {'type': 'pota', 'ref': 'US-1'},
    ]);
    expect(decorated[0], same(summit), reason: 'an undecorated reference comes back as it went in, not dropped');
    expect(decorated[1]['name'], 'Park US-1');

    final links = await extensions.linkForRefs([
      summit,
      {'type': 'pota', 'ref': 'US-1'},
    ]);
    expect(links[0], isNull);
    expect(links[1]?.url, 'https://pota.app/#/park/US-1');
  });

  test('a reference with no type is not asked about, and keeps its place', () async {
    final host = _host();
    final extensions = ExtensionServiceWithFakeHost(host);
    final untyped = {'ref': 'US-1'};

    final decorated = await extensions.decorateRefs([
      untyped,
      {'type': 'pota', 'ref': 'US-2'},
    ]);

    expect(host.batches.single, hasLength(1), reason: 'no handler can answer for a reference with no type');
    expect(decorated[0], same(untyped));
    expect(decorated[1]['name'], 'Park US-2');
  });

  test('a malformed reference costs its own answer, never the rest of the list', () async {
    // One list crosses as one batch, so a reference that cannot even be routed
    // must fail alone rather than throw for every reference beside it.
    final extensions = ExtensionServiceWithFakeHost(_host());
    final malformed = {'type': 42, 'ref': 'US-1'};

    final decorated = await extensions.decorateRefs([
      malformed,
      {'type': 'pota', 'ref': 'US-2'},
    ]);

    expect(decorated[0], same(malformed));
    expect(decorated[1]['name'], 'Park US-2');
  });

  test('an outline source says whether its program answered at all', () async {
    // "No outline" is remembered by the map; "could not ask" is asked again.
    // A failed program must not read as a program with nothing to show.
    final extensions = ExtensionServiceWithFakeHost(_host());

    final answers = await extensions.geojsonUrlsForRefs([
      {'type': 'pota', 'ref': 'US-1'},
      {'type': 'sota', 'ref': 'W2/GC-116'},
      {'ref': 'untyped'},
      {'type': 'wwff', 'ref': 'KFF-0001'},
    ]);

    // `wwff` has no handler at all: that is "no outline", settled, like a
    // program that answered with none — asking again would never change it.
    expect([for (final a in answers) (a.source, a.answered)], [(null, true), (null, false), (null, true), (null, true)]);
    expect(
      (await ExtensionService().geojsonUrlsForRefs([
        {'type': 'pota', 'ref': 'US-1'},
      ])).single.answered,
      false,
      reason: 'no runtime has not answered',
    );
  });

  test('the single-reference decoration takes the same path', () async {
    final host = _host();
    final extensions = ExtensionServiceWithFakeHost(host);

    expect((await extensions.decorateRef({'type': 'pota', 'ref': 'US-3'}))['name'], 'Park US-3');
    expect(host.batches, hasLength(1));
  });

  test('with no runtime, every reference comes back as it went in', () async {
    final refs = [
      {'type': 'pota', 'ref': 'US-1'},
    ];
    expect(await ExtensionService().decorateRefs(refs), [same(refs.single)]);
    expect(await ExtensionService().linkForRefs(refs), [isNull]);
  });
}
