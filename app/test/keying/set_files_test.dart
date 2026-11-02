// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A message set written to a file and read back in, for CW and voice.
//
// The traps: a voice set's file that carries its labels and not its audio
// (the set is its recordings), an import that takes over the set in use
// (an imported set plays on the air the moment it lands), an import that
// reuses the exported set's id or name (two sets the operator cannot tell
// apart, or one that overwrites the other's recordings), and a file of one
// kind read as the other.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/computer_voice_keyer.dart' show VoiceAudioFailure;
import 'package:ham2k_logger/services/sets/cw_message_set_category.dart';
import 'package:ham2k_logger/services/sets/set_category.dart';
import 'package:ham2k_logger/services/sets/voice_message_set_category.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/fake_voice_audio.dart';
import '../support/halo_test_support.dart';

const codec = AudioDevice(id: 'c0dec', name: 'USB Audio CODEC');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('voice', () {
    late HaLoServices services;
    late FakeVoiceAudio audio;
    late VoiceMessageSetCategory category;
    final recording = Uint8List.fromList(List.generate(200, (i) => i % 256));

    setUp(() async {
      audio = FakeVoiceAudio()..outputDevices = [codec];
      audio.write('/v/s1/1.wav', recording);
      final harness = await makeHaLoServices(
        cat: (settings) => CatService(settings, voiceAudio: audio, voiceMessagesDirectory: () async => '/v'),
      );
      services = harness.services;
      await services.settings.setVoiceMessageSets([
        VoiceMessageSet(id: 's1', name: 'CQ', labels: const ['CQ', '', '', '', '', '', '', ''], templates: const ['', 'QRZ?', '', '', '', '', '', '']),
      ], active: VoiceMessageSet.defaultId);
      // The recordings' directory is found on first use.
      services.cat.computerVoiceAudio;
      await pumpEventQueue();
      category = VoiceMessageSetCategory(services.settings, services.cat);
    });

    test('a set comes back with its labels, templates and recordings, as a new set not in use', () async {
      final file = await category.export('s1');
      expect(file.filename, endsWith('.h2kvoice'));
      expect(file.content, isA<Uint8List>(), reason: 'a zip, not text');

      final id = await category.import(file.content as Uint8List, file.filename);
      expect(id, isNot('s1'), reason: "the import's recordings must not land on the exported set's");
      final imported = services.settings.voiceMessageSets.firstWhere((set) => set.id == id);
      expect(imported.name, 'CQ 2', reason: 'a name already taken is numbered');
      expect(imported.label(1), 'CQ');
      expect(imported.template(2), 'QRZ?');
      expect(audio.written['/v/$id/1.wav'], recording);
      expect(services.settings.voiceMessageSetId, VoiceMessageSet.defaultId, reason: 'an import is not put in use');
    });

    test('a CW set file, or not a zip at all, is refused for what it is', () async {
      final cw = await CwMessageSetCategory(services.settings).export(services.settings.cwMessageSets.first.id);
      await expectLater(
        category.import(Uint8List.fromList((cw.content as String).codeUnits), cw.filename),
        throwsA(isA<SetFileException>().having((e) => e.problem, 'problem', SetFileProblem.unreadable)),
      );
      final sets = services.settings.voiceMessageSets.length;
      await expectLater(
        category.import(Uint8List.fromList([1, 2, 3]), 'junk.h2kvoice'),
        throwsA(isA<SetFileException>().having((e) => e.problem, 'problem', SetFileProblem.unreadable)),
      );
      expect(services.settings.voiceMessageSets.length, sets, reason: 'nothing added for a file that was refused');
    });

    test('a recording that unpacks past what a set may hold is refused', () async {
      // Zeros deflate a thousandfold: the file is small, what it unpacks to
      // is not — the size that decides is the inflated one, not the file's.
      final file = await category.export('s1');
      final archive = ZipDecoder().decodeBytes(file.content as Uint8List)..addFile(ArchiveFile.bytes('2.wav', Uint8List(60 * 1024 * 1024)));
      final bomb = ZipEncoder().encodeBytes(archive);
      expect(bomb.length, lessThan(1024 * 1024));
      final sets = services.settings.voiceMessageSets.length;
      await expectLater(category.import(bomb, 'bomb.h2kvoice'), throwsA(isA<SetFileException>().having((e) => e.problem, 'problem', SetFileProblem.malformed)));
      expect(services.settings.voiceMessageSets.length, sets);
    });
    test('a recording damaged in the file is refused, not imported cut short', () async {
      // The inflater stops quietly at bad data; without the checksum, what it
      // wrote until then would land as the recording, and the import would
      // say it worked.
      final file = (await category.export('s1')).content as Uint8List;
      final name = utf8.encode('1.wav');
      var header = -1;
      for (var i = 0; i + 30 + name.length < file.length; i++) {
        if (file[i] == 0x50 && file[i + 1] == 0x4b && file[i + 2] == 3 && file[i + 3] == 4 && _same(file.sublist(i + 30, i + 30 + name.length), name)) {
          header = i;
          break;
        }
      }
      expect(header, isNonNegative, reason: "sanity: 1.wav's local header");
      final data = header + 30 + name.length + (file[header + 28] | file[header + 29] << 8);
      final damaged = Uint8List.fromList(file)..[data + 20] ^= 0xff;
      final sets = services.settings.voiceMessageSets.length;
      await expectLater(
        category.import(damaged, 'damaged.h2kvoice'),
        throwsA(isA<SetFileException>().having((e) => e.problem, 'problem', SetFileProblem.malformed)),
      );
      expect(services.settings.voiceMessageSets.length, sets);
    });

    test('a duplicate lands right after the set it copies, as a CW one does', () async {
      await services.settings.setVoiceMessageSets([
        ...services.settings.voiceMessageSets,
        VoiceMessageSet(id: 's2', name: 'QRZ', labels: const ['', '', '', '', '', '', '', ''], templates: const ['', '', '', '', '', '', '', '']),
      ], active: VoiceMessageSet.defaultId);
      final copy = await category.duplicate('s1', 'CQ copy');
      final ids = [for (final set in services.settings.voiceMessageSets) set.id];
      expect(ids.indexOf(copy!), ids.indexOf('s1') + 1, reason: 'not after QRZ, at the end of the list');
      expect(audio.copied, contains(('/v/s1/1.wav', '/v/$copy/1.wav')));
    });

    test('recordings that will not delete leave the set listed, and the failure names no path', () async {
      // Deleting the set first would leave its recordings on disk under a
      // set nothing lists, for good; and a path under the home folder names
      // the operator's OS account, which an upload must not carry.
      audio.failingDelete = true;
      await expectLater(category.delete('s1'), throwsA(isA<VoiceAudioFailure>().having((e) => '$e', 'text', isNot(contains('/v/')))));
      expect([for (final set in services.settings.voiceMessageSets) set.id], contains('s1'));
    });

    test('an import whose recordings fail to write partway leaves no set and no files behind', () async {
      audio.write('/v/s1/2.wav', recording);
      final file = await category.export('s1');
      audio.failingWriteOf = '/2.wav';
      final sets = services.settings.voiceMessageSets.length;
      await expectLater(category.import(file.content as Uint8List, file.filename), throwsA(isA<VoiceAudioFailure>()));
      expect(services.settings.voiceMessageSets.length, sets);
      expect(audio.written.keys.where((path) => !path.startsWith('/v/s1/')), isEmpty, reason: 'no recordings under a set nothing names');
    });

    test('with no directory for recordings, export and delete refuse rather than answer without them', () async {
      // A made-up answer here is a file that says "exported" with no audio
      // in it, or a set deleted with its recordings left on disk.
      final bare = (await makeHaLoServices(cat: (settings) => CatService(settings, voiceAudio: audio))).services;
      await bare.settings.setVoiceMessageSets(services.settings.voiceMessageSets, active: VoiceMessageSet.defaultId);
      final category = VoiceMessageSetCategory(bare.settings, bare.cat);
      await expectLater(category.export('s1'), throwsStateError);
      await expectLater(category.delete('s1'), throwsStateError);
      expect([for (final set in bare.settings.voiceMessageSets) set.id], contains('s1'));
    });
  });

  group('cw', () {
    late HaLoServices services;
    late CwMessageSetCategory category;

    setUp(() async {
      services = (await makeHaLoServices()).services;
      category = CwMessageSetCategory(services.settings);
    });

    test('a set comes back with its messages and labels, as a new set not in use', () async {
      final settings = services.settings;
      final source = settings.cwMessageSets.last;
      final active = settings.cwMessageSetId;
      final file = await category.export(source.id);
      final id = await category.import(Uint8List.fromList((file.content as String).codeUnits), file.filename);

      final imported = settings.cwMessageSets.firstWhere((set) => set.id == id);
      expect(id, isNot(source.id));
      expect(imported.name, '${source.name} 2');
      expect(imported.messages, source.messages);
      expect(imported.labels, source.labels);
      expect(settings.cwMessageSetId, active, reason: 'an import is not put in use');
    });

    test('numbers written by hand without quotes come in as the text they say', () {
      // YAML reads an unquoted 599 as a number; taken as "not text", the
      // message would come in empty and the import would say it worked.
      final set = CwMessageSetCategory.parse('$setFileMarker: 1\nkind: ${CwMessageSetCategory.kind}\nname: 2026\nmessages: [599, 73, TU]\nlabels: [1]\n');
      expect(set.name, '2026');
      expect([set.message(1), set.message(2), set.message(3)], ['599', '73', 'TU']);
      expect(set.label(1), '1');
    });

    test('a file of another kind is refused as one', () {
      const voice = '$setFileMarker: 1\nkind: ${VoiceMessageSetCategory.kind}\nname: CQ\n';
      expect(() => CwMessageSetCategory.parse(voice), throwsA(isA<SetFileException>().having((e) => e.problem, 'problem', SetFileProblem.wrongKind)));
      expect(
        () => CwMessageSetCategory.parse('$setFileMarker: 99\nkind: cw-messages\nmessages: []\n'),
        throwsA(isA<SetFileException>().having((e) => e.problem, 'problem', SetFileProblem.newerVersion)),
      );
    });
  });
}

bool _same(List<int> a, List<int> b) => a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);
