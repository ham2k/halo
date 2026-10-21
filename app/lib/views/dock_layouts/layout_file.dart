// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A layout as a file: one or both of a view's arrangements, or any part of
// one, written as YAML that names PANELS rather than placements
// (docs/design/layouts.md § Layout files).

import 'package:flutter/painting.dart' show Axis;
import 'package:halo_widgets/halo_widgets.dart';
import 'package:yaml/yaml.dart';

import '../../services/panel_service.dart' show PanelDefinition, PanelService;
import '../dock_host.dart' show DockLayoutClass;
import '../operation/pane_layout_options.dart';
import 'yaml_writer.dart' as yaml_writer;

/// The top-level key that marks a layout file, and the format version it
/// carries. A reader refuses a version it does not know rather than guessing
/// at a shape that was never written for it.
const layoutFileMarker = 'ham2k-layout';
const layoutFileVersion = 1;

/// Where an imported layout goes: a layout of its own, in place of the one on
/// screen, or beside what the one on screen already holds.
enum LayoutImportMode { newLayout, replace, add }

/// Why a file is not a layout this version can read — what the operator is
/// told, in their language.
enum LayoutFileProblem { notYaml, notLayoutFile, newerVersion, noArrangement, malformed, tooLarge }

class LayoutFileException implements Exception {
  final LayoutFileProblem problem;

  /// The line the YAML parser stopped at, for [LayoutFileProblem.notYaml].
  final int? line;

  /// Which part of the file, in English: for the console, never the screen.
  final String detail;

  const LayoutFileException(this.problem, this.detail, {this.line});

  @override
  String toString() => '${problem.name}: $detail';
}

/// One tab: a panel, or a container holding a subtree of its own.
class LayoutFileTab {
  /// The panel's DESCRIPTOR id — `#n` is a slot in this device's config
  /// store, which means nothing on the device that reads the file.
  final String? panel;

  /// Whether the placement was one of several instances of [panel]. Read on
  /// import only when the catalog cannot say (the panel's extension is not
  /// installed), so that a placement of a panel that allows several still
  /// gets an id of its own.
  final bool instance;

  final LayoutFileNode? container;

  /// [PaneLayoutOptions] as JSON.
  final Map<String, dynamic> options;

  /// The panel's own form values.
  final Map<String, dynamic> settings;

  const LayoutFileTab({this.panel, this.instance = false, this.container, this.options = const {}, this.settings = const {}});

  Map<String, dynamic> toJson() => {
    if (container case final node?) 'container': node.toJson() else 'panel': panel,
    if (instance) 'instance': true,
    if (options.isNotEmpty) 'options': options,
    if (settings.isNotEmpty) 'settings': settings,
  };
}

sealed class LayoutFileNode {
  Map<String, dynamic> toJson();

  static LayoutFileNode fromJson(Object? json) {
    if (json is! Map) throw const LayoutFileException(LayoutFileProblem.malformed, 'a layout node is not a map');
    if (json['tabs'] case final List<dynamic> tabs) {
      if (tabs.isEmpty) throw const LayoutFileException(LayoutFileProblem.malformed, 'a tab group has no tabs');
      return LayoutFileGroup([for (final tab in tabs) _tabFromJson(tab)]);
    }
    if (json['split'] case final String axis) {
      final children = [for (final child in json['children'] is List ? json['children'] as List : const []) fromJson(child)];
      if (children.isEmpty) throw const LayoutFileException(LayoutFileProblem.malformed, 'a split has no children');
      final weights = json['weights'] is List ? (json['weights'] as List).whereType<num>().map((w) => w.toDouble()).toList() : null;
      final valid = weights != null && weights.length == children.length && weights.every((w) => w.isFinite && w > 0);
      return LayoutFileSplit(axis == 'vertical' ? Axis.vertical : Axis.horizontal, children, valid ? weights : List.filled(children.length, 1));
    }
    throw const LayoutFileException(LayoutFileProblem.malformed, 'a layout node is neither "tabs" nor "split"');
  }

