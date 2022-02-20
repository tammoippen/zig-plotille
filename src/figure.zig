const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const expectEqualStrings = std.testing.expectEqualStrings;

const color = @import("./color.zig");
const canvas = @import("./canvas.zig");
const hist = @import("./hist.zig");
const terminfo = @import("./terminfo.zig");
const utils = @import("./utils.zig");

const Figure = struct {
    /// The number of characters for the width (columns) of the canvas.
    width: u16,
    /// The number of characters for the hight (rows) of the canvas.
    height: u16,
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
    _texts: std.ArrayList(Text),
    _spans: std.ArrayList(Span),

    /// Allocator for all the stuff.
    allocator: mem.Allocator,

    /// Deinitialize with `deinit`.
    pub fn init(allocator: mem.Allocator, width: u16, height: u16, bg: ?color.Color) !Figure {
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
            ._texts = std.ArrayList(Text).init(allocator),
            ._spans = std.ArrayList(Span).init(allocator),
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
        for (self._texts.items) |*t| {
            t.deinit(self.allocator);
        }
        self._texts.deinit();
        if (self._canvas) |cvs| {
            cvs.deinit(self.allocator);
        }
        self._spans.deinit();
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

    pub fn text(self: *Figure, x: f64, y: f64, str: []const u8, lc: ?color.Color) !void {
        var t = try Text.init(
            self.allocator,
            x,
            y,
            str,
            if (lc) |c| c else color.Color.no_color(),
        );
        errdefer t.deinit(self.allocator);

        try self._texts.append(t);
    }

    pub fn axvline(self: *Figure, x: f64, opts: struct {
        lc: color.Color = color.Color.no_color(),
        ymin: f64 = 0,
        ymax: f64 = 1,
    }) !void {
        assert(0 <= x and x <= 1);
        assert(0 <= opts.ymin and opts.ymin <= 1);
        assert(0 <= opts.ymax and opts.ymax <= 1);
        assert(opts.ymin <= opts.ymax);
        try self._spans.append(Span{
            .xmin = x,
            .xmax = x,
            .ymin = opts.ymin,
            .ymax = opts.ymax,
            .lc = opts.lc,
        });
    }

    pub fn axvspan(self: *Figure, xmin: f64, xmax: f64, opts: struct {
        lc: color.Color = color.Color.no_color(),
        ymin: f64 = 0,
        ymax: f64 = 1,
    }) !void {
        assert(0 <= xmin and xmin <= 1);
        assert(0 <= xmax and xmax <= 1);
        assert(0 <= opts.ymin and opts.ymin <= 1);
        assert(0 <= opts.ymax and opts.ymax <= 1);
        assert(xmin <= xmax);
        assert(opts.ymin <= opts.ymax);
        try self._spans.append(Span{
            .xmin = xmin,
            .xmax = xmax,
            .ymin = opts.ymin,
            .ymax = opts.ymax,
            .lc = opts.lc,
        });
    }

    pub fn axhline(self: *Figure, y: f64, opts: struct {
        lc: color.Color = color.Color.no_color(),
        xmin: f64 = 0,
        xmax: f64 = 1,
    }) !void {
        assert(0 <= y and y <= 1);
        assert(0 <= opts.xmin and opts.xmin <= 1);
        assert(0 <= opts.xmax and opts.xmax <= 1);
        assert(opts.xmin <= opts.xmax);
        try self._spans.append(Span{
            .xmin = opts.xmin,
            .xmax = opts.xmax,
            .ymin = y,
            .ymax = y,
            .lc = opts.lc,
        });
    }

    pub fn axhspan(self: *Figure, ymin: f64, ymax: f64, opts: struct {
        lc: color.Color = color.Color.no_color(),
        xmin: f64 = 0,
        xmax: f64 = 1,
    }) !void {
        assert(0 <= ymin and ymin <= 1);
        assert(0 <= ymax and ymax <= 1);
        assert(0 <= opts.xmin and opts.xmin <= 1);
        assert(0 <= opts.xmax and opts.xmax <= 1);
        assert(ymin <= ymax);
        assert(opts.xmin <= opts.xmax);
        try self._spans.append(Span{
            .xmin = opts.xmin,
            .xmax = opts.xmax,
            .ymin = ymin,
            .ymax = ymax,
            .lc = opts.lc,
        });
    }

    /// Create the canvas and print the plots into the canvas.
    pub fn prepare(self: *Figure) !void {
        if (self._canvas) |cvs| {
            cvs.deinit(self.allocator);
        }
        self._canvas = try canvas.Canvas.init(self.allocator, self.width, self.height, self.bg_color);
        self._canvas.?.setReferenceSystem(self.xmin, self.ymin, self.xmax, self.ymax);

        for (self._spans.items) |s| {
            try s.write(&self._canvas.?);
        }
        for (self._histograms.items) |h| {
            try h.write(&self._canvas.?);
        }
        for (self._plots.items) |p| {
            try p.write(&self._canvas.?);
        }
        for (self._texts.items) |t| {
            try t.write(&self._canvas.?);
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

        var row: i17 = self.height + 1;
        while (row >= 0) : (row -= 1) {
            try self.printYAxis(row, writer);
            if (row < self.height) {
                try self._canvas.?.printRow(row, writer);
                if (row == 0) {
                    try writer.writeAll(utils.line_separator);
                }
            } else {
                try writer.writeAll(utils.line_separator);
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

        try writer.print("-> ({s})" ++ utils.line_separator, .{self.x_label});

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
            allocator: mem.Allocator,
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
                .xs = try allocator.dupe(f64, xs),
                .ys = try allocator.dupe(f64, ys),
                .lc = lc,
                .interpolate = interp,
                .label = try allocator.dupe(u8, label),
                .marker = marker,
            };
        }

        fn deinit(self: *Plot, allocator: mem.Allocator) void {
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

        /// Deinitialize with `deinit`.
        fn init(
            allocator: mem.Allocator,
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

    const Text = struct {
        x: f64,
        y: f64,
        str: []const u8,
        lc: color.Color,

        /// Deinitialize with `deinit`.
        fn init(
            allocator: mem.Allocator,
            x: f64,
            y: f64,
            str: []const u8,
            lc: color.Color,
        ) !Text {
            assert(str.len > 0);
            return Text{
                .x = x,
                .y = y,
                .str = try allocator.dupe(u8, str),
                .lc = lc,
            };
        }

        fn deinit(self: *Text, allocator: mem.Allocator) void {
            allocator.free(self.str);
        }

        fn write(self: Text, cvs: *canvas.Canvas) !void {
            cvs.text(.{ .x = self.x, .y = self.y }, self.str, self.lc);
        }
    };

    const Span = struct {
        /// Lower left corner of the span.
        xmin: f64,
        ymin: f64,
        /// Upper right corner of the span.
        xmax: f64,
        ymax: f64,
        /// Color of the span.
        lc: color.Color,

        fn write(self: Span, cvs: *canvas.Canvas) !void {
            assert(0 <= self.xmin and self.xmin <= 1);
            assert(0 <= self.ymin and self.ymin <= 1);
            assert(0 <= self.xmax and self.xmax <= 1);
            assert(0 <= self.ymax and self.ymax <= 1);
            assert(self.xmin <= self.xmax);
            assert(self.ymin <= self.ymax);

            const xmax_inside = cvs.xmin + (@intToFloat(f64, cvs.width) * 2 - 1) * cvs.x_delta_pt;
            const xdelta = xmax_inside - cvs.xmin;
            const ymax_inside = cvs.ymin + (@intToFloat(f64, cvs.height) * 4 - 1) * cvs.y_delta_pt;
            const ydelta = ymax_inside - cvs.ymin;
            assert(xdelta > 0);
            assert(ydelta > 0);

            try cvs.rect(
                .{
                    .x = cvs.xmin + self.xmin * xdelta,
                    .y = cvs.ymin + self.ymin * ydelta,
                },
                .{
                    .x = cvs.xmin + self.xmax * xdelta,
                    .y = cvs.ymin + self.ymax * ydelta,
                },
                self.lc,
                null,
            );
        }
    };
};

test "working test" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.plot(&[_]f64{ 0, 1 }, &[_]f64{ 0, 1 }, .{ .lc = color.Color.by_name(.red), .label = "xxx" });
    try fig.scatter(&[_]f64{ 0.1, 0.9 }, &[_]f64{ 0.9, 0.1 }, .{ .lc = color.Color.by_name(.blue), .label = "yyy", .marker = 'x' });
    try fig.histogram(&[_]f64{ 0.1, 0.1, 0.2, 0.4, 0.5 }, 10, color.Color.by_name(.yellow));
    try fig.text(0.6, 1.65, "Hello", color.Color.by_name(.magenta));

    fig.xmin = 0;
    fig.xmax = 1.1;
    fig.ymin = 0;
    fig.ymax = 3;
    fig.width = 45;

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\3.000      | 
        \\2.700      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\2.400      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\2.100      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\1.800      | ⠀⠀⠀⠀⣶⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\1.500      | ⠀⠀⠀⠀⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀Hello⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\1.200      | ⠀⠀⠀⠀⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.900      | ⠀⠀⠀⠀x⡇⠀⣤⡄⠀⠀⠀⠀⠀⠀⢠⣤⠀⢠⣤⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⣀⠤⠤⠀⠀⠀⠀
        \\0.600      | ⠀⠀⠀⠀⣿⡇⠀⣿⡇⠀⠀⠀⠀⠀⠀⢸⣿⠀⢸⣿⠀⠀⠀⢀⣀⣀⡠⠤⠤⠤⠒⠒⠒⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.300      | ⠀⠀⠀⠀⣿⡇⠀⣿⡇⠀⠀⣀⣀⣀⡠⢼⣿⠔⢺⣿⠊⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.000      | ⣀⣀⠤⠤⣿⡗⠒⣿⡏⠉⠉⠀⠀⠀⠀⢸⣿⠀⢸⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀x⠀⠀⠀⠀⠀⠀⠀⠀
        \\-----------|-|---------|---------|---------|---------|------> (X)
        \\           | 0.000     0.244     0.489     0.733     0.978     
    , list.items);

    // force colors
    terminfo.TermInfo.testing();
    std.debug.print("\n{}\n", .{fig});
}

test "figure with axvline center" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axvline(0.5, .{});

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.800      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.700      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.600      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.500      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.400      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.300      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.200      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.100      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.000      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}

test "figure with axvline center center" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axvline(0.5, .{ .ymin = 0.25, .ymax = 0.75 });

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.800      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.700      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.600      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.500      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.400      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.300      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.200      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.100      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.000      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}

test "figure with axvline left" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axvline(0, .{});

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.800      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.700      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.600      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.500      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.400      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.300      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.200      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.100      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.000      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}

