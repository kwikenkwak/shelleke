#!/usr/bin/env bash
# fetch_cover_art.sh ARTIST TITLE ALBUM OUTDIR
#
# Cover-art fallback for players whose MPRIS bus has no mpris:artUrl (Firefox's
# native bus never publishes one). Looks the track up on the iTunes Search API
# (no auth required) and caches the 512px artwork under OUTDIR. Prints the
# cached file path on success, exits non-zero on miss so the caller shows its
# placeholder instead.
set -euo pipefail

artist="$1"; title="$2"; album="${3:-}"; outdir="$4"
mkdir -p "$outdir"

key=$(printf '%s|%s|%s' "$artist" "$album" "$title" | md5sum | cut -d' ' -f1)
out="$outdir/itunes-$key.jpg"
if [ -s "$out" ]; then
    printf '%s' "$out"
    exit 0
fi

search() {
    curl -sSf --max-time 10 -G 'https://itunes.apple.com/search' \
        --data-urlencode "term=$1" \
        --data-urlencode 'media=music' \
        --data-urlencode 'entity=song' \
        --data-urlencode 'limit=1' \
        | jq -r '.results[0].artworkUrl100 // empty'
}

url=$(search "$artist $title" || true)
if [ -z "$url" ]; then
    # Retry without remix/feat. decorations: "Valerie (feat. X) - Version" -> "Valerie"
    clean_title=$(printf '%s' "$title" | sed -E 's/ *[([][^)\]]*[)\]]//g; s/ +- .*$//; s/ +$//')
    [ "$clean_title" != "$title" ] && [ -n "$clean_title" ] && url=$(search "$artist $clean_title" || true)
fi
[ -n "$url" ] || exit 1

# artworkUrl100 is a 100x100 thumb; the CDN serves any size on request.
url="${url/100x100bb/512x512bb}"
curl -sSf --max-time 10 "$url" -o "$out"
printf '%s' "$out"
