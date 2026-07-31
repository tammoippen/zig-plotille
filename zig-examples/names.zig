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

    try writer.print("Colors by name:       ", .{});
    for (std.enums.values(plt.color.ColorName)) |color_value| {
        if (color_value == plt.color.ColorName.invalid) {
            continue;
        }
        try writer.print("{:^5}", .{@intFromEnum(color_value)});
    }
    try writer.print("\n", .{});
    for (std.enums.values(plt.color.ColorName)) |bg_value| {
        if (bg_value == plt.color.ColorName.invalid) {
            continue;
        }

        const bg = plt.color.Color.by_name(bg_value);
        try writer.print("{:2}{s:^20} ", .{ @intFromEnum(bg_value), @tagName(bg_value) });
        for (std.enums.values(plt.color.ColorName)) |fg_value| {
            if (fg_value == plt.color.ColorName.invalid) {
                continue;
            }
            const fg = plt.color.Color.by_name(fg_value);
            try plt.color.colorPrint(writer, "Text ", .{}, .{ .fg = fg, .bg = bg });
        }
        try writer.print("\n", .{});
    }
    try writer.print("\nThis is basically the terminal color scheme.\n", .{});
}
