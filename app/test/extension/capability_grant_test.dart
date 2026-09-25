// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Who a manifest capability reaches. The kernel lets a bundle define
// sub-extensions under its own key, so the host has to answer "whose is this
// key" — and answering by bare prefix gives a grant to anything named right.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_info.dart';

ExtensionInfo info(String key, {bool location = false}) => ExtensionInfo(key: key, file: '$key.js', core: true, name: key, requiresLocation: location);

void main() {
  final grant = CapabilityGrant.among([info('pota', location: true), info('pota-themes'), info('sota')], (info) => info.requiresLocation);

  test('a bundle and the sub-extensions it defines share its grant', () {
    expect(grant.allows('pota'), isTrue);
    expect(grant.allows('pota-all-parks'), isTrue);
    expect(grant.allows('pota_all_parks'), isTrue);
  });

  test('a loaded bundle answers only for itself, whatever its name extends', () {
    expect(grant.allows('pota-themes'), isFalse);
    // And what THAT bundle defines is its own, not `pota`'s: the longest
    // owner wins, or a second hop through the name would get the grant back.
    expect(grant.allows('pota-themes-dark'), isFalse);
  });

  test('nothing else is granted', () {
    expect(grant.allows('sota'), isFalse);
    expect(grant.allows('potato'), isFalse);
    expect(grant.allows('unknown'), isFalse);
    expect(grant.allows(null), isFalse);
    expect(const CapabilityGrant().allows('pota'), isFalse);
  });
}
