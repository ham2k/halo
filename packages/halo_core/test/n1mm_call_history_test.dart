// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

// Trimmed from the live search for "CWOPS", markup verbatim. The search matches
// anywhere in a name, so it lists CWOPSOPEN beside CWOPS, and two CWOPS files
// published the same day (CCC, BBB) sit below a newer one.
const _listing = '''
<div class="cmdm-archive-items CMDM-list-view">
<div class="searchTitle">Showing 1-4 of 4</div>
<ul>		<li>
            <span>
                <a href="https://n1mmwp.hamdocs.com/mmfiles/cwops_4002-txt/">
				                    <span class="cmdm-list-item-title">CWOPS_4002.txt</span>
                </a>
				<div class="cmdm-list-item-desc">
                    2026-10-20                </div>
            </span>
            <span>
                <span class="CMDM-author"><a href="https://n1mmwp.hamdocs.com/uploader/ve2fk/" class="CMDM-author-link" title="Contributor&#039;s page">Claude</a></span>            </span>
			<span>
                                    <div class="cmdm-publish-date">2026-10-20</div>
            </span>
		</li>
		<li>
            <span>
                <a href="https://n1mmwp.hamdocs.com/mmfiles/cwops_4000-ccc-txt/">
				                    <span class="cmdm-list-item-title">CWOPS_4000-CCC.txt</span>
                </a>
            </span>
			<span>
                                    <div class="cmdm-publish-date">2026-10-14</div>
            </span>
		</li>
		<li>
            <span>
                <a href="https://n1mmwp.hamdocs.com/mmfiles/cwops_4000-bbb-txt/">
				                    <span class="cmdm-list-item-title">CWOPS_4000-BBB.txt</span>
                </a>
            </span>
			<span>
                                    <div class="cmdm-publish-date">2026-10-14</div>
            </span>
		</li>
		<li>
            <span>
                <a href="https://n1mmwp.hamdocs.com/mmfiles/cwopsopen_2026-002-txt/">
				                    <span class="cmdm-list-item-title">CWOPSOPEN_2026-002.txt</span>
                </a>
            </span>
			<span>
                                    <div class="cmdm-publish-date">2026-08-31</div>
            </span>
		</li>
	</ul>
</div>
''';

const _detail = '''
<form role="search" method="get" class="searchform" action="https://n1mmwp.hamdocs.com/">
		<input type="search" class="s" placeholder="Search" value="" name="s" />
</form>
<form method="post" class="CMDM-downloadForm" action="https://n1mmwp.hamdocs.com/mmfile/get/file/CWOPS_4002.txt">
	        <input type="hidden" name="cmdm_nonce" value="41e6393e54" />
	        <input type="hidden" name="id" value="242427" />
	        	<input type="hidden" name="shortcodeId" value="7cc65bbc7b88ea64868a42e674984852" />
	        	<input type="hidden" name="backurl" value="/mmfiles/cwops_4002-txt/#cmdm-shortcode-7cc65bbc7b88ea64868a42e674984852" />
	        <a href="#" class="downloadBut cmdm-download-button cmdm-button cmdm-button-primary cmdm-button-large 				">Download</a>
	        <input type="submit" value="Download"  style="display:none" />
</form>
''';

