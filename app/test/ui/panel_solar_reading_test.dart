// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the solar panel makes of what the three feeds say — and, at least as
// much, what it makes of what they say on a bad day.
//
// The parsers are total by contract: the panel classifies a failure as a
// TRANSPORT one by elimination, so anything that throws out of a parse would
// tell every operator in the world their network was down on the day a feed
// changed a field's type. The hostile-payload group holds them to that.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/solar/solar_reading.dart';

/// N0NBH's document, cut down to the tags the panel reads — including the
/// leading spaces the real feed puts inside `<aindex>` and `<kindex>`, which
/// are the reason nothing here parses with a bare `int.parse`.
const _solarXml = '''
<?xml version="1.0" encoding="UTF-8" ?>
<solar>
	<solardata>
		<source url="http://www.hamqsl.com/solar.html">N0NBH</source>
		<updated> 25 Aug 2026 1753 GMT</updated>
		<solarflux>143</solarflux>
		<aindex> 6</aindex>
		<kindex> 1</kindex>
		<xray>B9.9</xray>
		<sunspots>83</sunspots>
		<aurora> 2</aurora>
		<calculatedconditions>
			<band name="80m-40m" time="day">Fair</band>
			<band name="30m-20m" time="day">Good</band>
			<band name="12m-10m" time="day">Fair</band>
			<band name="80m-40m" time="night">Good</band>
			<band name="30m-20m" time="night">Good</band>
			<band name="12m-10m" time="night">Poor</band>
		</calculatedconditions>
		<calculatedvhfconditions>
			<phenomenon name="E-Skip" location="europe">Band Closed</phenomenon>
		</calculatedvhfconditions>
		<geomagfield>VR QUIET</geomagfield>
		<signalnoise>S0-S1</signalnoise>
		<fof2></fof2>
		<muf>NoRpt</muf>
	</solardata>
</solar>
''';

