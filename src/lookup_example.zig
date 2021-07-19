const std = @import("std");

const color = @import("./color.zig");

pub fn main() !void {
    var buff: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buff);

    var int_buff: [4]u8 = undefined;
    const fg_black = color.Color.by_lookup(232);
    const fg_white = color.Color.by_lookup(231);

    std.debug.print("Colors by lookup:\n", .{});

    std.debug.print("- Standard colors (can be modified in terminal):\n    ", .{});
    var idx: u16 = 0;
    while (idx <= 7) : (idx += 1) {
        const bg = color.Color.by_lookup(@truncate(u8, idx));
        const int_str = try std.fmt.bufPrint(int_buff[0..], "{:4}", .{idx});
        try color.color(int_str, fbs.writer(), fg_white, bg, false);
        std.debug.print("{s}", .{fbs.getWritten()});
        fbs.reset();
    }
    std.debug.print("\n", .{});

    std.debug.print("- High-intensity colors (can be modified in terminal):\n    ", .{});
    while (idx <= 15) : (idx += 1) {
        const bg = color.Color.by_lookup(@truncate(u8, idx));
        const int_str = try std.fmt.bufPrint(int_buff[0..], "{:4}", .{idx});
        try color.color(int_str, fbs.writer(), fg_black, bg, false);
        std.debug.print("{s}", .{fbs.getWritten()});
        fbs.reset();
    }
    std.debug.print("\n", .{});

    std.debug.print("- 216 colors:", .{});
    while (idx <= 231) : (idx += 1) {
        if ((idx - 16) % 36 == 0) {
            std.debug.print("\n    ", .{});
        }
        const bg = color.Color.by_lookup(@truncate(u8, idx));
        const int_str = try std.fmt.bufPrint(int_buff[0..], "{:4}", .{idx});
        if ((idx - 16) % 36 >= 18) {
            try color.color(int_str, fbs.writer(), fg_black, bg, false);
            std.debug.print("{s}", .{fbs.getWritten()});
            fbs.reset();
        } else {
            try color.color(int_str, fbs.writer(), fg_white, bg, false);
            std.debug.print("{s}", .{fbs.getWritten()});
            fbs.reset();
        }
    }
    std.debug.print("\n", .{});

    std.debug.print("- Grayscale colors:\n    ", .{});
    while (idx <= 255) : (idx += 1) {
        const bg = color.Color.by_lookup(@truncate(u8, idx));
        const int_str = try std.fmt.bufPrint(int_buff[0..], "{:4}", .{idx});
        if (idx < 244) {
            try color.color(int_str, fbs.writer(), fg_white, bg, false);
            std.debug.print("{s}", .{fbs.getWritten()});
            fbs.reset();
        } else {
            try color.color(int_str, fbs.writer(), fg_black, bg, false);
            std.debug.print("{s}", .{fbs.getWritten()});
            fbs.reset();
        }
    }
    std.debug.print("\n", .{});
}
