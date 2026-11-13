// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `host.draftSuggestions` (docs/design/logging-fields.md § Draft
// suggestions): who may offer suggestions, what a list may hold, and which
// list an operation shows. A pick writes the draft, so the grant is
// `updateDraft`'s; and it never moves the radio, so a draft naming a
// frequency must be refused where it is made rather than dropped unseen.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;
import 'package:halo_widgets/halo_widgets.dart' show DraftSuggestionList, mergeDraftPatch;
import 'package:ham2k_logger/services/extensions/extension_info.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ExtensionServiceWithFakeHost harness({bool draftWrite = true}) {
    final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}));
    extensions.debugSetAvailableExtensions([
      for (final key in ['k1abc-scp', 'k2xyz-history'])
        ExtensionInfo(key: key, file: '$key.js', name: key, core: false, source: ExtensionSource.installed, requiresDraftWrite: draftWrite),
    ]);
    extensions.frontOperationUuid = () => 'op-front';
    addTearDown(extensions.bandAnnotations.dispose);
    addTearDown(extensions.spotMarks.dispose);
    return extensions;
  }

  Map<String, dynamic> draft(String call, [Map<String, dynamic> more = const {}]) => {
    'qso': {
      'their': {'call': call},
      ...more,
    },
  };

  DraftSuggestionList? shown(ExtensionServiceWithFakeHost extensions, String operation, [String call = 'K1A']) =>
      extensions.draftSuggestions.listFor(operation, call: call)?.list;

  Future<dynamic> post(ExtensionServiceWithFakeHost extensions, Map<String, dynamic> params, {String from = 'k1abc-scp'}) =>
      extensions.debugHandleHostCall('draftSuggestionsPost', {'extensionKey': from, ...params});

  test('is refused without requiresDraftWrite, and offers nothing', () async {
    final extensions = harness(draftWrite: false);
    await expectLater(
      post(extensions, {
        'forCall': 'K1A',
        'drafts': [draft('K1AB')],
      }),
      throwsA(isA<ExtensionHostException>()),
    );
    expect(shown(extensions, 'op-front'), isNull);
  });

  test('a list reaches the operation in front, its calls read as the call field reads them', () async {
    final extensions = harness();
    final answer = await post(extensions, {
      'forCall': ' k1a ',
      'drafts': [
        {
          ...draft(' k1ab', {
            'their': {'call': ' k1ab', 'name': 'Al'},
          }),
          'notices': ['duplicate'],
        },
      ],
    });
    expect(answer, {'accepted': true});
    final list = shown(extensions, 'op-front')!;
    expect(list.forCall, 'K1A');
    expect(list.drafts.single.call, 'K1AB');
    expect(list.drafts.single.qso, {
      'their': {'call': 'K1AB', 'name': 'Al'},
    });
    expect(list.drafts.single.isDuplicate, isTrue);
  });

  // Refused at the post, not dropped: a draft the contact cannot take would
  // otherwise throw on the operator's keypress, half applied, and every log
  // of that contact after it.
  test('refuses a draft carrying more than the station, or a field of the wrong kind, and more drafts than the line holds', () async {
    final extensions = harness();
    final refused = <String, Map<String, dynamic>>{
      'freq': {'freq': 14025},
      'band': {'band': '20m'},
      'mode': {'mode': 'CW'},
      'startAtMillis': {'startAtMillis': 1},
      'endAtMillis': {'endAtMillis': 1},
      'uuid': {'uuid': 'abc'},
      'notes, not text': {'notes': 42},
      'their.name, not text': {
        'their': {'call': 'K1AB', 'name': 7},
      },
      'their.sent, the report': {
        'their': {'call': 'K1AB', 'sent': '599'},
      },
      'refs, not pairs of text': {
        'refs': [
          {'type': 'pota'},
        ],
      },
    };
    for (final MapEntry(key: reason, value: more) in refused.entries) {
      await expectLater(
        post(extensions, {
          'forCall': 'K1A',
          'drafts': [draft('K1AB', more)],
        }),
        throwsFormatException,
        reason: reason,
      );
    }
    await expectLater(
      post(extensions, {
        'forCall': 'K1A',
        'drafts': [
          {
            ...draft('K1AB'),
            'alerts': [for (var i = 0; i < 17; i++) 'a$i'],
          },
        ],
      }),
      throwsFormatException,
      reason: 'more verdicts than a call carries',
    );
    await expectLater(
      post(extensions, {
        'forCall': 'K1A',
        'drafts': [for (var i = 0; i < 11; i++) draft('K${i}AB')],
      }),
      throwsA(isA<ExtensionHostException>()),
    );
    expect(shown(extensions, 'op-front'), isNull);
  });

  test("a set shows the newest list made for its call; an empty post or a clear shows the other extension's, and a runtime going takes its own", () async {
    final extensions = harness();
    await post(extensions, {
      'forCall': 'K1A',
      'drafts': [draft('K1AB')],
    });
    await post(extensions, {
      'forCall': 'K1A',
      'drafts': [draft('K1AC')],
    }, from: 'k2xyz-history');
    expect(shown(extensions, 'op-front')!.drafts.single.call, 'K1AC');

    // A list for text the operator has typed past hides nothing.
    await post(extensions, {
      'forCall': 'K1',
      'drafts': [draft('K1XYZ')],
    }, from: 'k2xyz-history');
    expect(shown(extensions, 'op-front')!.drafts.single.call, 'K1AB', reason: "k2xyz-history's K1 list replaced its own, and is not for K1A");

    await post(extensions, {
      'forCall': 'K1A',
      'drafts': [draft('K1AC')],
    }, from: 'k2xyz-history');
    await post(extensions, {'forCall': 'K1A', 'drafts': <Object>[]}, from: 'k2xyz-history');
    expect(shown(extensions, 'op-front')!.drafts.single.call, 'K1AB', reason: 'an empty list takes its own down rather than blanking the line');

    await extensions.debugHandleHostCall('draftSuggestionsClear', {'extensionKey': 'k2xyz-history'});
    expect(shown(extensions, 'op-front')!.drafts.single.call, 'K1AB');

    extensions.draftSuggestions.clearExtension('k1abc-scp');
    expect(shown(extensions, 'op-front'), isNull);
  });

  test('a picked grid clears the coordinate it would otherwise lose to', () async {
    final extensions = harness();
    await post(extensions, {
      'forCall': 'K1A',
      'drafts': [
        draft('K1AB', {
          'their': {'call': 'K1AB', 'grid': 'FN31'},
        }),
      ],
    });
    final their = mergeDraftPatch({
      'their': {'call': 'K1A', 'grid': 'EM12', 'lat': 33.0, 'lon': -97.0},
    }, shown(extensions, 'op-front')!.drafts.single.qso)['their'];
    expect(their, {'call': 'K1AB', 'grid': 'FN31'});
  });

  test('a post with no operation open to show it in is not accepted', () async {
    final extensions = harness()..frontOperationUuid = () => null;
    expect(
      await post(extensions, {
        'forCall': 'K1A',
        'drafts': [draft('K1AB')],
      }),
      {'accepted': false},
    );
  });

  test('a list for a named operation goes to that one alone', () async {
    final extensions = harness();
    await post(extensions, {
      'forCall': 'K1A',
      'operationUuid': 'op-other',
      'drafts': [draft('K1AB')],
    });
    expect(shown(extensions, 'op-other'), isNotNull);
    expect(shown(extensions, 'op-front'), isNull);
  });
}
