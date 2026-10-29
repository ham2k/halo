// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import '../../../services/panel_content_budgets.dart';
import '../panel_environment.dart';

/// The values a scene that names a [PanelScene.radio] is given, live, by the
/// host: its meters and whether it is transmitting (1 or 0). A missing reading
/// is negative infinity, which a binding takes as the bottom of its range and
/// a text shows as a dash. Reserved: a scene may not declare them itself.
///
/// `radio.swrAverage` is the SWR averaged over the transmission under way, or else the last one;
/// `radio.secondsSinceTransmit` is 0 while transmitting, then counts up — a long time when there
/// has been none, so a hold bound to it is over rather than pending.
///
/// The dial follows `readRadio`: `radio.frequencyHz` is the last frequency reported, connected or
/// not, so a readout holds it as the built-in Radio panel does; the passband and the power setting
/// only while it is live, which `radio.connected` says as 1 or 0. `radio.ptt` (the app holding the
/// radio's PTT, 1 or 0) only where `readRadio` gives `keying`.
const sceneRadioValues = {
  'radio.signalDbm',
  'radio.powerOut',
  'radio.swr',
  'radio.alc',
  'radio.supplyVolts',
  'radio.transmitting',
  'radio.swrAverage',
  'radio.secondsSinceTransmit',
  'radio.frequencyHz',
  'radio.passbandLowHz',
  'radio.passbandHighHz',
  'radio.passbandWidthHz',
  'radio.powerWatts',
  'radio.ptt',
  'radio.connected',
};

/// The host-fed words, beside [sceneRadioValues] and reserved the same way: the mode as the
/// radio reports it (`USB`, `CW`…), last known like the frequency; the tuner (`inline`, `bypassed`,
/// `tuning`, `failed`) while live; the connection's status (`connected`, `connecting`,
/// `disconnected`…). One the radio has not given is empty.
const sceneRadioStrings = {'radio.mode', 'radio.tuner', 'radio.status'};

/// Validate once at the document boundary, never in the frame callback.
class PanelScene {
  final double width, height;
  final Map<String, double> values;

  /// Whether the host feeds [sceneRadioValues], and from which radio: a
  /// station node's id, or null for the designated one.
  final bool hasRadio;
  final String? radio;

  /// A key names one value: it is in [values] or here, never both, so a patch
  /// or an event can name it without saying which.
  final Map<String, String> strings;
  final List<SceneLayer> layers;
  final List<SceneControl> controls;
  final Map<String, SceneControl> controlsById;

  /// Null: the artwork fills the panel and every control has a rect.
  final SceneLayoutNode? layout;

  /// A scene longer than its panel along [axis] (`x` or `y`), scrolled natively: scaled to fill the
  /// panel across, it runs on past it along the axis. The position, in scene units from the start,
  /// is written to the scene value [value] as it scrolls; a render that changes that value moves
  /// the view there. [event], when given, is sent once scrolling settles, with the position.
  final ({String axis, String value, String? event})? scroll;

