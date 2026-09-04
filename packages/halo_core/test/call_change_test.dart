// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the Operation Details dialog is allowed to say, and to offer, when the
// station or operator callsign is edited. The offer rewrites every contact in
// the log, so each verdict here is a promise about when that offer appears at
// all — an offer made in the wrong case relabels contacts that were right.

import 'package:test/test.dart';
import 'package:halo_core/halo_core.dart';

void main() {
  test('an empty log has nothing to say', () {
    expect(adviceForCallChange(calls: const [], typed: 'KI2D').change, CallChange.quiet);
  });

  test('an empty field has nothing to say either', () {
    // Mid-edit — the field is cleared before the new call is typed, and an
    // offer to restamp every contact to "" would be there for that keystroke.
    expect(adviceForCallChange(calls: const ['N0DEV'], typed: '').change, CallChange.quiet);
  });

  test('a log that already agrees offers nothing', () {
    final advice = adviceForCallChange(calls: const ['KI2D', 'KI2D'], typed: 'KI2D');
    expect(advice.change, CallChange.agrees);
    expect(advice.count, 0, reason: 'nothing to restamp means nothing to count');
  });

  test('the comparison ignores case and surrounding space', () {
    // The stored value comes from a QSON blob that other apps and importers
    // write; treating " ki2d" as a different call would offer to restamp a log
    // that is already right.
    expect(adviceForCallChange(calls: const [' ki2d '], typed: 'ki2d').change, CallChange.agrees);
  });

  test('one other call is the restamp offer', () {
    final advice = adviceForCallChange(calls: const ['N0DEV', 'N0DEV', 'N0DEV'], typed: 'KI2D');
    expect(advice.change, CallChange.single);
    expect(advice.previous, ['N0DEV']);
    expect(advice.count, 3);
  });

  test('contacts carrying no call at all are still the single case, and still counted', () {
    // An operator call is absent on most contacts — the operation names one
    // and nothing stamps it per contact. Reading that as "nothing to offer"
    // would leave the whole log unable to name who operated it.
    final advice = adviceForCallChange(calls: const ['', ''], typed: 'KI2D');
    expect(advice.change, CallChange.single);
    expect(advice.previous, isEmpty, reason: 'there is no previous call to name in the message');
    expect(advice.count, 2);
  });

  test('a contact with no call is restamped alongside one carrying the old call', () {
    // The count is contacts, not occurrences of the old call: a blank contact
    // is exactly as wrong as one carrying the old call, and the restamp
    // rewrites it too — a count of 1 here would understate what Save does.
    final advice = adviceForCallChange(calls: const ['N0DEV', ''], typed: 'KI2D');
    expect(advice.change, CallChange.single);
    expect(advice.count, 2);
  });

  test('the calls it names include the one being typed', () {
    // "already has contacts under N0DEV, W2XYZ" is false when a third of the
    // log is already under the call the operator is typing.
    final advice = adviceForCallChange(calls: const ['KI2D', 'N0DEV', 'W2XYZ'], typed: 'KI2D');
    expect(advice.change, CallChange.several);
    expect(advice.previous, ['KI2D', 'N0DEV', 'W2XYZ']);
  });

  test('several calls in use offers nothing, and names them', () {
    // A multi-call operation has no single "the wrong one" to replace, so the
    // dialog states what is there and leaves the log alone.
    final advice = adviceForCallChange(calls: const ['N0DEV', 'W1AW', 'N0DEV'], typed: 'KI2D');
    expect(advice.change, CallChange.several);
    expect(advice.previous, ['N0DEV', 'W1AW']);
    expect(advice.count, 0, reason: 'no offer means no count to show on one');
  });

  test('a single straggler beside the typed call is offered, and only it is counted', () {
    // Contacts that already carry the typed call are not counted and not
    // written: the number on the offer is what actually changes, so an
    // operator reading "1 contact" must not have 20 rewritten behind it.
    final advice = adviceForCallChange(calls: const ['KI2D', 'W1AW', 'KI2D'], typed: 'KI2D');
    expect(advice.change, CallChange.single);
    expect(advice.previous, ['W1AW']);
    expect(advice.count, 1);
  });

  test('a partly-stamped log is offered the rest, not read as agreeing', () {
    // An operator named halfway through an operation leaves every earlier
    // contact blank. Reading that as "the log already agrees" strands them
    // with no way to backfill.
    final advice = adviceForCallChange(calls: const ['KI2D', '', ''], typed: 'KI2D');
    expect(advice.change, CallChange.single);
    expect(advice.previous, isEmpty);
    expect(advice.count, 2);
  });
}
