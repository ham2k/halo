// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A kind of named set, as the set picker and the set manager see it. Each
// kind — CW messages, voice messages — says how its sets are stored, copied,
// deleted and written to a file; the picker and the manager are written once,
// against this.

import 'package:flutter/foundation.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:yaml/yaml.dart';

import '../../views/dock_layouts/yaml_reader.dart';
import '../key_bindings_file.dart' show keyBindingsFileMarker;
import '../settings_service.dart';
import 'set_tree.dart';

/// A set as a list shows it.
typedef SetSummary = ({String id, String name});

/// A set written out as a file — text or bytes, as the kind's format is.
typedef SetFileOut = ({String filename, Object content, String mimeType});

/// What a kind's files are called, for the import picker.
typedef SetFileType = ({String label, List<String> extensions, List<String> mimeTypes});

/// Why a file is not a set this version of the kind can read — what the
/// operator is told.
enum SetFileProblem { unreadable, wrongKind, newerVersion, malformed }

class SetFileException implements Exception {
  final SetFileProblem problem;

  /// In English, for the console — never the screen.
  final String detail;

  const SetFileException(this.problem, this.detail);

  @override
  String toString() => '${problem.name}: $detail';
}

/// The top-level key that marks a set file, and the version it carries. A
/// reader refuses a version it does not know rather than guessing at it.
const setFileMarker = 'ham2k-set';
const setFileVersion = 1;

/// [name] as a file name can hold it — a slash would be taken as a folder.
String setFileStem(String prefix, String name) {
  final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-').trim();
  return safe.isEmpty ? prefix : '$prefix $safe';
}

/// [fields] under the header every kind's file starts with — the marker,
/// its version, and the [kind].
Map<String, Object?> setFileDocument(String kind, Map<String, Object?> fields) => {setFileMarker: setFileVersion, 'kind': kind, ...fields};

/// The document in a set file's [text], once its header says it is a set of
/// [kind] this version can read. Throws [SetFileException] for anything else.
Map<dynamic, dynamic> readSetFile(String text, String kind) {
  final Object? document;
  try {
    document = loadPlainYaml(text);
  } on YamlTooLargeException catch (e) {
    throw SetFileException(SetFileProblem.malformed, e.detail);
  } on YamlException catch (e) {
    throw SetFileException(SetFileProblem.unreadable, e.message);
  } on StackOverflowError {
    throw const SetFileException(SetFileProblem.malformed, 'nested too deeply to read');
  }
  if (document is! Map) throw const SetFileException(SetFileProblem.unreadable, 'the document is not a map');
  final version = document[setFileMarker];
  if (version is! int && document[keyBindingsFileMarker] is int) throw const SetFileException(SetFileProblem.wrongKind, 'a keyboard shortcuts file');
  if (version is! int) throw const SetFileException(SetFileProblem.unreadable, 'no "$setFileMarker" version');
  if (version > setFileVersion) throw SetFileException(SetFileProblem.newerVersion, 'format $version');
  if (document['kind'] != kind) throw SetFileException(SetFileProblem.wrongKind, 'kind ${document['kind']}');
  return document;
}

/// [value] with each number or true/false in it as text: YAML reads an
/// unquoted `599` or `73` as a number, and a message written that way by
/// hand must not come in empty.
Object? setFileText(Object? value) => switch (value) {
  num() || bool() => '$value',
  List() => [for (final entry in value) setFileText(entry)],
  _ => value,
};

abstract class SetCategory {
  SettingsService get settings;

  /// What changes when [sets], [tree], [openFolders] or [activeId] does.
  Listenable get listenable => settings;

  /// What tells this kind's folders apart from another's — the key
  /// [openFolders] is kept under, and [tree] too where the kind stores it
  /// in a settings group ([SetTreeInSettingsGroup]).
  String get treeKey;

  /// The manager pane's title — "CW Message Sets".
  String get title;

  /// The picker's footer — "Manage CW Sets…".
  String get manageLabel;

