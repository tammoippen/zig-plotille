const std = @import("std");

const plt = @import("plotille");

fn usage() void {
    std.debug.print(
        \\Use like:
        \\> hsl [--short] [HUE_VALUES ...]
        \\
        \\Please make sure the HUE_VALUES are in the range [0, 360].
        \\
        \\ Options
        \\   --short         Only provide one line per HUE_VALUE.
        \\
        \\ Examples:
        \\
        \\  - Print one hue map per hue value:
        \\      > hsl 10.4 100 200
        \\  - Print a rainbow over all hue values:
        \\      > hsl --short $(seq 0 360)
        \\
    , .{});
}

const max_col: f64 = 40;
const max_rows: f64 = 20;
const space = "                                        ";

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    // detect terminal information
    try plt.terminfo.TermInfo.detect(io, init.minimal.environ, allocator);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const writer = &stdout_writer.interface;
    defer writer.flush() catch {};

    const args = try init.minimal.args.toSlice(allocator);

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
            const bg = plt.color.Color.by_hsl(hue, 1.0, 0.5);
            try writer.print("{s:>5} ", .{arg[0..@min(arg.len, 5)]});
            try plt.color.colorPrint(writer, "{s}", .{space}, .{ .bg = bg });
            try writer.print(" {x:0<2}{x:0<2}{x:0<2}\n", .{ bg.rgb[0], bg.rgb[1], bg.rgb[2] });
            continue;
        }

        try writer.print("Saturation and lightness for hue {s} :\n", .{arg});
        try writer.print("  Saturation left to right 0.0 to 1.0\n  ", .{});
        var lum: f64 = max_rows;
        while (lum >= 0) : (lum -= 1.0) {
            var sat: f64 = 0.0;
            while (sat < max_col) : (sat += 1.0) {
                const bg = plt.color.Color.by_hsl(hue, sat / max_col, lum / max_rows);
                try plt.color.colorPrint(writer, " ", .{}, .{ .bg = bg });
            }
            if (lum == max_rows / 2) {
                try writer.print("  Lightness top down 1.0 to 0.0; max color at 0.5", .{});
            }
            try writer.print("\n  ", .{});
        }
        try writer.print("\n", .{});
    }
}
