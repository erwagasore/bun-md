# bun-md

Standalone extraction of [Bun's Markdown parser](https://github.com/oven-sh/bun/tree/main/src/md) — a Zig port of [md4c](https://github.com/mity/md4c).

**This package contains only the parser source files.** It targets Zig 0.16.x and requires the consumer to provide a `"bun"` module (shim) that supplies stdlib replacements for Bun-specific APIs. The repo includes a test-only shim under `test/bun.zig` so `zig build test` validates the package locally without changing the public module contract.

## Upstream

- **Source**: `oven-sh/bun@d1047c2` (`src/md/`)
- **Original**: [md4c](https://github.com/mity/md4c) by Martin Mitáš (MIT)
- **Zig port**: Jarred Sumner (Bun PR [#26440](https://github.com/oven-sh/bun/pull/26440))

## Features

CommonMark 0.31.2 compliant, plus:

- GFM tables, strikethrough, task lists
- Permissive autolinks (URL, www, email)
- Wiki links, LaTeX math, underline
- Heading IDs, autolinked headings
- HTML blocks and inline HTML
- GFM tag filter

## Usage

Add as a Zig dependency and provide a `"bun"` module shim. See [ztree-parse-md](https://github.com/erwagasore/ztree-parse-md) for a working example.

```zig
const md = @import("bun-md");

const html = try md.renderToHtmlWithOptions(
    "# Hello\n\nThis is **Markdown**.",
    allocator,
    .github,
);
defer allocator.free(html);
```

## Development

Requires Zig 0.16.x.

```bash
zig build            # compile test suite (default library health check)
zig build check      # compile tests without running them
zig build test       # run parser smoke tests and unicode unit tests
./scripts/check-shim.sh              # check local tracked subset
./scripts/check-shim.sh --upstream   # check latest Bun src/md, excluding out-of-scope files
```

The `bun-md` module exported by `build.zig` intentionally does not wire in the test shim; consumers remain responsible for choosing/providing their own `"bun"` module.

## Sync from upstream

This repo tracks the parser + HTML renderer subset of `oven-sh/bun/src/md/`.
Terminal-oriented files such as `ansi_renderer.zig` are intentionally excluded
because they depend on Bun runtime/TTY/syscall APIs rather than the small parser
shim expected from `bun-md` consumers.

To pull in parser/HTML updates:

```bash
BUN_COMMIT="<hash>"
./scripts/sync-upstream.sh "${BUN_COMMIT}"
./scripts/check-shim.sh
./scripts/check-shim.sh --upstream "${BUN_COMMIT}"
zig build test

git add -A && git commit -m "sync: bun@${BUN_COMMIT:0:12}"
git tag -a v<next> -m "v<next>"
git push origin main --follow-tags
```

`check-shim.sh` reports any new `bun.*` APIs that consumers need to add
to their shim. Its upstream mode scans Bun's latest `src/md` while skipping
explicitly excluded files. Use `--include-excluded` when you intentionally want
to audit the full upstream directory and see why excluded files are out of scope.

After pushing, update consumers:

1. Update the hash in `build.zig.zon`
2. If `check-shim.sh` reported new APIs, add them to the shim
3. `zig build test`

## License

MIT
