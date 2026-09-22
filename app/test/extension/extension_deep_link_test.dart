// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `com.ham2k:///install_extension?url=…` (HALO-422).
//
// The parser is the whole security boundary of the link: nothing is fetched
// until it returns non-null, so what it refuses is never downloaded at all.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/deep_link_service.dart';

void main() {
  Uri? parse(String raw) => DeepLinkService.installExtensionRequest(Uri.parse(raw));

  test('accepts an https bundle url, in either authority form', () {
    // Both forms, for the same reason link_client accepts both: a link that
    // silently does nothing is indistinguishable from a broken one to
    // whoever clicked it.
    expect(parse('com.ham2k:///install_extension?url=https://example.org/a.h2kext')?.host, 'example.org');
    expect(parse('com.ham2k://install_extension?url=https://example.org/a.h2kext')?.host, 'example.org');
    expect(parse('com.ham2k.logger:///install_extension?url=https://example.org/a.h2kext')?.host, 'example.org');
  });

  test('refuses anything but https', () {
    // A bundle is code the app will run. Fetched over a connection anyone on
    // the path can rewrite, the consent screen would be describing whatever
    // they substituted.
    for (final scheme in ['http', 'ftp', 'file']) {
      expect(parse('com.ham2k:///install_extension?url=$scheme://example.org/a.h2kext'), isNull, reason: 'expected $scheme to be refused');
    }
  });

  test('refuses a url with no host, and a missing or empty one', () {
    expect(parse('com.ham2k:///install_extension?url=https:///a.h2kext'), isNull);
    expect(parse('com.ham2k:///install_extension'), isNull);
    expect(parse('com.ham2k:///install_extension?url='), isNull);
    expect(parse('com.ham2k:///install_extension?url=not%20a%20url'), isNull);
  });

  test('the catalog\'s install links resolve under every edition\'s scheme', () {
    // The catalog site writes `com.ham2k.logger[.<edition>]:///install_extension`
    // so the link reaches the one app it names (HALO-526). The URL is the
    // catalog's own bundle path, which deep_link_router.dart then routes through the
    // hash-verified download rather than the plain one.
    const bundle = 'https://catalog.ham2k.net/api/v1/extensions/k2hrc-llota/versions/1.2.0/bundle';
    for (final scheme in ['com.ham2k.logger', 'com.ham2k.logger.next', 'com.ham2k.logger.dev']) {
      final target = parse('$scheme:///install_extension?url=${Uri.encodeComponent(bundle)}');
      expect(target?.host, 'catalog.ham2k.net', reason: scheme);
      expect(target?.path, '/api/v1/extensions/k2hrc-llota/versions/1.2.0/bundle', reason: scheme);
    }
  });

  test('ignores links that are not this one', () {
    expect(parse('com.ham2k:///link_client?id=a&token=b'), isNull);
    expect(parse('https://example.org/install_extension?url=https://example.org/a.h2kext'), isNull, reason: 'only the app\'s own schemes are ours to act on');
  });
}
