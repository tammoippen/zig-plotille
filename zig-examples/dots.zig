const std = @import("std");
const plt = @import("plotille");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // detect terminal information
    try plt.terminfo.TermInfo.detect(allocator);

    const writer = std.io.getStdOut().writer();

    var dot = plt.dots.Dots{};
    dot.set(0, 0); // Top-left
    dot.set(1, 3); // Bottom-right
    dot.color.fg = plt.color.Color.by_name(.red);

    try writer.print("Dot pattern: {}\n", .{dot});
}
