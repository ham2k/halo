// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The web button on the reference rows — both lists that carry one. Three
// things are load-bearing and
// neither is visible from the extension side: a row whose program has no page
// for the reference shows NO button (rather than a disabled one, which would
// leave a dead control where the trailing buttons align with the header rows),
// and where a button does appear it is the RIGHTMOST — the same edge the
// search results put it on, so the two lists read as one — and on a search
// result the distance stays inside the button rather than at the row's edge.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';

/// Answers each ref type's `linkForRef` hook from a table keyed by reference
/// code, through the fake host — so the sheet's links take the real batched
/// path (`linkForRefs`), and a hook that fails for one reference fails the way
/// the runtime would report it. The real hooks are exercised against the real
/// bundles in halo_extension_host's `ref_link_test`.
class _LinkingExtensionService extends ExtensionServiceWithFakeHost {
  _LinkingExtensionService(Map<String, RefLink> links, {List<Map<String, dynamic>> suggestions = const [], String? failsFor})
    : super(
        FakeExtensionHost({
          'activity:*:suggest': [
            {'key': 'pota', 'ok': true, 'value': suggestions},
          ],
          for (final type in const ['potaActivation', 'pgaActivation'])
            'ref:$type:null:linkForRef': (Object? args) {
              final code = ((args! as Map)['ref'] as Map)['ref'];
              if (code == failsFor) throw ExtensionHostException('this program is down');
              final link = links[code];
              return link == null ? null : {'url': link.url, 'label': ?link.label};
            },
        }),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSheet(WidgetTester tester, ExtensionService extensions) async {
    final HaLoHarness(:services) = await makeHaLoServices(extensions: extensions);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: OperationSheet(
              services: services,
              operation: Operation(
                uuid: 'op-123',
                data: {
                  'refs': [
                    {'type': 'potaActivation', 'ref': 'US-0370', 'name': 'A Park'},
                    {'type': 'pgaActivation', 'ref': 'AB12', 'name': 'A Gmina'},
                  ],
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder rowFor(String reference) => find.ancestor(of: find.text(reference), matching: find.byType(ListTile));

  testWidgets('a ref with a link gets a web button, outside Remove', (tester) async {
    await pumpSheet(tester, _LinkingExtensionService({'US-0370': const RefLink(url: 'https://pota.app/#/park/US-0370', label: 'POTA US-0370')}));

    final row = rowFor('US-0370');
    final web = find.descendant(of: row, matching: find.byIcon(MdiIcons.web));
    expect(web, findsOneWidget);
    // The extension's own name for the destination, inside the app's phrasing.
    // An activity leaves the name off (the row already says it); a contest
    // sets one, because its link goes to rules rather than to the reference.
    expect(tester.widget<Icon>(web).semanticLabel, 'Open POTA US-0370');

    // Order, not just presence: `Row`'s children are laid out left to right,
    // so the web button — the row's last control — must sit to the RIGHT of
    // the trash.
    final trash = find.descendant(of: row, matching: find.byIcon(MdiIcons.delete));
    expect(tester.getCenter(web).dx, greaterThan(tester.getCenter(trash).dx));
  });

  testWidgets('a ref whose program has no page shows no web button at all', (tester) async {
    await pumpSheet(tester, _LinkingExtensionService(const {}));

    expect(find.byIcon(MdiIcons.web), findsNothing);
    // The row is otherwise unchanged — Remove is still there.
    expect(find.descendant(of: rowFor('AB12'), matching: find.byIcon(MdiIcons.delete)), findsOneWidget);
  });

  testWidgets('a search result carries the same button, outside the distance', (tester) async {
    await pumpSheet(
      tester,
      _LinkingExtensionService(
        {
          'US-9999': const RefLink(url: 'https://pota.app/#/park/US-9999', label: 'POTA US-9999'),
          'US-0370': const RefLink(url: 'https://pota.app/#/park/US-0370', label: 'POTA US-0370'),
        },
        suggestions: [
          {'type': 'potaActivation', 'ref': 'US-9999', 'name': 'A Nearby Park', 'distance': 12.0},
        ],
      ),
    );

    final row = rowFor('US-9999');
    final web = find.descendant(of: row, matching: find.byIcon(MdiIcons.web));
    expect(web, findsOneWidget);
    // The button takes the outside edge and the distance sits inside it.
    final distance = find.descendant(of: row, matching: find.textContaining('12'));
    expect(distance, findsOneWidget);
    expect(tester.getCenter(web).dx, greaterThan(tester.getCenter(distance).dx));

    // Centred against the whole two-line tile, not pinned to the title line —
    // which is where it lands if it is laid out inside the title row.
    expect(tester.getCenter(distance).dy, closeTo(tester.getCenter(row).dy, 1.0));

    // And the same inset from the edge as the Current Activities rows: the
    // button is in a different list, not a different place.
    final selected = rowFor('US-0370');
    final selectedWeb = find.descendant(of: selected, matching: find.byIcon(MdiIcons.web));
    expect(tester.getRect(row).right - tester.getRect(web).right, closeTo(tester.getRect(selected).right - tester.getRect(selectedWeb).right, 0.5));
  });

  testWidgets('one ref whose program fails does not cost the others their links', (tester) async {
    // Every link crosses in ONE batch, so a failure that escaped a single call
    // would leave the whole sheet with no buttons because of one program.
    await pumpSheet(tester, _LinkingExtensionService({'US-0370': const RefLink(url: 'https://pota.app/#/park/US-0370')}, failsFor: 'AB12'));

    expect(find.descendant(of: rowFor('US-0370'), matching: find.byIcon(MdiIcons.web)), findsOneWidget);
    expect(find.descendant(of: rowFor('AB12'), matching: find.byIcon(MdiIcons.web)), findsNothing);
  });

  testWidgets('the link follows the ref, not the row position', (tester) async {
    // One of the two refs links and the other does not, in one operation: a
    // cache keyed by row index rather than by reference would put PGA's row
    // under POTA's answer.
    await pumpSheet(tester, _LinkingExtensionService({'AB12': const RefLink(url: 'https://example.test/AB12')}));

    expect(find.descendant(of: rowFor('AB12'), matching: find.byIcon(MdiIcons.web)), findsOneWidget);
    expect(find.descendant(of: rowFor('US-0370'), matching: find.byIcon(MdiIcons.web)), findsNothing);
  });
}
