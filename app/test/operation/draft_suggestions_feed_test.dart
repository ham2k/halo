// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which list each logging set shows (docs/design/logging-fields.md § Draft
// suggestions). The traps: a pick changes the call, and an extension hearing
// it posts a list for the picked call that would take the walk's other calls
// away; and a list posted before a contact was logged carries verdicts from
// before it, so the same partial typed for the next contact must not bring
// it back.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/views/operation/draft_suggestions_feed.dart';

import '../support/halo_test_support.dart';

DraftSuggestionList _list(String forCall, List<String> calls) => DraftSuggestionList(
  forCall: forCall,
  drafts: [
    for (final call in calls)
      DraftSuggestion(
        call: call,
        qso: {
          'their': {'call': call},
        },
      ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late DraftSuggestionsFeed feed;
  late DraftSuggestions set;

  setUp(() async {
    services = (await makeHaLoServices()).services;
    feed = DraftSuggestionsFeed('op-1', services: services);
    set = feed.sets['A']!;
    addTearDown(feed.dispose);
  });

  test('a list posted for the picked call waits until the operator types', () {
    final walked = _list('K1A', ['K1AB', 'K1AC', 'K1AD']);
    services.extensions.draftSuggestions.post('scp', 'op-1', walked);
    set.call = 'K1A';
    expect(set.list, same(walked));

    // A pick, as LoggingControls makes one: marked, then the call changes.
    set
      ..picked = 0
      ..call = 'K1AB';
    services.extensions.draftSuggestions.post('scp', 'op-1', _list('K1AB', ['K1AB', 'K1ABC']));
    expect(set.list, same(walked), reason: 'K1AC and K1AD are still to walk');

    set.call = 'K1ABC';
    expect(set.picked, isNull);
    expect(set.list, isNull, reason: 'typed past both lists');
  });

  test('walking back past the last suggestion lands on the list walked, though its extension replaced it for a pick', () {
    final walked = _list('K1A', ['K1AB', 'K1AC']);
    services.extensions.draftSuggestions.post('scp', 'op-1', walked);
    set
      ..call = 'K1A'
      ..picked = 0
      ..call = 'K1AB';
    services.extensions.draftSuggestions.post('scp', 'op-1', _list('K1AB', ['K1AB', 'K1ABC']));

    // Past the last, back to the text typed, as LoggingControls walks it.
    set
      ..picked = null
      ..call = 'K1A';
    expect(set.list, same(walked), reason: 'without it the line goes and Alt-Y does nothing more');
    expect(set.showing, isTrue);
  });

  test('a panel opened on the operation again shows none of the lists it was offered before', () {
    services.extensions.draftSuggestions.post('scp', 'op-1', _list('K1A', ['K1AB']));
    final again = DraftSuggestionsFeed('op-1', services: services);
    addTearDown(again.dispose);
    again.sets['A']!.call = 'K1A';
    expect(again.sets['A']!.list, isNull, reason: 'scored before whatever was logged since');
  });

  test('a list posted before the field was emptied never shows again', () {
    final before = _list('K1A', ['K1AB']);
    services.extensions.draftSuggestions.post('scp', 'op-1', before);
    set.call = 'K1A';
    expect(set.list, same(before));

    set
      ..call = ''
      ..call = 'K1A';
    expect(set.list, isNull, reason: 'its verdicts describe the log before the contact just logged');

    final after = _list('K1A', ['K1AB']);
    services.extensions.draftSuggestions.post('scp', 'op-1', after);
    expect(set.list, same(after));
  });
}
