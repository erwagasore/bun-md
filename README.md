# bun-md

Standalone extraction of [Bun's Markdown parser](https://github.com/oven-sh/bun/tree/main/src/md) — a Zig port of [md4c](https://github.com/mity/md4c).

**This package contains only the parser source files.** It requires the consumer to provide a `"bun"` module (shim) that supplies stdlib replacements for Bun-specific APIs.

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

## Sync from upstream

This repo tracks `oven-sh/bun/src/md/`. To pull in updates:

```bash
BUN_COMMIT="<hash>"
curl -sL "https://github.com/oven-sh/bun/archive/${BUN_COMMIT}.tar.gz" | \
  tar xz --strip-components=3 -C src/ "bun-${BUN_COMMIT}/src/md/"
./scripts/check-shim.sh
git add -A && git commit -m "sync: bun@${BUN_COMMIT:0:12}"
git tag -a v<next> -m "v<next>"
git push origin main --follow-tags
```

`check-shim.sh` reports any new `bun.*` APIs that consumers need to add
to their shim.

After pushing, update consumers:

1. Update the hash in `build.zig.zon`
2. If `check-shim.sh` reported new APIs, add them to the shim
3. `zig build test`

## License

MIT
