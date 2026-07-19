#!/usr/bin/env bash
# Stamp a built web bundle (app/build/web) with a per-edition identity —
# favicon, PWA manifest, and titles — AFTER `flutter build web`. The source
# web/ tree is edition-neutral (a plain build stays generic); this selects
# dev | next | prod for an official / deployed build. See docs/releases.md §2.6.
#
# Branding rule (docs/design/user-interface.md): the display name drops the
# "Ham2K" prefix wherever it sits beside the app icon — the browser-tab title
# and the home-screen title both do — while the PWA manifest "name" (shown in
# the standalone install dialog) keeps it. The web product name is
# "Browser Logger"; the edition suffix matches the other platforms
# (Dev → " (Dev)", Next → " Next", Regular → none).
set -euo pipefail

edition="${1:?usage: apply-web-edition.sh <dev|next|prod> [webdir]}"
webdir="${2:-app/build/web}"

case "$edition" in
  dev)  suffix=" (Dev)" ;;
  next) suffix=" Next" ;;
  prod) suffix="" ;;
  *) echo "apply-web-edition: unknown edition '$edition' (want dev|next|prod)" >&2; exit 1 ;;
esac
product="Browser Logger${suffix}"

for f in "favicon-$edition.png" "manifest-$edition.json" "ham2k-$edition-square.svg"; do
  [ -f "$webdir/$f" ] || { echo "apply-web-edition: missing $webdir/$f — did 'flutter build web' run?" >&2; exit 1; }
done

cp "$webdir/favicon-$edition.png" "$webdir/favicon.png"
cp "$webdir/manifest-$edition.json" "$webdir/manifest.json"
# The #startup-splash logo (index.html references ham2k-square.svg) — swap it
# to the edition's art so the HTML splash matches the Flutter SplashScreen.
cp "$webdir/ham2k-$edition-square.svg" "$webdir/ham2k-square.svg"

# Escape characters special to sed's replacement text (\, &, and the # delimiter)
# so the product name is inserted literally, whatever it contains.
product_sed=$(printf '%s' "$product" | sed -e 's/[\\&#]/\\&/g')

# -i.bak is the portable (BSD + GNU sed) form; drop the backup afterwards. The
# apple-touch-icon match tolerates an existing -<edition> suffix so re-stamping
# (e.g. dev → next) still rewrites it.
sed -i.bak -E \
  -e "s#<title>[^<]*</title>#<title>${product_sed}</title>#" \
  -e "s#(name=\"apple-mobile-web-app-title\" content=\")[^\"]*#\1${product_sed}#" \
  -e "s#(rel=\"apple-touch-icon\" href=\")icons/Icon-192(-[a-z]+)?\.png#\1icons/Icon-192-${edition}.png#" \
  "$webdir/index.html"
rm -f "$webdir/index.html.bak"

echo "✅ web edition '$edition' applied → $product"
