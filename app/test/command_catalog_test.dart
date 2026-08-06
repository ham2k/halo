// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `getCommandCatalog` collects what every `command` hook advertises through
// its optional `catalog()` (extensions/sdk/src/types.ts) for the ⌘K dialog's
// browsable list. Three things it must get right, all of which would show up
// as a subtly wrong palette rather than a crash:
//
//  • `catalog` is OPTIONAL, so hooks that don't implement it report not-ok —
//    that's the normal case, not a failure to log or bail on.
//  • It's cached. Unlike `interpret` this is not a per-keystroke call, and
//    the palette matches typed text against the cached entries locally. But
//    the cache has to DROP when the answer changes: enabling an extension
//    (runtime replaced) or switching language (the describes are localized
//    by the hook, so a stale cache leaves the palette in the old language).
//  • A transient failure must not cache "empty" for the rest of the session.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'package:ham2k_logger/services/extension_service.dart';

class _CatalogHost implements ExtensionHost {
  /// What the next `command:*:catalog` fan-out returns.
  List<Map<String, dynamic>> entries;

  /// Set to throw instead of answering, for the failure case.
  bool fail = false;

  int calls = 0;

  _CatalogHost(this.entries);

  @override
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async {
    if (category != 'command' || method != 'catalog') return const [];
    calls++;
    if (fail) throw ExtensionHostException('runtime is down');
    return entries;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ServiceWithHost extends ExtensionService {
  final _CatalogHost mockHost;
  _ServiceWithHost(this.mockHost);

  @override
  ExtensionHost? get host => mockHost;

  @override
  Future<void> start() async {}
}

/// The `{ok, value}` envelope `invokeHookAll` wraps each hook's answer in.
Map<String, dynamic> _ok(List<Map<String, dynamic>> value) => {'ok': true, 'value': value};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('collects entries from the hooks that implement catalog, skipping the ones that do not', () async {
    final host = _CatalogHost([
      _ok([
        {'command': 'SEED', 'describe': 'Fill the log', 'category': 'Developer'},
      ]),
      // A hook with no `catalog` — the overwhelmingly common case, and NOT
      // an error to swallow-and-log.
      {'ok': false, 'error': 'no such method'},
      _ok([
        {'command': 'NOTE', 'describe': 'Add a note', 'needsOperation': true},
      ]),
    ]);
    final service = _ServiceWithHost(host);

    final catalog = await service.getCommandCatalog();

    expect(catalog.map((e) => e['command']), ['SEED', 'NOTE']);
    expect(catalog.last['needsOperation'], isTrue);
  });

  test('drops entries with no usable command, which would render as blank unselectable rows', () async {
    final host = _CatalogHost([
      _ok([
        {'command': 'SEED', 'describe': 'Fill the log'},
        {'describe': 'no command at all'},
        {'command': '', 'describe': 'empty command'},
        {'command': 42, 'describe': 'not even a string'},
      ]),
    ]);

    final catalog = await _ServiceWithHost(host).getCommandCatalog();

    expect(catalog.map((e) => e['command']), ['SEED']);
  });

  test('caches across reads, but re-reads after a locale change and after the runtime is replaced', () async {
    final host = _CatalogHost([
      _ok([
        {'command': 'SEED', 'describe': 'Fill the log'},
      ]),
    ]);
    final service = _ServiceWithHost(host);

    await service.getCommandCatalog();
    await service.getCommandCatalog();
    expect(host.calls, 1, reason: 'the palette must not re-cross the bridge on every open');

    // ⌘⇧L: the hook builds `describe` against the hook context's locale, so
    // a cache that survived this would leave the palette in the old language.
    service.invalidateHookContext();
    await service.getCommandCatalog();
    expect(host.calls, 2);

    // Enabling/disabling an extension replaces the runtime, which is what
    // changes WHICH hooks answer at all.
    await service.restartRuntime();
    await service.getCommandCatalog();
    expect(host.calls, 3);
  });

  test('a failed read is not cached, so a transient runtime fault does not empty the palette for good', () async {
    final host = _CatalogHost([
      _ok([
        {'command': 'SEED', 'describe': 'Fill the log'},
      ]),
    ])..fail = true;
    final service = _ServiceWithHost(host);

    expect(await service.getCommandCatalog(), isEmpty);

    host.fail = false;
    expect((await service.getCommandCatalog()).map((e) => e['command']), ['SEED']);
  });

  test('no runtime yet means an empty catalog, not a crash', () async {
    // The dialog can be opened before the extension runtime finishes booting.
    expect(await ExtensionService().getCommandCatalog(), isEmpty);
  });
}