  static LayoutFileTab _tabFromJson(Object? json) {
    if (json is! Map) throw const LayoutFileException(LayoutFileProblem.malformed, 'a tab is not a map');
    final options = _stringMap(json['options']);
    final settings = _stringMap(json['settings']);
    if (json.containsKey('container')) return LayoutFileTab(container: fromJson(json['container']), options: options);
    final panel = json['panel'];
    if (panel is! String || panel.isEmpty) throw const LayoutFileException(LayoutFileProblem.malformed, 'a tab names no panel');
    return LayoutFileTab(panel: PanelDefinition.descriptorIdOf(panel), instance: json['instance'] == true, options: options, settings: settings);
  }
}

class LayoutFileGroup extends LayoutFileNode {
  final List<LayoutFileTab> tabs;
  LayoutFileGroup(this.tabs);

  @override
  Map<String, dynamic> toJson() => {
    'tabs': [for (final tab in tabs) tab.toJson()],
  };
}

class LayoutFileSplit extends LayoutFileNode {
  final Axis axis;
  final List<LayoutFileNode> children;
  final List<double> weights;
  LayoutFileSplit(this.axis, this.children, this.weights);

  @override
  Map<String, dynamic> toJson() => {
    'split': axis == Axis.vertical ? 'vertical' : 'horizontal',
    'weights': weights,
    'children': [for (final child in children) child.toJson()],
  };
}

/// One arrangement: its tree and the view's own options.
class LayoutFileArrangement {
  final LayoutFileNode root;
  final Map<String, dynamic> viewOptions;

  const LayoutFileArrangement({required this.root, this.viewOptions = const {}});

  Map<String, dynamic> toJson() => {if (viewOptions.isNotEmpty) 'options': viewOptions, 'root': root.toJson()};

  static LayoutFileArrangement fromJson(Object? json) {
    if (json is! Map) throw const LayoutFileException(LayoutFileProblem.malformed, 'an arrangement is not a map');
    return LayoutFileArrangement(root: LayoutFileNode.fromJson(json['root']), viewOptions: _stringMap(json['options']));
  }

  /// [spec] as a file arrangement, keeping only the panes [keep] accepts —
  /// every pane when null. Null when nothing is kept.
  ///
  /// [settingsFor] supplies a placement's form values; it is asked once per
  /// kept pane, and an empty answer writes nothing.
  static LayoutFileArrangement? fromDock(
    DockNode spec, {
    required Map<String, PaneLayoutOptions> paneOptions,
    required PaneLayoutOptions viewOptions,
    required Map<String, dynamic> Function(String id) settingsFor,
    bool Function(String id)? keep,
  }) {
    final pruned = keep == null ? spec : spec.where(keep);
    if (pruned == null) return null;
    LayoutFileNode convert(DockNode node) => switch (node) {
      DockSplit(:final axis, :final children, :final weights) => LayoutFileSplit(axis, [for (final c in children) convert(c)], List.of(weights)),
      DockGroup(:final modules, :final nested) => LayoutFileGroup([
        for (final slot in modules)
          if (nested[slot] case final subtree?)
            LayoutFileTab(container: convert(subtree), options: paneOptions[slot]?.toJson() ?? const {})
          else
            LayoutFileTab(
              panel: PanelDefinition.descriptorIdOf(slot),
              instance: PanelDefinition.descriptorIdOf(slot) != slot,
              options: paneOptions[slot]?.toJson() ?? const {},
              settings: settingsFor(slot),
            ),
      ]),
    };
    return LayoutFileArrangement(root: convert(pruned), viewOptions: viewOptions.toJson());
  }

