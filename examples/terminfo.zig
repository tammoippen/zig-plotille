const std = @import("std");
const json = std.json;

const plt = @import("zig-plotille");
const TermInfo = plt.terminfo.TermInfo;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try TermInfo.detect(allocator);
    const info = TermInfo.get();

    const writer = std.io.getStdOut().writer();
    try json.stringify(info, .{}, writer);
    try writer.writeByte('\n');
}
