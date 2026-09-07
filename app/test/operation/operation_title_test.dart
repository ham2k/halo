// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// displayTitleFor/displaySubtitleFor (ham2k/halo-dist#174): the final,
// localized "for X at Y" assembly step, layered over the pure
// mergeOperationTitleSuggestions grouping tested in halo_core.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/tools/operation_title.dart';

void main() {
  Operation operation({
    String userTitle = '',
    String title = '',
    bool hasRefs = false,
    Map<String, dynamic>? titleSuggestion,
    // Distinct from titleSuggestion == null (never cached): a ref hook that's
    // still booting, times out, or throws, or a live draft edit that removed
    // every ref, both cache an explicitly-empty suggestion the same way this
    // device would.
    bool cachedAsEmpty = false,
    String stationCall = '',
  }) =>
      Operation(
        uuid: 'u',
        data: {
          'stationCall': stationCall,
          'userTitle': userTitle,
          'title': title,
          if (hasRefs)
            'refs': [
              {'type': 'pota/activation', 'ref': 'K-1234'},
            ],
        },
        localData: cachedAsEmpty
            ? const {'titleSuggestion': null}
            : (titleSuggestion == null ? const {} : {'titleSuggestion': titleSuggestion}),
      );

  Future<String> titleFor(WidgetTester tester, Operation operation) async {
    late String result;
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(home: Builder(builder: (context) {
        result = displayTitleFor(context, operation);
        return const SizedBox();
      })),
    ));
    return result;
  }

  testWidgets("the user's own title leads, with the generated title appended after it", (tester) async {
    final title = await titleFor(
      tester,
      operation(userTitle: 'My Custom Title', titleSuggestion: {'at': 'K-1234', 'for': '', 'title': '', 'subtitle': ''}),
    );
    expect(title, 'My Custom Title at K-1234');
  });

  testWidgets("the user's own title alone, with no trailing space, when there's no suggestion to append",
      (tester) async {
    final title = await titleFor(tester, operation(userTitle: 'My Custom Title'));
    expect(title, 'My Custom Title');
  });

  testWidgets('an "at" suggestion becomes a localized "at X" when there is no user title', (tester) async {
    final title = await titleFor(
      tester,
      operation(titleSuggestion: {'at': 'K-1234', 'for': '', 'title': '', 'subtitle': ''}),
    );
    expect(title, 'at K-1234', reason: 'must use the "at" joiner word from strings.g.dart, not raw concatenation');
  });

  testWidgets('a "for" suggestion becomes a localized "for X"', (tester) async {
    final title = await titleFor(
      tester,
      operation(titleSuggestion: {'for': 'Field Day', 'at': '', 'title': '', 'subtitle': ''}),
    );
    expect(title, 'for Field Day');
  });

  testWidgets('plain title, for, and at fragments compose in that order', (tester) async {
    final title = await titleFor(
      tester,
      operation(titleSuggestion: {'title': 'Special Event', 'for': 'Field Day', 'at': 'K-1234', 'subtitle': ''}),
    );
    expect(title, 'Special Event for Field Day at K-1234');
  });

  testWidgets('falls back to a localized "General Operation" with no user title and no suggestion', (tester) async {
    final title = await titleFor(tester, operation());
    expect(title, 'General Operation');
  });

  testWidgets('falls back to the synced generated title when this device has no local suggestion cache yet',
      (tester) async {
    // A freshly-synced operation (from another device, or PoLo) has no
    // localData on this device — without this fallback it would show
    // "General Operation" until someone opens it here to recompute the cache.
    final title = await titleFor(tester, operation(title: 'for Field Day at K-1234', hasRefs: true));
    expect(title, 'for Field Day at K-1234');
  });

  testWidgets('the live local cache wins over the synced title once this device has recomputed it', (tester) async {
    final title = await titleFor(
      tester,
      operation(
        title: 'stale synced title',
        hasRefs: true,
        titleSuggestion: {'for': 'Field Day', 'at': 'K-5678', 'title': '', 'subtitle': ''},
      ),
    );
    expect(title, 'for Field Day at K-5678');
  });

  testWidgets('the user title still leads even when only the synced generated title is available', (tester) async {
    final title = await titleFor(tester, operation(userTitle: 'My Custom Title', title: 'for Field Day', hasRefs: true));
    expect(title, 'My Custom Title for Field Day');
  });

  testWidgets('ignores the synced title on a ref-less operation, since PoLo writes its own placeholder text there',
      (tester) async {
    // PoLo sets data.title to its OWN localized "General Operation" (or
    // "New Operation" for a brand new one) when an operation has no refs
    // (operationsDB.js, setOperationData.js) — never a real ref-derived
    // suggestion. Falling back to it here would render that placeholder as
    // though HaLo had generated it, in whichever language PoLo used.
    final title = await titleFor(tester, operation(title: 'Nueva Operación'));
    expect(title, 'General Operation');
  });

  testWidgets('a ref-less draft never resurrects the stale synced title, cache state notwithstanding', (tester) async {
    // OperationView's live draft preview caches an explicitly-empty
    // suggestion the moment the user removes every ref, mid-edit, before
    // Save refreshes data['title'] — but what actually decides the fallback
    // is refs being empty, the same as a freshly-synced ref-less operation.
    final title = await titleFor(tester, operation(title: 'for Field Day at K-1234', cachedAsEmpty: true));
    expect(title, 'General Operation');
  });

  testWidgets('a failed or still-booting hook attempt does not blank an already-good synced title', (tester) async {
    // retitleOperation caches an explicitly-empty suggestion whenever a ref
    // hook produces nothing — including a timeout or an in-flight extension
    // runtime, not just a genuine "these refs suggest nothing". With refs
    // still present, that must degrade to the synced title, not to
    // "General Operation" — regressing a title that was correct moments ago.
    final title = await titleFor(tester, operation(title: 'for Field Day at K-1234', hasRefs: true, cachedAsEmpty: true));
    expect(title, 'for Field Day at K-1234');
  });

  testWidgets('a subtitle-only cache is a real live suggestion, not a reason to fall back to the stale synced title',
      (tester) async {
    // A live cache with only subtitle set (title/for/at all empty — a shape
    // every current suggestOperationTitle hook produces alongside "at"/"for",
    // but the merge logic allows on its own) renders as '' via
    // buildGeneratedTitle. That must still count as "this device has an
    // up-to-date answer", not get mistaken for "no cache yet".
    final title = await titleFor(
      tester,
      operation(
        title: 'stale synced title',
        hasRefs: true,
        titleSuggestion: {'title': '', 'for': '', 'at': '', 'subtitle': 'Some Park'},
      ),
    );
    expect(title, 'General Operation');
  });

  test('the subtitle is always the ref-derived one, independent of the user title', () {
    final withUserTitle = operation(userTitle: 'My Title', titleSuggestion: {'subtitle': 'Some Park'});
    expect(displaySubtitleFor(withUserTitle), 'Some Park');
  });

  test('the subtitle is empty when nothing has been suggested', () {
    expect(displaySubtitleFor(operation()), isEmpty);
  });

  group('Test Operations', () {
    testWidgets('a /T station call appends "Testing" to the placeholder', (tester) async {
      final title = await titleFor(tester, operation(stationCall: 'KI2D/T'));
      expect(title, 'General Operation Testing');
    });

    testWidgets('a /TEST station call appends "Testing" to a generated title', (tester) async {
      final title = await titleFor(
        tester,
        operation(stationCall: 'KI2D/TEST', titleSuggestion: {'at': 'K-1234', 'for': '', 'title': '', 'subtitle': ''}),
      );
      expect(title, 'at K-1234 Testing');
    });

    testWidgets('a non-test call never gets the suffix', (tester) async {
      final title = await titleFor(tester, operation(stationCall: 'KI2D'));
      expect(title, 'General Operation');
    });
  });

  group('headerCallsignFor', () {
    // The Operation View's header is the one place with room to say who is at
    // the key and which device this is. A list is not: two operations of the
    // same station must still be told apart by their titles, not by a
    // parenthetical that is the same on both.
    // The operator goes in the slot the POSITION names — `operatorCall` with
    // no position, `operator2` at position 2 — which is where the header
    // reads it from.
    Operation withCalls(String stationCall, {String operatorCall = '', String position = ''}) => Operation(
          uuid: 'u',
          data: {'stationCall': stationCall, operatorCallKeyFor(position): operatorCall},
          localData: position.isEmpty ? const {} : {'multiIdentifier': position},
        );

    test('a station logged by its own licensee names nobody new', () {
      expect(headerCallsignFor(withCalls('KI2D', operatorCall: 'KI2D')), 'KI2D');
      expect(headerCallsignFor(withCalls('KI2D')), 'KI2D');
    });

    test('a club call names the operator behind it', () {
      expect(headerCallsignFor(withCalls('K2SUL', operatorCall: 'KI2D')), 'K2SUL (op KI2D)');
    });

    test("a multi-station position qualifies the operator it belongs to", () {
      expect(headerCallsignFor(withCalls('K2SUL', operatorCall: 'KI2D', position: '2')), 'K2SUL (op KI2D /OP2)');
    });

    test('a position with no separate operator still shows, since the spot still carries it', () {
      expect(headerCallsignFor(withCalls('K2SUL', position: '2')), 'K2SUL (/OP2)');
    });

    // The header reads the operator through `operatorCallFor`, so at a
    // position it names that position's operator and not the operation's
    // positionless one — without this, two devices sharing an operation would
    // both show whoever wrote `operatorCall` last.
    test("a position's own operator outranks the operation's", () {
      final operation = Operation(
        uuid: 'u',
        data: {'stationCall': 'K2SUL', 'operatorCall': 'KI2D', 'operator2': 'W2ABC'},
        localData: const {'multiIdentifier': '2'},
      );
      expect(headerCallsignFor(operation), 'K2SUL (op W2ABC /OP2)');
    });
  });
}
