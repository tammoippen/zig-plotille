const std = @import("std");
const plt = @import("plotille");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    // detect terminal information
    try plt.terminfo.TermInfo.detect(io, init.minimal.environ, allocator);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const writer = &stdout_writer.interface;
    defer writer.flush() catch {};

    var dot = plt.dots.Dots{};
    dot.set(0, 0); // Top-left
    dot.set(1, 3); // Bottom-right
    dot.color.fg = plt.color.Color.by_name(.red);

    try writer.print("Dot pattern: {f}\n", .{dot});
}
