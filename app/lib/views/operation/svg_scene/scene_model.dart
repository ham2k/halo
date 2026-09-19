// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

/// Validate once at the document boundary, never in the frame callback.
class SvgScene {
  final double width, height;
  final Map<String, double> values;
  final List<SceneLayer> layers;
  final List<SceneControl> controls;

  SvgScene(Map<dynamic, dynamic> json)
    : width = number(json, 'width', min: 1, max: 8192),
      height = number(json, 'height', min: 1, max: 8192),
      values = parseValues(json['values']),
      layers = items(json['layers'], 128).map(SceneLayer.new).toList(),
      controls = items(json['controls'] ?? [], 64).map(SceneControl.new).toList() {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported scene version');
    }
    if (layers.fold<int>(0, (n, l) => n + (l.svg?.length ?? 0) + (l.text?.toString().length ?? 0)) > 1048576) {
      throw const FormatException('Scene artwork and text exceed 1 MiB');
    }
    final ids = <String>{};
    for (final layer in layers) {
      if (!ids.add(layer.id)) throw const FormatException('Duplicate layer ID');
      for (final binding in layer.bindings.values) {
        if (!values.containsKey(binding.value)) {
          throw const FormatException('Unknown bound value');
        }
      }
      if (layer.text?['value'] != null && !values.containsKey(layer.text!['value'])) {
        throw const FormatException('Unknown text value');
      }
    }
    ids.clear();
    for (final control in controls) {
      if (!ids.add(control.id)) {
        throw const FormatException('Duplicate control ID');
      }
      if (control.kind != 'button' && !values.containsKey(control.value)) {
        throw const FormatException('Unknown control value');
      }
    }
  }
}

Map<String, double> parseValues(Object? raw) {
  if (raw is! Map<dynamic, dynamic> || raw.length > 256) {
    throw const FormatException('Invalid scene values');
  }
  return {
    for (final key in raw.keys) string({'key': key}, 'key'): number(raw, key as String),
  };
}

List<Map<dynamic, dynamic>> items(Object? raw, int limit) {
  if (raw is! List || raw.length > limit || raw.any((v) => v is! Map<dynamic, dynamic>)) {
    throw const FormatException('Invalid scene items');
  }
  return raw.cast<Map<dynamic, dynamic>>();
}

double number(Map<dynamic, dynamic> json, String key, {double? fallback, double min = -1e12, double max = 1e12}) {
  final value = json[key] ?? fallback;
  if (value is! num || !value.isFinite || value < min || value > max) {
    throw FormatException('Invalid scene number: $key');
  }
  return value.toDouble();
}

String string(Map<dynamic, dynamic> json, String key, {String? fallback}) {
  final value = json[key] ?? fallback;
  if (value is! String || value.length > 262144) {
    throw FormatException('Invalid scene string: $key');
  }
  return value;
}

Rect bounds(Map<dynamic, dynamic> json) => Rect.fromLTWH(
  number(json, 'x'),
  number(json, 'y'),
  number(json, 'width', min: 1, max: 8192),
  number(json, 'height', min: 1, max: 8192),
);

List<double> pair(Object? value) {
  if (value is! List || value.length != 2) {
    throw const FormatException('Expected pair');
  }
  return [
    number({'n': value[0]}, 'n'),
    number({'n': value[1]}, 'n'),
  ];
}

class SceneBinding {
  final String value;
  final double scale;
  final double? modulo;
  final bool truncate;
  final List<double> input, output;
  final List<double>? samples;
  SceneBinding(Map<dynamic, dynamic> json)
    : value = string(json, 'value'),
      scale = number(json, 'scale', fallback: 1),
      modulo = json['modulo'] == null ? null : number(json, 'modulo', min: 1e-9),
      truncate = json['truncate'] == true,
      input = pair(json['input']),
      output = pair(json['output']),
      samples = json['samples'] == null ? null : _bindingSamples(json['samples']) {
    if (input[0] >= input[1]) {
      throw const FormatException('Invalid binding range');
    }
  }
  double evaluate(Map<String, double> values) {
    var source = values[value]! * scale;
    if (truncate) source = (source + 1e-7).floorToDouble();
    if (modulo != null) source %= modulo!;
    final t = ((source - input[0]) / (input[1] - input[0])).clamp(0.0, 1.0);
    if (samples != null) {
      final position = t * (samples!.length - 1);
      final index = position.floor();
      final next = (index + 1).clamp(0, samples!.length - 1);
      return samples![index] + (samples![next] - samples![index]) * (position - index);
    }
    return output[0] + (output[1] - output[0]) * t;
  }
}

List<double> _bindingSamples(dynamic value) {
  if (value is! List || value.isEmpty || value.length > 4096 || value.any((v) => v is! num || !v.isFinite)) {
    throw const FormatException('Invalid binding samples');
  }
  return value.map((v) => (v as num).toDouble()).toList();
}

