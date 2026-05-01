#!/usr/bin/env bash
# Check whether the tracked Bun Markdown subset uses bun.* APIs outside the
# compatibility shim surface expected from consumers.
#
# By default this scans local src/*.zig. Use --upstream [ref] to fetch Bun's
# current src/md implementation and check the same parser/HTML-renderer subset.
# The terminal-oriented ANSI renderer is intentionally excluded from the subset.

set -euo pipefail

readonly BUN_REPO="https://github.com/oven-sh/bun"
readonly DEFAULT_UPSTREAM_REF="HEAD"
readonly EXCLUDED_FILES=("ansi_renderer.zig")

read -r -d '' KNOWN <<'EOF' || true
bun.JSError
bun.StackCheck
bun.StackCheck.init
bun.StackOverflow
bun.StringHashMapUnmanaged
bun.bit_set.StaticBitSet
bun.strings.codepointSize
bun.strings.decodeWTF8RuneT
bun.strings.encodeWTF8RuneT
bun.strings.eqlCaseInsensitiveASCIIICheckLength
bun.strings.eqlCaseInsensitiveASCIIIgnoreLength
bun.strings.indexOfAny
bun.strings.indexOfCharPos
bun.throwStackOverflow
EOF

usage() {
    cat <<'EOF'
Usage:
  ./scripts/check-shim.sh [--src DIR]
  ./scripts/check-shim.sh --upstream [REF]
  ./scripts/check-shim.sh --upstream [REF] --include-excluded

Options:
  --src DIR            Scan a local Markdown source directory instead of src/.
  --upstream [REF]     Fetch oven-sh/bun and scan src/md at REF. Defaults to HEAD.
  --include-excluded   Also scan files intentionally outside this package's scope.
  -h, --help           Show this help.

Notes:
  The default scope is Bun's parser + HTML renderer subset. It intentionally
  excludes ansi_renderer.zig because that file depends on Bun terminal/runtime
  APIs rather than the small parser shim expected from bun-md consumers.
EOF
}

src_dir="src"
upstream_ref=""
include_excluded=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --src)
            [[ $# -ge 2 ]] || { echo "error: --src requires a directory" >&2; exit 2; }
            src_dir="$2"
            shift 2
            ;;
        --upstream)
            upstream_ref="$DEFAULT_UPSTREAM_REF"
            shift
            if [[ $# -gt 0 && "$1" != --* ]]; then
                upstream_ref="$1"
                shift
            fi
            ;;
        --include-excluded)
            include_excluded=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

tmp_dir=""
cleanup() {
    if [[ -n "$tmp_dir" ]]; then
        rm -rf "$tmp_dir"
    fi
}
trap cleanup EXIT

if [[ -n "$upstream_ref" ]]; then
    if [[ "$upstream_ref" == "HEAD" ]]; then
        if command -v git >/dev/null 2>&1; then
            upstream_ref=$(git ls-remote "$BUN_REPO.git" HEAD | awk '{print $1}')
        else
            upstream_ref="main"
        fi
    fi

    tmp_dir=$(mktemp -d)
    archive="$tmp_dir/bun.tar.gz"
    curl -fsSL "$BUN_REPO/archive/${upstream_ref}.tar.gz" -o "$archive"
    tar xzf "$archive" -C "$tmp_dir"
    src_dir=$(find "$tmp_dir" -path '*/src/md' -type d | head -n 1)
    if [[ -z "$src_dir" ]]; then
        echo "error: could not find src/md in Bun archive for ${upstream_ref}" >&2
        exit 1
    fi
    echo "Checking Bun upstream src/md at ${upstream_ref}"
else
    echo "Checking local ${src_dir}"
fi

if [[ ! -d "$src_dir" ]]; then
    echo "error: source directory not found: ${src_dir}" >&2
    exit 1
fi

is_excluded() {
    local file_name="$1"
    local excluded
    for excluded in "${EXCLUDED_FILES[@]}"; do
        if [[ "$file_name" == "$excluded" ]]; then
            return 0
        fi
    done
    return 1
}

files=()
skipped=()
while IFS= read -r -d '' file; do
    file_name=$(basename "$file")
    if [[ "$include_excluded" == false ]] && is_excluded "$file_name"; then
        skipped+=("$file_name")
        continue
    fi
    files+=("$file")
done < <(find "$src_dir" -maxdepth 1 -type f -name '*.zig' -print0 | sort -z)

if [[ ${#skipped[@]} -gt 0 ]]; then
    printf 'Skipping intentionally excluded file(s): %s\n' "${skipped[*]}"
fi

for excluded in "${EXCLUDED_FILES[@]}"; do
    refs=$(grep -FHn "$excluded" "${files[@]}" 2>/dev/null || true)
    if [[ -n "$refs" ]]; then
        echo "Warning: scanned file(s) reference intentionally excluded ${excluded}:"
        echo "$refs" | sed 's/^/  /'
        echo "         Keep those references out of the bun-md subset when syncing."
    fi
done

if [[ ${#files[@]} -eq 0 ]]; then
    echo "error: no Zig files found to scan in ${src_dir}" >&2
    exit 1
fi

used=$(grep -Eho 'bun\.[a-zA-Z0-9_.]*' "${files[@]}" | sort -u || true)
new=$(comm -23 <(printf '%s\n' "$used") <(printf '%s\n' "$KNOWN" | sort -u))

if [[ -z "$new" ]]; then
    echo "✓ All bun.* APIs covered by shim"
else
    echo "New bun.* APIs — consumers must update their shim or the file should be excluded:"
    echo "$new" | sed 's/^/  /'
    exit 1
fi
