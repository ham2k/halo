// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app's `mcp` extension in the real runtime (docs/design/agent-link.md
// § Events). The trap is `wait_for_events`: a hook call held open while
// nothing happens keeps the extension engine pumping its jobs every few
// milliseconds, so the extension must answer at once and ask the link to
// hold the request, and its own assistant observing something must be what
// tells the link to ask again.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/agent_link/agent_link_model.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExtensionService extensions;
  late HaLoHarness harness;
  late Operation operation;
  var id = 0;

  setUp(() async {
    extensions = ExtensionService();
    harness = await makeHaLoServices(extensions: extensions);
    extensions
      ..operations = harness.services.operations
      ..qsos = harness.services.qsos;
    await startWithShippedExtensions(extensions);
    // The bundle the build makes from extensions/core/mcp, loaded as the
    // experiment would load it.
    await extensions.host!.reloadBundle(ExtensionBundle(key: 'mcp', source: File('assets/extensions/mcp.js').readAsStringSync(), api: 25));
    operation = await harness.services.operations.create(stationCall: 'KI2D', userTitle: 'Field Day');
    extensions.frontOperationUuid = () => operation.uuid;
    extensions.openOperationUuids = () => [operation.uuid];
  });

  Future<Map<String, dynamic>> callTool(String name, Map<String, dynamic> arguments) async {
    final replies =
        await extensions.host!.invokeHook(
              'agentLink',
              key: 'mcp',
              method: 'handle',
              args: {
                'connection': 'c1',
                'client': {'name': 'probe'},
                'access': 'change',
                'message': {
                  'jsonrpc': '2.0',
                  'id': ++id,
                  'method': 'tools/call',
                  'params': {'name': name, 'arguments': arguments},
                },
              },
            )
            as List;
    final result = ((replies.single as Map)['result'] as Map).cast<String, dynamic>();
    expect(result['isError'], isNot(true), reason: '$name: ${result['content']}');
    return result;
  }

  test('a wait with nothing yet answers at once, held for the link; the assistant observing is the news that asks again', () async {
    final listed = (await callTool('list_operations', {}))['structuredContent'] as Map;
    expect((listed['operations'] as List).single, allOf(containsPair('uuid', operation.uuid), containsPair('title', 'Field Day'), containsPair('front', true)));

    final first = await callTool('wait_for_events', {'timeoutSeconds': 20});
    final hold = agentHoldOf({'result': first});
    expect(hold, isNotNull, reason: 'answered with nothing to hold');
    expect((first['structuredContent'] as Map)['events'], isEmpty);

    var news = 0;
    extensions.news.addListener(() => news++);
    // As the assistant service calls it when the operation opens.
    await extensions.observe(
      hookKey: 'mcp',
      assistantKey: 'events',
      args: {
        'operation': {...operation.data, 'uuid': operation.uuid},
        'qsoCount': 0,
        'config': <String, dynamic>{},
        'reasons': ['open'],
        'clock': {'nowMillis': 1000, 'realNowMillis': 1000},
      },
    );
    expect(news, 1);

    final again = await callTool('wait_for_events', hold!.arguments);
    expect(again['_meta'], isNull);
    final events = again['structuredContent'] as Map;
    expect((events['events'] as List).single, allOf(containsPair('type', 'operationOpened'), containsPair('operationUuid', operation.uuid)));
  });
}
