#!/bin/sh
# Inject the light-theme overlay into every built HTML file in $DIST.
#
# Idempotent — re-running on the same dist/ produces the same files.
# Adds three things to each *.html:
#   1. an early-paint inline <script> in <head> that sets the theme class
#      BEFORE the first paint, so there's no flash of dark when the user
#      previously chose light (or vice versa).
#   2. a <link> to /light-theme.css (the override sheet)
#   3. a deferred <script> for /theme-toggle.js (renders the toggle button)
#
# Also copies the two static assets (.css/.js) into $DIST so nginx serves them.
set -eu

DIST="${1:-/app/dist}"
OVERLAY="$(dirname "$0")"

if [ ! -d "$DIST" ]; then
    echo "[inject] $DIST not found — nothing to do." >&2
    exit 1
fi

# 1) Drop overlay assets next to the rest of the static site.
cp "$OVERLAY/light-theme.css" "$DIST/light-theme.css"
cp "$OVERLAY/theme-toggle.js" "$DIST/theme-toggle.js"

# Inline early-paint script (must be the first thing in <head>). Reads stored
# preference, falls back to OS prefers-color-scheme, otherwise leaves dark.
INLINE='<script>(function(){try{var t=localStorage.getItem("spdf-theme")||"light";if(t==="light")document.documentElement.classList.add("theme-light");}catch(_){}})();</script>'

LINK='<link rel="stylesheet" href="/light-theme.css">'
DEFER='<script src="/theme-toggle.js" defer></script>'

# Marker so we don't double-inject if this script runs twice.
MARKER='<!-- spdf-overlay-injected -->'

count=0
for f in $(find "$DIST" -maxdepth 4 -name '*.html' -type f); do
    if grep -q "$MARKER" "$f"; then
        continue
    fi
    # Use awk for a single-pass, escape-safe rewrite. We insert immediately
    # after the opening <head> tag so our inline script wins the race.
    tmp="${f}.spdf.tmp"
    awk -v inline="$INLINE" -v link="$LINK" -v defer="$DEFER" -v marker="$MARKER" '
        BEGIN { done = 0 }
        {
            if (!done && index(tolower($0), "<head>") > 0) {
                print
                print marker
                print inline
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
