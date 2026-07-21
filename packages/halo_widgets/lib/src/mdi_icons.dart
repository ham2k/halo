// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A hand-picked subset of Pictogrammers' Material Design Icons — the same
// icon set app-polo uses (react-native-paper's Icon renders MDI glyph names
// like 'clock-outline', 'radio', 'pine-tree' directly) — covering just the
// glyphs this app actually references. Not the `material_design_icons_flutter`
// pub package: as of Flutter 3.44, `IconData` became a `final class`, and
// that package's generated icon constants subclass it
// (`class _MdiIconData extends IconData`), so it fails to compile here.
// Constructing `IconData` directly (no subclassing) sidesteps the break, so
// this is a plain codepoint lookup against the bundled font
// (app/assets/fonts/MaterialDesignIcons.ttf, family 'MaterialDesignIcons')
// rather than a dependency — codepoints taken from that pub package's own
// icon_map.dart, which stays a valid source of codepoint data even though
// its Dart wrapper doesn't compile.

import 'package:flutter/widgets.dart';

class MdiIcons {
  MdiIcons._();

  static const IconData clock = IconData(0xf0954, fontFamily: 'MaterialDesignIcons');
  static const IconData clockOutline = IconData(0xf0150, fontFamily: 'MaterialDesignIcons');
  static const IconData radio = IconData(0xf0439, fontFamily: 'MaterialDesignIcons');
  static const IconData pineTree = IconData(0xf0405, fontFamily: 'MaterialDesignIcons');
  static const IconData puzzle = IconData(0xf0431, fontFamily: 'MaterialDesignIcons');
  static const IconData fileExport = IconData(0xf021d, fontFamily: 'MaterialDesignIcons');
  static const IconData plus = IconData(0xf0415, fontFamily: 'MaterialDesignIcons');
  static const IconData accountSearch = IconData(0xf0016, fontFamily: 'MaterialDesignIcons');
  static const IconData radioTower = IconData(0xf043b, fontFamily: 'MaterialDesignIcons');
  static const IconData bookOutline = IconData(0xf0b64, fontFamily: 'MaterialDesignIcons');
  static const IconData delete = IconData(0xf01b4, fontFamily: 'MaterialDesignIcons');
  static const IconData cog = IconData(0xf0493, fontFamily: 'MaterialDesignIcons');
  static const IconData keyChain = IconData(0xf1574, fontFamily: 'MaterialDesignIcons');
  static const IconData themeLightDark = IconData(0xf050e, fontFamily: 'MaterialDesignIcons');
  static const IconData whiteBalanceSunny = IconData(0xf05a8, fontFamily: 'MaterialDesignIcons');
  static const IconData weatherNight = IconData(0xf0594, fontFamily: 'MaterialDesignIcons');
  static const IconData informationOutline = IconData(0xf02fd, fontFamily: 'MaterialDesignIcons');
  static const IconData windowClose = IconData(0xf05ad, fontFamily: 'MaterialDesignIcons');
  static const IconData windowMaximize = IconData(0xf05af, fontFamily: 'MaterialDesignIcons');
  static const IconData windowMinimize = IconData(0xf05b0, fontFamily: 'MaterialDesignIcons');
  static const IconData windowRestore = IconData(0xf05b2, fontFamily: 'MaterialDesignIcons');
}
