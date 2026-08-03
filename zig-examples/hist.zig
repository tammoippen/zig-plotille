const std = @import("std");

const plt = @import("plotille");
const TermInfo = plt.terminfo.TermInfo;

fn usage() void {
    std.debug.print(
        \\Use like:
        \\> hist [-] [VALUES ...]
        \\
        \\Please make sure the VALUES are parseable as float.
        \\
        \\If there are no VALUES, and only the '-' sign, VALUES
        \\are read from stdin.
        \\
        \\ Examples:
        \\
        \\  - Print histogram of the given values:
        \\      > hist 10.4 100 200
        \\  - Print histogram of stdin values:
        \\      > echo 1 2 3 4 5 | hist -
        \\
    , .{});
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    try TermInfo.detect(io, init.minimal.environ, allocator);
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const writer = &stdout_writer.interface;
    defer writer.flush() catch {};

    const args = try init.minimal.args.toSlice(allocator);

    if (args.len == 1) {
        usage();
        return;
    }
    var use_stdin = false;
    if (std.mem.eql(u8, "-", args[1])) {
        if (args.len > 2) {
            std.debug.print("No arguments allowed after - .\n", .{});
            usage();
            std.process.exit(1);
        }
        use_stdin = true;
    }

    var values: std.ArrayList(f64) = .empty;
    defer values.deinit(allocator);

    if (!use_stdin) {
        for (args[1..]) |arg| {
            const val = std.fmt.parseFloat(f64, arg) catch {
                std.debug.print("Cannot parse '{s}' as float.\n", .{arg});
                usage();
                std.process.exit(1);
            };
            try values.append(allocator, val);
        }
    } else {
        var stdin_buffer: [4096]u8 = undefined;
        var stdin_reader = std.Io.File.stdin().readerStreaming(io, &stdin_buffer);
        const in = try stdin_reader.interface.allocRemaining(allocator, .limited(1 << 20));
        defer allocator.free(in);
        var it = std.mem.tokenizeAny(u8, in, " \r\n\t");
        while (it.next()) |arg| {
            const val = std.fmt.parseFloat(f64, arg) catch {
                std.debug.print("Cannot parse '{s}' as float.\n", .{arg});
                usage();
                std.process.exit(1);
            };
            try values.append(allocator, val);
        }
    }

    var h = try plt.hist.Histogram.init(allocator, values.items, 10);
    defer h.deinit(allocator);

    try writer.print("{f}\n\n", .{h});
}
