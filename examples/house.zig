const std = @import("std");

const plt = @import("zig-plotille");
const TermInfo = plt.terminfo.TermInfo;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    try TermInfo.detect(allocator);
    const writer = std.io.getStdOut().writer();

    var canvas = try plt.canvas.Canvas.init(allocator, 40, 20, plt.color.Color.by_name(.white));
    defer canvas.deinit(allocator);

    try canvas.rect(.{ .x = 0.2, .y = 0.2 }, .{ .x = 0.8, .y = 0.8 }, null);

    try writer.print("{}\n", .{canvas});
}
