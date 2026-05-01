#!/usr/bin/env bash
# Sync the parser + HTML renderer subset from oven-sh/bun/src/md.
# Intentionally excludes Bun's terminal-oriented ANSI renderer.

set -euo pipefail

if [[ $# -eq 1 && ("$1" == "-h" || "$1" == "--help") ]]; then
    cat <<'EOF'
Usage: ./scripts/sync-upstream.sh <bun-commit-or-ref>

Copies Bun's src/md parser + HTML renderer subset into src/, excluding
ansi_renderer.zig and removing root.zig re-exports that point at that excluded
file. Run tests and review the diff after syncing.
EOF
    exit 0
fi

if [[ $# -ne 1 ]]; then
    echo "error: expected exactly one Bun commit/ref" >&2
    echo "Usage: ./scripts/sync-upstream.sh <bun-commit-or-ref>" >&2
    exit 2
fi

readonly BUN_REPO="https://github.com/oven-sh/bun"
readonly BUN_REF="$1"

tmp_dir=$(mktemp -d)
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT

archive="$tmp_dir/bun.tar.gz"
curl -fsSL "$BUN_REPO/archive/${BUN_REF}.tar.gz" -o "$archive"
tar xzf "$archive" -C "$tmp_dir"

upstream_md=$(find "$tmp_dir" -path '*/src/md' -type d | head -n 1)
if [[ -z "$upstream_md" ]]; then
    echo "error: could not find src/md in Bun archive for ${BUN_REF}" >&2
    exit 1
fi

rsync -a --delete \
    --exclude 'ansi_renderer.zig' \
    "$upstream_md/" src/

# Upstream root.zig may re-export ansi_renderer.zig. Keep this package's public
# surface parser/HTML-only by removing those re-exports after the copy.
root_tmp=$(mktemp)
while IFS= read -r line; do
    case "$line" in
        'pub const ansi = @import("./ansi_renderer.zig");') continue ;;
        'pub const AnsiRenderer = ansi.'*) continue ;;
        'pub const AnsiTheme = ansi.'*) continue ;;
        'pub const ImageUrlCollector = ansi.'*) continue ;;
        'pub const renderToAnsi = ansi.'*) continue ;;
        'pub const detectLightBackground = ansi.'*) continue ;;
        'pub const detectKittyGraphics = ansi.'*) continue ;;
    esac
    printf '%s\n' "$line"
done < src/root.zig > "$root_tmp"
mv "$root_tmp" src/root.zig

echo "Synced Bun Markdown subset from ${BUN_REF}"
echo "Next: ./scripts/check-shim.sh && ./scripts/check-shim.sh --upstream ${BUN_REF} && zig build test"
