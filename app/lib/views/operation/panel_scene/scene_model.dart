// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import '../panel_environment.dart';

/// Validate once at the document boundary, never in the frame callback.
class PanelScene {
  final double width, height;
  final Map<String, double> values;

  /// A key names one value: it is in [values] or here, never both, so a patch
  /// or an event can name it without saying which.
  final Map<String, String> strings;
  final List<SceneLayer> layers;
  final List<SceneControl> controls;
  final Map<String, SceneControl> controlsById;

  /// Null: the artwork fills the panel and every control has a rect.
  final SceneLayoutNode? layout;

  PanelScene(Map<dynamic, dynamic> json)
    : width = number(json, 'width', min: 1, max: 8192),
      height = number(json, 'height', min: 1, max: 8192),
      values = parseValues(json['values']),
      strings = parseStrings(json['strings'] ?? const {}),
      layers = items(json['layers'], 128).map(SceneLayer.new).toList(),
      controls = items(json['controls'] ?? [], 64).map(SceneControl.new).toList(),
      controlsById = {},
      layout = json['layout'] == null ? null : SceneLayoutNode.parse(json['layout']) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported scene version');
    }
    if (strings.keys.any(values.containsKey)) {
      throw const FormatException('A scene value is both a number and a string');
    }
    if (layers.fold<int>(0, (n, l) => n + (l.svg?.length ?? 0) + (l.text?.toString().length ?? 0)) > 1048576) {
      throw const FormatException('Scene artwork and text exceed 1 MiB');
    }
    final layerIds = <String>{};
    for (final layer in layers) {
      if (!layerIds.add(layer.id)) throw const FormatException('Duplicate layer ID');
      for (final binding in layer.bindings.values) {
        if (!values.containsKey(binding.value)) {
          throw const FormatException('Unknown bound value');
        }
      }
      if (layer.text?['value'] != null && !values.containsKey(layer.text!['value']) && !strings.containsKey(layer.text!['value'])) {
        throw const FormatException('Unknown text value');
      }
    }
    for (final control in controls) {
      if (controlsById.putIfAbsent(control.id, () => control) != control) {
        throw const FormatException('Duplicate control ID');
      }
      final value = control.value;
      final bound = switch (control.binding) {
        SceneBinds.number => values.containsKey(value),
        SceneBinds.string => strings.containsKey(value),
        SceneBinds.optionalNumber => value == null || values.containsKey(value),
        SceneBinds.any => value == null || values.containsKey(value) || strings.containsKey(value),
        SceneBinds.none => value == null,
        SceneBinds.unchecked => true,
      };
      if (!bound) throw FormatException('Unknown control value: ${control.id}');
      // Shown as nothing chosen, and a multi-select would drop the stranger
      // on the operator's next tap: the author's mistake, so said as one.
      if (control.options case final options?) {
        final current = strings[value]!;
        final chosen = control.multi ? current.split(',') : [current];
        if (current.isNotEmpty && !chosen.every((c) => options.any((o) => o.value == c))) {
          throw FormatException('Control value is not one of its options: ${control.id}');
        }
      }
      if (control.opacityBinding != null && !values.containsKey(control.opacityBinding!.value)) {
        throw FormatException('Unknown opacity value: ${control.id}');
      }
      if (control.spectrum?.valueNames.any((name) => !values.containsKey(name)) ?? false) {
        throw FormatException('Unknown spectrum value: ${control.id}');
      }
      if (control.spectrum case final spectrum? when spectrum.annotations.map((a) => a.id).toSet().length != spectrum.annotations.length) {
        throw FormatException('Duplicate spectrum annotation ID: ${control.id}');
      }
      // Only a rect puts a control over the artwork, so only a rect gives it
      // a place among the layers.
      if (control.after != null && (control.rect == null || !layerIds.contains(control.after))) {
        throw FormatException('Control cannot be placed after that layer: ${control.id}');
      }
    }
    // Every control is placed exactly once: by its rect over the artwork, or
    // by a node in the layout. A control placed nowhere would be silently
    // missing, and one placed twice would be two widgets sharing one state.
    final placed = <String>{};
    var sceneLeaves = 0;
    layout?.visit((node) {
      if (node.control case final id?) {
        if (controlsById[id] == null || controlsById[id]!.rect != null) throw FormatException('Layout names a control it cannot place: $id');
        if (!placed.add(id)) throw const FormatException('Layout places a control twice');
      }
      if (node.type == 'scene') sceneLeaves++;
    });
    for (final control in controls) {
      if (control.rect == null && !placed.contains(control.id)) throw FormatException('Control has no rect and is not in the layout: ${control.id}');
    }
    if (layout != null && sceneLeaves == 0 && (layers.isNotEmpty || controls.any((c) => c.rect != null))) {
      throw const FormatException('Layout has no scene node for its layers');
    }
    if (sceneLeaves > 1) throw const FormatException('Layout shows the scene twice');
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

