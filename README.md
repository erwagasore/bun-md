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

Add as a Zig dependency and provide a `"bun"` module shim. See the upstream consumer for an example.

## License

MIT
