// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// Where the app fetches a data file's [urlString] from: on web, a host
/// that sends no CORS headers is reached through the services.ham2k.net
/// proxy, which must carry a route for it (services.ham2k.net's
/// config.yaml); anywhere else, the URL itself.
String dataFileFetchUrl(String urlString, {required bool isWeb}) {
  if (isWeb) {
    final uri = Uri.parse(urlString);
    const allowedDomains = {
      'api.pota.app',
      'logbook.qrz.com',
      'xmldata.qrz.com',
      'country-files.com',
      'pota.app',
      'www.sotadata.org.uk',
      'sotadata.org.uk',
      'llota.app',
      // Award-program hosts serving reference lists with no CORS headers of
      // their own. ham2k.com (ECA/ELA), polo.ham2k.com (Satellites/WCA) and
      // api.wwbota.org are deliberately absent: all three already answer a
      // cross-origin GET, verified against the real services.
      'www.cqgma.org',
      'www.sq7acp.pl',
      'www.silosontheair.com',
      'wwff.co',
      'ontheair.nz',
      'www.rozhledny.eu',
      // Custom data-file hosts (e.g. call-notes' custom note files):
      // neither sends CORS headers on its share-link redirect hop, so a
      // direct browser fetch is blocked even though the final redirected
      // response is itself CORS-permissive. docs.google.com and GitHub
      // Gists' raw content aren't listed here — both already send
      // permissive CORS headers directly, verified against the real
      // services, so proxying them would be needless indirection.
      'www.dropbox.com',
      'drive.google.com',
      // N1MM call history (`n1mm-history:`): no CORS headers on any of its
      // pages, and the download is a POST.
      'n1mmwp.hamdocs.com',
      // Super Check Partial's files (SCP.DB): no CORS headers.
      'www.supercheckpartial.com',
    };
    if (allowedDomains.contains(uri.host)) {
      return 'https://services.ham2k.net/${uri.host}${uri.path}${uri.hasQuery ? "?${uri.query}" : ""}';
    }
  }
  return urlString;
}
