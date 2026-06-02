#!/bin/sh
# Inject the light-theme overlay into every built HTML file in $DIST.
#
# Idempotent — re-running on the same dist/ produces the same files.
# Adds three things to each *.html:
#   1. <script src="/early-theme.js"></script> in <head> — runs synchronously
#      before paint, sets the theme-light class before any CSS is applied.
#      External (not inline) to comply with the BentoPDF CSP that bans
#      script-src 'unsafe-inline'.
#   2. <link rel="stylesheet" href="/light-theme.css"> — the override sheet.
#   3. <script src="/theme-toggle.js" defer></script> — adds the toggle
#      button + user menu, runs after DOMContentLoaded.
#
# Also copies the three static assets (.js/.css) into $DIST so nginx serves them.
set -eu

DIST="${1:-/app/dist}"
OVERLAY="$(dirname "$0")"

if [ ! -d "$DIST" ]; then
    echo "[inject] $DIST not found — nothing to do." >&2
    exit 1
fi

# 1) Drop overlay assets next to the rest of the static site.
cp "$OVERLAY/early-theme.js"   "$DIST/early-theme.js"
cp "$OVERLAY/light-theme.css"  "$DIST/light-theme.css"
cp "$OVERLAY/theme-toggle.js"  "$DIST/theme-toggle.js"

# 2) Tags injected immediately after <head>. EARLY must come first so it runs
#    before the bundled stylesheets / scripts the rest of <head> references.
EARLY='<script src="/early-theme.js"></script>'
LINK='<link rel="stylesheet" href="/light-theme.css">'
DEFER='<script src="/theme-toggle.js" defer></script>'

# Marker so we don't double-inject if this script runs twice.
MARKER='<!-- spdf-overlay-injected -->'

count=0
for f in $(find "$DIST" -maxdepth 4 -name '*.html' -type f); do
    if grep -q "$MARKER" "$f"; then
        continue
    fi
    tmp="${f}.spdf.tmp"
    awk -v early="$EARLY" -v link="$LINK" -v defer="$DEFER" -v marker="$MARKER" '
        BEGIN { done = 0 }
        {
            if (!done && index(tolower($0), "<head>") > 0) {
                print
                print marker
                print early
                print link
                print defer
                done = 1
                next
            }
            print
        }
    ' "$f" > "$tmp"
    mv "$tmp" "$f"
    count=$((count + 1))
done

echo "[inject] light-theme overlay injected into $count HTML files."
