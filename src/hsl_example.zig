const std = @import("std");

const color = @import("./color.zig");
const terminfo = @import("./terminfo.zig");

fn usage() void {
    std.debug.print(
        \\Use like:
        \\> hsl_example [--short] [HUE_VALUES ...]
        \\
        \\Please make sure the HUE_VALUES are in the range [0, 360].
        \\
        \\ Options
        \\   --short         Only provide one line per HUE_VALUE.
        \\
        \\ Examples:
        \\
        \\  - Print one hue map per hue value:
        \\      > hsl_example 10.4 100 200
        \\  - Print a rainbow over all hue values:
        \\      > hsl_example --short $(seq 0 360)
    , .{});
}

const max_col: f64 = 40;
const max_rows: f64 = 20;
const space = "                                        ";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    // detect terminal information
    try terminfo.TermInfo.detect(allocator);

    const writer = std.io.getStdOut().writer();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        usage();
        return;
    }

    var short = false;
    var start: u2 = 1;
    if (std.mem.eql(u8, "--short", args[1])) {
        short = true;
        start = 2;
        if (args.len == 2) {
            usage();
            return;
        }
        try writer.print("  Hue {s} RGB\n", .{space});
    }

    for (args[start..]) |arg| {
        const hue = try std.fmt.parseFloat(f64, arg);
        if (hue < 0 or hue > 360) {
            usage();
            return;
        }

        if (short) {
            const bg = color.Color.by_hsl(hue, 1.0, 0.5);
            try writer.print("{s:>5} ", .{arg[0..std.math.min(arg.len, 5)]});
            try color.colorPrint(writer, "{s}", .{space}, .{ .bg = bg });
            try writer.print(" {x:0<2}{x:0<2}{x:0<2}\n", .{ bg.rgb[0], bg.rgb[1], bg.rgb[2] });
            continue;
        }

        try writer.print("Saturation and lightness for hue {s} :\n", .{arg});
        try writer.print("  Saturation left to right 0.0 to 1.0\n  ", .{});
        var lum: f64 = max_rows;
        while (lum >= 0) : (lum -= 1.0) {
            var sat: f64 = 0.0;
            while (sat < max_col) : (sat += 1.0) {
                const bg = color.Color.by_hsl(hue, sat / max_col, lum / max_rows);
                try color.colorPrint(writer, " ", .{}, .{ .bg = bg });
            }
            if (lum == max_rows / 2) {
                try writer.print("  Lightness top down 1.0 to 0.0; max color at 0.5", .{});
            }
            try writer.print("\n  ", .{});
        }
        try writer.print("\n", .{});
    }
}
