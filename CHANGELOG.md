# Changelog

## [0.2.1] — 2026-05-01

### Other

- Sync Bun Markdown parser + HTML-renderer subset from `oven-sh/bun@1b82e1d492e3`.
- Preserve bun-md's Zig 0.16 compatibility and cleanup patch set during upstream sync.

## [0.2.0] — 2026-05-01

### Changed

- Upgrade package metadata and build scripts to Zig 0.16.x.
- Document that this package tracks Bun's parser + HTML-renderer subset, not terminal rendering integrations.
- Use Zig 0.16 module import wiring for test-only Bun shim integration.
- Update `std.ArrayListUnmanaged` / hash map initializers for Zig 0.16.

### Added

- Add `zig build test` and `zig build check` steps, with plain `zig build` compiling the test suite as a library health check.
- Add upstream-aware shim checking and sync automation with explicit exclusion for Bun's terminal-oriented ANSI renderer.
- Add a local test-only `bun` shim.
- Add parser HTML smoke tests, custom renderer coverage, and unicode unit-test wiring.
- Add `.gitignore` for Zig build outputs.

### Fixed

- Release HTML renderer auxiliary allocations after transferring rendered output.
- Release owned reference-definition labels, destinations, and titles during parser teardown.
- Avoid leaking temporary normalized labels during reference-link lookup.
- Include `OutOfMemory` in the parser public error set.

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
