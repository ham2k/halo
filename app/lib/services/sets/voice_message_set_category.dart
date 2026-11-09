// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The voice message sets recorded on this computer as a SetCategory. Copies
// and deletes go through the keying service, which moves the recordings
// with the set. A set's file is a zip: `set.yaml` — the same header and
// fields a CW set's file has — and each message's recording as `<n>.wav`.

import 'dart:convert';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart' show uuidGenerator;
import 'package:halo_i18n/halo_i18n.dart';

import '../../views/dock_layouts/yaml_writer.dart' as yaml_writer;

import '../cat/cat_service.dart';
import '../cat/computer_voice_keyer.dart' show VoiceAudioFailure, isVoiceAudioFailure;
import '../settings_service.dart';
import 'offered_keyer_sets.dart';
import 'set_category.dart';

/// A voice set's file, unpacked: its id is the importer's to give.
typedef VoiceSetFile = ({String name, List<String> labels, List<String> templates, Map<int, Uint8List> recordings});

class VoiceMessageSetCategory extends SetCategory with SetTreeInSettingsGroup {
  @override
  final SettingsService settings;
  final CatService cat;

  VoiceMessageSetCategory(this.settings, this.cat);

  @override
  String get settingsGroup => SettingsService.radioGroup;

  @override
  String get treeKey => VoiceMessageSet.treeKey;

  @override
  String get title => t.settings.radio.voiceMessages.setsTitle;

  @override
  String get manageLabel => t.settings.radio.voiceMessages.manageSets;

  @override
  List<SetSummary> get sets => [
    for (final set in settings.voiceMessageSets) (id: set.id, name: set.name),
    for (final (:set, owner: _, ownerName: _) in settings.offeredKeyerSets.voice) (id: set.id, name: set.name),
  ];

  @override
  List<OfferedSetPlace> get offered => [
    for (final (:set, :owner, :ownerName) in settings.offeredKeyerSets.voice) (id: set.id, owner: owner, ownerName: ownerName),
  ];

  @override
  String get activeId => settings.voiceMessageSetId;

  /// The default set is where sound files go before anyone has made a set,
  /// and is neither renamed nor deleted (VoiceMessageSet.defaultId); an
  /// extension's set is not the operator's to change.
  @override
  bool canRename(String id) => id != VoiceMessageSet.defaultId && !isOffered(id);

  @override
  bool canDelete(String id) => id != VoiceMessageSet.defaultId && !isOffered(id);

  /// [run], with a file failure under it rethrown as the voice keyer reports
  /// one — its reason, never its path, which names the operator's OS account
  /// (VoiceAudioFailure).
  static Future<T> _files<T>(String doing, Future<T> Function() run) async {
    try {
      return await run();
    } catch (e, stack) {
      if (!isVoiceAudioFailure(e)) rethrow;
      Error.throwWithStackTrace(VoiceAudioFailure('sets:$doing', e), stack);
    }
  }

  @override
  Future<String?> duplicate(String id, String name) async {
    final copy = await _files('duplicate', () => cat.addVoiceMessageSet(uniqueName(name), from: id, select: false));
    if (copy == null) return null;
    final folder = tree.folderOf(id);
    if (folder != null && !isOffered(folder)) await setTree(tree.moveSet(copy.id, folder));
    return copy.id;
  }

  @override
  Future<void> rename(String id, String name) async {
    if (canRename(id)) await cat.renameVoiceMessageSet(id, uniqueName(name, except: id));
  }

  @override
  Future<void> delete(String id) async {
    if (!canDelete(id)) return;
    await _files('delete', () => cat.deleteVoiceMessageSet(id));
    await setTree(tree.forgetSet(id));
  }

  @override
  String deleteConfirmation(String name) => t.settings.radio.voiceMessages.deleteSetConfirm(name: name);

  static const kind = 'voice-messages';
  static const fileExtension = 'h2kvoice';
  static const _yamlEntry = 'set.yaml';

  /// What one recording, and the whole file unpacked, may come to — a
  /// message is seconds of audio, and a file claiming more is not a set.
  /// Kept low because the import writes the recordings on the UI isolate
  /// (VoiceAudio's writes are synchronous), and the screen stops while it
  /// does.
  static const _maxRecordingBytes = 10 * 1024 * 1024;
  static const _maxFileBytes = 8 * _maxRecordingBytes;

  @override
  SetFileType get fileType => (label: t.settings.radio.voiceMessages.fileLabel, extensions: const [fileExtension, 'zip'], mimeTypes: const ['application/zip']);

  @override
  Future<SetFileOut> export(String id) async {
    final set = settings.offeredVoiceMessageSet(id) ?? settings.voiceMessageSets.firstWhere((set) => set.id == id);
    final yaml =
        '# Ham2K Logger voice messages\n${yaml_writer.toYaml(setFileDocument(kind, {'name': set.name, 'labels': set.labels, 'templates': set.templates}))}';
    final recordings = await _files('export', () => cat.voiceMessageRecordings(id));
    return (
      filename: '${setFileStem(t.settings.radio.voiceMessages.fileStem, set.name)}.$fileExtension',
      // Off the UI isolate: a set's audio runs to megabytes, and compressing
      // it in a frame would stall the screen.
      content: await compute(_zip, (yaml: yaml, recordings: recordings)),
      mimeType: 'application/zip',
    );
  }