Map<String, String> parseStrings(Object? raw) {
  if (raw is! Map<dynamic, dynamic> || raw.length > 256) {
    throw const FormatException('Invalid scene strings');
  }
  return {
    for (final key in raw.keys) string({'key': key}, 'key'): _boundedString(raw[key]),
  };
}

/// What a text field may hold, so an operator's typing cannot produce a patch
/// the next render refuses.
const sceneStringMaxLength = 4096;

String _boundedString(Object? value) {
  if (value is! String || value.length > sceneStringMaxLength) throw const FormatException('Invalid scene string value');
  return value;
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

Rect bounds(Map<dynamic, dynamic> json) =>
    Rect.fromLTWH(number(json, 'x'), number(json, 'y'), number(json, 'width', min: 1, max: 8192), number(json, 'height', min: 1, max: 8192));

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

String? _oneOf(Map<dynamic, dynamic> json, String key, List<String> allowed) {
  final value = json[key];
  if (value == null) return null;
  if (!allowed.contains(value)) throw FormatException('Invalid scene $key: $value');
  return value as String;
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

  /// Whether the layer takes the clicks that land on it. Off, it is click-
  /// through: artwork drawn over a control does not stop the control working.
  final bool blocksPointer;
  final Map<String, SceneBinding> bindings;
  final Alignment pivot;
  final int transitionMs;
  final Map<dynamic, dynamic>? pulse;
  SceneLayer(Map<dynamic, dynamic> json)
    : id = string(json, 'id'),
      rect = bounds(json),
      blocksPointer = json['blocksPointer'] == true,
      svg = json['svg'] == null ? null : string(json, 'svg'),
      text = json['text'] as Map<dynamic, dynamic>?,
      bindings = {
        for (final key in ['rotation', 'translateX', 'translateY', 'opacity'])
          if (json[key] != null) key: SceneBinding(json[key] as Map<dynamic, dynamic>),
      },
      pivot = json['pivot'] == null ? Alignment.center : Alignment(pair(json['pivot'])[0] * 2 - 1, pair(json['pivot'])[1] * 2 - 1),
      transitionMs = number(json, 'transitionMs', fallback: 0, min: 0, max: 10000).round(),
      pulse = json['pulse'] as Map<dynamic, dynamic>? {
    if ((svg == null) == (text == null)) {
      throw const FormatException('Expected SVG or text');
    }
    if (svg != null && RegExp(r'<(?:image|script|foreignObject)\b|<!DOCTYPE|<!ENTITY', caseSensitive: false).hasMatch(svg!)) {
      throw const FormatException('Scene SVG must be self-contained vector artwork');
    }
    if (text != null) {
      final samples = text!['samples'];
      if (samples != null && (samples is! List || samples.isEmpty || samples.length > 4096 || samples.any((v) => v is! String && (v is! num || !v.isFinite)))) {
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

/// What a control kind's `value` names.
enum SceneBinds { number, string, optionalNumber, any, none, unchecked }

/// Drawn by the extension's artwork, with an invisible hit area on top.
// A drawn button's `value` may name anything, or nothing: published scenes do.
// Its event carries what the name resolves to, `text` or `value`, null for none.
const _drawnKinds = {'button': SceneBinds.unchecked, 'slider': SceneBinds.number, 'knob': SceneBinds.number};

/// Material widgets, themed by the app.
const _nativeKinds = {
  'nativeButton': SceneBinds.none,
  'nativeSlider': SceneBinds.number,
  'nativeTextField': SceneBinds.string,
  'nativeDropdown': SceneBinds.string,
  'nativeSwitch': SceneBinds.number,
  'nativeCheckbox': SceneBinds.number,
  'nativeRadio': SceneBinds.string,
  'nativeSegmented': SceneBinds.string,
  // With a value, a toggle (FilterChip); without, an action (ActionChip).
  'nativeChip': SceneBinds.optionalNumber,
  'nativeText': SceneBinds.any,
  // Painted by the host from the radio's sweeps, which never cross the
  // bridge; its event carries the frequency clicked, as `value`.
  'spectrum': SceneBinds.none,
};

class SceneControl {
  final String id, label, kind;
  final String? value, event;

  /// Null only for a native control placed by the layout.
  final Rect? rect;
  final double min, max, step, sensitivity;
  final bool hover, discrete, continuous, multi, disabled;
  final List<String>? valueLabels;
  final List<({String label, String event})>? menu;
  final List<({String label, String value})>? options;
  final String? variant, icon, placeholder, style, align;

  /// The layer this control paints directly after, so later layers draw over
  /// it. Null: above every layer.
  final String? after;

  /// A fixed opacity, or [opacityBinding] when one is bound.
  final double opacity;
  final SceneBinding? opacityBinding;

  /// Set on a `spectrum` control, and only on one.
  final SceneSpectrumSpec? spectrum;
  SceneControl(Map<dynamic, dynamic> json)
    : after = json['after'] == null ? null : string(json, 'after'),
      spectrum = json['kind'] == 'spectrum' ? SceneSpectrumSpec(json) : null,
      opacity = json['opacity'] is Map ? 1 : number(json, 'opacity', fallback: 1, min: 0, max: 1),
      opacityBinding = json['opacity'] is Map ? SceneBinding(json['opacity'] as Map<dynamic, dynamic>) : null,
      menu = json['menu'] == null ? null : items(json['menu'], 32).map((m) => (label: string(m, 'label'), event: string(m, 'event'))).toList(),
      options = json['options'] == null ? null : items(json['options'], 64).map((m) => (label: string(m, 'label'), value: string(m, 'value'))).toList(),
      id = string(json, 'id'),
      label = string(json, 'label'),
      kind = string(json, 'kind'),
      value = json['value'] == null ? null : string(json, 'value'),
      event = json['event'] == null ? null : string(json, 'event'),
      rect = json['x'] == null && json['y'] == null && json['width'] == null && json['height'] == null && _nativeKinds.containsKey(json['kind'])
          ? null
          : bounds(json),
      multi = json['multi'] == true,
      disabled = json['disabled'] == true,
      variant = _oneOf(json, 'variant', const ['filled', 'tonal', 'outlined', 'text']),
      icon = json['icon'] == null ? null : string(json, 'icon'),
      placeholder = json['placeholder'] == null ? null : string(json, 'placeholder'),
      style = _oneOf(json, 'style', panelTextRoles),
      align = _oneOf(json, 'align', const ['start', 'center', 'end']),
      hover = json['hover'] == true,
      continuous = json['continuous'] == true,
      discrete = json['discrete'] == true,
      valueLabels = json['valueLabels'] == null ? null : (json['valueLabels'] as List).map((v) => string({'v': v}, 'v')).toList(),
      min = number(json, 'min', fallback: 0),
      max = number(json, 'max', fallback: 1),
      step = number(json, 'step', fallback: 1, min: 1e-9),
      sensitivity = number(json, 'sensitivity', fallback: 1, min: 1e-9) {
    final choices = options?.map((o) => o.value).toList();
    bool only(Object? field, Set<String> kinds) => field == null || field == false || kinds.contains(kind);
    if ((menu != null && (!const {'button', 'nativeButton'}.contains(kind) || menu!.isEmpty)) ||
        (_drawnKinds[kind] ?? _nativeKinds[kind]) == null ||
        min >= max ||
        (hover && (kind != 'slider' || event != null)) ||
        (valueLabels != null && (valueLabels!.isEmpty || valueLabels!.length > 4096)) ||
        // A choice needs something to choose from, and a value can be chosen once.
        (const {'nativeDropdown', 'nativeRadio', 'nativeSegmented'}.contains(kind) != (choices != null)) ||
        (choices != null && (choices.isEmpty || choices.toSet().length != choices.length)) ||
        !only(multi, {'nativeSegmented'}) ||
        // A multi-select is sent as its values joined with commas.
        (multi && choices!.any((c) => c.contains(','))) ||
        // A button that sends nothing is a button that does nothing.
        ((kind == 'nativeButton' || (kind == 'nativeChip' && value == null)) && event == null && menu == null) ||
        (kind == 'nativeText' && event != null) ||
        !only(json['variant'], {'nativeButton'}) ||
        !only(icon, {'nativeButton', 'nativeChip'}) ||
        !only(placeholder, {'nativeTextField', 'nativeDropdown'}) ||
        !only(style, {'nativeText'}) ||
        !only(align, {'nativeText'}) ||
        !only(continuous, {'slider', 'knob', 'nativeSlider', 'nativeTextField'}) ||
        SceneSpectrumSpec.keys.any((key) => !only(json[key], {'spectrum'}))) {
      throw FormatException('Invalid scene control: $id');
    }
  }

  bool get native => _nativeKinds.containsKey(kind);

  double opacityAt(Map<String, double> values) => (opacityBinding?.evaluate(values) ?? opacity).clamp(0, 1).toDouble();
  SceneBinds get binding => _drawnKinds[kind] ?? _nativeKinds[kind]!;

  /// Whether using it is an action rather than setting a value: it sends
  /// `activate`, and waits out an action already pending.
  bool get isAction => kind == 'button' || kind == 'nativeButton' || (kind == 'nativeChip' && value == null);
  String describe(double n) => valueLabels == null ? n.toString() : valueLabels![((clamp(n) - min) / step).round().clamp(0, valueLabels!.length - 1)];

  double atX(double x) => discrete ? clamp(min + (x / rect!.width * ((max - min) / step + 1)).floor() * step) : clamp(min + x / rect!.width * (max - min));

  double clamp(double n) => (min + ((n - min) / step).round() * step).clamp(min, max).toDouble();
}

/// A number a `spectrum` control reads on every sweep: a literal, or the name
/// of a scene value — which a slider with no event retunes with no bridge call.
class SceneNumber {
  final double? literal;
  final String? value;

  /// What a literal is checked against when parsed, and a value held to
  /// when read: a slider that reaches 0 must not become a range of 0, which
  /// the painters divide by.
  final double min, max;

  SceneNumber._(this.literal, this.value, this.min, this.max);

  static SceneNumber? parse(Map<dynamic, dynamic> json, String key, {required double min, required double max}) => switch (json[key]) {
    null => null,
    final String name => SceneNumber._(null, name, min, max),
    _ => SceneNumber._(number(json, key, min: min, max: max), null, min, max),
  };

  double? resolve(Map<String, double> values) => literal ?? values[value]?.clamp(min, max).toDouble();
}

/// `#RRGGBB`, or `#AARRGGBB` for a color with its own transparency.
Color? _color(Map<dynamic, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  final match = raw is String ? RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(raw) : null;
  if (match == null) throw FormatException('Invalid scene color: $key');
  final hex = match[1]!;
  return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
}

/// How a line or an area is drawn on one part of a `spectrum` control: [color]
/// and [width] for a line or an area's edges, [fill] for the area itself.
class SceneSpectrumStyle {
  final Color? color, fill;
  final SceneNumber? width;

  SceneSpectrumStyle(Map<dynamic, dynamic> json)
    : color = _color(json, 'color'),
      fill = _color(json, 'fill'),
      width = SceneNumber.parse(json, 'width', min: .25, max: 8);

  static SceneSpectrumStyle? parse(Object? raw) => switch (raw) {
    null => null,
    final Map<dynamic, dynamic> json => SceneSpectrumStyle(json),
    _ => throw const FormatException('Invalid scene spectrum style'),
  };
}

/// A line across the control: a border of the gap.
class SceneSpectrumBorder {
  final Color? color;
  final SceneNumber? width;

  SceneSpectrumBorder(Map<dynamic, dynamic> json) : color = _color(json, 'color'), width = SceneNumber.parse(json, 'width', min: 0, max: 20);

  static SceneSpectrumBorder? parse(Object? raw) => switch (raw) {
    null => null,
    final Map<dynamic, dynamic> json => SceneSpectrumBorder(json),
    _ => throw const FormatException('Invalid scene spectrum border'),
  };
}

/// The frequency labels.
///
/// [offset] is pixels from the base of the panadapter — the top of the
/// waterfall where there is no panadapter — to the top of the text: negative
/// rises into the panadapter, positive drops into the gap or the waterfall.
/// Null centers them in the gap.
class SceneSpectrumLabels {
  /// Hz between labels. Null: the gridlines' step.
  final SceneNumber? interval, size, weight, offset;
  final String? fontFamily;
  final bool italic;
  final Color? color;

  SceneSpectrumLabels(Map<dynamic, dynamic> json)
    : interval = SceneNumber.parse(json, 'interval', min: 1, max: 1e9),
      size = SceneNumber.parse(json, 'size', min: 4, max: 72),
      weight = SceneNumber.parse(json, 'weight', min: 100, max: 900),
      offset = SceneNumber.parse(json, 'offset', min: -2000, max: 2000),
      fontFamily = json['fontFamily'] == null ? null : string(json, 'fontFamily'),
      italic = json['italic'] == true,
      color = _color(json, 'color');

  Iterable<String> get valueNames => [
    for (final n in [interval, size, weight, offset]) ?n?.value,
  ];
}

/// Tick marks at an [interval] of Hz — the labels' unless given — from
/// [offset] pixels below the base the labels measure from, [length] long.
class SceneSpectrumTicks {
  final SceneNumber? interval, width, offset, length;
  final Color? color;

  SceneSpectrumTicks(Map<dynamic, dynamic> json)
    : interval = SceneNumber.parse(json, 'interval', min: 1, max: 1e9),
      width = SceneNumber.parse(json, 'width', min: .25, max: 20),
      offset = SceneNumber.parse(json, 'offset', min: -2000, max: 2000),
      length = SceneNumber.parse(json, 'length', min: 0, max: 2000),
      color = _color(json, 'color');

  Iterable<String> get valueNames => [
    for (final n in [interval, width, offset, length]) ?n?.value,
  ];
}

/// The gap between the panadapter and the waterfall — above the waterfall
/// where there is no panadapter, below the panadapter where there is no
/// waterfall — with what is drawn in and around it.
class SceneSpectrumScale {
  final SceneNumber? gap;
  final Color? background;
  final SceneSpectrumBorder? borderTop, borderBottom;

  /// Null: no labels — `labels: false`.
  final SceneSpectrumLabels? labels;
  final SceneSpectrumTicks? ticks;

  SceneSpectrumScale(Map<dynamic, dynamic> json)
    : gap = SceneNumber.parse(json, 'gap', min: 0, max: 200),
      background = _color(json, 'background'),
      borderTop = SceneSpectrumBorder.parse(json['borderTop']),
      borderBottom = SceneSpectrumBorder.parse(json['borderBottom']),
      labels = switch (json['labels']) {
        null || true => SceneSpectrumLabels(const {}),
        false => null,
        final Map<dynamic, dynamic> labels => SceneSpectrumLabels(labels),
        _ => throw const FormatException('Invalid scene spectrum labels'),
      },
      ticks = switch (json['ticks']) {
        null || false => null,
        true => SceneSpectrumTicks(const {}),
        final Map<dynamic, dynamic> ticks => SceneSpectrumTicks(ticks),
        _ => throw const FormatException('Invalid scene spectrum ticks'),
      };

  Iterable<String> get valueNames => [?gap?.value, ?borderTop?.width?.value, ?borderBottom?.width?.value, ...?labels?.valueNames, ...?ticks?.valueNames];
}

/// Text at a frequency on the panadapter or the waterfall, drawn by the host
/// and clickable: with an [event], a click sends `activate` carrying the
/// frequency as `value` and [id] as `annotation`, and does not tune.
class SceneSpectrumAnnotation {
  final String id, text;
  final SceneNumber hz;
  final SceneSpectrumAnchor anchor;
  final bool onWaterfall;

  /// Pixels from the panadapter's bottom up to the text's, or from the
  /// waterfall's top down to the text's.
  final SceneNumber? offset;

  /// Which end of the text sits at [hz].
  final String align;

  /// The point on the box that marks [hz]: its [SceneSpectrumPointer.size],
  /// and whether it leaves the box's top or bottom edge. Null: none.
  final SceneSpectrumPointer? pointer;
  final SceneNumber? size, weight, padding, borderWidth, radius;
  final String? fontFamily, event;
  final bool italic;
  final Color? color, background, borderColor;

  SceneSpectrumAnnotation(Map<dynamic, dynamic> json)
    : id = string(json, 'id'),
      text = _short(json, 'text'),
      hz = SceneNumber.parse(json, 'hz', min: -1e12, max: 1e12) ?? (throw const FormatException('A spectrum annotation needs hz')),
      anchor = SceneSpectrumAnchor.values.byName(_oneOf(json, 'anchor', const ['vfo', 'center', 'absolute']) ?? 'absolute'),
      onWaterfall = (_oneOf(json, 'part', const ['pan', 'waterfall']) ?? 'pan') == 'waterfall',
      offset = SceneNumber.parse(json, 'offset', min: -2000, max: 2000),
      align = _oneOf(json, 'align', const ['start', 'center', 'end']) ?? 'center',
      pointer = switch (json['pointer']) {
        false => null,
        null || true => SceneSpectrumPointer(const {}),
        final Map<dynamic, dynamic> pointer => pointer['show'] == false ? null : SceneSpectrumPointer(pointer),
        _ => throw const FormatException('Invalid scene spectrum pointer'),
      },
      size = SceneNumber.parse(json, 'size', min: 4, max: 72),
      weight = SceneNumber.parse(json, 'weight', min: 100, max: 900),
      padding = SceneNumber.parse(json, 'padding', min: 0, max: 40),
      borderWidth = SceneNumber.parse(json, 'borderWidth', min: 0, max: 10),
      radius = SceneNumber.parse(json, 'radius', min: 0, max: 40),
      fontFamily = json['fontFamily'] == null ? null : string(json, 'fontFamily'),
      event = json['event'] == null ? null : string(json, 'event'),
      italic = json['italic'] == true,
      color = _color(json, 'color'),
      background = _color(json, 'background'),
      borderColor = _color(json, 'borderColor');

  static String _short(Map<dynamic, dynamic> json, String key) {
    final text = string(json, key);
    if (text.length > 256) throw const FormatException('A spectrum annotation is at most 256 characters');
    return text;
  }

  Iterable<String> get valueNames => [
    for (final n in [hz, offset, size, weight, padding, borderWidth, radius, pointer?.size]) ?n?.value,
  ];
}

/// The point an annotation's box makes at its frequency.
class SceneSpectrumPointer {
  final SceneNumber? size;

  /// `top` or `bottom`; null points toward the part's edge the annotation
  /// is measured from — down on the panadapter, up on the waterfall.
  final String? corner;

  SceneSpectrumPointer(Map<dynamic, dynamic> json)
    : size = SceneNumber.parse(json, 'size', min: 0, max: 40),
      corner = _oneOf(json, 'corner', const ['top', 'bottom']) {
    if (json['show'] != null && json['show'] is! bool) throw const FormatException('Invalid scene spectrum pointer');
  }
}

/// The direction a spectrum's waterfall moves. Everything is laid out for
/// `down` and then mirrored or turned, text excepted, which stays upright.
enum SceneSpectrumFlow { down, up, right, left }

/// What a mark's numbers are measured from.
enum SceneSpectrumAnchor {
  /// The tuned frequency.
  vfo,

  /// The middle of the sweep — on a Flex the panadapter's center, which is
  /// not its slice.
  center,

  /// Nothing: the numbers are frequencies.
  absolute,
}

/// The tuned-frequency line, or a line or area at [at] / [from]..[to] Hz from
/// its [anchor], styled separately on the panadapter and the waterfall. A
/// part with no style is not drawn on.
///
/// On the panadapter an area is drawn behind the trace, and a line in front
/// of it unless [behind]; on the waterfall all of it is drawn over the rows,
/// since nothing under them would show.
class SceneSpectrumMark {
  final SceneNumber? at, from, to;
  final SceneSpectrumAnchor anchor;
  final bool behind;
  final SceneSpectrumStyle? pan, waterfall;

  SceneSpectrumMark(Map<dynamic, dynamic> json, {bool line = false})
    : at = SceneNumber.parse(json, 'at', min: -1e12, max: 1e12),
      from = SceneNumber.parse(json, 'from', min: -1e12, max: 1e12),
      to = SceneNumber.parse(json, 'to', min: -1e12, max: 1e12),
      anchor = SceneSpectrumAnchor.values.byName(_oneOf(json, 'anchor', const ['vfo', 'center', 'absolute']) ?? 'vfo'),
      // A band edge or a segment is scenery: the signals go in front of it.
      behind = switch (json['behind']) {
        null => json['anchor'] == 'absolute',
        final bool behind => behind,
        _ => throw const FormatException('Invalid scene spectrum behind'),
      },
      pan = SceneSpectrumStyle.parse(json['pan']),
      waterfall = SceneSpectrumStyle.parse(json['waterfall']) {
    if (!line && ((at == null) == (from == null || to == null) || (at != null && (from != null || to != null)))) {
      throw const FormatException('A spectrum overlay is a line at one offset or an area between two');
    }
    // An overlay with no style draws nothing, which is the author's mistake;
    // a center with none is how to have no tuned-frequency line at all.
    if (!line && pan == null && waterfall == null) throw const FormatException('A spectrum overlay with no style draws nothing');
  }

  Iterable<String> get valueNames => [
    for (final n in [at, from, to, pan?.width, waterfall?.width]) ?n?.value,
  ];
}

/// How a `spectrum` control draws the radio's sweeps — all of it on the host,
/// after the sweep arrives, so it means the same on every radio. The radio's
/// own scope settings (span, reference level, sweep speed) are
/// `setRadioSpectrum`'s, not these.
class SceneSpectrumSpec {
  static const keys = [
    'radio', 'display', 'split', 'palette', 'floor', 'range', 'hoverHz', 'hoverDb', //
    'average', 'fps', 'waterfallSpeed', 'waterfallFloor', 'waterfallRange', 'waterfallColors', //
    'traceColor', 'traceWidth', 'fillColor', 'fillColorBottom', 'backgroundColor', //
    'gridColor', 'gridDashed', 'waterfallGridColor', 'center', 'overlays', 'scale', 'tuneStep', 'annotations', 'flow', //
  ];
  static const palettes = ['classic', 'gray', 'heat'];

  /// A station node's id. Null is the designated radio.
  final String? radio;
  final bool pan, waterfall;

  /// Which way the waterfall moves; the panadapter sits on the side it
  /// comes from. Frequency rises left to right for `down` and `up`, bottom to
  /// top for `right` and `left`.
  final SceneSpectrumFlow flow;

  /// The panadapter's share of the height when both are shown.
  final double split;
  final String palette;

  /// dB added to the radio's floor, and the display's height in dB.
  final SceneNumber? floor, range;

  /// Written as the pointer moves.
  final String? hoverHz, hoverDb;

  /// How much of the trace each sweep replaces, as the share it does NOT:
  /// 0 draws every sweep as it is, 99 barely moves. The waterfall stays raw,
  /// so a short signal still marks it.
  final SceneNumber? average;

  /// The most times a second the panadapter is redrawn — the waterfall keeps
  /// its own pace, [waterfallSpeed].
  final SceneNumber? fps;

  /// Waterfall rows a second. Null: one per sweep.
  final SceneNumber? waterfallSpeed;

  /// The waterfall's own dB window; null follows the panadapter's.
  final SceneNumber? waterfallFloor, waterfallRange;

  /// 2 to 8 stops, lowest level first, in place of [palette].
  final List<Color>? waterfallColors;
  final SceneNumber? traceWidth;
  final Color? traceColor, fillColor, fillColorBottom, backgroundColor;

  /// The tuned-frequency line. Null draws it in the theme's color on both
  /// parts; given, only on the parts it styles.
  final SceneSpectrumMark? center;

  /// Lines and areas at offsets from the tuned frequency — a passband, a CW
  /// offset. At most 16.
  final List<SceneSpectrumMark> overlays;

  /// The panadapter's dB and frequency lines.
  final Color? gridColor;

  /// The frequency lines carried down through the waterfall. Null: none.
  final Color? waterfallGridColor;
  final bool gridDashed;

  /// What a click tunes to the nearest multiple of, in Hz. Null: wherever
  /// the click lands.
  final SceneNumber? tuneStep;

  /// The gap between the panadapter and the waterfall, and the frequency
  /// labels and ticks. Null: no gap, no labels.
  final SceneSpectrumScale? scale;

  /// Text at frequencies — a spot, a net, a beacon — that can be clicked.
  /// At most 64, each id once.
  final List<SceneSpectrumAnnotation> annotations;

  SceneSpectrumSpec(Map<dynamic, dynamic> json)
    : radio = json['radio'] == null ? null : string(json, 'radio'),
      flow = SceneSpectrumFlow.values.byName(_oneOf(json, 'flow', const ['down', 'up', 'right', 'left']) ?? 'down'),
      pan = (_oneOf(json, 'display', const ['both', 'pan', 'waterfall']) ?? 'both') != 'waterfall',
      waterfall = (_oneOf(json, 'display', const ['both', 'pan', 'waterfall']) ?? 'both') != 'pan',
      split = number(json, 'split', fallback: .4, min: .1, max: .9),
      palette = _oneOf(json, 'palette', palettes) ?? 'classic',
      floor = SceneNumber.parse(json, 'floor', min: -200, max: 200),
      range = SceneNumber.parse(json, 'range', min: 1, max: 200),
      hoverHz = json['hoverHz'] == null ? null : string(json, 'hoverHz'),
      hoverDb = json['hoverDb'] == null ? null : string(json, 'hoverDb'),
      average = SceneNumber.parse(json, 'average', min: 0, max: 99),
      fps = SceneNumber.parse(json, 'fps', min: 1, max: 60),
      waterfallSpeed = SceneNumber.parse(json, 'waterfallSpeed', min: .1, max: 60),
      waterfallFloor = SceneNumber.parse(json, 'waterfallFloor', min: -200, max: 200),
      waterfallRange = SceneNumber.parse(json, 'waterfallRange', min: 1, max: 200),
      waterfallColors = json['waterfallColors'] == null ? null : _stops(json['waterfallColors']),
      traceWidth = SceneNumber.parse(json, 'traceWidth', min: .25, max: 8),
      traceColor = _color(json, 'traceColor'),
      fillColor = _color(json, 'fillColor'),
      fillColorBottom = _color(json, 'fillColorBottom'),
      backgroundColor = _color(json, 'backgroundColor'),
      gridColor = _color(json, 'gridColor'),
      waterfallGridColor = _color(json, 'waterfallGridColor'),
      gridDashed = json['gridDashed'] == true,
      tuneStep = SceneNumber.parse(json, 'tuneStep', min: 1, max: 1e6),
      annotations = json['annotations'] == null ? const [] : items(json['annotations'], 64).map(SceneSpectrumAnnotation.new).toList(),
      scale = switch (json['scale']) {
        null || false => null,
        true => SceneSpectrumScale(const {}),
        final Map<dynamic, dynamic> scale => SceneSpectrumScale(scale),
        _ => throw const FormatException('Invalid scene spectrum scale'),
      },
      center = switch (json['center']) {
        null => null,
        false => SceneSpectrumMark(const {}, line: true),
        final Map<dynamic, dynamic> center => SceneSpectrumMark(center, line: true),
        _ => throw const FormatException('Invalid scene spectrum center'),
      },
      overlays = json['overlays'] == null ? const [] : items(json['overlays'], 16).map(SceneSpectrumMark.new).toList();

  static List<Color> _stops(Object? raw) {
    if (raw is! List || raw.length < 2 || raw.length > 8) throw const FormatException('Invalid scene waterfallColors');
    return [
      for (var i = 0; i < raw.length; i++) _color({'c': raw[i]}, 'c')!,
    ];
  }

  Iterable<String> get valueNames => [
    for (final n in [floor, range, average, fps, waterfallSpeed, waterfallFloor, waterfallRange, traceWidth, tuneStep]) ?n?.value,
    ?hoverHz,
    ?hoverDb,
    ...?center?.valueNames,
    ...?scale?.valueNames,
    for (final annotation in annotations) ...annotation.valueNames,
    for (final overlay in overlays) ...overlay.valueNames,
  ];
}

/// One node of a scene's layout: Flutter's Row, Column and Wrap, with
/// Flexible, Spacer and SizedBox folded in as fields. JSON names the type by
/// its one key — `{row: [...]}`, `{control: 'id'}`, `{scene: true}`,
/// `{spacer: 1}`.
///
/// Refused here, rather than left to throw in layout: a `flex` anywhere but a
/// row or column's direct child (Flutter asserts on the parent data). One the
/// parser cannot see — a row with no room to share, itself an unflexed child
/// of a row — is laid out unflexed by the view instead.
class SceneLayoutNode {
  static const maxDepth = 8, maxNodes = 128;
  static const _types = ['row', 'column', 'wrap', 'control', 'scene', 'spacer'];

  final String type;
  final List<SceneLayoutNode> children;
  final String? control;
  final int? flex;
  final bool tight;
  final double? width, height;
  final EdgeInsetsDirectional padding;
  final double spacing, runSpacing;
  final String mainAxisAlignment, crossAxisAlignment;

  SceneLayoutNode._(Map<dynamic, dynamic> json, this.type, this.children, {required bool inFlex})
    : control = type == 'control' ? string(json, 'control') : null,
      flex = type == 'spacer'
          ? number(json, 'spacer', min: 1, max: 1000).round()
          : json['flex'] == null
          ? null
          : number(json, 'flex', min: 1, max: 1000).round(),
      tight = _oneOf(json, 'fit', const ['tight', 'loose']) != 'loose',
      width = json['width'] == null ? null : number(json, 'width', min: 0, max: 8192),
      height = json['height'] == null ? null : number(json, 'height', min: 0, max: 8192),
      padding = _padding(json['padding']),
      spacing = number(json, 'spacing', fallback: 0, min: 0, max: 1000),
      runSpacing = number(json, 'runSpacing', fallback: 0, min: 0, max: 1000),
      mainAxisAlignment = _oneOf(json, 'mainAxisAlignment', const ['start', 'center', 'end', 'spaceBetween', 'spaceAround', 'spaceEvenly']) ?? 'start',
      crossAxisAlignment = _oneOf(json, 'crossAxisAlignment', const ['start', 'center', 'end', 'stretch']) ?? 'center' {
    if (type == 'scene' && json['scene'] != true) throw const FormatException('Invalid scene layout node');
    if (flex != null && !inFlex) throw const FormatException('Layout flex outside a row or column');
    if (type == 'wrap' && crossAxisAlignment == 'stretch') throw const FormatException('A wrap cannot stretch its runs');
  }

  static SceneLayoutNode parse(Object? json) {
    var count = 0;
    SceneLayoutNode node(Object? raw, int depth, {required bool inFlex}) {
      if (raw is! Map<dynamic, dynamic> || ++count > maxNodes || depth > maxDepth) throw const FormatException('Invalid scene layout');
      final types = _types.where(raw.containsKey).toList();
      if (types.length != 1) throw const FormatException('A layout node needs exactly one type');
      final type = types.single;
      final children = const {'row', 'column', 'wrap'}.contains(type)
          ? items(raw[type], maxNodes).map((c) => node(c, depth + 1, inFlex: type != 'wrap')).toList()
          : const <SceneLayoutNode>[];
      return SceneLayoutNode._(raw, type, children, inFlex: inFlex);
    }

    return node(json, 1, inFlex: false);
  }

  void visit(void Function(SceneLayoutNode) f) {
    f(this);
    for (final child in children) {
      child.visit(f);
    }
  }
}

/// A number for all four sides, or `[start, top, end, bottom]`.
EdgeInsetsDirectional _padding(Object? raw) {
  if (raw == null) return EdgeInsetsDirectional.zero;
  if (raw is num) return EdgeInsetsDirectional.all(number({'p': raw}, 'p', min: 0, max: 1000));
  if (raw is! List || raw.length != 4) throw const FormatException('Invalid layout padding');
  final p = [
    for (final v in raw) number({'p': v}, 'p', min: 0, max: 1000),
  ];
  return EdgeInsetsDirectional.fromSTEB(p[0], p[1], p[2], p[3]);
}
