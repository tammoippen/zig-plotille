const std = @import("std");
const plt = @import("plotille");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // detect terminal information
    try plt.terminfo.TermInfo.detect(allocator);

    var stdout_writer = std.fs.File.stdout().writer(&.{});
    const writer = &stdout_writer.interface;

    var dot = plt.dots.Dots{};
    dot.set(0, 0); // Top-left
    dot.set(1, 3); // Bottom-right
    dot.color.fg = plt.color.Color.by_name(.red);

    try writer.print("Dot pattern: {f}\n", .{dot});
}
