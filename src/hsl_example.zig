const std = @import("std");

const color = @import("./color.zig");

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

pub fn main() !void {
    var buff: [100]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

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
    }

    for (args[start..]) |arg| {
        const hue = try std.fmt.parseFloat(f64, arg);
        if (hue < 0 or hue > 360) {
            usage();
            return;
        }

        if (short) {
            const bg = color.Color.by_hsl(hue, 1.0, 0.5);
            const len = try color.color("                                        ", buff[0..], null, bg, false);
            std.debug.print("{s:>5} {s}\n", .{ arg, buff[0..len] });
            continue;
        }

        std.debug.print("Saturation and lightness for hue {s} :\n", .{arg});
        std.debug.print("  Saturation left to right 0.0 to 1.0\n  ", .{});
        var lum: f64 = max_rows;
        while (lum >= 0) : (lum -= 1.0) {
            var sat: f64 = 0.0;
            while (sat < max_col) : (sat += 1.0) {
                const bg = color.Color.by_hsl(hue, sat / max_col, lum / max_rows);
                const len = try color.color(" ", buff[0..], null, bg, false);
                std.debug.print("{s}", .{buff[0..len]});
            }
            if (lum == max_rows / 2) {
                std.debug.print("  Lightness top down 1.0 to 0.0; max color at 0.5", .{});
            }
            std.debug.print("\n  ", .{});
        }
        std.debug.print("\n", .{});
    }
}