  PanelScene(Map<dynamic, dynamic> json)
    : width = number(json, 'width', min: 1, max: 8192),
      height = number(json, 'height', min: 1, max: 8192),
      values = parseValues(json['values']),
      hasRadio = json['radio'] is Map,
      radio = json['radio'] is Map && (json['radio'] as Map)['node'] != null ? string(json['radio'] as Map, 'node') : null,
      strings = parseStrings(json['strings'] ?? const {}),
      layers = items(json['layers'], 512, budget: PanelBudget.layers, what: 'layers').map(SceneLayer.new).toList(),
      controls = items(json['controls'] ?? [], 256, budget: PanelBudget.controls, what: 'controls').map(SceneControl.new).toList(),
      controlsById = {},
      layout = json['layout'] == null ? null : SceneLayoutNode.parse(json['layout']),
      scroll = json['scroll'] is Map
          ? (
              axis: _oneOf(json['scroll'] as Map<dynamic, dynamic>, 'axis', const ['x', 'y']) ?? 'y',
              value: string(json['scroll'] as Map<dynamic, dynamic>, 'value'),
              event: (json['scroll'] as Map)['event'] == null ? null : string(json['scroll'] as Map<dynamic, dynamic>, 'event'),
            )
          : null {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported scene version');
    }
    if (strings.keys.any(values.containsKey)) {
      throw const FormatException('A scene value is both a number and a string');
    }
    if (json['radio'] != null && json['radio'] is! Map) throw const FormatException('Invalid scene radio');
    // A layout places the artwork among native controls; a scroll would leave them stranded.
    if (json['scroll'] != null && (scroll == null || json['layout'] != null)) throw const FormatException('Invalid scene scroll');
    if (scroll case final s? when !values.containsKey(s.value)) throw const FormatException('Unknown scroll value');
    bool reserved(String name) => sceneRadioValues.contains(name) || sceneRadioStrings.contains(name);
    if (values.keys.any(reserved) || strings.keys.any(reserved)) {
      throw const FormatException('A scene value uses a name the host reserves');
    }
    bool known(String name) => values.containsKey(name) || (hasRadio && sceneRadioValues.contains(name));
    bool knownString(String name) => strings.containsKey(name) || (hasRadio && sceneRadioStrings.contains(name));
    // Checked here, the one place that knows whether a name is a number or a string: a test written
    // for the other kind could never pass, and would hide its layer for good.
    void checkWhen(SceneCondition? when, String where) {
      if (when == null) return;
      final fits = knownString(when.value)
          ? when.matches != null && when.matches!.every((m) => m is String)
          : known(when.value) && (when.matches?.every((m) => m is double) ?? true);
      if (!fits) throw FormatException('Invalid when: $where');
    }

