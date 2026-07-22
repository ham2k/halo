// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/web_preview_label_parser.dart';

void main() {
  group('previewLabelForHost', () {
    test('a named preview alias yields its name as the DEV_LABEL (both hosts)', () {
      // Cloudflare Pages default domain (dot separator).
      expect(previewLabelForHost('193-password.halo-dev-ham2k-net.pages.dev'), '193-password');
      expect(previewLabelForHost('my-feature.halo-dev-ham2k-net.pages.dev'), 'my-feature');
      // Custom domain (hyphen separator).
      expect(previewLabelForHost('193-password-halo-dev.ham2k.net'), '193-password');
      expect(previewLabelForHost('my-feature-halo-dev.ham2k.net'), 'my-feature');
    });

    test('the production (bare) deployment hosts are not previews', () {
      // Production has no name before the separator, so it must NOT be
      // mistaken for a preview and labelled.
      expect(previewLabelForHost('halo-dev-ham2k-net.pages.dev'), '');
      expect(previewLabelForHost('halo-dev.ham2k.net'), '');
    });

    test('localhost, real domains, and empty are not previews', () {
      expect(previewLabelForHost('localhost'), '');
      expect(previewLabelForHost('app.ham2k.com'), '');
      expect(previewLabelForHost(''), '');
    });

    test('a nested/unexpected host does not guess a label', () {
      expect(previewLabelForHost('a.b.halo-dev-ham2k-net.pages.dev'), '');
      expect(previewLabelForHost('a.b-halo-dev.ham2k.net'), '');
    });
  });
}