test "figure with axvline right" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axvline(1, .{});

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.800      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.700      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.600      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.500      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.400      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.300      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.200      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.100      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.000      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}

test "figure with axvspan border" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axvspan(0, 1, .{});

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⡏⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⢹
        \\0.800      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.700      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.600      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.500      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.400      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.300      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.200      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.100      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.000      | ⣇⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣸
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}

test "figure with axvspan center" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axvspan(0.25, 0.75, .{});

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⠀⠀⠀⠀⠀⠀⠀⡏⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.800      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.700      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.600      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.500      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.400      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.300      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.200      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.100      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.000      | ⠀⠀⠀⠀⠀⠀⠀⣇⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⡇⠀⠀⠀⠀⠀⠀⠀
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}

test "figure with axvspan center center" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axvspan(0.25, 0.75, .{ .ymin = 0.25, .ymax = 0.75 });

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.800      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.700      | ⠀⠀⠀⠀⠀⠀⠀⡤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⡄⠀⠀⠀⠀⠀⠀⠀
        \\0.600      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.500      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.400      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.300      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.200      | ⠀⠀⠀⠀⠀⠀⠀⠧⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠇⠀⠀⠀⠀⠀⠀⠀
        \\0.100      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.000      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}

test "figure with axhline center" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axhline(0.5, .{});

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.800      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.700      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.600      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.500      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.400      | ⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉
        \\0.300      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.200      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.100      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.000      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}

