// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:halo_cli/src/json_args.dart';
import 'package:halo_cli/src/runtime.dart' show CliUsageError;
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('halo-cli-args'));
  tearDown(() => temp.deleteSync(recursive: true));

  String fileWith(String contents, {String name = 'log.qson'}) {
    final file = File('${temp.path}/$name')..writeAsStringSync(contents);
    return file.path;
  }

  test('a bare path is read as a file', () {
    // The everyday invocation: `--qson ~/Downloads/2026-07-15.KI2D.qson`.
    // Requiring `@` made this fail as "not valid JSON — Unexpected character
    // (at character 1)", pointing at the filename it was told to read.
    final path = fileWith('{"operation": {"uuid": "op-1"}}');
    expect(readJsonMapArg(path, label: '--qson'), containsPair('operation', {'uuid': 'op-1'}));
  });

  test('@path still works', () {
    final path = fileWith('{"a": 1}');
    expect(readJsonMapArg('@$path', label: '--qson'), {'a': 1});
  });

  test('inline JSON is recognized by its opening brace or bracket', () {
    expect(readJsonMapArg('{"a": 1}', label: '--op'), {'a': 1});
    expect(readJsonListArg('[{"a": 1}]', label: '--qsos'), [
      {'a': 1}
    ]);
  });

  test('a missing file says so, instead of blaming the JSON', () {
    // The old message named a parse error at character 1 of a path — the
    // single most confusing thing it could have said.
    expect(
      () => readJsonArg('${temp.path}/nope.qson', label: '--qson'),
      throwsA(isA<CliUsageError>().having((e) => e.message, 'message', allOf(contains('no such file'), contains('nope.qson')))),
    );
  });

  test('a real file holding broken JSON still reports a JSON error', () {
    // The path resolved fine; the content is the problem, and the message
    // must not now claim the file is missing.
    final path = fileWith('{not json');
    expect(
      () => readJsonArg(path, label: '--qson'),
      throwsA(isA<CliUsageError>().having((e) => e.message, 'message', contains('not valid JSON'))),
    );
  });

  test('the wrong JSON shape is named by shape, not by syntax', () {
    expect(() => readJsonMapArg('[1, 2]', label: '--op'),
        throwsA(isA<CliUsageError>().having((e) => e.message, 'message', contains('expected a JSON object'))));
    expect(() => readJsonListArg('{"a": 1}', label: '--qsos'),
        throwsA(isA<CliUsageError>().having((e) => e.message, 'message', contains('expected a JSON array'))));
  });
}
