const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const testing = std.testing;
const expectEqual = testing.expectEqual;
const expectEqualSlices = testing.expectEqualSlices;
const expectEqualStrings = testing.expectEqualStrings;

pub const Histogram = struct {
    counts: ArrayList(u32),
    bins: ArrayList(f64),
    delta: f64,
    // comptime fmt: ?[]const u8,

    /// Deinitialize with deinit.
    pub fn init(allocator: *Allocator, values: []const f64, bins: u8) !Histogram {
        assert(bins > 0);

        const x = Extrema.of(values);
        const delta = x.max - x.min;
        const xwidth = delta / @intToFloat(f64, bins);
        var h = Histogram{
            .counts = try ArrayList(u32).initCapacity(allocator, bins),
            .bins = try ArrayList(f64).initCapacity(allocator, bins + 1),
            .delta = delta,
        };
        errdefer h.counts.deinit();
        errdefer h.bins.deinit();

        // count values into bins
        try h.counts.appendNTimes(0, bins);
        for (values) |value| {
            const val_delta = value - x.min;
            const val_idx = math.min(bins - 1, @floatToInt(usize, val_delta / xwidth));
            h.counts.items[val_idx] += 1;
        }

        // values for bins
        try h.bins.appendNTimes(0, bins + 1);
        var idx: usize = 0;
        while (idx < bins + 1) : (idx += 1) {
            h.bins.items[idx] = @intToFloat(f64, idx) * xwidth + x.min;
        }

        return h;
    }

    pub fn deinit(self: *Histogram) void {
        self.bins.deinit();
        self.counts.deinit();
    }

    /// Output the Histogram to a writer.
    pub fn format(
        self: Histogram,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const width = options.width orelse 80;
        const h_max = lbl: {
            var count: u32 = 1;
            for (self.counts.items) |item| {
                if (item > count) {
                    count = item;
                }
            }
            break :lbl count;
        };

        const lasts = [_][]const u8{ "", "⠂", "⠆", "⠇", "⡇", "⡗", "⡷", "⡿" };

        try writer.writeAll("        bucket       | ");
        try writer.writeByteNTimes('_', width);
        try writer.writeAll(" Total Counts\n");

        var widx: usize = 0;
        for (self.counts.items) |count, idx| {
            if (fmt.len == 0) {
                try writer.print("[{d:<8.3}, {d:<8.3}) | ", .{ self.bins.items[idx], self.bins.items[idx + 1] });
            } else {
                const fmt2 = comptime fmt[0..1] ++ ":" ++ fmt[1..];
                try writer.print("[{" ++ fmt2 ++ "}, {" ++ fmt2 ++ "}) | ", .{ self.bins.items[idx], self.bins.items[idx + 1] });
            }
            const height = width * 8 * count / h_max;
            widx = 0;
            while (widx < height / 8) : (widx += 1) {
                try writer.writeAll("⣿");
            }
            try writer.writeAll(lasts[height % 8]);

            widx = 0;
            while (widx < width - height / 8 + @boolToInt(height % 8 == 0)) : (widx += 1) {
                try writer.writeAll("\u{2800}");
            }
            try writer.print(" {}\n", .{count});
        }

        widx = 0;
        while (widx < 23 + width + 13) : (widx += 1) {
            try writer.writeAll("‾");
        }
    }
};

const Extrema = struct {
    min: f64,
    max: f64,

    fn of(values: []const f64) Extrema {
        var xmin: f64 = undefined;
        var xmax: f64 = undefined;
        if (values.len == 0) {
            xmin = 0;
            xmax = 1;
        } else {
            xmin = math.inf_f64;
            xmax = -math.inf_f64;
            for (values) |value| {
                if (value < xmin) {
                    xmin = value;
                }
                if (value > xmax) {
                    xmax = value;
                }
            }
        }
        if (math.approxEqRel(f64, xmin, xmax, math.epsilon(f64))) {
            xmin -= 0.5;
            xmax += 0.5;
        }
        return Extrema{ .min = xmin, .max = xmax };
    }
};

test "Extrema of empty" {
    const values = [_]f64{};
    const e = Extrema.of(&values);
    try expectEqual(Extrema{ .min = 0, .max = 1 }, e);
}

test "Extrema of single value" {
    const values = [_]f64{23.45};
    const e = Extrema.of(&values);
    // +- 0.5
    try expectEqual(Extrema{ .min = 22.95, .max = 23.95 }, e);
}

test "Extrema of multiple equal values" {
    const values = [_]f64{ 1.5, 1.5, 1.5 };
    const e = Extrema.of(&values);
    // +- 0.5
    try expectEqual(Extrema{ .min = 1, .max = 2 }, e);
}

test "Extrema of multiple similar values" {
    const values = [_]f64{ 1.4999, 1.5, 1.50001 };
    const e = Extrema.of(&values);
    try expectEqual(Extrema{ .min = 1.4999, .max = 1.50001 }, e);
}

test "Histogram of empty list" {
    const values = [_]f64{};
    var h = try Histogram.init(testing.allocator, &values, 2);
    defer h.deinit();

    try expectEqualSlices(f64, h.bins.items, &([_]f64{ 0, 0.5, 1 }));
    try expectEqualSlices(u32, h.counts.items, &([_]u32{ 0, 0 }));
}