    final artwork = layers.fold<int>(0, (n, l) => n + (l.svg?.length ?? 0) + (l.text?.toString().length ?? 0));
    if (artwork > kSceneArtworkMaxChars) {
      throw PanelContentRefusal(
        PanelBudget.characters,
        kSceneArtworkMaxChars,
        'scene artwork and text are $artwork characters in all, at most $kSceneArtworkMaxChars',
      );
    }
    final layerIds = <String>{};
    final fixedLayers = <String>{};
    for (final layer in layers) {
      if (!layerIds.add(layer.id)) throw const FormatException('Duplicate layer ID');
      if (layer.fixed) fixedLayers.add(layer.id);
      for (final binding in layer.bindings.values) {
        if (!known(binding.value)) {
          throw const FormatException('Unknown bound value');
        }
      }
      if (layer.text?['value'] != null && !known(layer.text!['value'] as String) && !knownString(layer.text!['value'] as String)) {
        throw const FormatException('Unknown text value');
      }
      checkWhen(layer.when, layer.id);
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
      if (control.yAxis case final y? when !values.containsKey(y.value)) {
        throw FormatException('Unknown control valueY: ${control.id}');
      }
      if (control.opacityBinding != null && !known(control.opacityBinding!.value)) {
        throw FormatException('Unknown opacity value: ${control.id}');
      }
      checkWhen(control.when, control.id);
      if (control.hoverSet case final hover? when !values.containsKey(hover.value)) {
        throw FormatException('Unknown hoverSet value: ${control.id}');
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
      // Fixed and scrolling are drawn apart: a control can only sit among the layers it moves with.
      if (control.after != null && fixedLayers.contains(control.after) != control.fixed) {
        throw FormatException('Control cannot be placed after a layer that scrolls differently: ${control.id}');
      }
      if (control.fixed && control.rect == null) throw FormatException('A fixed control needs a rect: ${control.id}');
      if (control.kind == 'zoom' && (scroll == null || control.fixed || control.event == null)) {
        throw FormatException('A zoom strip belongs to a scrolling scene, scrolls with it, and sends an event: ${control.id}');
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
  if (raw is! Map<dynamic, dynamic>) throw const FormatException('Invalid scene values');
  if (raw.length > 256) throw _overCount('values', raw.length, 256);
  return {
    for (final key in raw.keys) string({'key': key}, 'key'): number(raw, key as String),
  };
}

Map<String, String> parseStrings(Object? raw) {
  if (raw is! Map<dynamic, dynamic>) throw const FormatException('Invalid scene strings');
  if (raw.length > 256) throw _overCount('strings', raw.length, 256);
  return {
    for (final key in raw.keys) string({'key': key}, 'key'): _boundedString(raw[key]),
  };
}

/// What a text field may hold, so an operator's typing cannot produce a patch
/// the next render refuses.
const sceneStringMaxLength = 4096;

/// What any one string field may hold; a layer's artwork is the one that gets there.
const sceneFieldMaxLength = 262144;

String _boundedString(Object? value) {
  if (value is! String) throw const FormatException('Invalid scene string value');
  if (value.length > sceneStringMaxLength) throw _overLength('string value', value.length, sceneStringMaxLength);
  return value;
}

/// A scene's budgets are refused as such — named to the operator, a line in the
/// console, nothing reported — where a malformed scene is a plain [FormatException].
PanelContentRefusal _overCount(String what, int count, int limit, [PanelBudget budget = PanelBudget.items]) =>
    PanelContentRefusal(budget, limit, 'scene has $count $what, at most $limit');

PanelContentRefusal _overLength(String what, int length, int max) =>
    PanelContentRefusal(PanelBudget.stringLength, max, 'scene $what is $length characters, at most $max');

List<Map<dynamic, dynamic>> items(Object? raw, int limit, {PanelBudget budget = PanelBudget.items, required String what}) {
  if (raw is! List) throw const FormatException('Invalid scene items');
  if (raw.length > limit) throw _overCount(what, raw.length, limit, budget);
  if (raw.any((v) => v is! Map<dynamic, dynamic>)) throw const FormatException('Invalid scene items');
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
  if (value is! String) throw FormatException('Invalid scene string: $key');
  if (value.length > sceneFieldMaxLength) throw _overLength(key, value.length, sceneFieldMaxLength);
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
    final raw = values[value]!;
    var source = raw * scale;
    if (truncate) source = (source + 1e-7).floorToDouble();
    if (modulo != null) source %= modulo!;
    // A radio value with no reading is negative infinity: the bottom of the
    // range, decided before any arithmetic — a negative scale would turn it
    // into the top — and never a NaN that would put a layer nowhere.
    final t = raw == double.negativeInfinity || source.isNaN ? 0.0 : ((source - input[0]) / (input[1] - input[0])).clamp(0.0, 1.0);
    if (samples != null) {
      final position = t * (samples!.length - 1);
      final index = position.floor();
      final next = (index + 1).clamp(0, samples!.length - 1);
      return samples![index] + (samples![next] - samples![index]) * (position - index);
    }
    return output[0] + (output[1] - output[0]) * t;
  }
}

/// A layer's or control's `when`: it is shown only while [value] passes the test — `is` one
/// value, `in` a list of them, or within `min`…`max` — and with [not], only while it fails. A
/// number or a string, the scene's or the host's; [PanelScene] checks the test against which.
///
/// A missing radio number (negative infinity) fails the test itself, before [not] inverts it: a
/// `max` alone never shows a layer for a reading the radio has not given, and `not` shows one only
/// while it is missing. A missing radio word is empty, and is tested as one.
class SceneCondition {
  final String value;
  final List<Object>? matches;
  final double? min, max;
  final bool not;

  SceneCondition(Map<dynamic, dynamic> json)
    : value = string(json, 'value'),
      matches = switch ((json['is'], json['in'])) {
        (null, null) => null,
        (final one?, null) => [_conditionOperand(one)],
        (null, final List<dynamic> many) when many.length > 256 => throw _overCount('when.in entries', many.length, 256),
        (null, final List<dynamic> many) when many.isNotEmpty => many.map(_conditionOperand).toList(),
        _ => throw const FormatException('Invalid scene when: give one of is or in'),
      },
      min = json['min'] == null ? null : number(json, 'min'),
      max = json['max'] == null ? null : number(json, 'max'),
      not = json['not'] == true {
    final ranged = min != null || max != null;
    if ((matches == null) == !ranged) throw const FormatException('Invalid scene when: give is, in, or min and max');
    if (min != null && max != null && min! > max!) throw const FormatException('Invalid scene when range');
  }

  /// Only [PanelScene] says which a value is, so a mismatch is caught there.
  bool holdsOn(Map<String, double> values, Map<String, String> strings) {
    final bool passes;
    if (strings[value] case final text?) {
      passes = matches?.contains(text) ?? false;
    } else {
      final n = values[value] ?? double.negativeInfinity;
      passes = n != double.negativeInfinity && (matches?.contains(n) ?? ((min == null || n >= min!) && (max == null || n <= max!)));
    }
    return passes != not;
  }
}

Object _conditionOperand(Object? v) => switch (v) {
  final String s when s.length > sceneStringMaxLength => throw _overLength('when operand', s.length, sceneStringMaxLength),
  final String s => s,
  final num n when n.isFinite => n.toDouble(),
  _ => throw const FormatException('Invalid scene when operand'),
};

/// Whether a spectrum's frequency rises left or up. Omitted, it rises the
/// way `down` turned a quarter puts it: right for `down` and `up`, up for
/// `right`, down for `left`.
bool _reversed(Map<dynamic, dynamic> json) {
  final across = const ['right', 'left'].contains(json['flow']) ? const ['down', 'up'] : const ['right', 'left'];
  // Each value is valid with some flow, so the error says which this one allows.
  final rising =
      _oneOf(json, 'rising', across, why: 'for flow ${json['flow'] ?? 'down'}, which rises ${across.join(' or ')}') ??
      (json['flow'] == 'right' ? 'up' : across.first);
  return rising == 'left' || rising == 'up';
}

String? _oneOf(Map<dynamic, dynamic> json, String key, List<String> allowed, {String? why}) {
  final value = json[key];
  if (value == null) return null;
  if (!allowed.contains(value)) throw FormatException('Invalid scene $key: $value${why == null ? '' : ' $why'}');
  return value as String;
}

List<double> _bindingSamples(dynamic value) {
  if (value is! List || value.isEmpty || value.any((v) => v is! num || !v.isFinite)) {
    throw const FormatException('Invalid binding samples');
  }
  if (value.length > 4096) throw _overCount('binding samples', value.length, 4096);
  return value.map((v) => (v as num).toDouble()).toList();
}

class SceneLayer {
  final String id;

  final Rect rect;
  final String? svg;
  final Map<dynamic, dynamic>? text;

  /// A named icon (`icon.name`, MDI or `fa-`), drawn by the app at the
  /// layer's size, in `icon.color` or the theme's.
  final ({String name, Color? color})? icon;

  /// Whether the layer takes the clicks that land on it. Off, it is click-
  /// through: artwork drawn over a control does not stop the control working.
  final bool blocksPointer;

  /// In a scrolling scene, drawn over the panel where it is, in panel coordinates, rather than
  /// scrolled with the rest.
  final bool fixed;

  /// While a zoom strip is dragged, scaled along the scroll rather than moved at its size: for a
  /// background, or a line that runs the whole way.
  final bool stretch;
  final Map<String, SceneBinding> bindings;

  /// Drawn only while this holds; see [SceneCondition].
  final SceneCondition? when;
  final Alignment pivot;
  final int transitionMs;
  final Map<dynamic, dynamic>? pulse;
  SceneLayer(Map<dynamic, dynamic> json)
    : id = string(json, 'id'),
      rect = bounds(json),
      blocksPointer = json['blocksPointer'] == true,
      fixed = json['fixed'] == true,
      stretch = json['stretch'] == true,
      svg = json['svg'] == null ? null : string(json, 'svg'),
      text = json['text'] as Map<dynamic, dynamic>?,
      icon = json['icon'] is Map ? _layerIcon(json['icon'] as Map<dynamic, dynamic>) : null,
      bindings = {
        for (final key in ['rotation', 'translateX', 'translateY', 'scaleX', 'scaleY', 'opacity'])
          if (json[key] != null) key: SceneBinding(json[key] as Map<dynamic, dynamic>),
      },
      when = json['when'] == null ? null : SceneCondition(_map(json, 'when')),
      pivot = json['pivot'] == null ? Alignment.center : Alignment(pair(json['pivot'])[0] * 2 - 1, pair(json['pivot'])[1] * 2 - 1),
      transitionMs = number(json, 'transitionMs', fallback: 0, min: 0, max: 10000).round(),
      pulse = json['pulse'] as Map<dynamic, dynamic>? {
    if ([svg, text, json['icon']].nonNulls.length != 1 || (json['icon'] != null && icon == null)) {
      throw const FormatException('Expected SVG, text or an icon');
    }
    if (svg != null) {
      final refusal = svgArtworkRefusal('scene artwork', svg!);
      if (refusal != null) throw refusal;
    }
    if (text != null) {
      final samples = text!['samples'];
      if (samples != null && (samples is! List || samples.isEmpty || samples.any((v) => v is! String && (v is! num || !v.isFinite)))) {
        throw const FormatException('Invalid text samples');
      }
      if (samples is List && samples.length > 4096) throw _overCount('text samples', samples.length, 4096);
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
      if (text!['glow'] != null && !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(string(text!, 'glow'))) {
        throw const FormatException('Invalid text glow');
      }
    }
    if (pulse != null) {
      number(pulse!, 'periodMs', min: 100, max: 60000);
      number(pulse!, 'minOpacity', min: 0, max: 1);
    }
  }

  /// Its opacity, 0 while its [when] fails: a hidden layer is one at 0, so everything that
  /// already treats 0 as gone — a `blocksPointer` letting clicks through — treats it so.
  double opacityAt(Map<String, double> values, Map<String, String> strings) =>
      (when?.holdsOn(values, strings) ?? true) ? (bindings['opacity']?.evaluate(values) ?? 1).clamp(0, 1).toDouble() : 0;
}

Map<dynamic, dynamic> _map(Map<dynamic, dynamic> json, String key) =>
    json[key] is Map ? json[key] as Map<dynamic, dynamic> : throw FormatException('Invalid scene $key');

({String name, Color? color}) _layerIcon(Map<dynamic, dynamic> json) {
  final color = json['color'] == null ? null : string(json, 'color');
  if (color != null && !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) throw const FormatException('Invalid icon color');
  return (name: string(json, 'name'), color: color == null ? null : Color(0xff000000 | int.parse(color.substring(1), radix: 16)));
}

/// What a control kind's `value` names.
enum SceneBinds { number, string, optionalNumber, any, none, unchecked }

/// Drawn by the extension's artwork, with an invisible hit area on top.
// A drawn button's `value` may name anything, or nothing: published scenes do.
// Its event carries what the name resolves to, `text` or `value`, null for none.
const _drawnKinds = {
  'button': SceneBinds.unchecked,
  'slider': SceneBinds.number,
  'knob': SceneBinds.number,
  // A strip of a scrolling scene where a drag along the scroll zooms it about the pane's middle;
  // its event carries the factor, as `value`. Drawn by nothing: it only claims the drag.
  'zoom': SceneBinds.none,
};

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

  /// A knob's drag moves its value the other way: content held under the finger, not a dial.
  final bool invertDrag;

  /// A slider or knob takes the scrolls that land on drawn buttons over it.
  final bool scrollThrough;

  /// A button's click sends where along its longer side it landed: 0 at its
  /// top or left end, 1 at its bottom or right — a scale clicked at a place.
  final bool tapAt;

  /// In a scrolling scene, placed over the panel rather than scrolled; see [SceneLayer.fixed].
  final bool fixed;
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

  /// Shown only while this holds; see [SceneCondition]. A control laid out by `layout` keeps its
  /// place while hidden, as one at opacity 0 does.
  final SceneCondition? when;

  /// Set on a `spectrum` control, and only on one.
  final SceneSpectrumSpec? spectrum;

  /// A drawn control's `hoverSet`: while the pointer is over it, the scene
  /// value [hoverSet.value] reads [hoverSet.to], set by the host with no call
  /// to the extension, so artwork bound to it lights up under the pointer.
  final ({String value, double to})? hoverSet;

  /// A knob's second axis, from `valueY`: vertical motion sets it while
  /// horizontal motion sets [value] — a passband's width and its shift on
  /// one patch of artwork. The same control, with its own value, range, step,
  /// sensitivity and event.
  final SceneControl? yAxis;

  /// Whether this is another control's [yAxis].
  final bool isYAxis;

  SceneControl(Map<dynamic, dynamic> json) : this._parse(json, isYAxis: false);

  SceneControl._parse(Map<dynamic, dynamic> json, {required this.isYAxis})
    : yAxis = isYAxis || json['valueY'] == null
          ? null
          : SceneControl._parse({
              ...json,
              'value': json['valueY'],
              'min': json['minY'],
              'max': json['maxY'],
              'step': json['stepY'],
              'sensitivity': json['sensitivityY'],
              'event': json['eventY'],
            }, isYAxis: true),
      after = json['after'] == null ? null : string(json, 'after'),
      spectrum = json['kind'] == 'spectrum' ? SceneSpectrumSpec(json) : null,
      hoverSet = json['hoverSet'] is Map
          ? (value: string(json['hoverSet'] as Map<dynamic, dynamic>, 'value'), to: number(json['hoverSet'] as Map<dynamic, dynamic>, 'to'))
          : null,
      opacity = json['opacity'] is Map ? 1 : number(json, 'opacity', fallback: 1, min: 0, max: 1),
      opacityBinding = json['opacity'] is Map ? SceneBinding(json['opacity'] as Map<dynamic, dynamic>) : null,
      when = json['when'] == null ? null : SceneCondition(_map(json, 'when')),
      menu = json['menu'] == null
          ? null
          : items(json['menu'], 32, what: 'menu entries').map((m) => (label: string(m, 'label'), event: string(m, 'event'))).toList(),
      options = json['options'] == null
          ? null
          : items(json['options'], 64, what: 'options').map((m) => (label: string(m, 'label'), value: string(m, 'value'))).toList(),
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
      invertDrag = json['invertDrag'] == true,
      scrollThrough = json['scrollThrough'] == true,
      tapAt = json['tapAt'] == true,
      fixed = json['fixed'] == true,
      continuous = json['continuous'] == true,
      discrete = json['discrete'] == true,
      valueLabels = json['valueLabels'] == null ? null : (json['valueLabels'] as List).map((v) => string({'v': v}, 'v')).toList(),
      min = number(json, 'min', fallback: 0),
      max = number(json, 'max', fallback: 1),
      step = number(json, 'step', fallback: 1, min: 1e-9),
      sensitivity = number(json, 'sensitivity', fallback: 1, min: 1e-9) {
    if (valueLabels != null && valueLabels!.length > 4096) throw _overCount('value labels', valueLabels!.length, 4096);
    final choices = options?.map((o) => o.value).toList();
    bool only(Object? field, Set<String> kinds) => field == null || field == false || kinds.contains(kind);
    if ((menu != null && (!const {'button', 'nativeButton', 'knob'}.contains(kind) || menu!.isEmpty)) ||
        (_drawnKinds[kind] ?? _nativeKinds[kind]) == null ||
        min >= max ||
        (hover && (kind != 'slider' || event != null)) ||
        // A zoom's range is the factors it allows, so it must say them.
        (kind == 'zoom' && (json['min'] == null || json['max'] == null || min <= 0)) ||
        // Drawn by nothing, a zoom strip has no place among the layers.
        (kind == 'zoom' && json['after'] != null) ||
        (json['hoverSet'] != null && (json['hoverSet'] is! Map || !_drawnKinds.containsKey(kind))) ||
        (valueLabels != null && valueLabels!.isEmpty) ||
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
        !only(json['invertDrag'], {'knob'}) ||
        !only(json['scrollThrough'], {'slider', 'knob'}) ||
        !only(json['tapAt'], {'button'}) ||
        // A click on a menu's button opens the menu, and one with no event goes nowhere: either way the place is lost.
        (tapAt && (menu != null || event == null)) ||
        (json['valueY'] != null && kind != 'knob') ||
        // An event carries no other mark of which axis moved: the second needs its own.
        (!isYAxis && json['valueY'] != null && json['event'] != null && (json['eventY'] == null || json['eventY'] == json['event'])) ||
        SceneSpectrumSpec.keys.any((key) => !only(json[key], {'spectrum'}))) {
      throw FormatException('Invalid scene control: $id');
    }
  }

  bool get native => _nativeKinds.containsKey(kind);

  /// 0 while its [when] fails, which hides it the way opacity 0 does: no clicks, no focus.
  double opacityAt(Map<String, double> values, Map<String, String> strings) =>
      (when?.holdsOn(values, strings) ?? true) ? (opacityBinding?.evaluate(values) ?? opacity).clamp(0, 1).toDouble() : 0;
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

  /// Decimals of MHz every label shows. Null: as many as tell one label
  /// from the next.
  final int? decimals;
  final String? fontFamily;
  final bool italic;
  final Color? color;

  SceneSpectrumLabels(Map<dynamic, dynamic> json)
    : interval = SceneNumber.parse(json, 'interval', min: 1, max: 1e9),
      size = SceneNumber.parse(json, 'size', min: 4, max: 72),
      weight = SceneNumber.parse(json, 'weight', min: 100, max: 900),
      offset = SceneNumber.parse(json, 'offset', min: -2000, max: 2000),
      decimals = json['decimals'] == null ? null : number(json, 'decimals', min: 0, max: 6).round(),
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
    if (text.length > 256) throw _overLength('annotation $key', text.length, 256);
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
    'gridColor', 'gridDashed', 'waterfallGridColor', 'center', 'overlays', 'scale', 'tuneStep', 'annotations', 'flow', 'rising', 'follow', 'span', //
  ];
  static const palettes = ['classic', 'gray', 'heat'];

