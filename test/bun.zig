const std = @import("std");

/// Minimal Bun compatibility shim used by this package's Zig tests.
/// Consumers still provide their own `bun` module when depending on bun-md.
pub const JSError = error{ JSError, JSTerminated };
pub const StackOverflow = error{StackOverflow};

pub const StringHashMapUnmanaged = std.StringHashMapUnmanaged;
pub const bit_set = std.bit_set;

pub const StackCheck = struct {
    pub fn init() StackCheck {
        return .{};
    }

    pub fn isSafeToRecurse(self: *const StackCheck) bool {
        _ = self;
        return true;
    }
};

pub fn throwStackOverflow() StackOverflow {
    return error.StackOverflow;
}

pub const strings = struct {
    pub fn codepointSize(comptime T: type, byte: T) u3 {
        return std.unicode.utf8ByteSequenceLength(@intCast(byte)) catch 0;
    }

    pub fn decodeWTF8RuneT(bytes: *const [4]u8, len: anytype, comptime T: type, replacement: T) T {
        const n: usize = @intCast(len);
        if (n == 0 or n > 4) return replacement;
        const codepoint = std.unicode.utf8Decode(bytes[0..n]) catch return replacement;
        return @intCast(codepoint);
    }

    pub fn encodeWTF8RuneT(out: *[4]u8, comptime T: type, codepoint: T) u3 {
        return std.unicode.utf8Encode(@intCast(codepoint), out[0..]) catch blk: {
            break :blk std.unicode.utf8Encode(0xFFFD, out[0..]) catch unreachable;
        };
    }

    pub fn eqlCaseInsensitiveASCIIICheckLength(a: []const u8, b: []const u8) bool {
        return std.ascii.eqlIgnoreCase(a, b);
    }

    pub fn eqlCaseInsensitiveASCIIIgnoreLength(a: []const u8, b: []const u8) bool {
        return a.len == b.len and std.ascii.eqlIgnoreCase(a, b);
    }

    pub fn indexOfAny(haystack: []const u8, needles: []const u8) ?usize {
        for (haystack, 0..) |c, i| {
            if (std.mem.indexOfScalar(u8, needles, c) != null) return i;
        }
        return null;
    }

    pub fn indexOfCharPos(haystack: []const u8, needle: u8, start: usize) ?usize {
        if (start >= haystack.len) return null;
        const rel = std.mem.indexOfScalar(u8, haystack[start..], needle) orelse return null;
        return start + rel;
    }
};