  /// Every set, in the order the kind keeps them. Never empty.
  List<SetSummary> get sets;

  /// The set in use.
  String get activeId;

  /// The sets extensions offer, which [sets] lists too and [tree] files in
  /// the extensions' folders. Never renamed, moved or deleted, and nothing
  /// is filed among them: a duplicate of one is the operator's own.
  List<OfferedSetPlace> get offered => const [];

  /// Whether [id] — a set's or a folder's — is an extension's, and so not
  /// the operator's to change.
  bool isOffered(String id) => isOfferedSetId(id);

  /// The folders, kept beside the sets they file.
  SetTree get tree;
  Future<void> setTree(SetTree tree);

  /// The prefs entry holding every kind's open folders, by [treeKey].
  static const openFoldersPrefsKey = 'setFoldersOpen';

  /// The folders the picker shows open — closed unless named here, so a list
  /// of many folders opens short. Kept apart from the folders, as a settings
  /// section's fold is: how a list was left is not a setting.
  Set<String> get openFolders {
    final ids = {for (final folder in tree.folders) folder.id};
    return {
      if (settings.jsonMapPref(openFoldersPrefsKey)[treeKey] case final List<dynamic> list)
        for (final id in list)
          if (id is String && ids.contains(id)) id,
    };
  }

  /// Opens folder [id] in the picker where it is closed, and closes it where
  /// it is open.
  Future<void> toggleFolder(String id) {
    final open = openFolders;
    if (!open.remove(id)) open.add(id);
    return settings.setJsonMapPref(openFoldersPrefsKey, {
      ...settings.jsonMapPref(openFoldersPrefsKey),
      treeKey: [...open],
    });
  }

  bool canRename(String id);
  bool canDelete(String id);

  /// A copy of set [id] named [name], beside it in the same folder. Returns
  /// the copy's id; null where nothing could be copied.
  Future<String?> duplicate(String id, String name);
  Future<void> rename(String id, String name);

  /// Deletes set [id], for good — the manager asks first.
  Future<void> delete(String id);

  /// What deleting [name] is confirmed with — whatever else goes with it.
  String deleteConfirmation(String name);

  /// The import picker's file type; null for a kind with no file format.
  SetFileType? get fileType;

  Future<SetFileOut> export(String id);

  /// Adds the set in [bytes] — renamed where its name is taken — and
  /// returns its id; null where the operator called it off partway. Throws
  /// [SetFileException] for a file that is not one.
  Future<String?> import(Uint8List bytes, String filename);

  /// [wanted], or [wanted] with a number after it where one of [taken]
  /// already is — names are what the operator picks a set or a folder by, and
  /// two alike would be two lines nobody can tell apart.
  static String unique(String wanted, Iterable<String> taken) {
    final names = taken.toSet();
    var name = wanted;
    for (var suffix = 2; names.contains(name); suffix++) {
      name = '$wanted $suffix';
    }
    return name;
  }

  /// [wanted], numbered where another set has that name.
  String uniqueName(String wanted, {String? except}) => unique(wanted, [
    for (final set in sets)
      if (set.id != except) set.name,
  ]);

  String nameOf(String id) => sets.where((set) => set.id == id).firstOrNull?.name ?? '?';

  /// [sets] as the picker and the manager lay them out.
  List<SetTreeRow> get rows => tree.rows([for (final set in sets) set.id]);
}

/// The folders of a kind whose sets are kept in a settings group, under
/// [treeKey] in that same group, with the [offered] sets' folders beside
/// them and never stored.
mixin SetTreeInSettingsGroup on SetCategory {
  String get settingsGroup;

  @override
  SetTree get tree => SetTree.fromJson(settings.settingValue(settingsGroup, treeKey)).withOffered(offered, rootName: t.sets.extensionsFolder);

  @override
  Future<void> setTree(SetTree tree) => settings.updateSettingsGroup(settingsGroup, {treeKey: tree.withoutOffered().toJson()});
}