  /// This arrangement with only the panel tabs [keep] accepts, in the same
  /// canonical shape [DockNode.where] leaves a dock tree. Null when none are.
  LayoutFileArrangement? pruned(bool Function(LayoutFileTab tab) keep) {
    LayoutFileNode? prune(LayoutFileNode node) {
      switch (node) {
        case LayoutFileSplit(:final axis, :final children, :final weights):
          return _keptSplit(children, weights, prune, (kept, keptWeights) => LayoutFileSplit(axis, kept, keptWeights));
        case LayoutFileGroup(:final tabs):
          final kept = <LayoutFileTab>[];
          for (final tab in tabs) {
            if (tab.container case final inner?) {
              if (prune(inner) case final innerKept?) kept.add(LayoutFileTab(container: innerKept, options: tab.options));
            } else if (keep(tab)) {
              kept.add(tab);
            }
          }
          return kept.isEmpty ? null : LayoutFileGroup(kept);
      }
    }

    final root = prune(this.root);
    return root == null ? null : LayoutFileArrangement(root: root, viewOptions: viewOptions);
  }

  /// Every panel descriptor this arrangement places, in visual order.
  List<String> get panels {
    final result = <String>[];
    void walk(LayoutFileNode node) {
      switch (node) {
        case LayoutFileSplit(:final children):
          children.forEach(walk);
        case LayoutFileGroup(:final tabs):
          for (final tab in tabs) {
            if (tab.container case final inner?) {
              walk(inner);
            } else {
              result.add(tab.panel!);
            }
          }
      }
    }

    walk(root);
    return result;
  }

  /// This arrangement as a dock tree with ids of this device's own.
  ///
  /// - A panel that allows several placements ([isMultiple]) gets a fresh
  ///   instance id — none of [takenIds], none handed out earlier in this call
  ///   — so its settings land in a slot nothing else is storing under.
  /// - A panel placed once keeps its plain id, and is SKIPPED when it is in
  ///   [presentIds] already or appears twice in the file: a module listed
  ///   twice hands one widget to two tabs.
  /// - A container gets a `nested#n` id clear of [takenContainerIds].
  /// - A panel [isOffered] refuses (another view's native pane) is skipped.
  ///
  /// [MaterializedArrangement.spec] is null when nothing is left to place,
  /// and its [MaterializedArrangement.skipped] still says what was there.
  MaterializedArrangement materialize({
    required bool Function(String descriptorId, {required bool fileSaysInstance}) isMultiple,
    required bool Function(String descriptorId) isOffered,
    Iterable<String> takenIds = const [],
    Iterable<String> presentIds = const [],
    Iterable<String> takenContainerIds = const [],
  }) {
    final taken = {...takenIds, ...presentIds};
    // Apart from [taken]: an id another LAYOUT holds is only unavailable to
    // an instance, whose id is a config slot. A panel placed once is the same
    // panel in every layout, and is refused only where THIS tree has it.
    final placed = {...presentIds};
    final takenContainers = {...takenContainerIds};
    final paneOptions = <String, PaneLayoutOptions>{};
    final settings = <String, Map<String, dynamic>>{};
    final skipped = <String>[];
    String newContainerId() {
      var n = 1;
      while (takenContainers.contains('$dockContainerIdBase#$n')) {
        n++;
      }
      final id = '$dockContainerIdBase#$n';
      takenContainers.add(id);
      return id;
    }

    DockNode? build(LayoutFileNode node) {
      switch (node) {
        case LayoutFileSplit(:final axis, :final children, :final weights):
          return _keptSplit(children, weights, build, (kept, keptWeights) => DockSplit(axis, kept, keptWeights));
        case LayoutFileGroup(:final tabs):
          final modules = <String>[];
          final nested = <String, DockNode>{};
          for (final tab in tabs) {
            final String id;
            if (tab.container case final inner?) {
              final subtree = build(inner);
              if (subtree == null) continue;
              id = newContainerId();
              nested[id] = subtree;
            } else {
              final descriptor = tab.panel!;
              if (!isOffered(descriptor)) {
                skipped.add(descriptor);
                continue;
              }
              if (isMultiple(descriptor, fileSaysInstance: tab.instance)) {
                id = PanelService.nextInstanceId(descriptor, taken);
              } else if (placed.contains(descriptor)) {
                skipped.add(descriptor);
                continue;
              } else {
                id = descriptor;
              }
              taken.add(id);
              placed.add(id);
              if (tab.settings.isNotEmpty) settings[id] = tab.settings;
            }
            modules.add(id);
            final options = PaneLayoutOptions.fromJson(tab.options);
            if (!options.isEmpty) paneOptions[id] = options;
          }
          if (modules.isEmpty) return null;
          return DockGroup(modules, nested: nested)..collapseNested();
      }
    }

    final spec = build(root);
    // `collapseNested` can retire a container whose subtree came down to one
    // pane; its options describe nothing now.
    final live = {...?spec?.collectModules(), ...?spec?.collectContainerIds()};
    paneOptions.removeWhere((id, _) => !live.contains(id));
    return MaterializedArrangement(
      spec: spec,
      paneOptions: paneOptions,
      viewOptions: PaneLayoutOptions.fromJson(viewOptions),
      settings: settings,
      skipped: skipped,
    );
  }
}

