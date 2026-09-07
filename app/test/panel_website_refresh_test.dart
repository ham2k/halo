// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// When the Web Site pane reloads.
//
// The failure worth catching here has no symptom. A refresh built on
// `Timer.periodic` and stopped by the visibility gate restarts its period
// from zero every time the pane comes back — so an operator who switches
// tabs more often than the interval never gets a reload at all, and the pane
// looks perfectly healthy showing a page from an hour ago. Measuring the
// deadline from the last LOAD is the whole design, and only a hide/show cycle
// shorter than the interval tells the two apart.
//
// These count real reloads rather than pending timers: a timer that exists
// but fires at the wrong moment is exactly the bug, and "a timer is pending"
// passes for it. No `pumpAndSettle` anywhere — a live refresh has no settle
// point.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/website/website_panel.dart';

import 'support/fake_panel_extensions.dart';

void main() {
  // The pane's deadline is read from an injectable clock, because
  // `DateTime.now()` is not advanced by `tester.pump(duration)` — only timers
  // are. [tick] moves both together, so a hide/show cycle in a test elapses
  // the same way it does for an operator.
  late DateTime fakeNow;
  setUp(() => fakeNow = DateTime.utc(2026, 1, 1, 12));

  Future<void> tick(WidgetTester tester, Duration by) async {
    fakeNow = fakeNow.add(by);
    await tester.pump(by);
  }

  
  PanelService serviceWith(Map<String, dynamic> config) {
    final service = PanelService(FakePanelExtensions(configs: {'website#1': config}));
    service.registerNative(const PanelDefinition(
      id: websitePanelId,
      title: 'Web Site',
      source: PanelSource.native,
      multiple: true,
      formFields: [
        {'type': 'field', 'key': websiteUrlKey, 'fieldType': 'text'},
        {'type': 'field', 'key': websiteRefreshKey, 'fieldType': 'select'},
        {'type': 'field', 'key': websiteTitleKey, 'fieldType': 'text'},
      ],
    ));
    return service;
  }

  /// Mounts the pane and returns the list its reloads are appended to.
  Future<List<int>> pump(
    WidgetTester tester, {
    required PanelService service,
    bool visible = true,
    ValueChanged<String?>? onTitle,
    bool Function()? isEnteringQso,
    List<int>? reloads,
  }) async {
    final log = reloads ?? <int>[];
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: DockPaneVisibility(
            visible: visible,
            child: WebsitePanel(
              panelId: 'website#1',
              panels: service,
              autoRefresh: true,
              // `InAppWebView` asserts a platform implementation is
              // registered and none is under `flutter test`, so the pane
              // draws its message instead. The SCHEDULE is the same code
              // either way — it is gated on the URL, the interval, dock
              // visibility and lifecycle, none of which the platform
              // touches. What no widget test can cover is the reload
              // reaching a real page.
              webviewSupported: false,
              now: () => fakeNow,
              onTitle: onTitle,
              isEnteringQso: isEnteringQso,
              onReload: () => log.add(log.length + 1),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return log;
  }

  group('the schedule', () {
    testWidgets('never means never, however long the pane is left open', (tester) async {
      final service = serviceWith({websiteUrlKey: 'https://example.com', websiteRefreshKey: 0});
      final reloads = await pump(tester, service: service);
      await tick(tester, const Duration(hours: 1));
      expect(reloads, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reloads once per interval', (tester) async {
      final service = serviceWith({websiteUrlKey: 'https://example.com', websiteRefreshKey: 5});
      final reloads = await pump(tester, service: service);
      await tick(tester, const Duration(minutes: 4, seconds: 59));
      expect(reloads, isEmpty, reason: 'not before the interval is up');
      await tick(tester, const Duration(seconds: 2));
      expect(reloads, hasLength(1));
      await tick(tester, const Duration(minutes: 5));
      expect(reloads, hasLength(2), reason: 'and again, on its own');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a hidden pane does not reload', (tester) async {
      // A dock group is an IndexedStack: the pane stays mounted behind
      // another tab. Without the gate, three hidden panes reload a page
      // nobody can see, forever.
      final service = serviceWith({websiteUrlKey: 'https://example.com', websiteRefreshKey: 5});
      final reloads = await pump(tester, service: service, visible: false);
      await tick(tester, const Duration(minutes: 30));
      expect(reloads, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tabbing away and back does not restart the interval', (tester) async {
      // THE test. Hide at 3 minutes of a 5-minute interval, come back at 4,
      // and the reload must still land at 5 — not at 9, which is what a
      // periodic timer re-armed by the gate produces. An operator switching
      // panes every few minutes would otherwise never see a refresh, with
      // nothing on screen to say so.
      final service = serviceWith({websiteUrlKey: 'https://example.com', websiteRefreshKey: 5});
      final reloads = <int>[];
      await pump(tester, service: service, reloads: reloads);

      await tick(tester, const Duration(minutes: 3));
      await pump(tester, service: service, visible: false, reloads: reloads);
      await tick(tester, const Duration(minutes: 1));
      await pump(tester, service: service, reloads: reloads);

      expect(reloads, isEmpty, reason: 'four minutes in, nothing yet');
      await tick(tester, const Duration(minutes: 1, seconds: 1));
      expect(reloads, hasLength(1), reason: 'the deadline survived the hide');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a refresh that came due while hidden happens on return', (tester) async {
      // The operator is arriving at a stale page; waiting out another full
      // interval would show them a page older than the one they left.
      final service = serviceWith({websiteUrlKey: 'https://example.com', websiteRefreshKey: 5});
      final reloads = <int>[];
      await pump(tester, service: service, reloads: reloads);
      await pump(tester, service: service, visible: false, reloads: reloads);
      await tick(tester, const Duration(minutes: 20));
      expect(reloads, isEmpty);

      await pump(tester, service: service, reloads: reloads);
      expect(reloads, hasLength(1), reason: 'overdue on return');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a URL the pane will not load never reloads', (tester) async {
      final service = serviceWith({websiteUrlKey: 'javascript:alert(1)', websiteRefreshKey: 1});
      final reloads = await pump(tester, service: service);
      await tick(tester, const Duration(minutes: 10));
      expect(reloads, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('disposing takes the timer with it', (tester) async {
      // A leaked timer fires into a disposed State and reds whatever test
      // runs next, under an unrelated name.
      final service = serviceWith({websiteUrlKey: 'https://example.com', websiteRefreshKey: 1});
      await pump(tester, service: service);
      await tester.pumpWidget(const SizedBox());
      await tick(tester, const Duration(minutes: 10));
    });
  });

  group('pausing while a QSO is being entered — always, not an option', () {
    testWidgets('skips the tick, and takes the next one', (tester) async {
      // Skipped rather than deferred: a caught-up reload would fire the
      // instant the operator finishes logging, which is exactly when they
      // look up at the pane.
      var entering = true;
      final service = serviceWith({websiteUrlKey: 'https://example.com', websiteRefreshKey: 1});
      final reloads = await pump(tester, service: service, isEnteringQso: () => entering);

      await tick(tester, const Duration(minutes: 1, seconds: 1));
      expect(reloads, isEmpty, reason: 'mid-QSO');

      entering = false;
      await tick(tester, const Duration(minutes: 1, seconds: 1));
      expect(reloads, hasLength(1), reason: 'the next tick, not immediately');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a pane the view cannot ask never pauses', (tester) async {
      // `isEnteringQso` is null wherever the view cannot say whether a QSO is
      // being entered. That must not stop the refresh — a pane that silently
      // never reloaded would look identical to one whose timer is broken.
      final service = serviceWith({websiteUrlKey: 'https://example.com', websiteRefreshKey: 1});
      final reloads = await pump(tester, service: service);
      await tick(tester, const Duration(minutes: 1, seconds: 1));
      expect(reloads, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the tab name', () {
    testWidgets('is the host when the operator has not named the pane', (tester) async {
      final titles = <String?>[];
      final service = serviceWith({websiteUrlKey: 'https://www.dxheat.com/dxc/'});
      await pump(tester, service: service, onTitle: titles.add);
      expect(titles, ['dxheat.com']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('is the operator’s own name when they gave one', (tester) async {
      final titles = <String?>[];
      final service = serviceWith({
        websiteUrlKey: 'https://www.dxheat.com/dxc/',
        websiteTitleKey: 'DX Heat',
      });
      await pump(tester, service: service, onTitle: titles.add);
      expect(titles, ['DX Heat']);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Refresh Now', () {
    testWidgets('the settings action reaches this placement, and only this one', (tester) async {
      // The whole point of the PanelService refresh counter: the asker is a
      // dialog and the answerer is a pane, and nothing else connects them.
      // Renaming the method constant on one side, dropping the branch in
      // `_onCatalogChanged`, or passing the descriptor id instead of the
      // placement id all leave the button silently inert — and the pane
      // cannot be exercised by hand on Linux or in the web build, so nothing
      // else would notice.
      final service = serviceWith({websiteUrlKey: 'https://example.com', websiteRefreshKey: 0});
      final reloads = await pump(tester, service: service);

      service.requestRefresh('website#1');
      await tester.pump();
      expect(reloads, hasLength(1));

      // The DESCRIPTOR id is a different key, and a pane must not answer it —
      // that is what would make two placements reload together.
      service.requestRefresh(websitePanelId);
      await tester.pump();
      expect(reloads, hasLength(1), reason: 'the descriptor id is not this placement');

      service.requestRefresh('website#2');
      await tester.pump();
      expect(reloads, hasLength(1), reason: 'nor is another placement');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('it works with the interval set to Never', (tester) async {
      // The case the button exists for: no timer at all, so this is the only
      // way the page is ever reloaded.
      final service = serviceWith({websiteUrlKey: 'https://example.com', websiteRefreshKey: 0});
      final reloads = await pump(tester, service: service);
      service.requestRefresh('website#1');
      await tester.pump();
      service.requestRefresh('website#1');
      await tester.pump();
      expect(reloads, hasLength(2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('it pushes the next scheduled refresh out', (tester) async {
      // A manual reload is a load: the deadline is measured from it, so the
      // timer must not fire moments later having ignored it.
      final service = serviceWith({websiteUrlKey: 'https://example.com', websiteRefreshKey: 5});
      final reloads = await pump(tester, service: service);
      await tick(tester, const Duration(minutes: 4));
      service.requestRefresh('website#1');
      await tester.pump();
      expect(reloads, hasLength(1), reason: 'the manual one');

      await tick(tester, const Duration(minutes: 1, seconds: 30));
      expect(reloads, hasLength(1), reason: 'the old deadline was dropped, not honoured');
      await tick(tester, const Duration(minutes: 4));
      expect(reloads, hasLength(2), reason: 'five minutes after the manual reload');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
