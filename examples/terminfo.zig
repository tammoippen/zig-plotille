const std = @import("std");
const json = std.json;

const plt = @import("zig-plotille");
const TermInfo = plt.terminfo.TermInfo;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    try TermInfo.detect(allocator);
    const info = TermInfo.get();

    const writer = std.io.getStdOut().writer();
    try json.stringify(info, .{}, writer);
    try writer.writeByte('\n');
}
