const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const testing = std.testing;
const expectEqualSlices = testing.expectEqualSlices;
const expectEqual = testing.expectEqual;

pub const Histogram = struct {
    counts: ArrayList(u32),
    bins: ArrayList(f64),

    /// Deinitialize with deinit.
    pub fn init(allocator: *Allocator, values: []const f64, bins: u8) !Histogram {
        assert(bins > 0);

        const x = Extrema.of(values);
        const delta = x.max - x.min;
        const xwidth = delta / @intToFloat(f64, bins);
        var h = Histogram{ .counts = try ArrayList(u32).initCapacity(allocator, bins), .bins = try ArrayList(f64).initCapacity(allocator, bins + 1) };
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
