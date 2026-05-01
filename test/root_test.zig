const std = @import("std");
const md = @import("bun-md");

test "render basic CommonMark HTML" {
    const html = try md.renderToHtmlWithOptions(
        "# Hello\n\nThis is **strong** and `code`.",
        std.testing.allocator,
        .commonmark,
    );
    defer std.testing.allocator.free(html);

    try std.testing.expectEqualStrings(
        "<h1>Hello</h1>\n<p>This is <strong>strong</strong> and <code>code</code>.</p>\n",
        html,
    );
}

test "render GitHub-style extensions" {
    const html = try md.renderToHtmlWithOptions(
        "- [x] done\n- [ ] todo\n\n| a | b |\n| :- | -: |\n| 1 | 2 |\n\n~~deleted~~\n",
        std.testing.allocator,
        .github,
    );
    defer std.testing.allocator.free(html);

    try std.testing.expect(std.mem.indexOf(u8, html, "task-list-item-checkbox\" disabled checked") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "<table>") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "<th align=\"left\">a</th>") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "<td align=\"right\">2</td>") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "<del>deleted</del>") != null);
}

test "render reference links without leaks" {
    const html = try md.renderToHtmlWithOptions(
        "[Bun][runtime]\n\n[runtime]: https://bun.sh \"Bun\"\n",
        std.testing.allocator,
        .commonmark,
    );
    defer std.testing.allocator.free(html);

    try std.testing.expectEqualStrings(
        "<p><a href=\"https://bun.sh\" title=\"Bun\">Bun</a></p>\n",
        html,
    );
}

test "render heading IDs and autolinked headings" {
    const html = try md.renderToHtmlWithOptions(
        "## Hello, World!\n## Hello World\n",
        std.testing.allocator,
        .{ .heading_ids = true, .autolink_headings = true },
    );
    defer std.testing.allocator.free(html);

    try std.testing.expectEqualStrings(
        "<h2 id=\"hello-world\"><a href=\"#hello-world\">Hello, World!</a></h2>\n" ++
            "<h2 id=\"hello-world-1\"><a href=\"#hello-world-1\">Hello World</a></h2>\n",
        html,
    );
}

test "custom renderer receives events" {
    const CountingRenderer = struct {
        blocks: usize = 0,
        spans: usize = 0,
        text_events: usize = 0,

        fn renderer(self: *@This()) md.Renderer {
            return .{ .ptr = self, .vtable = &.{
                .enterBlock = enterBlock,
                .leaveBlock = leaveBlock,
                .enterSpan = enterSpan,
                .leaveSpan = leaveSpan,
                .text = text,
            } };
        }

        fn enterBlock(ptr: *anyopaque, block_type: md.BlockType, data: u32, flags: u32) error{ JSError, JSTerminated }!void {
            _ = block_type;
            _ = data;
            _ = flags;
            const self: *@This() = @ptrCast(@alignCast(ptr));
            self.blocks += 1;
        }

        fn leaveBlock(ptr: *anyopaque, block_type: md.BlockType, data: u32) error{ JSError, JSTerminated }!void {
            _ = ptr;
            _ = block_type;
            _ = data;
        }

        fn enterSpan(ptr: *anyopaque, span_type: md.SpanType, detail: md.SpanDetail) error{ JSError, JSTerminated }!void {
            _ = span_type;
            _ = detail;
            const self: *@This() = @ptrCast(@alignCast(ptr));
            self.spans += 1;
        }

        fn leaveSpan(ptr: *anyopaque, span_type: md.SpanType) error{ JSError, JSTerminated }!void {
            _ = ptr;
            _ = span_type;
        }

        fn text(ptr: *anyopaque, text_type: md.TextType, content: []const u8) error{ JSError, JSTerminated }!void {
            _ = text_type;
            _ = content;
            const self: *@This() = @ptrCast(@alignCast(ptr));
            self.text_events += 1;
        }
    };

    var counting = CountingRenderer{};
    try md.renderWithRenderer("A **bold** link: <https://example.com>", std.testing.allocator, .{}, counting.renderer());

    try std.testing.expect(counting.blocks >= 2); // doc + paragraph
    try std.testing.expect(counting.spans >= 2); // strong + autolink
    try std.testing.expect(counting.text_events >= 2);
}
