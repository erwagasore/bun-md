const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Public package module. Consumers provide their own `bun` module shim.
    _ = b.addModule("bun-md", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Test-only wiring: Zig 0.16's module `imports` option lets us compile this
    // package against a minimal local Bun shim without changing the public API.
    const bun_test_mod = b.createModule(.{
        .root_source_file = b.path("test/bun.zig"),
        .target = target,
        .optimize = optimize,
    });

    const bun_md_test_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "bun", .module = bun_test_mod }},
    });

    const tests_mod = b.createModule(.{
        .root_source_file = b.path("test/root_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "bun-md", .module = bun_md_test_mod }},
    });

    const root_tests = b.addTest(.{
        .name = "bun-md-tests",
        .root_module = tests_mod,
    });
    const run_root_tests = b.addRunArtifact(root_tests);

    const unicode_tests_mod = b.createModule(.{
        .root_source_file = b.path("src/unicode.zig"),
        .target = target,
        .optimize = optimize,
    });
    const unicode_tests = b.addTest(.{
        .name = "unicode-tests",
        .root_module = unicode_tests_mod,
    });
    const run_unicode_tests = b.addRunArtifact(unicode_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_root_tests.step);
    test_step.dependOn(&run_unicode_tests.step);

    const check_step = b.step("check", "Compile unit tests without running them");
    check_step.dependOn(&root_tests.step);
    check_step.dependOn(&unicode_tests.step);

    // Keep plain `zig build` meaningful for this library-only package.
    b.default_step.dependOn(&root_tests.step);
    b.default_step.dependOn(&unicode_tests.step);
}
