const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;

const color = @import("./color.zig");
const canvas = @import("./canvas.zig");
const hist = @import("./hist.zig");
usingnamespace @import("./utils.zig");

const Figure = struct {
    /// The number of characters for the width (columns) of the canvas.
    width: u8,
    /// The number of characters for the hight (rows) of the canvas.
    height: u8,
    /// Lower left corner of reference system.
    xmin: f64,
    ymin: f64,
    /// Upper right corner of reference system.
    xmax: f64,
    ymax: f64,

    /// Whether to print the origin or not.
    origin: bool,
    /// Background color of the canvas.
    bg_color: color.Color,

    /// Labels for the axis.
    x_label: []const u8,
    y_label: []const u8,

    _canvas: ?canvas.Canvas,
    _plots: std.ArrayList(Plot),
    _histograms: std.ArrayList(Histogram),

    /// Allocator for all the stuff.
    allocator: *mem.Allocator,

    /// Deinitialize with `deinit`.
    pub fn init(allocator: *mem.Allocator, width: u8, height: u8, bg: ?color.Color) !Figure {
        assert(width > 0);
        assert(height > 0);
        return Figure{
            .width = width,
            .height = height,
            .xmin = 0.0,
            .ymin = 0.0,
            .xmax = 1.0,
            .ymax = 1.0,
            .origin = true,
            .bg_color = if (bg) |real_bg| real_bg else color.Color.no_color(),
            .x_label = try allocator.dupe(u8, "X"),
            .y_label = try allocator.dupe(u8, "Y"),
            ._canvas = null,
            ._plots = std.ArrayList(Plot).init(allocator),
            ._histograms = std.ArrayList(Histogram).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Figure) void {
        self.allocator.free(self.x_label);
        self.allocator.free(self.y_label);
        for (self._plots.items) |*p| {
            p.deinit(self.allocator);
        }
        self._plots.deinit();
        for (self._histograms.items) |*h| {
            h.deinit();
        }
        self._histograms.deinit();
        if (self._canvas) |cvs| {
            cvs.deinit(self.allocator);
        }
    }

    pub fn plot(self: *Figure, xs: []const f64, ys: []const f64, opts: struct {
        lc: color.Color = color.Color.no_color(),
        label: []const u8 = "Plot",
        marker: ?u8 = null,
    }) !void {
        var p = try Plot.init(self.allocator, xs, ys, opts.lc, true, opts.label, opts.marker);
        errdefer p.deinit(self.allocator);

        try self._plots.append(p);
    }

    pub fn scatter(self: *Figure, xs: []const f64, ys: []const f64, opts: struct {
        lc: color.Color = color.Color.no_color(),
        label: []const u8 = "Scatter",
        marker: ?u8 = null,
    }) !void {
        var p = try Plot.init(self.allocator, xs, ys, opts.lc, false, opts.label, opts.marker);
        errdefer p.deinit(self.allocator);

        try self._plots.append(p);
    }

    pub fn histogram(self: *Figure, xs: []const f64, bins: usize, lc: ?color.Color) !void {
        var h = try Histogram.init(
            self.allocator,
            xs,
            bins,
            if (lc) |c| c else color.Color.no_color(),
        );
        errdefer h.deinit();

        try self._histograms.append(h);
    }

    /// Create the canvas and print the plots into the canvas.
    pub fn prepare(self: *Figure) !void {
        if (self._canvas) |cvs| {
            cvs.deinit(self.allocator);
        }
        self._canvas = try canvas.Canvas.init(self.allocator, self.width, self.height, self.bg_color);
        self._canvas.?.setReferenceSystem(self.xmin, self.ymin, self.xmax, self.ymax);

        for (self._histograms.items) |h| {
            try h.write(&self._canvas.?);
        }
        for (self._plots.items) |p| {
            try p.write(&self._canvas.?);
        }
    }

    /// Output the figure to a writer.
    pub fn format(
        self: Figure,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        assert(self._canvas != null);
        assert(self._canvas.?.width == self.width);
        assert(self._canvas.?.height == self.height);
        // TODO reference system?

        var row: i9 = self.height + 1;
        while (row >= 0) : (row -= 1) {
            try self.printYAxis(row, writer);
            if (row < self.height) {
                try self._canvas.?.printRow(row, writer);
                if (row == 0) {
                    try writer.writeAll(line_separator);
                }
            } else {
                try writer.writeAll(line_separator);
            }
        }
        try self.printXAxis(writer);
    }

    fn printYAxis(self: Figure, idx: isize, writer: anytype) !void {
        assert(self.ymin < self.ymax);
        assert(0 <= idx);
        assert(idx <= self.height + 1);
        const y_delta = math.absFloat(self.ymax - self.ymin) / @intToFloat(f64, self.height);

        const value: f64 = @intToFloat(f64, idx) * y_delta + self.ymin;
        if (idx <= self.height) {
            // print canvas and max values
            try writer.print("{d: <10.3} | ", .{value});
        } else {
            // print label
            try writer.print("{s: ^10} ^", .{self.y_label});
        }
    }

    fn printXAxis(self: Figure, writer: anytype) !void {
        assert(self.xmin < self.xmax);
        const x_delta = math.absFloat(self.xmax - self.xmin) / @intToFloat(f64, self.width);

        try writer.writeByteNTimes('-', 11);
        try writer.writeAll("|-");
        var col: usize = 0;
        while (col < self.width / 10) : (col += 1) {
            try writer.writeAll("|---------");
        }
        try writer.writeAll("|");
        try writer.writeByteNTimes('-', self.width % 10);

        try writer.print("-> ({s})" ++ line_separator, .{self.x_label});

        try writer.writeByteNTimes(' ', 11);
        try writer.writeAll("| ");
        col = 0;
        while (col < self.width / 10 + 1) : (col += 1) {
            const value = @intToFloat(f64, col) * 10 * x_delta + self.xmin;
            try writer.print("{d: <9.3} ", .{value});
        }
    }

    const Plot = struct {
        xs: []const f64,
        ys: []const f64,
        lc: color.Color,
        interpolate: bool,
        label: []const u8,
        marker: ?u8,

        /// Deinitialize with `deinit`.
        fn init(
            allocator: *mem.Allocator,
            xs: []const f64,
            ys: []const f64,
            lc: color.Color,
            interp: bool,
            label: []const u8,
            marker: ?u8,
        ) !Plot {
            assert(xs.len == ys.len);
            assert(xs.len > 0);
            return Plot{
                .xs = try mem.dupe(allocator, f64, xs),
                .ys = try mem.dupe(allocator, f64, ys),
                .lc = lc,
                .interpolate = interp,
                .label = try mem.dupe(allocator, u8, label),
                .marker = marker,
            };
        }

        fn deinit(self: *Plot, allocator: *mem.Allocator) void {
            allocator.free(self.xs);
            allocator.free(self.ys);
            allocator.free(self.label);
        }

        fn write(self: Plot, cvs: *canvas.Canvas) !void {
            assert(self.xs.len == self.ys.len);
            if (self.xs.len == 0) {
                return;
            }
            // first point
            cvs.point(.{ .x = self.xs[0], .y = self.ys[0] }, self.lc, self.marker);

            var idx: usize = 1;
            while (idx < self.xs.len) : (idx += 1) {
                if (self.interpolate) {
                    try cvs.line(
                        .{ .x = self.xs[idx - 1], .y = self.ys[idx - 1] },
                        .{ .x = self.xs[idx], .y = self.ys[idx] },
                        self.lc,
                        self.marker,
                    );
                } else {
                    cvs.point(.{ .x = self.xs[idx], .y = self.ys[idx] }, self.lc, self.marker);
                }
            }
        }
    };

    const Histogram = struct {
        histogram: hist.Histogram,
        lc: color.Color,

        fn init(
            allocator: *mem.Allocator,
            xs: []const f64,
            bins: usize,
            lc: ?color.Color,
        ) !Histogram {
            return Histogram{
                .histogram = try hist.Histogram.init(allocator, xs, bins),
                .lc = if (lc) |real_lc| real_lc else color.Color.no_color(),
            };
        }

        fn deinit(self: *Histogram) void {
            self.histogram.deinit();
        }

        fn write(self: Histogram, cvs: *canvas.Canvas) !void {
            // how fat will one bar of the histogram be
            const distances = cvs.dotsBetween(
                .{ .x = self.histogram.bins.items[0], .y = 0 },
                .{ .x = self.histogram.bins.items[1], .y = 0 },
            );
            var x_diff: usize = 1;
            if (distances.x > 0) {
                x_diff = @intCast(usize, distances.x);
            }
            std.debug.print("\n{any}\n{}\n", .{ distances, x_diff });

            var idx: usize = 0;
            while (idx < self.histogram.counts.items.len) : (idx += 1) {
                if (self.histogram.counts.items[idx] == 0) {
                    continue;
                }
                var col: usize = 0;
                while (col < x_diff) : (col += 1) {
                    const x = self.histogram.bins.items[idx] + @intToFloat(f64, col) * cvs.x_delta_pt;

                    if (cvs.xmin <= x and x <= cvs.xmax) {
                        try cvs.line(
                            .{ .x = x, .y = 0.0 },
                            .{ .x = x, .y = @intToFloat(f64, self.histogram.counts.items[idx]) },
                            self.lc,
                            null,
                        );
                    }
                }
            }
        }
    };
};

test "working test" {
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.plot(&[_]f64{ 0, 1 }, &[_]f64{ 0, 1 }, .{ .lc = color.Color.by_name(.red), .label = "xxx" });
    try fig.scatter(&[_]f64{ 0.1, 0.9 }, &[_]f64{ 0.9, 0.1 }, .{ .lc = color.Color.by_name(.blue), .label = "yyy", .marker = 'x' });
    try fig.histogram(&[_]f64{ 0.1, 0.1, 0.2, 0.4, 0.5 }, 5, color.Color.by_name(.yellow));

    try fig.prepare();
    std.debug.print("\n{}\n", .{fig});
}