test "figure with axhline center center" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axhline(0.5, .{ .xmin = 0.25, .xmax = 0.75 });

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.800      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.700      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.600      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.500      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.400      | ⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀
        \\0.300      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.200      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.100      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.000      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}

test "figure with axhline bottom" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axhline(0, .{});

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.800      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.700      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.600      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.500      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.400      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.300      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.200      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.100      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.000      | ⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}

test "figure with axhline top" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axhline(1, .{});

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉
        \\0.800      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.700      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.600      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.500      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.400      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.300      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.200      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.100      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.000      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}

test "figure with axhspan border" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axhspan(0, 1, .{});

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⡏⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⢹
        \\0.800      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.700      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.600      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.500      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.400      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.300      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.200      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.100      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.000      | ⣇⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣸
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}

test "figure with axhspan center" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axhspan(0.25, 0.75, .{});

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.800      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.700      | ⡤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⢤
        \\0.600      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.500      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.400      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.300      | ⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸
        \\0.200      | ⠧⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠼
        \\0.100      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.000      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}

test "figure with axhspan center center" {
    terminfo.TermInfo.disable_color();
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.axhspan(0.25, 0.75, .{ .xmin = 0.25, .xmax = 0.75 });

    try fig.prepare();

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try list.writer().print("{}", .{fig});
    try expectEqualStrings(
        \\    Y      ^
        \\1.000      | 
        \\0.900      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.800      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.700      | ⠀⠀⠀⠀⠀⠀⠀⡤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⡄⠀⠀⠀⠀⠀⠀⠀
        \\0.600      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.500      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.400      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.300      | ⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀
        \\0.200      | ⠀⠀⠀⠀⠀⠀⠀⠧⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠇⠀⠀⠀⠀⠀⠀⠀
        \\0.100      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\0.000      | ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\-----------|-|---------|---------|---------|-> (X)
        \\           | 0.000     0.333     0.667     1.000     
    , list.items);
}
