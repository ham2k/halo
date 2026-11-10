// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'scene_model.dart';

/// What a rotator source gives, as numbers: where it points, where it was told to turn, whether it
/// is turning there (1 or 0), and whether it is connected (1 or 0).
const sceneRotatorValues = {'azimuth', 'elevation', 'targetAzimuth', 'moving', 'connected'};

/// A live source a scene names in `sources`: a radio (its node id, or null for the designated
/// radio), a rotator or an antenna switch (each by its id). The host feeds its readings into the
/// values and strings under the source's name, with no render and no bridge call.
class SceneSource {
  static const kinds = ['radio', 'rotator', 'antennaSwitch'];
  static const maxSources = 16;
  static final _name = RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,31}$');

  final String kind;
  final String? id;

  SceneSource._(this.kind, this.id);

  static Map<String, SceneSource> parse(Object? raw) {
    if (raw == null) return const {};
    if (raw is! Map<dynamic, dynamic>) throw const FormatException('Invalid scene sources');
    if (raw.length > maxSources) throw _overCount('sources', raw.length, maxSources);
    return {for (final MapEntry(:key, :value) in raw.entries) _sourceName(key): _source(key as String, value)};
  }

  static String _sourceName(Object? name) {
    // `radio` is the scene's own unnamed source, whose names are reserved already.
    if (name is! String || !_name.hasMatch(name) || name == 'radio') throw FormatException('Invalid scene source name: $name');
    return name;
  }

  static SceneSource _source(String name, Object? raw) {
    if (raw is! Map<dynamic, dynamic>) throw FormatException('Invalid scene source: $name');
    final named = kinds.where(raw.containsKey).toList();
    if (named.length != 1 || raw.length != 1) throw FormatException('A scene source is one of ${kinds.join(', ')}: $name');
    final kind = named.single;
    final id = raw[kind];
    if (id == null && kind == 'radio') return SceneSource._(kind, null);
    if (id is! String || id.isEmpty) throw FormatException('Invalid scene source id: $name');
    return SceneSource._(kind, id);
  }

  /// Whether this source gives the number [rest] names, the part of a value's name after the
  /// source's own: a radio's are the `radio.` values, a rotator's [sceneRotatorValues], a switch's
  /// `connected` and each port's `<port>.auto`. A switch names its ports by its own keys, which a
  /// scene cannot know ahead, so any port is accepted and one the switch lacks reads as missing.
  bool givesNumber(String rest) => switch (kind) {
    'radio' => sceneRadioValues.contains('radio.$rest'),
    'rotator' => sceneRotatorValues.contains(rest),
    _ => rest == 'connected' || _portField(rest, const {'auto'}),
  };

  /// As [givesNumber], for words: a radio's `radio.` strings, a switch port's `<port>.antenna`
  /// (the antenna's key) and `<port>.antennaName`.
  bool givesString(String rest) => switch (kind) {
    'radio' => sceneRadioStrings.contains('radio.$rest'),
    'rotator' => false,
    _ => _portField(rest, const {'antenna', 'antennaName'}),
  };

  static bool _portField(String rest, Set<String> fields) {
    final dot = rest.lastIndexOf('.');
    return dot > 0 && fields.contains(rest.substring(dot + 1));
  }
}

extension SceneSourceNames on PanelScene {
  /// The source [name] falls under, and the rest of the name after it, or null for a scene's own.
  ({String source, String rest})? sourceOf(String name) {
    final dot = name.indexOf('.');
    if (dot <= 0) return null;
    final source = name.substring(0, dot);
    return sources.containsKey(source) ? (source: source, rest: name.substring(dot + 1)) : null;
  }

  /// Whether [name] is fed by the host — the `radio` block's or a named source's — so a patch from
  /// the extension may not set it: shown, it would claim a reading the device has not given.
  bool isHostValue(String name) => sceneRadioValues.contains(name) || sceneRadioStrings.contains(name) || sourceOf(name) != null;

  /// A band scope's `radio`, which may name a radio source: the node to resolve, or the name as given.
  String? radioNodeFor(String? radio) => switch (sources[radio]) {
    SceneSource(kind: 'radio', :final id) => id,
    _ => radio,
  };
}