/// A file arrangement made into this device's own: what [LayoutFileArrangement.materialize] returns.
class MaterializedArrangement {
  /// Null when the file placed nothing this arrangement can hold.
  final DockNode? spec;
  final Map<String, PaneLayoutOptions> paneOptions;
  final PaneLayoutOptions viewOptions;

  /// Form values to store, keyed by the placement's NEW id.
  final Map<String, Map<String, dynamic>> settings;

  /// Panel descriptors the file placed that this arrangement does not.
  final List<String> skipped;

  const MaterializedArrangement({required this.spec, required this.paneOptions, required this.viewOptions, required this.settings, required this.skipped});
}

/// An extension a layout file's panels come from — enough to find it in the
/// catalog on a device that does not have it.
class LayoutFileExtension {
  final String key;
  final String? name;
  const LayoutFileExtension({required this.key, this.name});

  Map<String, dynamic> toJson() => {'key': key, 'name': ?name};
}

class LayoutFile {
  /// The view the layout was exported from — a [PanelViews] value.
  final String? view;
  final String? name;
  final String? description;
  final List<LayoutFileExtension> extensions;
  final Map<DockLayoutClass, LayoutFileArrangement> arrangements;

  const LayoutFile({this.view, this.name, this.description, this.extensions = const [], required this.arrangements});

  String toYaml() => '# Ham2K Logger layout\n${yaml_writer.toYaml(toJson())}';

  Map<String, dynamic> toJson() => {
    layoutFileMarker: layoutFileVersion,
    'view': ?view,
    'name': ?name,
    'description': ?description,
    if (extensions.isNotEmpty) 'extensions': [for (final extension in extensions) extension.toJson()],
    for (final entry in arrangements.entries) entry.key.name: entry.value.toJson(),
  };

  /// Throws [LayoutFileException] for anything that is not a layout file this
  /// version can read.
  static LayoutFile parse(String text) {
    try {
      return _parse(text);
    } on StackOverflowError {
      // Block nesting, which [_nestsTooDeep] does not count: one line of
      // `- - - …` a hundred thousand deep runs the parser out of stack, and
      // an Error is nothing the import catches.
      throw const LayoutFileException(LayoutFileProblem.tooLarge, 'nested too deeply to read');
    }
  }

