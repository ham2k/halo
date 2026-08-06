// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What an extension's panel document turns into. The kinds are a closed set
// the host renders itself — an extension contributes a document, never
// widgets — so the thing worth pinning down is what happens at the edges:
// an unknown kind, a malformed payload, a render that failed.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/panel_content_view.dart';

void main() {
  Future<void> pump(WidgetTester tester, {PanelContent? content, String? error}) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PanelContentView(content: content, error: error))),
      );

  testWidgets('markdown renders as markdown, not as its source text', (tester) async {
    await pump(tester, content: const PanelContent(kind: 'markdown', content: '# Title\n\nbody'));
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  testWidgets('a panel that has not answered yet shows progress, not an empty pane', (tester) async {
    await pump(tester);
    // An empty pane is indistinguishable from a panel with nothing to say.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a render failure is shown in the pane rather than swallowed', (tester) async {
    await pump(tester, error: 'boom');
    // A panel the operator deliberately added, that then says nothing, is
    // worse than one that says it broke.
    expect(find.text('boom'), findsOneWidget);
  });

  testWidgets('an unknown kind says so instead of rendering blank', (tester) async {
    await pump(tester, content: const PanelContent(kind: 'pdf', content: '...'));
    expect(find.textContaining('pdf'), findsOneWidget);
  });

  group('parsing what came over the bridge', () {
    test('a payload missing kind or content is not a panel document', () {
      expect(PanelContent.fromJson(null), isNull);
      expect(PanelContent.fromJson({'kind': 'markdown'}), isNull);
      expect(PanelContent.fromJson({'content': 'hi'}), isNull);
      // Numbers where strings belong: JS is on the other end of this.
      expect(PanelContent.fromJson({'kind': 'markdown', 'content': 42}), isNull);
    });

    test('a well-formed payload round-trips', () {
      expect(
        PanelContent.fromJson({'kind': 'svg', 'content': '<svg/>'}),
        const PanelContent(kind: 'svg', content: '<svg/>'),
      );
    });
  });
}