class SceneLayer {
  final String id;
  final Rect rect;
  final String? svg;
  final Map<dynamic, dynamic>? text;
  final Map<String, SceneBinding> bindings;
  final Alignment pivot;
  final int transitionMs;
  final Map<dynamic, dynamic>? pulse;
  SceneLayer(Map<dynamic, dynamic> json)
    : id = string(json, 'id'),
      rect = bounds(json),
      svg = json['svg'] == null ? null : string(json, 'svg'),
      text = json['text'] as Map<dynamic, dynamic>?,
      bindings = {
        for (final key in ['rotation', 'translateX', 'translateY', 'opacity'])
          if (json[key] != null) key: SceneBinding(json[key] as Map<dynamic, dynamic>),
      },
      pivot = json['pivot'] == null
          ? Alignment.center
          : Alignment(pair(json['pivot'])[0] * 2 - 1, pair(json['pivot'])[1] * 2 - 1),
      transitionMs = number(json, 'transitionMs', fallback: 0, min: 0, max: 10000).round(),
      pulse = json['pulse'] as Map<dynamic, dynamic>? {
    if ((svg == null) == (text == null)) {
      throw const FormatException('Expected SVG or text');
    }
    if (svg != null &&
        RegExp(r'<(?:image|script|foreignObject)\b|<!DOCTYPE|<!ENTITY', caseSensitive: false).hasMatch(svg!)) {
      throw const FormatException('Scene SVG must be self-contained vector artwork');
    }
    if (text != null) {
      final samples = text!['samples'];
      if (samples != null &&
          (samples is! List ||
              samples.isEmpty ||
              samples.length > 4096 ||
              samples.any((v) => v is! String && (v is! num || !v.isFinite)))) {
        throw const FormatException('Invalid text samples');
      }
      if ((text!['value'] == null) == (text!['literal'] == null)) {
        throw const FormatException('Expected literal or bound text');
      }
      if (text!['value'] != null) string(text!, 'value');
      if (text!['literal'] != null) string(text!, 'literal');
      if (text!['fontFamily'] != null) string(text!, 'fontFamily');
      if (text!['align'] != null && !['start', 'center', 'end'].contains(text!['align'])) {
        throw const FormatException('Invalid text alignment');
      }
      number(text!, 'fontWeight', fallback: 400, min: 100, max: 900);
      number(text!, 'lineHeight', fallback: 1.2, min: .5, max: 5);
      number(text!, 'letterSpacing', fallback: 0, min: -10, max: 100);
      string(text!, 'prefix', fallback: '');
      string(text!, 'suffix', fallback: '');
      number(text!, 'decimals', fallback: 0, min: 0, max: 6);
      number(text!, 'scale', fallback: 1);
      if (text!['modulo'] != null) number(text!, 'modulo', min: 1e-9);
      number(text!, 'minIntegerDigits', fallback: 1, min: 1, max: 20);
      number(text!, 'size', fallback: 20, min: 1, max: 512);
      if (text!['color'] != null && !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(string(text!, 'color'))) {
        throw const FormatException('Invalid text color');
      }
    }
    if (pulse != null) {
      number(pulse!, 'periodMs', min: 100, max: 60000);
      number(pulse!, 'minOpacity', min: 0, max: 1);
    }
  }
}

class SceneControl {
  final String id, label, kind;
  final String? value, event;
  final Rect rect;
  final double min, max, step, sensitivity;
  final bool hover, discrete, continuous;
  final List<String>? valueLabels;
  final List<({String label, String event})>? menu;
  SceneControl(Map<dynamic, dynamic> json)
    : menu = json['menu'] == null
          ? null
          : items(json['menu'], 32).map((m) => (label: string(m, 'label'), event: string(m, 'event'))).toList(),
      id = string(json, 'id'),
      label = string(json, 'label'),
      kind = string(json, 'kind'),
      value = json['value'] as String?,
      event = json['event'] as String?,
      rect = bounds(json),
      hover = json['hover'] == true,
      continuous = json['continuous'] == true,
      discrete = json['discrete'] == true,
      valueLabels = json['valueLabels'] == null
          ? null
          : (json['valueLabels'] as List).map((v) => string({'v': v}, 'v')).toList(),
      min = number(json, 'min', fallback: 0),
      max = number(json, 'max', fallback: 1),
      step = number(json, 'step', fallback: 1, min: 1e-9),
      sensitivity = number(json, 'sensitivity', fallback: 1, min: 1e-9) {
    if ((menu != null && (kind != 'button' || menu!.isEmpty)) ||
        !['button', 'slider', 'knob'].contains(kind) ||
        min >= max ||
        (hover && (kind != 'slider' || event != null)) ||
        (valueLabels != null && (valueLabels!.isEmpty || valueLabels!.length > 4096))) {
      throw const FormatException('Invalid scene control');
    }
  }
  String describe(double n) => valueLabels == null
      ? n.toString()
      : valueLabels![((clamp(n) - min) / step).round().clamp(0, valueLabels!.length - 1)];

  double atX(double x) => discrete
      ? clamp(min + (x / rect.width * ((max - min) / step + 1)).floor() * step)
      : clamp(min + x / rect.width * (max - min));

  double clamp(double n) => (min + ((n - min) / step).round() * step).clamp(min, max).toDouble();
}
