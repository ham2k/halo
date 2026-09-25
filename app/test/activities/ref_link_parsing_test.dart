// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the app accepts from a `linkForRef` hook. Every rejection here is
// invisible from the row — a refused link and a program with no page both draw
// no button — so nothing downstream can catch a guard that gets deleted.
//
// The URL check is the load-bearing one: the row draws its button BECAUSE a
// link came back, so a URL `openExternalUrl` would refuse must not become one.
// Left to the tap, it is a live-looking control that does nothing, forever,
// with a debugPrint as the only record.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

void main() {
  RefLink? parse(dynamic result) => refLinkFromHookResult(result, type: 'potaActivation');

  test('a url and a label come through', () {
    final link = parse({'url': 'https://pota.app/#/park/US-0370', 'label': 'POTA US-0370'});
    expect(link?.url, 'https://pota.app/#/park/US-0370');
    expect(link?.label, 'POTA US-0370');
  });

  test('no label is null, not an empty string the UI would announce', () {
    expect(parse({'url': 'https://pota.app/'})?.label, isNull);
    expect(parse({'url': 'https://pota.app/', 'label': ''})?.label, isNull);
    expect(parse({'url': 'https://pota.app/', 'label': 7})?.label, isNull);
  });

  test('a ref type with no link of its own answers null, which is not an error', () {
    expect(parse(null), isNull);
  });

  test('a hook answering with the wrong shape is refused', () {
    expect(parse('https://pota.app/'), isNull);
    expect(parse(['https://pota.app/']), isNull);
    expect(parse(const {}), isNull);
  });

  test('a url that is missing, empty or not a string is refused', () {
    expect(parse(const {'label': 'POTA US-0370'}), isNull);
    expect(parse(const {'url': ''}), isNull);
    expect(parse(const {'url': 42}), isNull);
  });

  test('a url the app would not open never becomes a button', () {
    // The scheme-less case is the realistic one: an extension's URL is built
    // by one line of config, so dropping `https://` costs every reference of
    // that program its link — and, without this, gives each one a dead button
    // instead of no button.
    expect(parse(const {'url': 'www.pota.app/#/park/US-0370'}), isNull);
    expect(parse(const {'url': 'javascript:alert(1)'}), isNull);
    expect(parse(const {'url': 'file:///etc/passwd'}), isNull);
  });
}
