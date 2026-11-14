// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which running extension a ref type belongs to decides whether it is marked
// a contest's, in the app and in halo-ext alike.

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

typedef _Extension = ({String key, List<String> hooks});

void main() {
  String? owner(List<_Extension> running, Object? type) => refTypeOwner(running, (e) => e.hooks, type)?.key;

  // A state-park contest declares `ref:stateparks/GA` and answers the
  // `stateparks` type for its own codes: the type alone must find it.
  test('a ref type belongs to the extension declaring it, or one of its own types under it', () {
    const running = <_Extension>[
      (key: 'pota', hooks: ['ref:potaActivation']),
      (key: 'gaspota', hooks: ['activity', 'ref:stateparks/GA']),
    ];
    expect(owner(running, 'potaActivation'), 'pota');
    expect(owner(running, 'stateparks'), 'gaspota');
    expect(owner(running, 'states'), isNull, reason: 'a prefix of a type is not the type');
    expect(owner(running, null), isNull);
  });

  // Two extensions may declare one type; the app asks the first, so the mark
  // must come from the same one.
  test('of two extensions declaring a type, the first running one owns it', () {
    const running = <_Extension>[
      (key: 'first', hooks: ['ref:cqww']),
      (key: 'second', hooks: ['ref:cqww']),
    ];
    expect(owner(running, 'cqww'), 'first');
  });
}