  static LayoutFile _parse(String text) {
    final Object? document;
    try {
      if (_nestsTooDeep(text)) throw const LayoutFileException(LayoutFileProblem.tooLarge, 'nested more than $_maxLayoutFileDepth deep');
      document = _plainJson(loadYaml(text), _NodeBudget());
    } on YamlException catch (e) {
      throw LayoutFileException(LayoutFileProblem.notYaml, e.message, line: e.span == null ? null : e.span!.start.line + 1);
    }
    if (document is! Map) throw const LayoutFileException(LayoutFileProblem.notLayoutFile, 'the document is not a map');
    final version = document[layoutFileMarker];
    if (version is! int) throw const LayoutFileException(LayoutFileProblem.notLayoutFile, 'no "$layoutFileMarker" version');
    if (version > layoutFileVersion) throw LayoutFileException(LayoutFileProblem.newerVersion, 'format $version');
    final arrangements = {
      for (final layoutClass in DockLayoutClass.values)
        if (document[layoutClass.name] != null) layoutClass: LayoutFileArrangement.fromJson(document[layoutClass.name]),
    };
    if (arrangements.isEmpty) throw const LayoutFileException(LayoutFileProblem.noArrangement, 'the file holds no arrangement');
    return LayoutFile(
      view: document['view'] is String ? document['view'] as String : null,
      name: document['name'] is String ? document['name'] as String : null,
      description: document['description'] is String ? document['description'] as String : null,
      extensions: [
        for (final entry in document['extensions'] is List ? document['extensions'] as List : const [])
          if (entry is Map && entry['key'] is String)
            LayoutFileExtension(key: entry['key'] as String, name: entry['name'] is String ? entry['name'] as String : null),
      ],
      arrangements: arrangements,
    );
  }
}

/// A split's [children] that [map] keeps, with their [weights], in the shape
/// [DockNode.where] gives a dock tree: null when none are kept, the one child
/// in place of a split of one, otherwise [split] of the rest.
O? _keptSplit<I, O>(List<I> children, List<double> weights, O? Function(I child) map, O Function(List<O> kept, List<double> weights) split) {
  final kept = <O>[];
  final keptWeights = <double>[];
  for (var i = 0; i < children.length; i++) {
    if (map(children[i]) case final child?) {
      kept.add(child);
      keptWeights.add(weights[i]);
    }
  }
  if (kept.isEmpty) return null;
  if (kept.length == 1) return kept.single;
  return split(kept, keptWeights);
}

Map<String, dynamic> _stringMap(Object? json) => json is Map ? {for (final e in json.entries) '${e.key}': e.value} : const {};

/// How many values a layout file may hold once its aliases are expanded —
/// far past any layout, far short of what stalls the app.
const _maxLayoutFileNodes = 100000;

class _NodeBudget {
  var _left = _maxLayoutFileNodes;

  void spend() {
    if (--_left < 0) throw const LayoutFileException(LayoutFileProblem.tooLarge, 'more than $_maxLayoutFileNodes values');
  }
}

/// How deep a layout file's brackets may nest — far past any layout.
const _maxLayoutFileDepth = 200;

/// Whether [text]'s `[` and `{` nest deeper than [_maxLayoutFileDepth],
/// checked before the parser sees it: its time grows with the square of the
/// depth, and a line of a hundred thousand brackets holds the app for
/// seconds. Counted with no regard for quoting, so an upper bound — the
/// layout writer nests by indentation, and a name's brackets are never two
/// hundred left open.
bool _nestsTooDeep(String text) {
  var depth = 0;
  for (final unit in text.codeUnits) {
    if (unit == 0x5B || unit == 0x7B) {
      if (++depth > _maxLayoutFileDepth) return true;
    } else if ((unit == 0x5D || unit == 0x7D) && depth > 0) {
      depth--;
    }
  }
  return false;
}

/// `package:yaml`'s nodes as plain maps and lists, so nothing downstream
/// meets a `YamlMap` that refuses to be written to.
///
/// Counted against [budget]: an alias is one node the parser hands back
/// wherever it is named, and copying it out copies it every time. Ten
/// levels of ten aliases each is a line of text per level and ten billion
/// values to copy.
Object? _plainJson(Object? node, _NodeBudget budget) {
  budget.spend();
  return switch (node) {
    final Map<dynamic, dynamic> map => {for (final e in map.entries) '${e.key}': _plainJson(e.value, budget)},
    final List<dynamic> list => [for (final item in list) _plainJson(item, budget)],
    _ => node,
  };
}
