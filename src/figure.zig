const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;

const color = @import("./color.zig");
const canvas = @import("./canvas.zig");
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
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Figure) void {
        self.allocator.free(self.x_label);
        self.allocator.free(self.y_label);
        if (self._canvas) |cvs| {
            cvs.deinit(self.allocator);
        }
    }

    /// Create the canvas and print the plots into the canvas.
    pub fn prepare(self: *Figure) !void {
        if (self._canvas) |cvs| {
            cvs.deinit(self.allocator);
        }
        self._canvas = try canvas.Canvas.init(self.allocator, self.width, self.height, self.bg_color);
        self._canvas.?.setReferenceSystem(self.xmin, self.ymin, self.xmax, self.ymax);
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
        while (row > 0) : (row -= 1) {
            try self.printYAxis(row, writer);
            if (row < self.height) {
                try self._canvas.?.printRow(row, writer);
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
};

test "working test" {
    var fig = try Figure.init(std.testing.allocator, 30, 10, null);
    defer fig.deinit();

    try fig.prepare();
    std.debug.print("\n{}\n", .{fig});
}
