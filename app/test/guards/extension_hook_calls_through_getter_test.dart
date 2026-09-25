// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `ExtensionService` keeps its runtime in `_host` and exposes it as `host`.
// The two are the same object in production, and not in tests: the test
// double (`ExtensionServiceWithFakeHost`) can override the getter but cannot
// reach the private field, which stays null. A hook call made through the
// field therefore takes the no-runtime early return under every fake, and
// that return is an empty answer rather than an error — so a test stubbing
// the hook passes whether or not the stub was ever consulted.
//
// So every hook call goes through the getter. Runtime MANAGEMENT stays on the
// field — the clock push, bundle reloads, KV writes, lifecycle — because the
// fake refuses those by design rather than pretend to vouch for them.
//
// A guard rather than a test per method because what matters is the next
// method: new code copies its neighbours, and a neighbour on the field is a
// test someone will write later that cannot fail.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _library = 'lib/services/extensions/extension_service.dart';

/// The library and every part it declares, read from its own `part`
/// directives so a piece split out later is scanned from its first line.
List<String> _libraryFiles() {
  final root = File(_library).readAsStringSync();
  final parts = [for (final m in RegExp(r"^part '([^']+)';", multiLine: true).allMatches(root)) '${File(_library).parent.path}/${m.group(1)}'];
  // Loudly, not vacuously: a library that stopped declaring its parts would
  // otherwise shrink the scan to the file that no longer holds the calls.
  if (parts.isEmpty) fail('$_library declares no parts — the hook calls it splits out would go unscanned');
  return [_library, ...parts];
}

/// A hook call and the name it is made through. Whitespace before the dot
/// is allowed, because a formatter breaks a long chain onto the next line.
final _hookCall = RegExp(r'\b(_?host)[!?]?\s*\.(?:invokeHook(?:All|Batch)?|invoke|invokeAll)\(');

/// A local bound to the field: `final host = _host;`, `var h = _host!;`,
/// `final ExtensionHost? host = _host;` — or reached through another object,
/// `final h = _service._host;`, the way the host-call class reaches the
/// service's state.
final _fieldBinding = RegExp(r'\b(\w+)\s*=\s*(?:\w+\.)?_host!?\s*;');

/// The half-open range of the innermost block enclosing [offset].
///
/// Counts braces without parsing, so a lone brace inside a string literal
/// before a binding would misplace the block. None exists in the file; a
/// field handed to a helper that makes the hook call is not seen at all.
/// The guard catches the shapes new code copies from its neighbours, not
/// every way to reach the field.
(int, int) _enclosingBlock(String source, int offset) {
  var depth = 0;
  var open = 0;
  for (var i = offset; i >= 0; i--) {
    if (source[i] == '}') depth++;
    if (source[i] == '{') {
      if (depth == 0) {
        open = i;
        break;
      }
      depth--;
    }
  }
  depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return (open, i);
    }
  }
  return (open, source.length);
}

int _lineOf(String source, int offset) => '\n'.allMatches(source.substring(0, offset)).length + 1;

/// What [source] does wrong, one line each.
List<String> offendersIn(String source, {String file = _library}) {
  final offenders = <String>[];
  for (final call in _hookCall.allMatches(source)) {
    if (call.group(1) == '_host') {
      offenders.add('$file:${_lineOf(source, call.start)} — a hook call through the `_host` field');
    }
  }
  // The field bound to a local, whatever its name, declaration or null
  // assertion: legitimate in a block that only manages the runtime, a trap in
  // one that calls a hook through that local.
  for (final binding in _fieldBinding.allMatches(source)) {
    final local = binding.group(1)!;
    final (from, to) = _enclosingBlock(source, binding.start);
    final callsThroughIt = RegExp('\\b${RegExp.escape(local)}[!?]?\\s*\\.(?:invokeHook(?:All|Batch)?|invoke|invokeAll)\\(');
    if (callsThroughIt.hasMatch(source.substring(from, to))) {
      offenders.add('$file:${_lineOf(source, binding.start)} — `$local` holds the `_host` field in a block that calls a hook through it');
    }
  }
  return offenders;
}

void main() {
  test('every extension hook call goes through the public getter', () {
    expect(
      [for (final file in _libraryFiles()) ...offendersIn(File(file).readAsStringSync(), file: file)],
      isEmpty,
      reason:
          'Read `this.host`, not `_host`, wherever a hook is called: the test double can\n'
          'only stand in for the getter, and a hook call through the field answers empty\n'
          'under every fake instead of failing. Runtime management (setClockTravel,\n'
          'reloadBundle, setKV, lifecycle) stays on the field.',
    );
  });

  // The guard is two regexes and a brace matcher, and a guard that cannot fail
  // guards nothing. These pin the shapes it has to see, against source it
  // does not read from disk.
  test('the guard sees each shape of the trap', () {
    expect(offendersIn('void a() { final host = _host; host.invokeHook(x); }'), hasLength(1));
    expect(offendersIn('void a() { _host?.invokeHookAll(x); }'), hasLength(1));
    expect(
      offendersIn('void a() {\n  final host = _host;\n  host\n      .invokeHook(x);\n}'),
      hasLength(1),
      reason: 'a chain the formatter broke across lines',
    );
    for (final shape in [
      'void a() { final ExtensionHost? host = _host; host?.invokeHook(x); }',
      'void a() { var host = _host; host!.invokeHook(x); }',
      'void a() { final host = _host!; host.invokeHook(x); }',
      'void a() { final h = _host; h?.invokeHookAll(x); }',
      'void a() { final h = _service._host; h?.invokeHook(x); }',
      // The catalog's call forms, which are what lib code writes.
      'void a() { _host?.invoke(Hooks.spotsFetchSpots); }',
      'void a() { final host = _host; host.invokeAll(Hooks.spotsFetchSpots); }',
      'void a() { final host = _host!; host.invokeHookBatch(calls); }',
    ]) {
      expect(offendersIn(shape), hasLength(1), reason: shape);
    }
  });

  test('the guard leaves runtime management on the field alone', () {
    // A binding is only wrong where the same block calls a hook. Without the
    // enclosing-block check, the clock push and the dev-bundle reload would be
    // flagged, and the only way to quiet them would be a rename that says
    // nothing.
    expect(offendersIn('void a() { final host = _host; host.setClockTravel(x); }'), isEmpty);
    expect(
      offendersIn('void a() { final host = _host; host.reload(); }\nvoid b() { final host = this.host; host.invokeHook(x); }'),
      isEmpty,
      reason: "one method's field binding does not taint the next method's getter binding",
    );
  });
}