  /// A station node's id. Null is the designated radio.
  final String? radio;
  final bool pan, waterfall;

  /// Which way the waterfall moves; the panadapter sits on the side it
  /// comes from. Frequency rises the way [reversed] says.
  final SceneSpectrumFlow flow;

  /// Frequency rises left, or up — `rising`, or for `right` its default —
  /// rather than right, or down.
  final bool reversed;

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

  /// Keeps the tuned frequency at least this share of the width from either
  /// edge by moving the radio's scope — where the radio lets the app move it
  /// and the panel may command the radio. Null: the window is the radio's.
  final double? follow;

  /// Hz shown across the control, from the middle of each sweep: a sweep
  /// wider than this is cropped to it, so a radio whose scope comes in a few
  /// fixed widths can still be shown at any. Null, or wider than the sweep:
  /// the whole sweep.
  final SceneNumber? span;

  SceneSpectrumSpec(Map<dynamic, dynamic> json)
    : radio = json['radio'] == null ? null : string(json, 'radio'),
      flow = SceneSpectrumFlow.values.byName(_oneOf(json, 'flow', const ['down', 'up', 'right', 'left']) ?? 'down'),
      reversed = _reversed(json),
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
      follow = json['follow'] == null ? null : number(json, 'follow', min: 0, max: .45),
      span = SceneNumber.parse(json, 'span', min: 100, max: 1e7),
      annotations = json['annotations'] == null ? const [] : items(json['annotations'], 64, what: 'annotations').map(SceneSpectrumAnnotation.new).toList(),
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
      overlays = json['overlays'] == null ? const [] : items(json['overlays'], 16, what: 'overlays').map(SceneSpectrumMark.new).toList();

