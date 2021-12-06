const std = @import("std");

const plt = @import("zig-plotille");
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

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try TermInfo.detect(allocator);
    const writer = std.io.getStdOut().writer();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

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

    var values = std.ArrayList(f64).init(allocator);
    defer values.deinit();

    if (!use_stdin) {
        for (args[1..]) |arg| {
            const val = std.fmt.parseFloat(f64, arg) catch {
                std.debug.print("Cannot parse '{s}' as float.\n", .{arg});
                usage();
                std.process.exit(1);
            };
            try values.append(val);
        }
    } else {
        const stdin = std.io.getStdIn().reader();
        const in = try stdin.readAllAlloc(allocator, 1 << 20);
        defer allocator.free(in);
        var it = std.mem.tokenize(u8, in, " \r\n\t");
        while (it.next()) |arg| {
            const val = std.fmt.parseFloat(f64, arg) catch {
                std.debug.print("Cannot parse '{s}' as float.\n", .{arg});
                usage();
                std.process.exit(1);
            };
            try values.append(val);
        }
    }

    var h = try plt.hist.Histogram.init(allocator, values.items, 10);
    defer h.deinit();

    try writer.print("{}\n", .{h});
}
