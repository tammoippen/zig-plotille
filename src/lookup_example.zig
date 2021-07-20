const std = @import("std");

const color = @import("./color.zig");

pub fn main() !void {
    var int_buff: [4]u8 = undefined;
    const fg_black = color.Color.by_lookup(16);
    const fg_white = color.Color.by_lookup(231);

    std.debug.print("Colors by lookup:\n", .{});

    std.debug.print("- Standard colors (can be modified in terminal):\n    ", .{});
    var idx: u16 = 0;
    while (idx <= 7) : (idx += 1) {
        const bg = color.Color.by_lookup(@truncate(u8, idx));
        const int_str = try std.fmt.bufPrint(int_buff[0..], "{:4}", .{idx});
        try color.colorPrint(std.io.getStdOut().writer(), "{s}", .{int_str}, .{ .fg = fg_white, .bg = bg });
    }
    std.debug.print("\n", .{});

    std.debug.print("- High-intensity colors (can be modified in terminal):\n    ", .{});
    while (idx <= 15) : (idx += 1) {
        const bg = color.Color.by_lookup(@truncate(u8, idx));
        const int_str = try std.fmt.bufPrint(int_buff[0..], "{:4}", .{idx});
        try color.colorPrint(std.io.getStdOut().writer(), "{s}", .{int_str}, .{ .fg = fg_black, .bg = bg });
    }
    std.debug.print("\n", .{});

    std.debug.print(
        \\- 6 × 6 × 6 cube (216 colors): 16 + 36 × r + 6 × g + b (0 ≤ r, g, b ≤ 5)
        \\    * red increments down in a cube
        \\    * blue increments to the right in a cube
        \\    * green increments for each cube
        \\    * the color values in each direction are 0: 00, 1: 5F, 2: 87, 3: AF, 4: D7 and 5: FF
        \\    * e.g. 131: r = 3, g = 1, b = 1 has the color code 0xAF5F5F.
    , .{});
    while (idx <= 231) : (idx += 1) {
        if ((idx - 16) % 36 == 0) {
            std.debug.print("\n    ", .{});
        }
        const bg = color.Color.by_lookup(@truncate(u8, idx));
        const int_str = try std.fmt.bufPrint(int_buff[0..], "{:4}", .{idx});
        if ((idx - 16) % 36 >= 18) {
            try color.colorPrint(std.io.getStdOut().writer(), "{s}", .{int_str}, .{ .fg = fg_black, .bg = bg });
        } else {
            try color.colorPrint(std.io.getStdOut().writer(), "{s}", .{int_str}, .{ .fg = fg_white, .bg = bg });
        }
    }
    std.debug.print("\n", .{});

    std.debug.print("- Grayscale colors:\n    ", .{});
    while (idx <= 255) : (idx += 1) {
        const bg = color.Color.by_lookup(@truncate(u8, idx));
        const int_str = try std.fmt.bufPrint(int_buff[0..], "{:4}", .{idx});
        if (idx < 244) {
            try color.colorPrint(std.io.getStdOut().writer(), "{s}", .{int_str}, .{ .fg = fg_white, .bg = bg });
        } else {
            try color.colorPrint(std.io.getStdOut().writer(), "{s}", .{int_str}, .{ .fg = fg_black, .bg = bg });
        }
    }
    std.debug.print("\n", .{});
}
