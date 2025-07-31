const std = @import("std");
const testing = std.testing;

pub const line_separator = if (@import("builtin").target.os.tag == .windows) "\r\n" else "\n";

pub fn expectEqualStringsNormalized(expected: []const u8, actual: []const u8) !void {
    const normalized = try std.mem.replaceOwned(u8, std.testing.allocator, expected, "\n", line_separator);
    defer std.testing.allocator.free(normalized);

    try testing.expectEqualStrings(normalized, actual);
}