void main() {
  final fetchedAt = DateTime.utc(2026, 8, 25, 18);

  group('hamqsl conditions', () {
    test('reads the indices past the feed\'s own leading spaces', () {
      final reading = parseSolarReading(_solarXml, fetchedAtUtc: fetchedAt)!;

      expect(reading.solarFlux, 143);
      expect(reading.sunspots, 83);
      // ' 6' and ' 1' as the feed sends them: a parser that trusted the
      // whitespace would drop both numbers, and a panel showing SFI with no
      // A or K looks like a quiet day rather than a bug.
      expect(reading.aIndex, 6);
      expect(reading.kIndex, 1);
      expect(reading.xray, 'B9.9');
      expect(reading.geomagneticField, 'VR QUIET');
      expect(reading.signalNoise, 'S0-S1');
      expect(reading.fetchedAtUtc, fetchedAt);
    });

    test('an empty or non-numeric field reads as absent, not as a value', () {
      final reading = parseSolarReading(_solarXml, fetchedAtUtc: fetchedAt)!;

      // `<fof2></fof2>` and `NoRpt` are what this feed sends most days. An
      // empty string would draw a label with nothing beside it; a zero would
      // be a reading nobody took.
      expect(reading.solarFlux, isNotNull, reason: 'sanity: the document did parse');
      expect(parseSolarReading('<solarflux>143</solarflux><xray></xray>', fetchedAtUtc: fetchedAt)!.xray, isNull);
      expect(parseSolarReading('<solarflux>143</solarflux><aindex>NoRpt</aindex>', fetchedAtUtc: fetchedAt)!.aIndex,
          isNull);
    });

    test('band rows pair day with night, in the feed\'s own order', () {
      final reading = parseSolarReading(_solarXml, fetchedAtUtc: fetchedAt)!;

      // The feed sends day and night as SEPARATE elements, so a grid built by
      // iterating matches would draw six half-rows instead of three whole
      // ones.
      expect(reading.bands.map((b) => b.band), ['80m-40m', '30m-20m', '12m-10m']);
      expect(reading.bands.first.day, BandRating.fair);
      expect(reading.bands.first.night, BandRating.good);
      expect(reading.bands.last.night, BandRating.poor);
    });

    test('the VHF block contributes no rows', () {
      final reading = parseSolarReading(_solarXml, fetchedAtUtc: fetchedAt)!;

      // `<phenomenon>` carries name/location attributes that look enough like
      // a band's to be caught by a looser pattern — and "Band Closed" as a
      // rating would render as an unknown row named "E-Skip" in the HF grid.
      expect(reading.bands.map((b) => b.band), isNot(contains('E-Skip')));
      expect(reading.bands, hasLength(3));
    });

    test('a rating the feed has never sent is unknown, not poor', () {
      final reading = parseSolarReading(
        '<solarflux>143</solarflux><band name="6m" time="day">Marginal</band>',
        fetchedAtUtc: fetchedAt,
      )!;

      // An operator deciding which band to call on is owed the difference
      // between "poor" and "we don't know" — guessing the worst case reads as
      // a closed band that may be wide open.
      expect(reading.bands.single.day, BandRating.unknown);
      expect(reading.bands.single.night, BandRating.unknown, reason: 'the feed sent no night element at all');
    });

    test('no solar flux at all is not a reading', () {
      // The one field the headline is built from. Everything else may be
      // missing and simply is not drawn — this is the case that means the
      // answer was not a reading, which is what lets the panel keep the
      // previous one instead of blanking.
      expect(parseSolarReading('<html><body>404</body></html>', fetchedAtUtc: fetchedAt), isNull);
      expect(parseSolarReading('', fetchedAtUtc: fetchedAt), isNull);
    });
  });

  group('where it asks', () {
    test('the conditions URL is proxied on web, and only there', () {
      // hamqsl sends no CORS headers, so a browser refuses the response — and
      // this is the panel's one REQUIRED source, so unproxied the whole pane
      // is empty on web. `services.ham2k.net` is the same proxy the extension
      // host already routes this host through for the SOLAR command.
      expect(solarConditionsUrl(web: false).host, 'www.hamqsl.com');
      expect(solarConditionsUrl(web: true).toString(),
          'https://services.ham2k.net/www.hamqsl.com/solarxml.php');
    });

    test('SWPC is never proxied', () {
      // It answers cross-origin GETs itself; routing it through a host we run
      // would be indirection with an outage of its own.
      expect(solarFluxSeriesUrl().host, 'services.swpc.noaa.gov');
      expect(solarKpSeriesUrl().host, 'services.swpc.noaa.gov');
    });
  });

  group('SWPC series', () {
    test('flux and Kp read their own field, with the stamp as UTC', () {
      final flux = parseFluxSeries('[{"time_tag":"2026-08-24T20:00:00","flux":143}]');
      final kp = parseKpSeries('[{"time_tag":"2026-08-25T12:00:00","Kp":1.67,"a_running":6}]');

      expect(flux.single.value, 143);
      expect(kp.single.value, closeTo(1.67, 0.001));
      // The stamps carry no zone marker. `DateTime.parse` would read them as
      // the DEVICE's local time and slide the whole series by the operator's
      // offset — invisible in UTC-0, three hours wrong in Anchorage.
      expect(flux.single.utc, DateTime.utc(2026, 8, 24, 20));
      expect(kp.single.utc.isUtc, isTrue);
    });

    test('rows are sorted, because the charts index by position', () {
      final kp = parseKpSeries('['
          '{"time_tag":"2026-08-25T06:00:00","Kp":2},'
          '{"time_tag":"2026-08-25T00:00:00","Kp":5},'
          '{"time_tag":"2026-08-25T03:00:00","Kp":3}]');

      // One out-of-order row would draw a storm spike backwards through the
      // week — a shape, at a plausible height, describing nothing.
      expect(kp.map((p) => p.value), [5, 3, 2]);
    });

    test('a row missing its value or its stamp is skipped, not zeroed', () {
      final kp = parseKpSeries('['
          '{"time_tag":"2026-08-25T00:00:00","Kp":4},'
          '{"time_tag":"2026-08-25T03:00:00"},'
          '{"Kp":7},'
          '{"time_tag":"nonsense","Kp":8}]');

      // A zeroed row is a quiet three hours that never happened, sitting in
      // the middle of the record.
      expect(kp.map((p) => p.value), [4]);
    });
  });

  group('hostile payloads', () {
    // The panel reports "no network" for anything that is not its own
    // bad-answer exception. Every case here is a feed that ANSWERED.
    const bodies = [
      '',
      'null',
      '{}',
      '[]',
      'not json at all',
      '[1, 2, 3]',
      '["a", null]',
      '[{"time_tag":123,"Kp":1}]',
      '[{"time_tag":"2026-08-25T00:00:00","Kp":"4"}]',
      '[{"time_tag":"2026-08-25T00:00:00","Kp":null}]',
      '<solar><solardata><solarflux>oops</solarflux></solardata></solar>',
      '<band name="80m" time="day">Good</band>',
      '<solarflux>143</solarflux><updated>the 25th of never</updated>',
      '<solarflux>143</solarflux><band name="" time="day">Good</band>',
    ];

    for (final body in bodies) {
      test('nothing throws on ${body.isEmpty ? '(empty)' : body.substring(0, body.length.clamp(0, 40))}', () {
        expect(() => parseSolarReading(body, fetchedAtUtc: fetchedAt), returnsNormally);
        expect(() => parseFluxSeries(body), returnsNormally);
        expect(() => parseKpSeries(body), returnsNormally);
      });
    }
  });

  group('lastDays', () {
    final now = DateTime.utc(2026, 8, 25, 12);
    final series = [
      for (var days = 10; days >= 0; days--)
        (utc: now.subtract(Duration(days: days)), value: days.toDouble()),
    ];

    test('slices against the clock it is handed, not the device\'s', () {
      // Sliced per BUILD rather than at parse time, so a DEVTT jump reshapes
      // the chart without a refetch — which is the whole reason this is not
      // done in the parser.
      expect(SolarReading.lastDays(series, now, 3), hasLength(3));
      // Travel far enough back and the whole record is ahead of the app's
      // own now: the chart empties rather than drawing a month nobody has
      // lived through yet.
      expect(SolarReading.lastDays(series, now.subtract(const Duration(days: 20)), 3), isEmpty);
    });

    test('the window slides, it does not widen', () {
      // Bounded at BOTH ends. With only a floor, a clock moved back five days
      // would keep every later reading too — eight days of chart under a
      // caption saying three, ending on a day the rest of the app says has
      // not happened.
      final travelled = SolarReading.lastDays(series, now.subtract(const Duration(days: 5)), 3);
      expect(travelled, hasLength(3));
      expect(travelled.last.utc, now.subtract(const Duration(days: 5)));
    });
  });

  group('parseSolarWindSeries', () {
    // SWPC's propagated wind is an array of ARRAYS with a header row, where
    // the flux and Kp products are arrays of maps.
    String body(String header, String rows) => '[$header,$rows]';

    test('reads speed and time by NAME, not by position', () {
      // The columns reordered. A parser holding a fixed index would return a
      // perfectly plausible curve of the wrong quantity — a density plotted
      // as a wind speed looks exactly like a wind speed.
      final points = parseSolarWindSeries(body(
        '["time_tag","density","speed"]',
        '["2026-08-26T12:18:00Z",1.72,301.9]',
      ));

      expect(points, hasLength(1));
      expect(points.single.value, 301.9);
      expect(points.single.utc, DateTime.utc(2026, 8, 26, 12, 18));
    });

    test('a null speed is a gap, not a zero', () {
      // The spacecraft drops readings routinely. Drawn as zero, a dropout is
      // a wind that stopped.
      final points = parseSolarWindSeries(body(
        '["time_tag","speed"]',
        '["2026-08-26T12:18:00Z",null],["2026-08-26T12:19:00Z",302.0]',
      ));

      expect(points.map((point) => point.value), [302.0]);
    });

    test('sorted, whatever order the rows arrive in', () {
      final points = parseSolarWindSeries(body(
        '["time_tag","speed"]',
        '["2026-08-26T12:20:00Z",303.0],["2026-08-26T12:18:00Z",301.0]',
      ));

      expect(points.map((point) => point.value), [301.0, 303.0]);
    });

    test('nothing usable is an empty series, never a throw', () {
      // The panel treats a missing series as a normal state, and NOTHING in
      // this file may throw: the panel reads a throw as "no network" and
      // would tell every operator their connection was down on the day a feed
      // changed shape.
      expect(parseSolarWindSeries('not json'), isEmpty);
      expect(parseSolarWindSeries('{}'), isEmpty);
      expect(parseSolarWindSeries('[]'), isEmpty);
      expect(parseSolarWindSeries(body('["time_tag","density"]', '["2026-08-26T12:18:00Z",1.7]')), isEmpty,
          reason: 'no speed column at all');
      expect(parseSolarWindSeries(body('["time_tag","speed"]', '["nonsense",302.0]')), isEmpty);
    });
  });

  group('mergeSeries', () {
    test('the fresher feed wins a shared stamp', () {
      // The wind's week and its hour overlap by that hour, and the hourly
      // feed is the one that has heard more recently.
      final bulletin = [
        (utc: DateTime.utc(2026, 8, 25, 0), value: 1.0),
        (utc: DateTime.utc(2026, 8, 25, 3), value: 2.0),
      ];
      final json = [(utc: DateTime.utc(2026, 8, 25, 3), value: 4.0)];

      expect(mergeSeries(bulletin, json).map((point) => point.value), [1.0, 4.0]);
    });

    test('keeps the depth of one and the reach of the other, in order', () {
      final bulletin = [(utc: DateTime.utc(2026, 7, 28), value: 1.0)];
      final json = [(utc: DateTime.utc(2026, 8, 26), value: 3.0)];

      final merged = mergeSeries(bulletin, json);

      expect(merged.map((point) => point.utc), [DateTime.utc(2026, 7, 28), DateTime.utc(2026, 8, 26)]);
    });
  });

  group('averageIntoBuckets', () {
    test('aligns to the UTC three-hour grid the Kp bars sit on', () {
      // Readings starting at an arbitrary minute. Floored against the EPOCH
      // rather than against the first of them, so the buckets land on
      // 00/03/06 UTC whatever minute the feed happens to begin on — a wind
      // mark and a Kp bar at the same position must cover the same hours.
      final points = [
        (utc: DateTime.utc(2026, 8, 24, 4, 17), value: 400.0),
        (utc: DateTime.utc(2026, 8, 24, 5, 43), value: 500.0),
        (utc: DateTime.utc(2026, 8, 24, 6, 1), value: 300.0),
      ];

      final buckets = averageIntoBuckets(points);

      expect(buckets.map((point) => point.utc), [
        DateTime.utc(2026, 8, 24, 3),
        DateTime.utc(2026, 8, 24, 6),
      ]);
    });

    test('each bucket is the mean of what fell in it', () {
      final points = [
        (utc: DateTime.utc(2026, 8, 24, 3, 10), value: 400.0),
        (utc: DateTime.utc(2026, 8, 24, 4, 10), value: 500.0),
        (utc: DateTime.utc(2026, 8, 24, 5, 10), value: 600.0),
      ];

      expect(averageIntoBuckets(points).single.value, 500.0);
    });

    test('an empty bucket is absent, never interpolated', () {
      // The spacecraft drops readings. A gap invented as the mean of its
      // neighbours is a wind nobody measured.
      final points = [
        (utc: DateTime.utc(2026, 8, 24, 0, 5), value: 400.0),
        (utc: DateTime.utc(2026, 8, 24, 9, 5), value: 500.0),
      ];

      final buckets = averageIntoBuckets(points);

      expect(buckets, hasLength(2));
      expect(buckets.map((point) => point.utc), [
        DateTime.utc(2026, 8, 24, 0),
        DateTime.utc(2026, 8, 24, 9),
      ]);
    });

    test('a week of one-minute readings collapses to the week in buckets', () {
      final week = [
        for (var i = 0; i < 7 * 24 * 60; i++)
          (utc: DateTime.utc(2026, 8, 19).add(Duration(minutes: i)), value: 300.0 + i % 7),
      ];

      // 7 days / 3 hours.
      expect(averageIntoBuckets(week), hasLength(56));
    });

    test('nothing in, nothing out', () {
      expect(averageIntoBuckets(const []), isEmpty);
    });
  });


  group('the wind\'s two feeds', () {
    test('a bucket the week already averaged is not replaced by a partial one', () {
      // Right after a big fetch the recent readings are cleared, so the hour
      // held since covers only the tail of the bucket the week already
      // averaged over three hours. Letting that win draws a one-hour mean
      // under a label naming three — the plausible curve of the wrong
      // quantity, again.
      final history = [
        (utc: DateTime.utc(2026, 8, 24, 0), value: 500.0),
        (utc: DateTime.utc(2026, 8, 24, 3), value: 450.0),
      ];
      // An hour of readings inside the period history already covered, plus
      // one that runs past it.
      final recent = [
        for (var i = 0; i < 60; i++)
          (utc: DateTime.utc(2026, 8, 24, 5, i), value: 350.0),
        (utc: DateTime.utc(2026, 8, 24, 6, 1), value: 300.0),
      ];

      final buckets = averageIntoBuckets(recent);
      final covered = history.last.utc;
      final beyond = [
        for (final bucket in buckets)
          if (bucket.utc.isAfter(covered)) bucket,
      ];

      // The 03:00 bucket stays the week's own; only 06:00 comes from recent.
      expect(mergeSeries(history, beyond).map((point) => point.value), [500.0, 450.0, 300.0]);
    });
  });
}
