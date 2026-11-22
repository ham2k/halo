// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sidetone renders promptly in the next block and releases across variable block sizes', () async {
    final dir = Directory.systemTemp.createTempSync('halo_sidetone_render');
    addTearDown(() => dir.deleteSync(recursive: true));
    final executable = '${dir.path}/sidetone_render';
    final libraries = Platform.isMacOS
        ? ['-framework', 'CoreFoundation', '-framework', 'CoreAudio', '-framework', 'AudioToolbox']
        : ['-lpthread', '-lm', '-ldl'];

    final compile = await Process.run('cc', ['-w', 'test/sidetone_render.c', '-o', executable, ...libraries]);
    expect(compile.exitCode, 0, reason: '${compile.stdout}${compile.stderr}');
    final result = await Process.run(executable, []);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  }, skip: !Platform.isMacOS && !Platform.isLinux);
}
