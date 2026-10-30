// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The preview of a spot command naming a source: the hook has the word, the
// app has the sources and their names, and the preview says where the spot
// will go — or refuses a word nothing answers to before Enter can send it.

import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/services/extensions/spot_command_sources.dart';

const _names = {'ham2k-pota': 'POTA.app', 'ki2d-discord-spotting': 'Discord', 'ham2k-discord-spotterbot': 'Spotterbot'};

/// What the spot-commands hook answers: its own words, and the word typed.
Map<String, dynamic> _spot({String? comment, String target = 'self', String? source}) => {
  'mixedCase': true,
  'describe': 'Self-spot?',
  'confirm': 'Self-spotting…',
  'commands': [
    {
      'sendSpots': {'comment': ?comment, 'target': target, 'source': ?source},
    },
  ],
};

void main() {
  // By the names the Spotting control's icons show, not the keys typed, and
  // every source the word reaches — a preview naming one of two would hide
  // where the spot also goes.
  test('names every source the word reaches, as its hook names it, in place of the hook\'s words', () {
    final out = describeSpotSources(_spot(comment: 'hey', source: 'discord'), _names);
    expect(out['describe'], 'Self-spot to Discord, Spotterbot with "hey"?');
    expect(out['confirm'], 'Self-spotting to Discord, Spotterbot: hey');
    expect(
      out['commands'],
      _spot(comment: 'hey', source: 'discord')['commands'],
      reason: 'the action still carries the word the control filters by',
    );
    expect(out['mixedCase'], isTrue);
    expect(describeSpotSources(_spot(source: 'POTA'), _names)['describe'], 'Self-spot to POTA.app?', reason: 'case aside, and no comment');
  });

  test('SPOTLAST says what it spots', () {
    expect(describeSpotSources(_spot(target: 'last', source: 'pota'), _names)['describe'], 'Spot the last logged QSO to POTA.app?');
    final out = describeSpotSources(_spot(target: 'last', comment: 'QSB', source: 'pota'), _names);
    expect(out['describe'], 'Spot the last logged QSO to POTA.app with "QSB"?');
    expect(out['confirm'], 'Spotting last QSO to POTA.app: QSB');
  });

  // Left to run, the spot would go nowhere and say so only after Enter; and
  // the keys are what the next try has to be a word of.
  test('a word no installed source answers to is an error in place of the command, naming the keys that would', () {
    final out = describeSpotSources(_spot(comment: 'hi', source: 'qpspots'), _names);
    expect(out['error'], 'No spot source matches "qpspots" — installed: ham2k-pota, ki2d-discord-spotting, ham2k-discord-spotterbot.');
    expect(out.containsKey('commands'), isFalse, reason: 'Enter must run nothing');
    expect(out.containsKey('describe'), isFalse);
    expect(out['mixedCase'], isTrue, reason: 'the field keeps what was typed while the error shows');
  });

  test('a command naming no source, or a runtime with no names to give, is left as the hook answered', () {
    final plain = _spot(comment: 'hi');
    expect(describeSpotSources(plain, _names), same(plain));
    final narrowed = _spot(comment: 'hi', source: 'pota');
    expect(describeSpotSources(narrowed, const {}), same(narrowed), reason: 'nothing to refuse it against; the Spotting control explains when it runs');
    expect(sendSpotsNamingSource(plain), isNull);
    expect(sendSpotsNamingSource(narrowed)?['source'], 'pota');
  });
}
