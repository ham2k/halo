// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../svg_scene/scene_model.dart';
import 'weather_chart.dart';
import 'weather_reading.dart';

String _rgb(Color color) =>
    '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';

/// Production forecast expressed entirely in the public scene protocol.
/// Data fetching, localization and layout remain the panel's responsibility.
/// Inspection is local: no weather request or extension event per pointer move.
SvgScene weatherScene({
  required Size size,
  required List<WeatherHour> hours,
  required String unit,
  required String zone,
  required String label,
  required Color line,
  required Color rain,
  required Color baseline,
  required Color surface,
  required Color foreground,
  required double labelSize,
  required double labelHeight,
}) {
  final width = size.width.clamp(1.0, 8192.0);
  final height = size.height.clamp(1.0, 8192.0);
  // Reserve a caption band: an opaque overlay would hide forecast peaks.
  final captionHeight = labelHeight;
  final showCaption = height >= captionHeight + 24 && width >= 120;
  final plotTop = showCaption ? captionHeight : 0.0;
  final plotHeight = height - plotTop;
  final curve = weatherCurve([
    for (final hour in hours) hour.temperature,
  ], Size(width, plotHeight));
  final art = StringBuffer();
  final barWidth = math.min(width / hours.length * .44, 14.0);
  for (final (i, hour) in hours.indexed) {
    final chance = hour.precipitationChance;
    if (chance == null || chance <= 0) continue;
    final barHeight = plotHeight * .5 * chance.clamp(0, 100) / 100;
    final x = weatherColumnCenter(width, hours.length, i) - barWidth / 2;
    art.write(
      '<rect x="$x" y="${plotHeight - barHeight}" width="$barWidth" height="$barHeight" rx="2" fill="${_rgb(rain)}" fill-opacity=".30"/>',
    );
  }
  if (curve.points.isNotEmpty) {
    art.write(
      '<defs><linearGradient id="temperature" x1="0" y1="0" x2="0" y2="1"><stop stop-color="${_rgb(line)}" stop-opacity=".22"/><stop offset="1" stop-color="${_rgb(line)}" stop-opacity="0"/></linearGradient></defs>',
    );
    art.write(
      '<path d="${curve.svgPath} L$width $plotHeight L0 $plotHeight Z" fill="url(#temperature)"/>',
    );
    art.write(
      '<path d="${curve.svgPath}" fill="none" stroke="${_rgb(line)}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    );
  }
  art.write(
    '<path d="M0 ${plotHeight - .5} H$width" stroke="${_rgb(baseline)}"/>',
  );
  final descriptions = [
    for (final hour in hours)
      '${hour.localHour.toString().padLeft(2, '0')}:00${zone.isEmpty ? '' : ' $zone'} · ${hour.temperature?.round() ?? '—'}$unit · ${hour.precipitationChance ?? '—'}%',
  ];
  Map<String, Object> svgLayer(String id, double w, double h, String body) => {
    'id': id,
    'x': 0,
    'y': 0,
    'width': w,
    'height': h,
    'svg':
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h">$body</svg>',
  };
  // Keep inspection available in short charts through adjustable semantics;
  // only show its caption when there is room above the curve.
  return SvgScene({
    'version': 1,
    'width': width,
    'height': height,
    'values': {'hour': 0},
    'layers': [
      {
        ...svgLayer('forecast', width, plotHeight, art.toString()),
        'y': plotTop,
      },
      {
        ...svgLayer(
          'cursor',
          1,
          plotHeight,
          '<path d="M.5 0 V$plotHeight" stroke="${_rgb(foreground)}" stroke-opacity=".45" stroke-dasharray="3 3"/>',
        ),
        'y': plotTop,
        'translateX': {
          'value': 'hour',
          'input': [0, hours.length - 1],
          'output': [
            weatherColumnCenter(width, hours.length, 0),
            weatherColumnCenter(width, hours.length, hours.length - 1),
          ],
        },
      },
      if (showCaption) ...[
        svgLayer(
          'caption-plate',
          width,
          captionHeight,
          '<rect width="$width" height="$captionHeight" fill="${_rgb(surface)}" fill-opacity=".88"/>',
        ),
        {
          'id': 'caption',
          'x': 8,
          'y': 0,
          'width': width - 16,
          'height': captionHeight,
          'text': {
            'value': 'hour',
            'samples': descriptions,
            'size': labelSize,
            'color': _rgb(foreground),
          },
        },
      ],
    ],
    'controls': [
      {
        'id': 'forecast-hour',
        'label': label,
        'kind': 'slider',
        'x': 0,
        'y': 0,
        'width': width,
        'height': height,
        'value': 'hour',
        'min': 0,
        'max': hours.length - 1,
        'step': 1,
        'hover': true,
        'discrete': true,
        'valueLabels': descriptions,
      },
    ],
  });
}
