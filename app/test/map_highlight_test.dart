// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The map highlights the QSO currently in the logging panel: a marker and a
// great-circle line drawn on top of everything else, in the panel's accent
// colour — orange while composing a new QSO, blue while editing one. This
// covers the colour/location logic; the on-top layering is per-backend and
// verified on-device.

import 'package:flutter/material.dart' show Color, HSLColor;
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart' show CallInfoData;
import 'package:ham2k_logger/views/map/map_marker_data.dart';
import 'package:ham2k_logger/views/operation/map_panel.dart';

void main() {
  const composing = Color(0xFFFF8800); // stand-in for colorScheme.tertiary
  const editing = Color(0xFF0088FF); // stand-in for colorScheme.secondary

  ({List<MapMarkerData> markers, List<MapLineData> lines}) build(CallInfoData? info, {String? grid = 'CM87'}) =>
      buildHighlightData(callInfo: info, operationGrid: grid, composingColor: composing, editingColor: editing);

  test('nothing to highlight when there is no call info', () {
    expect(build(null).markers, isEmpty);
    expect(build(null).lines, isEmpty);
  });

  test('nothing to highlight when the location cannot be resolved', () {
    expect(build(CallInfoData(call: 'W1AW')).markers, isEmpty, reason: 'no guess at all');
    expect(build(CallInfoData(call: 'W1AW', guess: {})).markers, isEmpty, reason: 'guess with no location keys');
  });

  test('a resolved location produces one highlight marker in the composing colour', () {
    final result = build(CallInfoData(call: 'W1AW', guess: {'grid': 'FN31pr'}));
    expect(result.markers, hasLength(1));
    final marker = result.markers.single;
    expect(marker.highlight, isTrue, reason: 'so backends draw it on top');
    expect(marker.color, composing, reason: 'composing a new QSO uses the orange/tertiary accent');
    expect(marker.label, 'W1AW');
    expect(marker.kind, MapMarkerKind.qso);
    expect(marker.sizeFactor, greaterThan(1.0), reason: 'drawn larger so it reads as the current QSO');
  });

  test('editing an existing QSO uses the editing colour for the marker and line', () {
    final result = build(CallInfoData(call: 'W1AW', guess: {'grid': 'FN31pr'}, isEditing: true));
    expect(result.markers.single.color, editing, reason: 'editing uses the blue/secondary accent');
    expect(result.lines, isNotEmpty);
    expect(result.lines.every((l) => l.color == editing), isTrue);
  });

  test('with an operation grid, the highlight includes a great-circle line, all flagged highlight', () {
    final result = build(CallInfoData(call: 'W1AW', guess: {'grid': 'FN31pr'}));
    expect(result.lines, isNotEmpty);
    expect(result.lines.every((l) => l.highlight), isTrue);
    expect(result.lines.every((l) => l.color == composing), isTrue);
  });

  test('without an operation grid there is a marker but no line to draw', () {
    final result = build(CallInfoData(call: 'W1AW', guess: {'grid': 'FN31pr'}), grid: null);
    expect(result.markers, hasLength(1));
    expect(result.lines, isEmpty);
  });

  test('mapHighlightColor brightens a muted hue without shifting it', () {
    // The theme's light-mode tertiary — a dark, brownish orange.
    const mutedOrange = Color(0xFF964900);
    final bright = mapHighlightColor(mutedOrange);
    final before = HSLColor.fromColor(mutedOrange);
    final after = HSLColor.fromColor(bright);
    expect(after.hue, closeTo(before.hue, 1.0), reason: 'same hue, just brighter');
    expect(after.lightness, greaterThan(before.lightness), reason: 'brighter — the muted orange is dark');
    expect(after.saturation, greaterThanOrEqualTo(before.saturation), reason: 'at least as vivid (forced to full)');
    expect(after.saturation, 1.0);
  });
}
