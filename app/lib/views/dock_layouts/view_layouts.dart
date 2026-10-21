// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The named layouts a docked view offers, and which one is on screen
// (docs/design/layouts.md § Named layouts).

import '../../services/settings_service.dart';

/// One named layout: both of a view's arrangements, wide and narrow, under
/// the keys [layoutKey] derives from [id].
class ViewLayout {
  final String id;

  /// Null for the layout every view starts with, which is called whatever
  /// the app's language calls "Default" until the operator renames it.
  final String? name;

  /// The operator's own words for it. Null when they have given none, which
  /// shows as the list of its panels instead — see
  /// `NamedLayouts.layoutDescription`.
  final String? description;

  const ViewLayout({required this.id, this.name, this.description});

  Map<String, dynamic> toJson() => {'id': id, 'name': ?name, 'description': ?description};

  static ViewLayout? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final name = json['name'];
    final description = json['description'];
    return ViewLayout(
      id: id,
      name: name is String && name.isNotEmpty ? name : null,
      description: description is String && description.isNotEmpty ? description : null,
    );
  }
}

/// The list of a view's named layouts, stored under `<view>.layouts`.
///
/// The first layout a view ever had is [defaultId], and its keys are the
/// view's original unsuffixed ones — so an arrangement saved before there
/// were named layouts IS the default layout, with nothing to migrate. Every
/// other layout suffixes those keys with `@<id>` (see [layoutKey]).
class ViewLayouts {
  static const defaultId = 'default';

  /// Which layout the view draws. Always one of [layouts].
  final String active;

  /// Never empty: a view with no layout has nothing to draw.
  final List<ViewLayout> layouts;

  /// Whether [read] had to rebuild the list from the keys the layouts
  /// store under — the stored list was unreadable, and the layouts' names
  /// went with it.
  final bool recovered;

  const ViewLayouts({required this.active, required this.layouts, this.recovered = false});

  static const initial = ViewLayouts(
    active: defaultId,
    layouts: [ViewLayout(id: defaultId)],
  );

  static String storageKey(String view) => '$view.layouts';

  /// The settings key [baseKey] (one of a view's [LayoutKeys]) has in the
  /// layout [layoutId].
  static String layoutKey(String baseKey, String layoutId) => layoutId == defaultId ? baseKey : '$baseKey@$layoutId';

  /// The list stored for [view]. Where it is unreadable, every layout whose
  /// keys still hold something is listed again, unnamed: those keys outlive
  /// the list, and a list that forgot them would hand their ids to new
  /// layouts, which empty a key before taking it.
  ///
  /// A missing list is a view with only the default layout — the list and
  /// the keys are one stored map, and one is never lost without the other.
  /// Not scanned for, either: that is every view the operator has not made a
  /// second layout in, and the scan decodes the whole map.
  static ViewLayouts read(SettingsService settings, String view) {
    final json = settings.layoutData(storageKey(view));
    if (json == null) return initial;
    if (fromJson(json) case final layouts?) return layouts;
    final ids = <String>{
      for (final key in settings.jsonMapPref(SettingsService.layoutPrefsKey).keys)
        if (key.startsWith('$view.') && key.contains('@') && (settings.layoutData(key)?.isNotEmpty ?? false)) key.substring(key.lastIndexOf('@') + 1),
    };
    return ViewLayouts(
      active: defaultId,
      layouts: [
        const ViewLayout(id: defaultId),
        for (final id in ids.toList()..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0))) ViewLayout(id: id),
      ],
      recovered: true,
    );
  }

  Future<void> write(SettingsService settings, String view) => settings.setLayoutData(storageKey(view), toJson());

  Map<String, dynamic> toJson() => {
    'active': active,
    'layouts': [for (final layout in layouts) layout.toJson()],
  };

  /// Null for anything unreadable — see [read].
  static ViewLayouts? fromJson(Object? json) {
    if (json is! Map) return null;
    final seen = <String>{};
    final layouts = [
      for (final entry in json['layouts'] is List ? json['layouts'] as List : const [])
        if (ViewLayout.fromJson(entry) case final layout? when seen.add(layout.id)) layout,
    ];
    if (layouts.isEmpty) return null;
    final active = json['active'];
    return ViewLayouts(active: layouts.any((layout) => layout.id == active) ? active as String : layouts.first.id, layouts: layouts);
  }

  ViewLayout get activeLayout => layouts.firstWhere((layout) => layout.id == active);

  ViewLayout? operator [](String id) => layouts.where((layout) => layout.id == id).firstOrNull;

  /// An id no layout of this view holds. Numbered, like a panel instance:
  /// it ends up in settings keys, where readable beats unguessable.
  String nextId() {
    for (var i = 2; ; i++) {
      final candidate = '$i';
      if (this[candidate] == null) return candidate;
    }
  }

  ViewLayouts copyWith({String? active, List<ViewLayout>? layouts}) => ViewLayouts(active: active ?? this.active, layouts: layouts ?? this.layouts);

  ViewLayouts edited(String id, {required String name, String? description}) => copyWith(
    layouts: [for (final layout in layouts) layout.id == id ? ViewLayout(id: id, name: name, description: description) : layout],
  );

  /// Without [id], drawing the first remaining layout if [id] was on screen.
  /// The caller refuses to remove the last one.
  ViewLayouts without(String id) {
    final remaining = [
      for (final layout in layouts)
        if (layout.id != id) layout,
    ];
    return ViewLayouts(active: active == id ? remaining.first.id : active, layouts: remaining);
  }
}
