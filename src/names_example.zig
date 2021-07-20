const std = @import("std");

const color = @import("./color.zig");

pub fn main() !void {
    const writer = std.io.getStdOut().writer();

    try writer.print("Colors by name:       ", .{});
    for (std.enums.values(color.ColorName)) |color_value| {
        if (color_value == color.ColorName.invalid) {
            continue;
        }
        try writer.print("{:^5}", .{@enumToInt(color_value)});
    }
    try writer.print("\n", .{});
    for (std.enums.values(color.ColorName)) |bg_value| {
        if (bg_value == color.ColorName.invalid) {
            continue;
        }

        const bg = color.Color.by_name(bg_value);
        try writer.print("{:2}{s:^20} ", .{ @enumToInt(bg_value), @tagName(bg_value) });
        for (std.enums.values(color.ColorName)) |fg_value| {
            if (fg_value == color.ColorName.invalid) {
                continue;
            }
            const fg = color.Color.by_name(fg_value);
            try color.colorPrint(writer, "Text ", .{}, .{ .fg = fg, .bg = bg });
        }
        try writer.print("\n", .{});
    }
    try writer.print("\nThis is basically the terminal color scheme.\n", .{});
}