void main() {
  final searchUrl = n1mmCallHistorySearchUrl('CWOPS');
  final pageUrl = Uri.parse('https://n1mmwp.hamdocs.com/mmfiles/cwops_4002-txt/');

  group('n1mmCallHistoryStem', () {
    test('reads the stem from the scheme, and nothing from an ordinary URL', () {
      expect(n1mmCallHistoryStem('n1mm-history:CWOPS'), 'CWOPS');
      expect(n1mmCallHistoryStem(' N1MM-HISTORY:CWOPS '), 'CWOPS');
      // A real https URL must keep the plain download path.
      expect(n1mmCallHistoryStem('https://n1mmwp.hamdocs.com/mmfiles/cwops_4002-txt/'), isNull);
    });
  });

  group('pickN1mmCallHistoryFile', () {
    List<String> items(String html) => RegExp(r'<li\b[\s\S]*?</li>').allMatches(html).map((m) => m[0]!).toList();
    String listingOf(Iterable<String> items) => '<div class="cmdm-archive-items"><ul>${items.join()}</ul></div>';

    test("takes the stem's newest file, never a longer name the search also found", () {
      final file = pickN1mmCallHistoryFile(_listing, 'CWOPS', pageUrl: searchUrl)!;
      expect(file.name, 'CWOPS_4002.txt');
      expect(file.pageUrl, pageUrl);
      expect(file.published, DateTime(2026, 10, 20));
    });

    test('goes by publish date, not by where the listing puts a file', () {
      // A listing sorted some other way must still yield the newest file.
      expect(pickN1mmCallHistoryFile(listingOf(items(_listing).reversed), 'CWOPS', pageUrl: searchUrl)!.name, 'CWOPS_4002.txt');
    });

    test("a same-day tie keeps the listing's newest-first order", () {
      // Dates are days: the listing's order, asked for newest first, is the
      // only thing that tells CCC from BBB. A later equal date winning would
      // pick the older upload.
      expect(pickN1mmCallHistoryFile(listingOf(items(_listing).skip(1)), 'CWOPS', pageUrl: searchUrl)!.name, 'CWOPS_4000-CCC.txt');
    });

    test('a page listing none of the stem\'s files is null, not the nearest name', () {
      expect(pickN1mmCallHistoryFile(_listing, 'CWOPSO', pageUrl: searchUrl), isNull);
    });

    test('a page without the listing markup is a changed site, not an empty search', () {
      expect(
        () => pickN1mmCallHistoryFile('<html><body>Maintenance</body></html>', 'CWOPS', pageUrl: searchUrl),
        throwsA(isA<N1mmCallHistoryUnavailable>().having((e) => e.noMatch, 'noMatch', isFalse)),
      );
    });

    test('decodes the numeric entities WordPress writes into URLs and titles', () {
      final html = listingOf([
        '<li><a href="https://n1mmwp.hamdocs.com/mmfiles/cwops-x/?a=1&#038;b=2"><span class="cmdm-list-item-title">CWOPS_A&#8211;B.txt</span></a></li>',
      ]);
      final file = pickN1mmCallHistoryFile(html, 'CWOPS', pageUrl: searchUrl)!;
      expect(file.pageUrl.queryParameters, {'a': '1', 'b': '2'}, reason: 'a literal &#038; sends the GET to a different address');
      expect(file.name, 'CWOPS_A\u2013B.txt');
    });
  });

  group('N1mmCallHistoryFile.version', () {
    test('changes with the publish date, not only the name', () {
      // SSCW_new.txt keeps its name across updates: versioned by name alone,
      // a re-upload reads as unchanged and is never downloaded.
      final a = N1mmCallHistoryFile(name: 'SSCW_new.txt', pageUrl: pageUrl, published: DateTime(2025, 11, 3));
      final b = N1mmCallHistoryFile(name: 'SSCW_new.txt', pageUrl: pageUrl, published: DateTime(2026, 10, 30));
      expect(a.version, isNot(b.version));
    });
  });

  group('findN1mmCallHistoryFile', () {
    // A page of 50 filled with longer names: a short stem's search can list
    // its own files only on a later page.
    String page(int shown, int total, List<String> names) =>
        '<div class="searchTitle">Showing ${shown - 49}-$shown of $total</div><div class="cmdm-archive-items"><ul>'
        '${names.map((n) => '<li><a href="https://n1mmwp.hamdocs.com/mmfiles/${n.toLowerCase()}/"><span class="cmdm-list-item-title">$n</span></a></li>').join()}'
        '</ul></div>';

    test('reads on past a page that lists none of the stem\'s files, newest first', () async {
      final requested = <Uri>[];
      final file = await findN1mmCallHistoryFile('SS', (url) async {
        requested.add(url);
        return url.path.contains('/page/2/') ? page(100, 134, ['SS_2026.txt']) : page(50, 134, ['SSCW_new.txt', 'SSSSB.txt']);
      });

      expect(file.name, 'SS_2026.txt');
      expect(requested.map((u) => u.path), ['/mmfiles/categories/callhistory/', '/mmfiles/categories/callhistory/page/2/']);
      expect(requested.every((u) => u.queryParameters['sort'] == 'newest'), isTrue, reason: 'the first page with a match holds the newest only in this order');
    });

    test('stops at the last page, and says nothing matched', () async {
      var pages = 0;
      await expectLater(
        findN1mmCallHistoryFile('SS', (url) async {
          pages++;
          return page(50, 50, ['SSCW_new.txt']);
        }),
        throwsA(isA<N1mmCallHistoryUnavailable>().having((e) => e.noMatch, 'noMatch', isTrue)),
      );
      expect(pages, 1);
    });
  });

  group('downloadN1mmCallHistoryFile', () {
    final file = N1mmCallHistoryFile(name: 'CWOPS_4002.txt', pageUrl: pageUrl);

    test('POSTs the form from the file\'s page', () async {
      Map<String, String>? sent;
      final body = await downloadN1mmCallHistoryFile(file, 'CWOPS', (url) async => _detail, (url, fields) async {
        sent = fields;
        return (bytes: [0x21], contentType: 'application/octet-stream');
      });
      expect(body.bytes, [0x21]);
      expect(sent?['cmdm_nonce'], '41e6393e54');
    });

    test('an HTML answer to the POST is a refusal, not the file', () async {
      // Taken as the file, the access-denied page is imported and its version
      // stored, so nothing fetches the real file until N1MM publishes another.
      await expectLater(
        downloadN1mmCallHistoryFile(file, 'CWOPS', (url) async => _detail, (url, fields) async => (bytes: [0x3c], contentType: 'text/html; charset=UTF-8')),
        throwsA(isA<N1mmCallHistoryUnavailable>()),
      );
    });
  });

  group('n1mmCallHistoryNameMatches', () {
    test('a separator must follow the stem', () {
      expect(n1mmCallHistoryNameMatches('CWOPS.txt', 'CWOPS'), isTrue);
      expect(n1mmCallHistoryNameMatches('cwops-new.txt', 'CWOPS'), isTrue);
      expect(n1mmCallHistoryNameMatches('CWOPSOPEN_2026-002.txt', 'CWOPS'), isFalse);
      expect(n1mmCallHistoryNameMatches('QSOP_NY-2026-002.txt', 'QSOP_NY'), isTrue);
      expect(n1mmCallHistoryNameMatches('QSOP_NYC-2026-002.txt', 'QSOP_NY'), isFalse);
    });
  });

  group('parseN1mmDownloadForm', () {
    test("reads the download form's action and every hidden field, nonce included", () {
      final form = parseN1mmDownloadForm(_detail, 'CWOPS', pageUrl: pageUrl);
      // The site search form comes first on the page; taking it would POST
      // to the home page.
      expect(form.action, Uri.parse('https://n1mmwp.hamdocs.com/mmfile/get/file/CWOPS_4002.txt'));
      expect(form.fields, {
        'cmdm_nonce': '41e6393e54',
        'id': '242427',
        'shortcodeId': '7cc65bbc7b88ea64868a42e674984852',
        'backurl': '/mmfiles/cwops_4002-txt/#cmdm-shortcode-7cc65bbc7b88ea64868a42e674984852',
      });
    });

    test('a form without a nonce fails here, since the POST would only be refused', () {
      final noNonce = _detail.replaceFirst(RegExp(r'<input type="hidden" name="cmdm_nonce"[^>]*>'), '');
      expect(() => parseN1mmDownloadForm(noNonce, 'CWOPS', pageUrl: pageUrl), throwsA(isA<N1mmCallHistoryUnavailable>()));
    });

    test('a page without the download form fails', () {
      expect(() => parseN1mmDownloadForm('<form class="searchform" action="/"></form>', 'CWOPS', pageUrl: pageUrl), throwsA(isA<N1mmCallHistoryUnavailable>()));
    });
  });
}
