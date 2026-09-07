// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How wide the settings pane is, for a panel that lays its rows out by it.
// Provided by the screen, read by any panel — its own file so a panel need
// not import the screen that builds it.

import 'package:flutter/material.dart';

/// The pane's width, published once per layout for the section bands, whose
/// pinned extent has to be measured against it.
///
/// Not read from a `SliverLayoutBuilder` at the band itself, which is where
/// it is wanted: `SliverConstraints` carry `scrollOffset`, so such a builder
/// re-runs on every frame of a scroll — one text measurement per section per
/// frame, across every group and extension panel in Settings, for a width
/// that cannot change while scrolling.
class SettingsPaneWidth extends InheritedWidget {
  final double width;

  const SettingsPaneWidth({super.key, required this.width, required super.child});

  @override
  bool updateShouldNotify(SettingsPaneWidth old) => old.width != width;
}

/// The width `_buildPanelContent` (settings_view.dart) published, or the window's where a panel is
/// rendered outside it (a test pumping one directly).
double settingsPaneWidth(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<SettingsPaneWidth>()?.width ?? MediaQuery.sizeOf(context).width;
