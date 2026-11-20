// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Settings → Developer → Extension Dev Server: the address is typed in a
// dialog. The traps: an address typed and then dismissed — Escape or a tap
// outside, not Done — being thrown away, so the author retypes it on every
// visit; and Connect being offered with nothing to connect to. And a tool
// connected over the dev link: its row following its client as it connects.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/agent_link/agent_link_peer.dart';
import 'package:ham2k_logger/services/extensions/dev_link/extension_dev_link.dart';
import 'package:ham2k_logger/services/extensions/dev_link/extension_dev_link_wiring.dart';
import 'package:ham2k_logger/services/extensions/extension_dev_client.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/views/settings/developer_panel.dart';

import '../support/halo_test_support.dart';

Future<HaLoServices> _services() async {
  final services = (await makeHaLoServices(extensions: ExtensionServiceWithFakeHost(FakeExtensionHost(const {})))).services;
  await services.settings.setDeveloperMode(true);
  return services;
}

Future<void> _openDialog(WidgetTester tester, HaLoServices services) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(body: DeveloperPanel(services: services)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Server address'));
  await tester.pumpAndSettle();
}

Finder get _addressField => find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));

Finder get _connect => find.widgetWithText(FilledButton, 'Connect');

class _Peer implements AgentLinkPeer {
  final _in = StreamController<String>();
  final _done = Completer<void>();

  @override
  Stream<String> get lines => _in.stream;

  @override
  Future<void> get done => _done.future;

  @override
  void send(String line) {}

  @override
  Future<void> close() async {
    if (!_in.isClosed) unawaited(_in.close());
    if (!_done.isCompleted) _done.complete();
  }
}

class _Listener implements AgentLinkListener {
  @override
  int get port => 47392;

  @override
  Future<void> close() async {}
}

/// Connects when [release] completes, and not before.
class _HeldClient extends ExtensionDevClient {
  final release = Completer<void>();
  DevServerState _state = DevServerState.disconnected;

  _HeldClient(Set<String> keys) : super(extensions: ExtensionService(), server: 'link:0', only: keys);

  @override
  DevServerState get state => _state;

  @override
  List<String> get servedKeys => [...?only];

  @override
  Future<void> connect(String url) async {
    _state = DevServerState.connecting;
    notifyListeners();
    await release.future;
    _state = DevServerState.connected;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the Extension Dev Server dialog', () {
    testWidgets('keeps an address typed and dismissed without connecting, and the row shows it', (tester) async {
      final services = await _services();
      await _openDialog(tester, services);

      await tester.enterText(_addressField, '10.0.0.5:8787');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(services.settings.extensionDevServerUrl, '10.0.0.5:8787');
      expect(find.text('10.0.0.5:8787\nNot connected'), findsOneWidget);
    });

    testWidgets('offers Connect only once there is an address', (tester) async {
      final services = await _services();
      await _openDialog(tester, services);

      expect(tester.widget<FilledButton>(_connect).onPressed, isNull);
      await tester.enterText(_addressField, '10.0.0.5:8787');
      await tester.pump();
      expect(tester.widget<FilledButton>(_connect).onPressed, isNotNull);
      await tester.enterText(_addressField, '   ');
      await tester.pump();
      expect(tester.widget<FilledButton>(_connect).onPressed, isNull);
    });
  });

  testWidgets('a tool connected over the dev link has its row follow its connect through', (tester) async {
    final services = await _services();
    void Function(AgentLinkPeer)? connectTool;
    late _HeldClient client;
    final link = ExtensionDevLink(
      wanted: () => true,
      ports: const [47392],
      app: const {'name': 'Ham2K Logger', 'edition': 'dev', 'label': '', 'version': '26.11'},
      newClient: (server, keys) => client = _HeldClient(keys),
      bind: ({required port, required onPeer}) async {
        connectTool = onPeer;
        return _Listener();
      },
    );
    debugSetExtensionDevLink(services, link);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(body: DeveloperPanel(services: services)),
        ),
      ),
    );
    await tester.pump();

    final peer = _Peer();
    connectTool!(peer);
    peer._in.add(
      jsonEncode({
        'extDevLink': 1,
        'tool': {'name': 'h2kext-dev', 'version': '1.29.0'},
        'dir': '/Users/w7abc/notes',
        'keys': ['w7abc-notes'],
        'server': 'http://127.0.0.1:8787/',
      }),
    );
    await tester.pump();
    link.answer(link.pendingRequest!, allow: true);
    await tester.pump();
    expect(find.textContaining('Connecting…'), findsOneWidget);

    // Only the client says it connected; the link does not notify again.
    // The row listening to the clients there were before this one joined
    // would say "Connecting…" for as long as the panel is open.
    client.release.complete();
    await tester.pump();
    expect(find.textContaining('Connecting…'), findsNothing);

    await peer.close();
    link.dispose();
    await tester.pump();
  });
}
