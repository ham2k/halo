// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import '../bundles.dart';
import '../cli.dart';

/// What extensions exist, and — with `--hooks` — what they actually
/// registered once loaded.
class ListCommand extends ExtCommand {
  @override
  final name = 'list';
  @override
  final description = 'List the extensions in the bundle index, and optionally the hooks they register.';

  ListCommand() {
    argParser.addFlag('hooks', negatable: false, help: 'Boot the runtime and report the hooks each extension actually registered.');
  }

  @override
  bool get needsLookups => false;

  @override
  Future<int> run() async {
    if (!argResults!.flag('hooks')) {
      // No runtime: this answers from index.json, so it still works when a
      // bundle is broken enough that the runtime won't boot — which is
      // exactly when somebody runs it.
      final index = BundleIndex.load(dir: globalResults!.option('bundles') != null ? Directory(globalResults!.option('bundles')!) : null);
      emit({
        'bundles': index.directory.path,
        'extensions': [for (final entry in index.extensions) entry.toJson()],
      });
      return 0;
    }

    return withRuntime((runtime) async {
      final active = await invoke(runtime, 'runtime', key: 'kernel', method: 'listExtensions');
      final registered = await invoke(runtime, 'runtime', key: 'kernel', method: 'listHooks');
      final hooksByExtension = <String, List<Object?>>{};
      for (final hook in (registered as List? ?? const [])) {
        if (hook is! Map) continue;
        hooksByExtension.putIfAbsent(hook['extensionKey'] as String? ?? '?', () => []).add({
          'category': hook['category'],
          'key': hook['key'],
          'priority': hook['priority'],
          'methods': hook['methods'],
        });
      }
      emit({
        'bundles': runtime.index.directory.path,
        'loaded': [
          for (final entry in (active as List? ?? const []).cast<Map<dynamic, dynamic>>())
            {...entry.cast<String, Object?>(), 'hooks': hooksByExtension[entry['key']] ?? const []},
        ],
      });
      return 0;
    });
  }
}
