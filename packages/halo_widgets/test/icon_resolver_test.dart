// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  group('resolveIconName', () {
    test('resolves a bare name against Material Design Icons', () {
      expect(resolveIconName('pine-tree'), MdiIcons.pineTree);
    });

    test('resolves an fa- prefixed name against FontAwesome6 solid', () {
      final icon = resolveIconName('fa-tree');
      expect(icon.fontFamily, 'FontAwesome6Solid');
      expect(icon.codePoint, 61883);
    });

    test('falls back to a placeholder for an unknown MDI name', () {
      expect(resolveIconName('not-a-real-icon'), MdiIcons.puzzle);
    });

    test('falls back to a placeholder for an unknown FontAwesome name', () {
      expect(resolveIconName('fa-not-a-real-icon'), MdiIcons.puzzle);
    });

    test('falls back to a placeholder for null or empty input', () {
      expect(resolveIconName(null), MdiIcons.puzzle);
      expect(resolveIconName(''), MdiIcons.puzzle);
    });
  });
}
