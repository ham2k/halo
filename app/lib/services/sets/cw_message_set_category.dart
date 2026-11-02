// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The CW message sets as a SetCategory — what the set picker and manager
// work through — and their file: YAML, one set to a file, so it can be read
// and written by hand as the shortcuts file can.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' show uuidGenerator;
import 'package:halo_i18n/halo_i18n.dart';

import '../../views/dock_layouts/yaml_writer.dart' as yaml_writer;
import '../settings_service.dart';
import 'set_category.dart';

class CwMessageSetCategory extends SetCategory {
  @override
  final SettingsService settings;

  CwMessageSetCategory(this.settings);

  static const kind = 'cw-messages';
  static const fileExtension = 'h2kset';

  @override
  String get settingsGroup => SettingsService.radioGroup;

  @override
  String get treeKey => CwMessageSet.treeKey;

  @override
  String get title => t.settings.radio.cwMessages.setsTitle;

  @override
  String get manageLabel => t.settings.radio.cwMessages.manageSets;

  @override
  List<SetSummary> get sets => [for (final set in settings.cwMessageSets) (id: set.id, name: set.name)];

  @override
  String get activeId => settings.cwMessageSetId;

  @override
  bool canRename(String id) => true;

  /// Any but the last: the function keys have to have somewhere to read
  /// from.
  @override
  bool canDelete(String id) => settings.cwMessageSets.length > 1;

  @override
  Future<String?> duplicate(String id, String name) async {
    final sets = settings.cwMessageSets;
    final index = sets.indexWhere((set) => set.id == id);
    if (index < 0) return null;
    final copy = sets[index].copiedAs(id: uuidGenerator.v4(), name: uniqueName(name));
    await settings.setCwMessageSets([...sets]..insert(index + 1, copy), active: settings.cwMessageSetId);
    final folder = tree.folderOf(id);
    if (folder != null) await setTree(tree.moveSet(copy.id, folder));
    return copy.id;
  }

  @override
  Future<void> rename(String id, String name) => settings.setCwMessageSets([
    for (final set in settings.cwMessageSets) set.id == id ? set.renamed(uniqueName(name, except: id)) : set,
  ], active: settings.cwMessageSetId);

  /// The set beside it takes over where it was in use, as with voice.
  @override
  Future<void> delete(String id) async {
    if (!canDelete(id)) return;
    final sets = settings.cwMessageSets;
    final index = sets.indexWhere((set) => set.id == id);
    if (index < 0) return;
    final left = [...sets]..removeAt(index);
    final active = settings.cwMessageSetId;
    await settings.setCwMessageSets(left, active: active != id ? active : left[index.clamp(0, left.length - 1)].id);
    await setTree(tree.forgetSet(id));
  }

  @override
  String deleteConfirmation(String name) => t.sets.deleteConfirm(name: name);

  @override
  SetFileType get fileType =>
      (label: t.settings.radio.cwMessages.fileLabel, extensions: const [fileExtension, 'yaml', 'yml'], mimeTypes: const ['application/yaml', 'text/yaml']);

  @override
  Future<SetFileOut> export(String id) async {
    final set = settings.cwMessageSets.firstWhere((set) => set.id == id);
    final body = yaml_writer.toYaml(setFileDocument(kind, {'name': set.name, 'messages': set.messages, 'labels': set.labels}));
    return (
      filename: '${setFileStem(t.settings.radio.cwMessages.fileStem, set.name)}.$fileExtension',
      content: '# Ham2K Logger CW messages\n$body',
      mimeType: 'application/yaml',
    );
  }

  @override
  Future<String> import(Uint8List bytes, String filename) async {
    final set = parse(utf8.decode(bytes, allowMalformed: true));
    final copy = set.copiedAs(id: uuidGenerator.v4(), name: uniqueName(set.name));
    await settings.setCwMessageSets([...settings.cwMessageSets, copy], active: settings.cwMessageSetId);
    return copy.id;
  }

  /// The set in a file's [text]; its id is the caller's to give. Throws
  /// [SetFileException] for anything else.
  static CwMessageSet parse(String text) {
    final document = readSetFile(text, kind);
    final messages = setFileText(document['messages']), labels = setFileText(document['labels']), name = setFileText(document['name']);
    if (messages is! List || (labels != null && labels is! List)) throw const SetFileException(SetFileProblem.malformed, 'messages is not a list');
    return CwMessageSet.fromJson({'id': '', 'name': name is String ? name : null, 'messages': messages, 'labels': labels});
  }
}
