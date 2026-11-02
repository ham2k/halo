// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The folders an operator files their sets in — CW messages, voice
// messages, and whatever else is kept as named sets. Beside the sets rather
// than inside them: a kind of set knows nothing about folders, and a set
// that is in no folder is simply at the top, which is where every set an
// install already has stays.

import 'package:halo_core/halo_core.dart' show uuidGenerator;

class SetFolder {
  final String id;
  final String name;

  /// The folder this one is in; null for the top level.
  final String? parent;

  const SetFolder({required this.id, required this.name, this.parent});

  static SetFolder? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'], parent = json['parent'];
    if (id is! String || id.isEmpty) return null;
    return SetFolder(id: id, name: name is String && name.trim().isNotEmpty ? name : '?', parent: parent is String && parent.isNotEmpty ? parent : null);
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'parent': ?parent};
}

/// One line of a tree laid out for a list: a folder, or a set, at [depth].
sealed class SetTreeRow {
  final int depth;
  const SetTreeRow(this.depth);
}

class SetTreeFolderRow extends SetTreeRow {
  final SetFolder folder;
  const SetTreeFolderRow(this.folder, super.depth);
}

class SetTreeSetRow extends SetTreeRow {
  final String id;
  const SetTreeSetRow(this.id, super.depth);
}

/// The folders, and which folder each set is in. Immutable: every edit
/// returns a new tree, written whole.
class SetTree {
  final List<SetFolder> folders;

  /// Set id → folder id. A set not named here is at the top level, and so is
  /// one whose folder is gone — a stale entry costs nothing and loses no set.
  final Map<String, String> placement;

  const SetTree({this.folders = const [], this.placement = const {}});

  SetTree _with({List<SetFolder>? folders, Map<String, String>? placement}) =>
      SetTree(folders: folders ?? this.folders, placement: placement ?? this.placement);

  static SetTree fromJson(Object? json) {
    if (json is! Map) return const SetTree();
    final folders = [
      if (json['folders'] case final List<dynamic> list)
        for (final entry in list) ?SetFolder.fromJson(entry),
    ];
    final ids = {for (final folder in folders) folder.id};
    return SetTree(
      // A folder whose parent is gone, or that is its own ancestor, is at
      // the top: anything else and it, and every set in it, drops out of
      // the list.
      folders: [for (final folder in folders) _reachable(folder, folders, ids) ? folder : SetFolder(id: folder.id, name: folder.name)],
      placement: {
        if (json['placement'] case final Map<dynamic, dynamic> map)
          for (final MapEntry(:key, :value) in map.entries)
            if (key is String && value is String && ids.contains(value)) key: value,
      },
    );
  }

  static bool _reachable(SetFolder folder, List<SetFolder> folders, Set<String> ids) {
    final seen = <String>{folder.id};
    var parent = folder.parent;
    while (parent != null) {
      if (!ids.contains(parent) || !seen.add(parent)) return false;
      parent = folders.firstWhere((f) => f.id == parent).parent;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
    'folders': [for (final folder in folders) folder.toJson()],
    'placement': placement,
  };

  SetFolder? folder(String? id) => id == null ? null : folders.where((f) => f.id == id).firstOrNull;

  /// The folder set [setId] is in, null for the top level.
  String? folderOf(String setId) => folder(placement[setId])?.id;

  /// [folderId] and every folder inside it, however deep.
  Set<String> folderAndDescendants(String folderId) {
    final found = {folderId};
    var grew = true;
    while (grew) {
      grew = false;
      for (final folder in folders) {
        if (folder.parent != null && found.contains(folder.parent) && found.add(folder.id)) grew = true;
      }
    }
    return found;
  }

  /// The path from the top to [folderId], names only — what a "move to"
  /// list says each folder is.
  List<String> pathOf(String folderId) {
    final names = <String>[];
    for (var f = folder(folderId); f != null; f = folder(f.parent)) {
      names.insert(0, f.name);
    }
    return names;
  }

  (SetTree, SetFolder) addFolder(String name, {String? parent}) {
    final created = SetFolder(id: uuidGenerator.v4(), name: name, parent: folder(parent)?.id);
    return (_with(folders: [...folders, created]), created);
  }

  SetTree renameFolder(String id, String name) => _with(
    folders: [for (final f in folders) f.id == id ? SetFolder(id: f.id, name: name, parent: f.parent) : f],
  );

  /// Moves folder [id] into [parent] (null: the top). A folder never moves
  /// into itself or its own descendants — that would cut it off the tree.
  SetTree moveFolder(String id, String? parent) {
    if (parent != null && folderAndDescendants(id).contains(parent)) return this;
    return _with(
      folders: [for (final f in folders) f.id == id ? SetFolder(id: f.id, name: f.name, parent: parent) : f],
    );
  }

  /// Removes folder [id]; what was in it — sets and folders — moves up to
  /// where the folder was. A folder is a way of filing sets, and losing one
  /// never takes a set with it.
  SetTree deleteFolder(String id) {
    final gone = folder(id);
    if (gone == null) return this;
    return _with(
      folders: [
        for (final f in folders)
          if (f.id != id) f.parent == id ? SetFolder(id: f.id, name: f.name, parent: gone.parent) : f,
      ],
      placement: {
        for (final MapEntry(:key, :value) in placement.entries)
          if (value != id) key: value else if (gone.parent != null) key: gone.parent!,
      },
    );
  }

  SetTree moveSet(String setId, String? folderId) => _with(
    placement: {
      for (final MapEntry(:key, :value) in placement.entries)
        if (key != setId) key: value,
      if (folder(folderId) != null) setId: folderId!,
    },
  );

  /// Drops set [setId]'s entry — for a set that was deleted.
  SetTree forgetSet(String setId) => moveSet(setId, null);

  /// [setIds], in the order given, laid out as a list: the top level's sets
  /// first, then each folder — by name — with its sets and its own folders
  /// under it, one [SetTreeRow.depth] further in. Every set appears exactly
  /// once; every folder appears, empty or not, so one just made is there to
  /// move sets into.
  ///
  /// With [open], a folder not in it has its row and nothing under it.
  List<SetTreeRow> rows(List<String> setIds, {Set<String>? open}) {
    final out = <SetTreeRow>[];
    void walk(String? folderId, int depth) {
      for (final id in setIds) {
        if (folderOf(id) == folderId) out.add(SetTreeSetRow(id, depth));
      }
      final children = [
        for (final f in folders)
          if (f.parent == folderId) f,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (final child in children) {
        out.add(SetTreeFolderRow(child, depth));
        if (open == null || open.contains(child.id)) walk(child.id, depth + 1);
      }
    }

    walk(null, 0);
    return out;
  }
}