  static List<Color> _stops(Object? raw) {
    if (raw is! List || raw.length < 2) throw const FormatException('Invalid scene waterfallColors');
    if (raw.length > 8) throw _overCount('waterfall colors', raw.length, 8);
    return [
      for (var i = 0; i < raw.length; i++) _color({'c': raw[i]}, 'c')!,
    ];
  }

  Iterable<String> get valueNames => [
    for (final n in [floor, range, average, fps, waterfallSpeed, waterfallFloor, waterfallRange, traceWidth, tuneStep, span]) ?n?.value,
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
      if (raw is! Map<dynamic, dynamic>) throw const FormatException('Invalid scene layout');
      if (++count > maxNodes) throw PanelContentRefusal(PanelBudget.items, maxNodes, 'scene layout has more than $maxNodes nodes');
      if (depth > maxDepth) throw PanelContentRefusal(PanelBudget.layoutDepth, maxDepth, 'scene layout nests $depth deep, at most $maxDepth');
      final types = _types.where(raw.containsKey).toList();
      if (types.length != 1) throw const FormatException('A layout node needs exactly one type');
      final type = types.single;
      final children = const {'row', 'column', 'wrap'}.contains(type)
          ? items(raw[type], maxNodes, what: 'layout children').map((c) => node(c, depth + 1, inFlex: type != 'wrap')).toList()
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
