// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// N1MM Logger+'s call history files, kept by their contributors at
// n1mmwp.hamdocs.com and usually renamed with every update (CWOPS_4002.txt), so
// no URL points at "the current one" for good. A data file names one by stem —
// `url: 'n1mm-history:CWOPS'` — and the host finds it in three requests:
//
//   1. GET the category's search for the stem, newest first, page by page
//      until one lists a file of the stem ([findN1mmCallHistoryFile]);
//   2. GET that file's page, which holds its download form;
//   3. POST that form ([downloadN1mmCallHistoryFile]). Its nonce is the only
//      gate: a GET of the form's action, or a POST without the nonce, is
//      redirected to an "access denied" page.
//
// The responses carry no ETag; [N1mmCallHistoryFile.version] stands in for
// one, so an unchanged version lets the app skip steps 2 and 3.
//
// Both hosts run this — the app's DataFileManager and the CLI's DataFileSync —
// each passing in its own GET and POST, so the sequence and its checks exist
// once. A hand-rolled scan rather than an HTML parser, as for `<contactinfo>`:
// the pages come from one WordPress plugin, and a change to its markup fails
// loudly as [N1mmCallHistoryUnavailable] rather than picking a wrong file.

/// The `url` prefix that names an N1MM call history file by stem.
const n1mmCallHistoryScheme = 'n1mm-history:';

/// The stem a data-file [url] names, or null when it is an ordinary URL.
String? n1mmCallHistoryStem(String url) {
  final u = url.trim();
  if (!u.toLowerCase().startsWith(n1mmCallHistoryScheme)) return null;
  return u.substring(n1mmCallHistoryScheme.length).trim();
}

/// One [page] of the category search for [stem], newest first. The search
/// matches anywhere in a file's name — `CWOPS` also finds
/// `CWOPSOPEN_2026-002.txt` — so its results go through
/// [n1mmCallHistoryNameMatches]. A page lists 50 files.
Uri n1mmCallHistorySearchUrl(String stem, {int page = 1}) => Uri.https(
  'n1mmwp.hamdocs.com',
  page == 1 ? '/mmfiles/categories/callhistory/' : '/mmfiles/categories/callhistory/page/$page/',
  {'CMDsearch': stem, 'sort': 'newest'},
);

/// One file in an N1MM listing.
class N1mmCallHistoryFile {
  const N1mmCallHistoryFile({required this.name, required this.pageUrl, this.published});

  /// The file's name, `CWOPS_4002.txt`.
  final String name;

  /// The file's own page, where its download form is.
  final Uri pageUrl;

  /// A day, not a time: the listing shows no more.
  final DateTime? published;

  /// What changes when the file does. Most contributors upload each update
  /// under a new name, but not all — `SSCW_new.txt` keeps its own — so the
  /// publish date and the page count too.
  String get version => '$name@${published?.toIso8601String().substring(0, 10) ?? '-'}@$pageUrl';
}

/// N1MM's pages did not lead to a file: nothing matched the stem ([noMatch]),
/// or a page no longer has the shape this scan reads, or the download was
/// refused.
class N1mmCallHistoryUnavailable implements Exception {
  const N1mmCallHistoryUnavailable(this.stem, this.reason, {this.noMatch = false});

  final String stem;
  final String reason;
  final bool noMatch;

  @override
  String toString() => 'N1mmCallHistoryUnavailable: $reason for "$stem"';
}

final _listItem = RegExp(r'<li\b[\s\S]*?</li>', caseSensitive: false);
final _itemLink = RegExp(
  r'''<a\s[^>]*href=["']([^"']+)["'][^>]*>\s*<span[^>]*class=["'][^"']*cmdm-list-item-title[^"']*["'][^>]*>([\s\S]*?)</span>''',
  caseSensitive: false,
);
final _itemDate = RegExp(r'''class=["'][^"']*cmdm-publish-date[^"']*["'][^>]*>\s*([^<]*?)\s*<''', caseSensitive: false);
final _showing = RegExp(r'Showing\s+\d+-(\d+)\s+of\s+(\d+)');

/// Every file a listing page shows, in the listing's order.
List<N1mmCallHistoryFile> parseN1mmCallHistoryListing(String html, {required Uri pageUrl}) => [
  for (final item in _listItem.allMatches(html))
    if (_itemLink.firstMatch(item[0]!) case final link?)
      N1mmCallHistoryFile(
        name: _decodeEntities(link[2]!.trim()),
        pageUrl: pageUrl.resolve(_decodeEntities(link[1]!)),
        published: DateTime.tryParse(_itemDate.firstMatch(item[0]!)?[1] ?? ''),
      ),
];

/// Whether [name] is a file of [stem]: the stem itself, or the stem followed by
/// `-` or `_`, ignoring case and the extension. `CWOPS` takes `CWOPS_4002.txt`
/// and `CWOPS_4000-CCC.txt`, not `CWOPSOPEN_2026-002.txt`.
bool n1mmCallHistoryNameMatches(String name, String stem) {
  final dot = name.lastIndexOf('.');
  final base = (dot > 0 ? name.substring(0, dot) : name).toLowerCase();
  final s = stem.toLowerCase();
  return base == s || base.startsWith('${s}_') || base.startsWith('$s-');
}

