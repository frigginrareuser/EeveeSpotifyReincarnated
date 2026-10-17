#!/usr/bin/env bash
# Renames the Spotify app bundle to the Evil Spotify meme branding:
#   evil-rename.sh <Spotify.app dir or path.ipa>
#
# What it does (Info.plist only — safe for existing signing identities):
#   1. CFBundleDisplayName  -> "Evil Spotify"
#   2. CFBundleName         -> "Evil Spotify" (19 char / 1024-byte limits: fits)
#   3. CFBundleExecutable, CFBundleIdentifier, CFBundleURLScheme entries and
#      the binary are NOT touched, so platform hooks, the Safari extension and
#      www-spotify deep links keep working.

set -euo pipefail
PB=/usr/libexec/PlistBuddy

patch_app() {
    local app="$1" plist="$1/Info.plist"
    [ -f "$plist" ] || { echo "[evil-rename] no Info.plist in $app" >&2; return 1; }

    "$PB" -c "Set :CFBundleDisplayName Evil Spotify"  "$plist" 2>/dev/null \
        || "$PB" -c "Add :CFBundleDisplayName string Evil Spotify" "$plist"
    "$PB" -c "Set :CFBundleName Evil Spotify"        "$plist"
    echo "[evil-rename] renamed $(basename "$app") -> Evil Spotify"
}

patch_ipa() {
    local ipa="$1" abs="" tmp=""
    abs="$(cd "$(dirname "$ipa")" && pwd)/$(basename "$ipa")"
    tmp="$(mktemp -d -t evil-rename.XXXXXX)"
    trap 'rm -rf "$tmp"' RETURN
    ( cd "$tmp" && unzip -q "$abs" )
    local app
    app="$(find "$tmp/Payload" -maxdepth 2 -name '*.app' -type d | head -1)"
    [ -n "$app" ] || { echo "[evil-rename] no .app in $ipa" >&2; return 1; }
    patch_app "$app"
    rm -f "$abs"
    ( cd "$tmp" && zip -qry "$abs" Payload )
}

target="${1:-}"
[ -z "$target" ] && { echo "usage: evil-rename.sh <Spotify.app|path.ipa>" >&2; exit 1; }

if   [ -d "$target" ];                        then patch_app "$target"
elif [ -f "$target" ] && [[ "$target" == *.ipa || "$target" == *.zip ]]; then patch_ipa "$target"
else echo "[evil-rename] bad target: $target" >&2; exit 1
fi
