#!/usr/bin/env bash
# Sync the parser + HTML renderer subset from oven-sh/bun/src/md.
# Intentionally excludes Bun's terminal-oriented ANSI renderer.

set -euo pipefail

if [[ $# -eq 1 && ("$1" == "-h" || "$1" == "--help") ]]; then
    cat <<'EOF'
Usage: ./scripts/sync-upstream.sh <bun-commit-or-ref>

Copies Bun's src/md parser + HTML renderer subset into src/, excluding
ansi_renderer.zig and removing root.zig re-exports that point at that excluded
file. Then reapplies bun-md's local Zig 0.16 compatibility/cleanup patch set.
Run tests and review the diff after syncing.
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

# Bun's upstream Markdown sources currently target Bun's in-tree Zig/Bun build.
# Reapply the small bun-md compatibility layer needed for standalone Zig 0.16
# tests and leak-free parser teardown. Keep these transformations explicit so a
# future upstream shape change fails loudly instead of silently producing broken
# sources.
python3 - <<'PY'
from pathlib import Path


def patch(path: str, replacements: list[tuple[str, str]]) -> None:
    p = Path(path)
    text = p.read_text()
    for old, new in replacements:
        if old in text:
            text = text.replace(old, new, 1)
        elif new not in text:
            raise SystemExit(f"sync-upstream: expected patch context not found in {path}:\n{old}")
    p.write_text(text)

patch("src/parser.zig", [
    ('''    marks: std.ArrayListUnmanaged(Mark) = .{},
    containers: std.ArrayListUnmanaged(Container) = .{},
    block_bytes: std.ArrayListAlignedUnmanaged(u8, .@"4") = .{},
    buffer: std.ArrayListUnmanaged(u8) = .{},
    emph_delims: std.ArrayListUnmanaged(EmphDelim) = .{},''', '''    marks: std.ArrayListUnmanaged(Mark) = .empty,
    containers: std.ArrayListUnmanaged(Container) = .empty,
    block_bytes: std.ArrayListAlignedUnmanaged(u8, .@"4") = .empty,
    buffer: std.ArrayListUnmanaged(u8) = .empty,
    emph_delims: std.ArrayListUnmanaged(EmphDelim) = .empty,'''),
    ('''    current_block_lines: std.ArrayListUnmanaged(VerbatimLine) = .{},''', '''    current_block_lines: std.ArrayListUnmanaged(VerbatimLine) = .empty,'''),
    ('''    ref_defs: std.ArrayListUnmanaged(RefDef) = .{},''', '''    ref_defs: std.ArrayListUnmanaged(RefDef) = .empty,'''),
    ('''    pub const Error = bun.JSError || bun.StackOverflow;''', '''    pub const Error = bun.JSError || bun.StackOverflow || error{OutOfMemory};'''),
    ('''        self.current_block_lines.deinit(self.allocator);
        self.ref_defs.deinit(self.allocator);
        self.emph_delims.deinit(self.allocator);''', '''        self.current_block_lines.deinit(self.allocator);
        for (self.ref_defs.items) |ref_def| {
            self.allocator.free(ref_def.label);
            self.allocator.free(ref_def.dest);
            self.allocator.free(ref_def.title);
        }
        self.ref_defs.deinit(self.allocator);
        self.emph_delims.deinit(self.allocator);'''),
    ('''    return html_renderer.toOwnedSlice();''', '''    const html = try html_renderer.toOwnedSlice();
    html_renderer.deinit();
    return html;'''),
])

patch("src/html_renderer.zig", [
    ('''    heading_buf: std.ArrayListUnmanaged(u8) = .{},''', '''    heading_buf: std.ArrayListUnmanaged(u8) = .empty,'''),
    ('''            .out = .{ .list = .{}, .allocator = allocator, .oom = false },''', '''            .out = .{ .list = .empty, .allocator = allocator, .oom = false },'''),
])

patch("src/helpers.zig", [
    ('''    text_buf: std.ArrayListUnmanaged(u8) = .{},
    slug_counts: bun.StringHashMapUnmanaged(u32) = .{},''', '''    text_buf: std.ArrayListUnmanaged(u8) = .empty,
    slug_counts: bun.StringHashMapUnmanaged(u32) = .empty,'''),
])

patch("src/render_blocks.zig", [
    ('''                var buf: std.ArrayListUnmanaged(u8) = .{};''', '''                var buf: std.ArrayListUnmanaged(u8) = .empty;'''),
])

patch("src/ref_defs.zig", [
    ('''    var result = std.ArrayListUnmanaged(u8){};''', '''    var result: std.ArrayListUnmanaged(u8) = .empty;'''),
    ('''                    result.append(self.allocator, ' ') catch return raw;''', '''                    result.append(self.allocator, ' ') catch {
                        result.deinit(self.allocator);
                        return raw;
                    };'''),
    ('''                        result.appendSlice(self.allocator, buf[0..len]) catch return raw;''', '''                        result.appendSlice(self.allocator, buf[0..len]) catch {
                            result.deinit(self.allocator);
                            return raw;
                        };'''),
    ('''                result.append(self.allocator, std.ascii.toLower(c)) catch return raw;''', '''                result.append(self.allocator, std.ascii.toLower(c)) catch {
                    result.deinit(self.allocator);
                    return raw;
                };'''),
    ('''    return result.items;''', '''    return result.toOwnedSlice(self.allocator) catch {
        result.deinit(self.allocator);
        return raw;
    };'''),
    ('''    const normalized = self.normalizeLabel(raw_label);
    if (normalized.len == 0) return null; // whitespace-only labels are invalid
    for (self.ref_defs.items) |rd| {
        if (std.mem.eql(u8, rd.label, normalized)) return rd;
    }
    return null;''', '''    const normalized = self.normalizeLabel(raw_label);
    if (normalized.len == 0) return null; // whitespace-only labels are invalid
    defer if (normalized.ptr != raw_label.ptr) self.allocator.free(normalized);

    for (self.ref_defs.items) |rd| {
        if (std.mem.eql(u8, rd.label, normalized)) return rd;
    }
    return null;'''),
    ('''            const norm_label = self.normalizeLabel(result.label);
            if (norm_label.len == 0) break; // whitespace-only labels are invalid
            var already_exists = false;
            for (self.ref_defs.items) |existing| {
                if (std.mem.eql(u8, existing.label, norm_label)) {
                    already_exists = true;
                    break;
                }
            }
            if (!already_exists) {
                // Dupe dest and title since they point into self.buffer which gets reused
                const dest_dupe = self.allocator.dupe(u8, result.dest) catch return error.OutOfMemory;
                const title_dupe = self.allocator.dupe(u8, result.title) catch return error.OutOfMemory;
                try self.ref_defs.append(self.allocator, .{
                    .label = norm_label,
                    .dest = dest_dupe,
                    .title = title_dupe,
                });
            }''', '''            const norm_label = self.normalizeLabel(result.label);
            if (norm_label.len == 0) break; // whitespace-only labels are invalid
            if (norm_label.ptr == result.label.ptr) return error.OutOfMemory;

            var already_exists = false;
            for (self.ref_defs.items) |existing| {
                if (std.mem.eql(u8, existing.label, norm_label)) {
                    already_exists = true;
                    break;
                }
            }
            if (already_exists) {
                self.allocator.free(norm_label);
            } else {
                // Dupe dest and title since they point into self.buffer which gets reused
                const dest_dupe = self.allocator.dupe(u8, result.dest) catch {
                    self.allocator.free(norm_label);
                    return error.OutOfMemory;
                };
                const title_dupe = self.allocator.dupe(u8, result.title) catch {
                    self.allocator.free(norm_label);
                    self.allocator.free(dest_dupe);
                    return error.OutOfMemory;
                };
                self.ref_defs.append(self.allocator, .{
                    .label = norm_label,
                    .dest = dest_dupe,
                    .title = title_dupe,
                }) catch {
                    self.allocator.free(norm_label);
                    self.allocator.free(dest_dupe);
                    self.allocator.free(title_dupe);
                    return error.OutOfMemory;
                };
            }'''),
])

patch("src/blocks.zig", [
    ('''        const norm_label = self.normalizeLabel(result.label);
        if (norm_label.len == 0) break;

        // First definition wins
        var already_exists = false;
        for (self.ref_defs.items) |existing| {
            if (std.mem.eql(u8, existing.label, norm_label)) {
                already_exists = true;
                break;
            }
        }
        if (!already_exists) {
            const dest_dupe = self.allocator.dupe(u8, result.dest) catch return;
            const title_dupe = self.allocator.dupe(u8, result.title) catch return;
            self.ref_defs.append(self.allocator, .{
                .label = norm_label,
                .dest = dest_dupe,
                .title = title_dupe,
            }) catch return;
        }''', '''        const norm_label = self.normalizeLabel(result.label);
        if (norm_label.len == 0) break;
        if (norm_label.ptr == result.label.ptr) return;

        // First definition wins
        var already_exists = false;
        for (self.ref_defs.items) |existing| {
            if (std.mem.eql(u8, existing.label, norm_label)) {
                already_exists = true;
                break;
            }
        }
        if (already_exists) {
            self.allocator.free(norm_label);
        } else {
            const dest_dupe = self.allocator.dupe(u8, result.dest) catch {
                self.allocator.free(norm_label);
                return;
            };
            const title_dupe = self.allocator.dupe(u8, result.title) catch {
                self.allocator.free(norm_label);
                self.allocator.free(dest_dupe);
                return;
            };
            self.ref_defs.append(self.allocator, .{
                .label = norm_label,
                .dest = dest_dupe,
                .title = title_dupe,
            }) catch {
                self.allocator.free(norm_label);
                self.allocator.free(dest_dupe);
                self.allocator.free(title_dupe);
                return;
            };
        }'''),
])
PY

zig fmt src/*.zig

echo "Synced Bun Markdown subset from ${BUN_REF}"
echo "Next: ./scripts/check-shim.sh && ./scripts/check-shim.sh --upstream ${BUN_REF} && zig build test"
