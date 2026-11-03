// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The keyboard shortcut sets as a SetCategory: App Defaults, the app's own
// keys, and the sets the operator makes from them
// (docs/design/keyboard-shortcuts.md § Sets).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' show uuidGenerator;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../key_bindings_file.dart';
import '../key_bindings_service.dart';
import '../settings_service.dart';
import 'set_category.dart';
import 'set_tree.dart';

/// What an import stores from [file]: its keys as this keyboard reads them,
/// or null where the operator called the import off.
typedef KeyBindingsImportTranslator = Future<KeyBindingOverrides?> Function(KeyBindingsFile file);

class KeyboardShortcutSetCategory extends SetCategory {
  final KeyBindingsService service;

  /// Asks how a file's modifiers read on this keyboard. Without one, an
  /// import takes [suggestedTranslation].
  final KeyBindingsImportTranslator? translate;

  KeyboardShortcutSetCategory(this.service, {this.translate});

  static const appDefaultsId = KeyBindingsService.appDefaultsId;

  @override
  SettingsService get settings => service.settings;

  @override
  Listenable get listenable => Listenable.merge([settings, service]);

  @override
  String get treeKey => 'keyboardShortcutSetTree';

  @override
  SetTree get tree => service.tree;

  @override
  Future<void> setTree(SetTree tree) => service.setSets(service.sets, active: service.activeSetId, tree: tree);

  @override
  String get title => t.keyboardShortcuts.sets.title;

  @override
  String get manageLabel => t.keyboardShortcuts.sets.manage;

  /// App Defaults first: it is where every set starts from.
  @override
  List<SetSummary> get sets => [(id: appDefaultsId, name: t.keyboardShortcuts.sets.appDefaults), for (final set in service.sets) (id: set.id, name: set.name)];

  @override
  String get activeId => service.activeSetId;

  Future<void> use(String id) => service.setSets(service.sets, active: id);

  @override
  bool canRename(String id) => id != appDefaultsId;

  /// Any but App Defaults, which is always there to fall back on.
  @override
  bool canDelete(String id) => id != appDefaultsId;

  @override
  Future<String?> duplicate(String id, String name) async {
    final stored = service.sets;
    final KeyBindingSet copy;
    final int at;
    if (id == appDefaultsId) {
      copy = KeyBindingSet(id: uuidGenerator.v4(), name: uniqueName(name));
      at = 0;
    } else {
      final index = stored.indexWhere((set) => set.id == id);
      if (index < 0) return null;
      copy = stored[index].copiedAs(id: uuidGenerator.v4(), name: uniqueName(name));
      at = index + 1;
    }
    final folder = tree.folderOf(id);
    await service.setSets([...stored]..insert(at, copy), active: service.activeSetId, tree: folder == null ? null : tree.moveSet(copy.id, folder));
    return copy.id;
  }

  @override
  Future<void> rename(String id, String name) async {
    if (!canRename(id)) return;
    await service.setSets([for (final set in service.sets) set.id == id ? set.renamed(uniqueName(name, except: id)) : set], active: service.activeSetId);
  }

  /// The set beside it takes over where it was in use, as with the message
  /// sets — App Defaults where it was the only one.
  @override
  Future<void> delete(String id) async {
    if (!canDelete(id)) return;
    final all = [for (final set in sets) set.id];
    final index = all.indexOf(id);
    if (index < 0) return;
    final left = [...all]..removeAt(index);
    final active = service.activeSetId;
    await service.setSets(
      [
        for (final set in service.sets)
          if (set.id != id) set,
      ],
      active: active != id ? active : left[index.clamp(0, left.length - 1)],
      tree: tree.forgetSet(id),
    );
  }

  @override
  String deleteConfirmation(String name) => t.sets.deleteConfirm(name: name);

  @override
  SetFileType get fileType => (
    label: t.keyboardShortcuts.sets.fileLabel,
    // Plain `.yaml` too: the format is meant to be written by hand.
    extensions: const [keyBindingsFileExtension, 'yaml', 'yml'],
    mimeTypes: const ['application/yaml', 'text/yaml'],
  );

  @override
  Future<SetFileOut> export(String id) async {
    final name = nameOf(id);
    final keys = service.sets.where((set) => set.id == id).firstOrNull?.keys ?? const KeyBindingOverrides();
    final file = KeyBindingsFile(platform: keyboardPlatformToken(), name: name, overrides: keys);
    return (
      filename: '${setFileStem(t.keyboardShortcuts.sets.fileStem, name)}.$keyBindingsFileExtension',
      content: file.toYaml(),
      mimeType: 'application/yaml',
    );
  }

  @override
  Future<String?> import(Uint8List bytes, String filename) async {
    final KeyBindingsFile file;
    try {
      file = KeyBindingsFile.parse(utf8.decode(bytes, allowMalformed: true));
    } on KeyBindingsFileException catch (e) {
      throw SetFileException(switch (e.problem) {
        KeyBindingsFileProblem.notYaml || KeyBindingsFileProblem.notKeysFile => SetFileProblem.unreadable,
        KeyBindingsFileProblem.otherSetKind => SetFileProblem.wrongKind,
        KeyBindingsFileProblem.newerVersion => SetFileProblem.newerVersion,
        KeyBindingsFileProblem.malformed || KeyBindingsFileProblem.tooLarge => SetFileProblem.malformed,
      }, e.detail);
    }
    final keys = await (translate ?? _suggested)(file);
    if (keys == null) return null;
    final set = KeyBindingSet(id: uuidGenerator.v4(), name: uniqueName(file.name ?? filename.replaceFirst(RegExp(r'\.[^.]*$'), '')), keys: keys);
    await service.setSets([...service.sets, set], active: service.activeSetId);
    return set.id;
  }

  static Future<KeyBindingOverrides?> _suggested(KeyBindingsFile file) async =>
      file.importable(suggestedTranslation(file.overrides.platformModifiers, file.platform)).overrides;
}
