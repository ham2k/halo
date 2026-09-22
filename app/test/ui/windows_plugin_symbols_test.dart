// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Guards the Release PDB flags every Windows plugin target gets from
// app/windows/CMakeLists.txt.
//
// Nothing else can see this. ./scripts/test.sh compiles no C++ and no GitHub
// CI job configures CMake, so dropping the loop stays green everywhere right
// up to a tag-triggered Codemagic release — and even then it is not a build
// error. It is a silently less useful crash report, discovered months later
// by whoever is trying to read a stack that has gone back to <unknown>.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _windowsCMakeLists() {
  final file = File('windows/CMakeLists.txt');
  if (!file.existsSync()) {
    fail(
      'No app/windows/CMakeLists.txt — this test runs from app/, and without '
      'that file it cannot answer the question it exists to answer.',
    );
  }
  return file.readAsStringSync();
}

void main() {
  test('every Windows plugin target is built with Release debug symbols', () {
    final source = _windowsCMakeLists();
    expect(
      source,
      contains(r'target_compile_options(${plugin}_plugin PRIVATE $<$<CONFIG:Release>:/Zi>)'),
      reason:
          'without /Zi a Release frame inside a plugin DLL resolves to the '
          'nearest exported symbol, which is how HALO-290 spent four rounds '
          'attributing plugin frames to MSVCP140',
    );
    expect(
      source,
      contains(r'target_link_options(${plugin}_plugin PRIVATE $<$<CONFIG:Release>:/DEBUG>)'),
      reason:
          'MSVC emits the linked PDB only with the linker\'s /DEBUG — /Zi '
          'alone leaves compiler-side PDBs the release pipeline never '
          'uploads, so dropping just this line defeats the hunk while the /Zi '
          'check above stays green',
    );
  });

  test('the flags are applied after the generated plugin list exists', () {
    // FLUTTER_PLUGIN_LIST is defined by flutter/generated_plugins.cmake. A
    // loop placed above the include iterates an empty list: it configures
    // cleanly, builds cleanly, and silently applies the flags to nothing.
    final source = _windowsCMakeLists();
    expect(
      source.indexOf('include(flutter/generated_plugins.cmake)'),
      lessThan(source.indexOf(r'foreach(plugin ${FLUTTER_PLUGIN_LIST})')),
      reason:
          'the loop must come after the include, or it iterates an empty '
          'list and no plugin gets symbols',
    );
  });

  test('the flags cover the whole generated plugin list, not a hand-picked few', () {
    // The generated file is regenerated on every build, so a plugin added
    // later must inherit the flags without anyone remembering to add it.
    // Naming targets individually here would leave exactly the gap that made
    // app_links the one delegate on the HALO-290 stack with no symbols.
    final source = _windowsCMakeLists();
    final loop = source.substring(source.indexOf(r'foreach(plugin ${FLUTTER_PLUGIN_LIST})'));
    final body = loop.substring(0, loop.indexOf('endforeach'));
    expect(
      body,
      isNot(contains('universal_ble')),
      reason:
          'the loop must stay driven by FLUTTER_PLUGIN_LIST; naming any '
          'plugin inside it reintroduces the per-plugin gap',
    );
  });
}
