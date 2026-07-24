// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// displayTitleFor/displaySubtitleFor (ham2k/app-halo-dist#174): the final,
// localized "for X at Y" assembly step, layered over the pure
// mergeOperationTitleSuggestions grouping tested in halo_core.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/tools/operation_title.dart';

void main() {
  Operation operation({String title = '', Map<String, dynamic>? titleSuggestion}) => Operation(
        uuid: 'u',
        data: {'title': title},
        localData: titleSuggestion == null ? const {} : {'titleSuggestion': titleSuggestion},
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
      operation(title: 'My Custom Title', titleSuggestion: {'at': 'K-1234', 'for': '', 'title': '', 'subtitle': ''}),
    );
    expect(title, 'My Custom Title at K-1234');
  });

  testWidgets("the user's own title alone, with no trailing space, when there's no suggestion to append",
      (tester) async {
    final title = await titleFor(tester, operation(title: 'My Custom Title'));
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

  test('the subtitle is always the ref-derived one, independent of the user title', () {
    final withUserTitle = operation(title: 'My Title', titleSuggestion: {'subtitle': 'Some Park'});
    expect(displaySubtitleFor(withUserTitle), 'Some Park');
  });

  test('the subtitle is empty when nothing has been suggested', () {
    expect(displaySubtitleFor(operation()), isEmpty);
  });
}