test "Histogram of list of one" {
    const values = [_]f64{42};
    var h = try Histogram.init(testing.allocator, &values, 2);
    defer h.deinit();

    try expectEqualSlices(f64, h.bins.items, &([_]f64{ 41.5, 42, 42.5 }));
    try expectEqualSlices(u32, h.counts.items, &([_]u32{ 0, 1 }));
}

test "Histogram of list of two" {
    const values = [_]f64{ 42, -42 };
    var h = try Histogram.init(testing.allocator, &values, 2);
    defer h.deinit();

    try expectEqualSlices(f64, h.bins.items, &([_]f64{ -42, 0, 42 }));
    try expectEqualSlices(u32, h.counts.items, &([_]u32{ 1, 1 }));
}

test "Histogram of list of many" {
    const values = [_]f64{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12 };
    var h = try Histogram.init(testing.allocator, &values, 2);
    defer h.deinit();

    try expectEqualSlices(f64, h.bins.items, &([_]f64{ 1, 6.5, 12 }));
    try expectEqualSlices(u32, h.counts.items, &([_]u32{ 6, 5 }));
}

test "Histogram of list of many with one bin for each" {
    const values = [_]f64{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12 };
    var h = try Histogram.init(testing.allocator, &values, 12);
    defer h.deinit();

    try expectEqualSlices(f64, h.bins.items, &([_]f64{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }));
    try expectEqualSlices(u32, h.counts.items, &([_]u32{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }));
}

test "Histogram of list of many with one bin for each negative" {
    const values = [_]f64{ 0, -1, -2, -3, -4, -5, -6, -7, -8, -9, -10, -12 };
    var h = try Histogram.init(testing.allocator, &values, 12);
    defer h.deinit();

    try expectEqualSlices(f64, h.bins.items, &([_]f64{ -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1, 0 }));
    try expectEqualSlices(u32, h.counts.items, &([_]u32{ 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2 }));
}

test "write simple Histogram" {
    const values = [_]f64{ 0, 1, 2, 3, 4, 5, 5, 5, 8, 9, 10, 12 };
    var h = try Histogram.init(testing.allocator, &values, 12);
    defer h.deinit();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{:60}", .{h});

    try expectEqualStrings(
        \\        bucket       | ____________________________________________________________ Total Counts
        \\[0.000   , 1.000   ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 1
        \\[1.000   , 2.000   ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 1
        \\[2.000   , 3.000   ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 1
        \\[3.000   , 4.000   ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 1
        \\[4.000   , 5.000   ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 1
        \\[5.000   , 6.000   ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀ 3
        \\[6.000   , 7.000   ) | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 0
        \\[7.000   , 8.000   ) | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 0
        \\[8.000   , 9.000   ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 1
        \\[9.000   , 10.000  ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 1
        \\[10.000  , 11.000  ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 1
        \\[11.000  , 12.000  ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 1
        \\‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
    , list.items);
}

test "write random Histogram" {
    var prng = std.rand.DefaultPrng.init(12345);
    var values: [1000]f64 = undefined;
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        values[i] = prng.random.floatNorm(f64);
    }
    var h = try Histogram.init(testing.allocator, &values, 10);
    defer h.deinit();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{:40}", .{h});

    try expectEqualStrings(
        \\        bucket       | ________________________________________ Total Counts
        \\[-2.810  , -2.234  ) | ⣿⣿⠆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 12
        \\[-2.234  , -1.658  ) | ⣿⣿⣿⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 31
        \\[-1.658  , -1.082  ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 101
        \\[-1.082  , -0.507  ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀ 169
        \\[-0.507  , 0.069   ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀ 203
        \\[0.069   , 0.645   ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀ 208
        \\[0.645   , 1.221   ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 155
        \\[1.221   , 1.797   ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 86
        \\[1.797   , 2.373   ) | ⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 29
        \\[2.373   , 2.948   ) | ⣿⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 6
        \\‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
    , list.items);
}

test "write large random Histogram" {
    var prng = std.rand.DefaultPrng.init(32345);
    var values: [1000]f64 = undefined;
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        values[i] = 1_000_000 * prng.random.floatNorm(f64);
    }
    var h = try Histogram.init(testing.allocator, &values, 10);
    defer h.deinit();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{e<8.1}", .{h});

    try expectEqualStrings(
        \\        bucket       | ________________________________________________________________________________ Total Counts
        \\[-2.8e+06, -2.2e+06) | ⣿⣿⣿⣿⠆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 13
        \\[-2.2e+06, -1.6e+06) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 39
        \\[-1.6e+06, -1.0e+06) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 87
        \\[-1.0e+06, -3.9e+05) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 189
        \\[-3.9e+05, 2.1e+05 ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀ 238
        \\[2.1e+05 , 8.2e+05 ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠆⠀⠀⠀⠀⠀⠀ 221
        \\[8.2e+05 , 1.4e+06 ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 138
        \\[1.4e+06 , 2.0e+06 ) | ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 52
        \\[2.0e+06 , 2.6e+06 ) | ⣿⣿⣿⣿⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 16
        \\[2.6e+06 , 3.2e+06 ) | ⣿⣿⠆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 7
        \\‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
    , list.items);
}
