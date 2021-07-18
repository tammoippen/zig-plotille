const std = @import("std");

const color = @import("./color.zig");

pub fn main() !void {
    var buff: [100]u8 = undefined;

    std.debug.print("Colors by name:       ", .{});
    for (std.enums.values(color.ColorName)) |color_value| {
        if (color_value == color.ColorName.invalid) {
            continue;
        }
        std.debug.print("{:^5}", .{@enumToInt(color_value)});
    }
    std.debug.print("\n", .{});
    for (std.enums.values(color.ColorName)) |bg_value| {
        if (bg_value == color.ColorName.invalid) {
            continue;
        }

        const bg = color.Color.by_name(bg_value);
        std.debug.print("{:2}{s:^20} ", .{ @enumToInt(bg_value), @tagName(bg_value) });
        for (std.enums.values(color.ColorName)) |fg_value| {
            if (fg_value == color.ColorName.invalid) {
                continue;
            }
            const fg = color.Color.by_name(fg_value);
            const len = try color.color("Text ", buff[0..], fg, bg, false);
            std.debug.print("{s}", .{buff[0..len]});
        }
        std.debug.print("\n", .{});
    }
}