/// The newest file of [stem] on one search listing page, or null when it lists
/// none. A tie on the publish date, or a date the scan cannot read, keeps the
/// listing's newest-first order.
N1mmCallHistoryFile? pickN1mmCallHistoryFile(String html, String stem, {required Uri pageUrl}) {
  final files = parseN1mmCallHistoryListing(html, pageUrl: pageUrl);
  if (files.isEmpty && !html.contains('cmdm-')) throw N1mmCallHistoryUnavailable(stem, 'the search page has no file listing');
  N1mmCallHistoryFile? newest;
  for (final file in files) {
    if (!n1mmCallHistoryNameMatches(file.name, stem)) continue;
    final a = file.published, b = newest?.published;
    if (newest == null || (a != null && b != null && a.isAfter(b))) newest = file;
  }
  return newest;
}

/// Whether a search listing page has more results after it ("Showing 1-50 of
/// 134").
bool n1mmCallHistoryListingHasMore(String html) {
  final m = _showing.firstMatch(html);
  return m != null && int.parse(m[1]!) < int.parse(m[2]!);
}

/// The newest file of [stem], searched through [get] (the page's body, or a
/// throw). Newest first, so the first page listing one of the stem's files
/// holds the newest; [maxPages] bounds a stem so short that its search lists
/// most of the category.
Future<N1mmCallHistoryFile> findN1mmCallHistoryFile(String stem, Future<String> Function(Uri url) get, {int maxPages = 10}) async {
  for (var page = 1; page <= maxPages; page++) {
    final url = n1mmCallHistorySearchUrl(stem, page: page);
    final html = await get(url);
    final file = pickN1mmCallHistoryFile(html, stem, pageUrl: url);
    if (file != null) return file;
    if (!n1mmCallHistoryListingHasMore(html)) break;
  }
  throw N1mmCallHistoryUnavailable(stem, 'no call history file matches', noMatch: true);
}

/// The POST a file's page makes to download it.
class N1mmDownloadForm {
  const N1mmDownloadForm(this.action, this.fields);

  final Uri action;

  /// Every hidden input, the nonce among them.
  final Map<String, String> fields;
}

final _downloadForm = RegExp(r'''<form\b[^>]*class=["'][^"']*CMDM-downloadForm[^"']*["'][^>]*>([\s\S]*?)</form>''', caseSensitive: false);
final _input = RegExp(r'<input\b[^>]*>', caseSensitive: false);
final _attribute = RegExp(r'''([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')''');

Map<String, String> _attributes(String tag) => {for (final m in _attribute.allMatches(tag)) m[1]!.toLowerCase(): _decodeEntities(m[2] ?? m[3]!)};

/// The download form on a file's page.
N1mmDownloadForm parseN1mmDownloadForm(String html, String stem, {required Uri pageUrl}) {
  final form = _downloadForm.firstMatch(html);
  final action = form == null ? null : _attributes(html.substring(form.start, html.indexOf('>', form.start) + 1))['action'];
  if (form == null || action == null || action.isEmpty) throw N1mmCallHistoryUnavailable(stem, "the file's page has no download form");
  final fields = <String, String>{
    for (final input in _input.allMatches(form[1]!))
      if (_attributes(input[0]!) case {'type': final type, 'name': final name} when type.toLowerCase() == 'hidden') name: _attributes(input[0]!)['value'] ?? '',
  };
  if (!fields.containsKey('cmdm_nonce')) throw N1mmCallHistoryUnavailable(stem, "the file's download form has no nonce");
  return N1mmDownloadForm(pageUrl.resolve(action), fields);
}

/// [file]'s body as served: its page read through [get], then its form sent
/// through [post], which answers the body's bytes and Content-Type, or throws.
Future<({List<int> bytes, String? contentType})> downloadN1mmCallHistoryFile(
  N1mmCallHistoryFile file,
  String stem,
  Future<String> Function(Uri url) get,
  Future<({List<int> bytes, String? contentType})> Function(Uri url, Map<String, String> fields) post,
) async {
  final form = parseN1mmDownloadForm(await get(file.pageUrl), stem, pageUrl: file.pageUrl);
  final response = await post(form.action, form.fields);
  // A refused POST redirects to an "access denied" page, which a host's [post]
  // fails on: native clients do not follow a POST's redirect, and the web
  // proxy answers it with a 502. A site that served that page outright would
  // answer 200, and without this an HTML page is imported as the file and its
  // version stored as downloaded.
  if (response.contentType?.toLowerCase().startsWith('text/html') ?? false) {
    throw N1mmCallHistoryUnavailable(stem, 'N1MM refused the download of ${file.name}');
  }
  return response;
}

final _numericEntity = RegExp(r'&#(x?)([0-9a-fA-F]+);');

/// WordPress writes `&#038;` into URLs (`esc_url`) and `&#8211;` into titles,
/// beside the named entities.
String _decodeEntities(String s) => s
    .replaceAllMapped(_numericEntity, (m) {
      final code = int.tryParse(m[2]!, radix: m[1]!.isEmpty ? 10 : 16);
      return code == null || code > 0x10FFFF ? m[0]! : String.fromCharCode(code);
    })
    .replaceAll('&quot;', '"')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');
