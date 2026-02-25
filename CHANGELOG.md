# Changelog

## [0.1.1] — 2026-02-24

### Other

- Add sync-from-upstream instructions to README.
- Add `scripts/check-shim.sh` for detecting new `bun.*` APIs after sync.
- Add consumer update steps to sync instructions.

## [0.1.0] — 2026-02-24

### Features

- Initial extraction of Bun's Markdown parser from `oven-sh/bun@d1047c2`.
- 15 Zig source files from `src/md/`.
- CommonMark 0.31.2 compliant with GFM extensions (tables, strikethrough, task lists, autolinks).
- Requires consumer-provided `"bun"` module shim.
