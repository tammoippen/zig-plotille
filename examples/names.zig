const std = @import("std");

const plt = @import("zig-plotille");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // detect terminal information
    try plt.terminfo.TermInfo.detect(allocator);

    const writer = std.io.getStdOut().writer();

    try writer.print("Colors by name:       ", .{});
    for (std.enums.values(plt.color.ColorName)) |color_value| {
        if (color_value == plt.color.ColorName.invalid) {
            continue;
        }
        try writer.print("{:^5}", .{@enumToInt(color_value)});
    }
    try writer.print("\n", .{});
    for (std.enums.values(plt.color.ColorName)) |bg_value| {
        if (bg_value == plt.color.ColorName.invalid) {
            continue;
        }

        const bg = plt.color.Color.by_name(bg_value);
        try writer.print("{:2}{s:^20} ", .{ @enumToInt(bg_value), @tagName(bg_value) });
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
