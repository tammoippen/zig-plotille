const std = @import("std");
const json = std.json;

const plt = @import("plotille");
const TermInfo = plt.terminfo.TermInfo;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try TermInfo.detect(allocator);
    const info = TermInfo.get();

    var stdout_writer = std.fs.File.stdout().writer(&.{});
    const writer = &stdout_writer.interface;
    try writer.print("{f}\n", .{json.fmt(info, .{})});
}