  static Uint8List _zip(({String yaml, Map<int, Uint8List> recordings}) file) {
    final archive = Archive()..addFile(ArchiveFile.string(_yamlEntry, file.yaml));
    for (final MapEntry(key: n, value: bytes) in file.recordings.entries) {
      archive.addFile(ArchiveFile.bytes('$n.wav', bytes));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  @override
  Future<String> import(Uint8List bytes, String filename) async {
    // Off the UI isolate, as the export is.
    final (:labels, :templates, :name, :recordings) = await compute(parse, bytes);
    final set = VoiceMessageSet(id: uuidGenerator.v4(), name: uniqueName(name), labels: labels, templates: templates);
    final added = await _files('import', () => cat.importVoiceMessageSet(set, recordings));
    return added.id;
  }

  /// The set in a file's [bytes]. Throws [SetFileException] for anything
  /// else.
  static VoiceSetFile parse(Uint8List bytes) {
    final Archive archive;
    // What the archive package throws for bytes that are not a zip, or a
    // zip cut short. Anything else is a fault here, not in the file, and
    // goes on to be reported as one.
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on FormatException catch (e) {
      throw SetFileException(SetFileProblem.unreadable, 'not a zip: ${e.message}');
    } on RangeError catch (e) {
      throw SetFileException(SetFileProblem.unreadable, 'not a zip: $e');
    }
    // Every entry is inflated by hand, into a buffer that stops at what is
    // left of the file's allowance whatever size its header claims: a header
    // is the file's own word, and a few kilobytes can inflate to gigabytes.
    // ArchiveFile's own decompression, on a native platform, collects the
    // whole entry before writing any of it. By hand, the checksum is ours to
    // check too: this inflater stops quietly at damaged data, and what it
    // wrote until then would come in as a recording cut short.
    var left = _maxFileBytes;
    Uint8List unpack(ArchiveFile file) {
      final entry = file.rawContent;
      final out = _CappedOutput(math.min(_maxRecordingBytes, left));
      if (entry is! ZipFile) throw SetFileException(SetFileProblem.unreadable, '${file.name} is not a zip entry');
      if (entry.flags & 1 != 0) throw SetFileException(SetFileProblem.unreadable, '${file.name} is encrypted');
      try {
        switch (entry.compressionMethod) {
          case CompressionType.deflate:
            Inflate.stream(entry.getStream(decompress: false), output: out);
          case CompressionType.none:
            out.writeStream(entry.getStream(decompress: false));
          case final other:
            throw SetFileException(SetFileProblem.unreadable, '${file.name} is compressed with ${other.name}');
        }
      } on FormatException catch (e) {
        throw SetFileException(SetFileProblem.unreadable, '${file.name}: ${e.message}');
      } on RangeError catch (e) {
        throw SetFileException(SetFileProblem.unreadable, '${file.name}: $e');
      }
      final unpacked = out.getBytes();
      if (getCrc32(unpacked) != entry.crc32) throw SetFileException(SetFileProblem.malformed, '${file.name} fails its checksum');
      left -= unpacked.length;
      return unpacked;
    }

    final yamlFile = archive.files.where((file) => file.isFile && file.name == _yamlEntry).firstOrNull;
    if (yamlFile == null) throw const SetFileException(SetFileProblem.unreadable, 'no $_yamlEntry');
    final document = readSetFile(utf8.decode(unpack(yamlFile), allowMalformed: true), kind);
    // Read through the stored form, which pads and cleans the lists the same
    // way a set read back from settings is.
    final read = VoiceMessageSet.fromJson({
      'id': 'file',
      'name': setFileText(document['name']),
      'labels': setFileText(document['labels']),
      'templates': setFileText(document['templates']),
    })!;
    final recordings = <int, Uint8List>{};
    for (final file in archive.files) {
      final n = file.isFile ? int.tryParse(RegExp(r'^(\d+)\.wav$').firstMatch(file.name)?.group(1) ?? '') : null;
      if (n != null && n >= 1 && n <= SettingsService.voiceMessageCount) recordings[n] = unpack(file);
    }
    return (name: read.name, labels: read.labels, templates: read.templates, recordings: recordings);
  }
}

/// Unpacked bytes that refuse to grow past [cap].
class _CappedOutput extends OutputMemoryStream {
  final int cap;

  _CappedOutput(this.cap);

  void _grow(int count) {
    if (length + count > cap) throw const SetFileException(SetFileProblem.malformed, 'an entry unpacks past what a set may hold');
  }

  @override
  void writeByte(int value) {
    _grow(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _grow(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _grow(stream.length);
    super.writeStream(stream);
  }
}
