// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

// Field values match a real N1MM broadcast captured live against HALO-306:
// `band` is a Cabrillo-style code (nominal MHz, not meters) and
// `txfreq`/`rxfreq` are in tens of Hz (not kHz).
const _contactInfo = '''
<contactinfo>
<app>N1MM</app>
<contestname>ARRL-SS-CW</contestname>
<timestamp>2026-03-15 22:15:32</timestamp>
<mycall>N0DEV</mycall>
<band>14</band>
<txfreq>1402540</txfreq>
<operator>N0DEV</operator>
<mode>CW</mode>
<call>K3TN</call>
<snt>599</snt>
<rcv>599</rcv>
<gridsquare>FN42</gridsquare>
<exchange1>2</exchange1>
<section>CT</section>
<name>Ken</name>
<sntnr>1</sntnr>
<rcvnr>2</rcvnr>
</contactinfo>
''';

void main() {
  test('parses a contactinfo datagram into QSON', () {
    final info = parseN1mmContactInfo(_contactInfo);
    expect(info, isNotNull);
    expect(info!.myCall, 'N0DEV');
    expect(info.qso['our'], containsPair('call', 'N0DEV'));
    expect(info.qso['their'], containsPair('call', 'K3TN'));
    expect(info.qso['band'], '20m');
    expect(info.qso['mode'], 'CW');
    expect(info.qso['freq'], 14025.40);
    expect(info.qso['startAtMillis'], DateTime.utc(2026, 3, 15, 22, 15, 32).millisecondsSinceEpoch);
    // Contest exchange has no QSON field of its own (extensions own that
    // vocabulary), so it lands in notes rather than being dropped.
    expect(info.qso['notes'], contains('CT'));
    expect(info.qso['notes'], contains('Exch: 2'));
  });

  // N1MM sends <operator> on every contact, normally the station call itself.
  // Stored unconditionally it becomes a fact the logging side must not
  // overwrite (`qsoWithOperator`), and every capture then blocks the stamp
  // that names who was actually at the key — so a multi-op's N1MM contacts
  // name nobody. Worse, `qsoForStation` rewrites `our.call` to the
  // operation's own call and leaves this alone, so an operation running
  // KI2D/P would export <OPERATOR>KI2D: a guest operator who never existed.
  test('an operator equal to the station call is not a fact about the contact', () {
    final same = parseN1mmContactInfo(_contactInfo)!;
    expect(same.qso['our'], isNot(contains('operatorCall')));

    // Neither value is normalized on its way off the wire.
    final cased = parseN1mmContactInfo(_contactInfo.replaceFirst('<operator>N0DEV</operator>', '<operator>n0dev</operator>'))!;
    expect(cased.qso['our'], isNot(contains('operatorCall')));

    final guest = parseN1mmContactInfo(_contactInfo.replaceFirst('<operator>N0DEV</operator>', '<operator>W1ABC</operator>'))!;
    expect(guest.qso['our'], containsPair('operatorCall', 'W1ABC'));
  });

  test('tolerates the XML declaration N1MM prefixes every real datagram with', () {
    final info = parseN1mmContactInfo('<?xml version="1.0" encoding="utf-8"?>\r\n$_contactInfo');
    expect(info, isNotNull);
    expect(info!.qso['their'], containsPair('call', 'K3TN'));
  });

  test('ignores any datagram that is not contactinfo', () {
    expect(parseN1mmContactInfo('<RadioInfo><Freq>14025400</Freq></RadioInfo>'), isNull);
    expect(parseN1mmContactInfo('not xml at all'), isNull);
  });

  test('rejects a contactinfo record with no callsign or no timestamp', () {
    expect(parseN1mmContactInfo('<contactinfo><timestamp>2026-03-15 22:15:32</timestamp></contactinfo>'), isNull);
    expect(parseN1mmContactInfo('<contactinfo><call>K3TN</call></contactinfo>'), isNull);
  });

  test('dedupe key is stable for the same contact and differs for another', () {
    final a = parseN1mmContactInfo(_contactInfo)!;
    final b = parseN1mmContactInfo(_contactInfo)!;
    expect(n1mmDedupeKey(a), n1mmDedupeKey(b));

    final different = parseN1mmContactInfo(_contactInfo.replaceFirst('K3TN', 'W1AW'))!;
    expect(n1mmDedupeKey(a), isNot(n1mmDedupeKey(different)));
  });

  test('frequency wins over the band code when both are present', () {
    // <band> here says "14" (20m) but <txfreq> says 21.025MHz (15m) — freq
    // is the more precise source, so it must be the one that wins.
    final mismatched = _contactInfo.replaceFirst('<txfreq>1402540</txfreq>', '<txfreq>2102540</txfreq>');
    final info = parseN1mmContactInfo(mismatched);
    expect(info!.qso['band'], '15m');
  });

  test('a free-text comment leads the notes, ahead of the contest exchange', () {
    final withComment = _contactInfo.replaceFirst('<name>Ken</name>', '<name>Ken</name><comment>Was fun</comment>');
    final info = parseN1mmContactInfo(withComment);
    expect(info!.qso['notes'], startsWith('Was fun'));
    expect(info.qso['notes'], contains('N1MM exchange'));
  });

  test('falls back to the band code when N1MM omits frequency', () {
    final noFreq = _contactInfo.replaceFirst('<txfreq>1402540</txfreq>', '');
    final info = parseN1mmContactInfo(noFreq);
    expect(info!.qso['band'], '20m');
    expect(info.qso.containsKey('freq'), isFalse);
  });
}
