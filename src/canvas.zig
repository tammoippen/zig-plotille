const std = @import("std");
const absFloat = std.math.absFloat;
const absInt = std.math.absInt;
const approxEqAbs = std.math.approxEqAbs;
const floor = std.math.floor;
const max = std.math.max;
const round = std.math.round;
const signbit = std.math.signbit;

const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

const color = @import("./color.zig");
const dots = @import("./dots.zig");
const terminfo = @import("./terminfo.zig");

const XCoord = struct {
    braille_idx: i32,
    char_idx: i32,
    dot_idx: u1,

    fn with(idx: i32) XCoord {
        return XCoord{
            .braille_idx = idx,
            .char_idx = @divFloor(idx, 2),
            .dot_idx = @intCast(u1, absInt(@rem(idx, 2)) catch unreachable), // % 2
        };
    }
};
const YCoord = struct {
    braille_idx: i32,
    char_idx: i32,
    dot_idx: u2,

    fn with(idx: i32) YCoord {
        return YCoord{
            .braille_idx = idx,
            .char_idx = @divFloor(idx, 4),
            .dot_idx = @intCast(u2, absInt(@rem(idx, 4)) catch unreachable),
        };
    }
};

const Point = struct {
    x: f64,
    y: f64,
};

/// A canvas object for plotting braille dots
///
/// A Canvas object has a `width` x `height` characters large canvas, in which it
/// can plot indivitual braille point, lines out of braille points, rectangles,...
/// Since a full braille character has 2 x 4 dots (⣿), the canvas has `width` * 2, `height` * 4
/// dots to plot into in total.
///
/// It maintains two coordinate systems: a reference system with the limits (xmin, ymin)
/// in the lower left corner to (xmax, ymax) in the upper right corner is transformed
/// into the canvas discrete, i.e. dots, coordinate system (0, 0) to (`width` * 2, `height` * 4).
/// It does so transparently to clients of the Canvas, i.e. all plotting functions
/// only accept coordinates in the reference system. If the coordinates are outside
/// the reference system, they are not plotted.
pub const Canvas = struct {
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
    /// value of x between one point
    x_delta_pt: f64,
    /// value of y between one point
    y_delta_pt: f64,
    /// Background color of the canvas.
    bg: color.Color,
    /// The actual canvas to draw in.
    canvas: []dots.Dots,

    /// Deinitialize with `deinit`.
    pub fn init(allocator: *std.mem.Allocator, width: u8, height: u8, bg: color.Color) !Canvas {
        assert(width > 0);
        assert(height > 0);
        var result = Canvas{
            .width = width,
            .height = height,
            .xmin = 0,
            .ymin = 0,
            .xmax = 1,
            .ymax = 1,
            // computed later
            .x_delta_pt = 0,
            .y_delta_pt = 0,
            .bg = bg,
            .canvas = try allocator.alloc(dots.Dots, @as(u32, width) * @as(u32, height)),
        };
        for (result.canvas) |*dot| {
            dot.* = dots.Dots{};
        }
        result.setReferenceSystem(0, 0, 1, 1);
        return result;
    }

    /// Release all allocated memory.
    pub fn deinit(self: Canvas, allocator: *std.mem.Allocator) void {
        allocator.free(self.canvas);
    }

    /// Set the reference system of the canvas.
    ///
    /// Default reference system is bottom-left (0,0) to top right (1, 1).
    pub fn setReferenceSystem(self: *Canvas, xmin: f64, ymin: f64, xmax: f64, ymax: f64) void {
        assert(xmin < xmax);
        assert(ymin < ymax);
        self.xmin = xmin;
        self.ymin = ymin;
        self.xmax = xmax;
        self.ymax = ymax;
        self.x_delta_pt = absFloat((xmax - xmin) / @intToFloat(f64, @as(u32, self.width) * 2)); // 2 points in left
        self.y_delta_pt = absFloat((ymax - ymin) / @intToFloat(f64, @as(u32, self.height) * 4)); // 4 points in up
    }

    /// Transform an x-coordinate of the reference system to an index
    /// of a braille point and char index.
    /// As we have a width defined as u8, and 2 points per character
    /// we are in the range of u9.
    fn transform_x(self: Canvas, x: f64) XCoord {
        const flt_idx = floor((x - self.xmin) / self.x_delta_pt);
        if (flt_idx > 0x7FFFFFFF) {
            return XCoord.with(0x7FFFFFFF);
        }
        if (flt_idx < -0x80000000) {
            return XCoord.with(-0x80000000);
        }
        const braille_idx = @floatToInt(i32, flt_idx);
        return XCoord.with(braille_idx);
    }

    /// Transform an y-coordinate of the reference system to an index
    /// of a braille point and char index.
    /// As we have a height defined as u8, and 4 points per character
    /// we are in the range of u0.
    fn transform_y(self: Canvas, y: f64) YCoord {
        const flt_idx = floor((y - self.ymin) / self.y_delta_pt);
        if (flt_idx > 0x7FFFFFFF) {
            return YCoord.with(0x7FFFFFFF);
        }
        if (flt_idx < -0x80000000) {
            return YCoord.with(-0x80000000);
        }
        const braille_idx = @floatToInt(i32, flt_idx);
        return YCoord.with(braille_idx);
    }

    fn set(self: *Canvas, x_coord: XCoord, y_coord: YCoord, fg_color: ?color.Color, char: ?u8) void {
        if (x_coord.char_idx < 0 or x_coord.char_idx >= self.width or y_coord.char_idx < 0 or y_coord.char_idx >= self.height) {
            // out of canvas
            return;
        }
        const idx = @intCast(usize, y_coord.char_idx * self.width + x_coord.char_idx);
        self.canvas[idx].set(x_coord.dot_idx, y_coord.dot_idx);
        if (fg_color) |c| {
            self.canvas[idx].color.fg = c;
        }
        if (char) |c| {
            self.canvas[idx].char = c;
        }
    }

    /// Put a text into the canvas at (x, y) [reference coordinate system]
    ///
    /// Parameters:
    ///     x:      x-coordinate on reference system.
    ///     y:      y-coordinate on reference system.
    ///     string:   The text to put into the canvas.
    ///     color:  Color of the text.
    pub fn text(self: *Canvas, p: Point, string: []const u8, fg_color: ?color.Color) void {
        const x_coord = self.transform_x(p.x);
        const y_coord = self.transform_y(p.y);

        if (self.width < x_coord.char_idx or y_coord.char_idx < 0 or y_coord.char_idx >= self.height) {
            return;
        }

        var idx: i32 = 0;
        if (x_coord.char_idx < 0) {
            idx -= x_coord.char_idx;
        }
        while (idx < @as(i32, self.width) - x_coord.char_idx) : (idx += 1) {
            if (string.len <= idx) {
                return;
            }
            const char_idx = @intCast(usize, y_coord.char_idx * self.width + x_coord.char_idx + idx);
            self.canvas[char_idx].char = string[@intCast(usize, idx)];
            if (fg_color) |c| {
                self.canvas[char_idx].color.fg = c;
            }
        }
    }

    /// Put a point into the canvas at (x, y) [reference coordinate system]
    ///
    /// Parameters:
    ///     x:      x-coordinate on reference system.
    ///     y:      y-coordinate on reference system.
    ///     color:  Color of the point.
    ///     char:   A character to put into the point.
    pub fn point(self: *Canvas, p: Point, fg_color: ?color.Color, char: ?u8) void {
        const x_coord = self.transform_x(p.x);
        const y_coord = self.transform_y(p.y);

        self.set(x_coord, y_coord, fg_color, char);
    }

    /// Fill the complete char in the canvas at (x, y) [reference coordinate system]
    ///
    /// Parameters:
    ///     x:      x-coordinate on reference system.
    ///     y:      y-coordinate on reference system.
    pub fn fillChar(self: *Canvas, p: Point) void {
        const x_coord = self.transform_x(p.x);
        const y_coord = self.transform_y(p.y);

        if (x_coord.char_idx < 0 or x_coord.char_idx >= self.width or y_coord.char_idx < 0 or y_coord.char_idx >= self.height) {
            // out of canvas
            return;
        }
        const idx = @intCast(usize, y_coord.char_idx * self.width + x_coord.char_idx);
        self.canvas[idx].fill();
    }

    /// Plot line between point (x0, y0) and (x1, y1) [reference coordinate system].
    ///
    /// Parameters:
    ///     x0, y0:  Point 0
    ///     x1, y1:  Point 1
    ///     color:   Color of the line.
    ///     char:    A character to put at the start and end of the line.
    pub fn line(self: *Canvas, p0: Point, p1: Point, fg_color: ?color.Color, char: ?u8) !void {
        const x0_coord = self.transform_x(p0.x);
        const y0_coord = self.transform_y(p0.y);
        const x1_coord = self.transform_x(p1.x);
        const y1_coord = self.transform_y(p1.y);

        // set start and end
        self.set(x0_coord, y0_coord, fg_color, char);
        self.set(x1_coord, y1_coord, fg_color, char);

        // difference along the coordinates
        const x_diff = x1_coord.braille_idx - x0_coord.braille_idx;
        const y_diff = y1_coord.braille_idx - y0_coord.braille_idx;

        // steps to go in each direction
        const max_steps = max(try absInt(x_diff), try absInt(y_diff));
        const xstep = @intToFloat(f64, x_diff) / @intToFloat(f64, max_steps);
        const ystep = @intToFloat(f64, y_diff) / @intToFloat(f64, max_steps);

        if (max_steps > 0) {
            const x_start = start_idx(x0_coord.braille_idx, xstep, @as(i32, self.width) * 2);
            var y_start = start_idx(y0_coord.braille_idx, ystep, @as(i32, self.height) * 4);

            var idx: usize = max(1, max(x_start, y_start));
            while (idx < max_steps) : (idx += 1) {
                const xb = x0_coord.braille_idx + @floatToInt(i32, round(xstep * @intToFloat(f64, idx)));
                const yb = y0_coord.braille_idx + @floatToInt(i32, round(ystep * @intToFloat(f64, idx)));
                if (0 <= xb and xb < @as(u32, self.width) * 2 and 0 <= yb and yb < @as(u32, self.height) * 4) {
                    self.set(XCoord.with(xb), YCoord.with(yb), fg_color, null);
                } else {
                    return;
                }
            }
        }
    }

    fn start_idx(c: i32, step: f64, c_max: i32) usize {
        assert(c_max > 0);
        if (approxEqAbs(f64, 0, step, 0.001)) {
            // cannot devide by 0
            return 0;
        }
        if (0 <= c and c < c_max) {
            // we are in the canvas
            return 0;
        }
        if ((c < 0) == signbit(step)) {
            // we are outside the canvas, and c and step have same
            // sign => we leave the canvas even more
            return 0; // TODO error?
        }
        if (c < 0) {
            return @floatToInt(usize, @intToFloat(f64, -c) / step);
        } else {
            assert(c >= c_max);
            return @floatToInt(usize, @intToFloat(f64, -(c - c_max + 1)) / step);
        }
    }

    /// Plot rectangle with bbox bottom_left to top_right [reference coordinate system].
    ///
    /// Parameters:
    ///     bottom_left:   Bottom left corner of rectangle.
    ///     top_right:     Top right corner of rectangle.
    ///     color:         Color of the rect.
    ///     char:          A character to put into the corners of the rect.
    pub fn rect(self: *Canvas, bottom_left: Point, top_right: Point, fg_color: ?color.Color, char: ?u8) !void {
        assert(bottom_left.x <= top_right.x);
        assert(bottom_left.y <= top_right.y);

        try self.line(bottom_left, .{ .x = bottom_left.x, .y = top_right.y }, fg_color, char);
        try self.line(.{ .x = bottom_left.x, .y = top_right.y }, top_right, fg_color, char);
        try self.line(top_right, .{ .x = top_right.x, .y = bottom_left.y }, fg_color, char);
        try self.line(.{ .x = top_right.x, .y = bottom_left.y }, bottom_left, fg_color, char);
    }

    /// Output the canvas to a writer.
    pub fn format(
        self: Canvas,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        // ignored options -> conform to signature
        _ = options;
        _ = fmt;
        var h_idx: i9 = self.height - 1;
        while (h_idx >= 0) : (h_idx -= 1) {
            try self.printRow(h_idx, writer);
        }
    }

    pub fn printRow(self: Canvas, row: i9, writer: anytype) !void {
        assert(row >= 0);
        var w_idx: u9 = 0;
        while (w_idx < self.width) : (w_idx += 1) {
            const idx: usize = @intCast(usize, row) * @as(usize, self.width) + w_idx;
            var d = self.canvas[idx];
            d.color.bg = self.bg;
            try writer.print("{}", .{d});
        }
        if (row > 0) {
            try writer.writeAll("\n");
        }
    }
};

test "init and deinit Canvas" {
    const c = try Canvas.init(std.testing.allocator, 10, 10, color.Color.by_name(.blue));
    defer c.deinit(std.testing.allocator);

    try expectEqual(@as(f64, 0.0), c.xmin);
    try expectEqual(@as(f64, 0.0), c.ymin);
    try expectEqual(@as(f64, 0.05), c.x_delta_pt);
    try expectEqual(@as(f64, 1.0), c.xmax);
    try expectEqual(@as(f64, 1.0), c.ymax);
    try expectEqual(@as(f64, 0.025), c.y_delta_pt);
}

test "init and deinit large Canvas" {
    const c = try Canvas.init(std.testing.allocator, 255, 255, color.Color.by_name(.blue));
    defer c.deinit(std.testing.allocator);

    try expectEqual(@as(f64, 0.0), c.xmin);
    try expectEqual(@as(f64, 0.0), c.ymin);
    try expectEqual(@as(f64, 1.0 / 510.0), c.x_delta_pt);
    try expectEqual(@as(f64, 1.0), c.xmax);
    try expectEqual(@as(f64, 1.0), c.ymax);
    try expectEqual(@as(f64, 1.0 / 1020.0), c.y_delta_pt);
}

test "compute x-coordinates of braille points" {
    const c = try Canvas.init(std.testing.allocator, 1, 1, color.Color.by_name(.blue));
    defer c.deinit(std.testing.allocator);

    {
        const coord = c.transform_x(0);
        try expectEqual(@as(i32, 0), coord.braille_idx);
        try expectEqual(@as(i32, 0), coord.char_idx);
        try expectEqual(@as(i32, 0), coord.dot_idx);
    }
    {
        const coord = c.transform_x(0.24);
        try expectEqual(@as(i32, 0), coord.braille_idx);
        try expectEqual(@as(i32, 0), coord.char_idx);
        try expectEqual(@as(i32, 0), coord.dot_idx);
    }
    {
        const coord = c.transform_x(0.25);
        try expectEqual(@as(i32, 0), coord.braille_idx);
        try expectEqual(@as(i32, 0), coord.char_idx);
        try expectEqual(@as(i32, 0), coord.dot_idx);
    }
    {
        const coord = c.transform_x(0.49);
        try expectEqual(@as(i32, 0), coord.braille_idx);
        try expectEqual(@as(i32, 0), coord.char_idx);
        try expectEqual(@as(i32, 0), coord.dot_idx);
    }
    {
        const coord = c.transform_x(0.5);
        try expectEqual(@as(i32, 1), coord.braille_idx);
        try expectEqual(@as(i32, 0), coord.char_idx);
        try expectEqual(@as(i32, 1), coord.dot_idx);
    }
    {
        const coord = c.transform_x(0.75);
        try expectEqual(@as(i32, 1), coord.braille_idx);
        try expectEqual(@as(i32, 0), coord.char_idx);
        try expectEqual(@as(i32, 1), coord.dot_idx);
    }
    {
        const coord = c.transform_x(0.99);
        try expectEqual(@as(i32, 1), coord.braille_idx);
        try expectEqual(@as(i32, 0), coord.char_idx);
        try expectEqual(@as(i32, 1), coord.dot_idx);
    }
    {
        const coord = c.transform_x(1);
        try expectEqual(@as(i32, 2), coord.braille_idx);
        try expectEqual(@as(i32, 1), coord.char_idx);
        try expectEqual(@as(i32, 0), coord.dot_idx);
    }
}

test "compute y-coordinates of braille points" {
    const c = try Canvas.init(std.testing.allocator, 1, 1, color.Color.by_name(.blue));
    defer c.deinit(std.testing.allocator);

    {
        const coord = c.transform_y(0);
        try expectEqual(@as(i32, 0), coord.braille_idx);
        try expectEqual(@as(i32, 0), coord.char_idx);
        try expectEqual(@as(i32, 0), coord.dot_idx);
    }
    {
        const coord = c.transform_y(0.25);
        try expectEqual(@as(i32, 1), coord.braille_idx);
        try expectEqual(@as(i32, 0), coord.char_idx);
        try expectEqual(@as(i32, 1), coord.dot_idx);
    }
    {
        const coord = c.transform_y(0.5);
        try expectEqual(@as(i32, 2), coord.braille_idx);
        try expectEqual(@as(i32, 0), coord.char_idx);
        try expectEqual(@as(i32, 2), coord.dot_idx);
    }
    {
        const coord = c.transform_y(0.75);
        try expectEqual(@as(i32, 3), coord.braille_idx);
        try expectEqual(@as(i32, 0), coord.char_idx);
        try expectEqual(@as(i32, 3), coord.dot_idx);
    }
    {
        const coord = c.transform_y(0.99);
        try expectEqual(@as(i32, 3), coord.braille_idx);
        try expectEqual(@as(i32, 0), coord.char_idx);
        try expectEqual(@as(i32, 3), coord.dot_idx);
    }
    {
        const coord = c.transform_y(1);
        try expectEqual(@as(i32, 4), coord.braille_idx);
        try expectEqual(@as(i32, 1), coord.char_idx);
        try expectEqual(@as(i32, 0), coord.dot_idx);
    }
}

test "simple format canvas" {
    var c = try Canvas.init(std.testing.allocator, 10, 10, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    c.point(.{ .x = 0, .y = 0 }, null, null);
    c.point(.{ .x = 0, .y = 0.5 }, null, null);
    c.point(.{ .x = 0, .y = 0.99 }, null, null);
    c.point(.{ .x = 0.5, .y = 0.99 }, null, null);
    // intentionally leave right bottom blank
    // c.point(.{.x=0.99, .y=0.99}, null, null);
    c.point(.{ .x = 0.99, .y = 0.5 }, null, null);
    c.point(.{ .x = 0.99, .y = 0 }, null, null);
    c.point(.{ .x = 0.5, .y = 0 }, null, null);
    c.point(.{ .x = 0.5, .y = 0.5 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 309), list.items.len); // 3 chars per unicode + 9 linebreaks
    try expectEqualStrings(
        \\⠁⠀⠀⠀⠀⠁⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⡀⠀⠀⠀⠀⡀⠀⠀⠀⢀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⡀⠀⠀⠀⠀⡀⠀⠀⠀⢀
    , list.items);
}

test "points with chars in canvas" {
    var c = try Canvas.init(std.testing.allocator, 10, 10, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    c.point(.{ .x = 0, .y = 0 }, null, 'x');
    c.point(.{ .x = 0, .y = 0.5 }, null, 'o');
    c.point(.{ .x = 0, .y = 0.99 }, null, 'z');
    c.point(.{ .x = 0.5, .y = 0.99 }, null, 'u');
    // intentionally leave right bottom blank
    // c.point(.{.x=0.99, .y=0.99}, null, 'a');
    c.point(.{ .x = 0.99, .y = 0.5 }, null, 'c');
    c.point(.{ .x = 0.99, .y = 0 }, null, 'h');
    c.point(.{ .x = 0.5, .y = 0 }, null, 'v');
    c.point(.{ .x = 0.5, .y = 0.5 }, null, 'b');

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 293), list.items.len); // 3 chars per unicode + 9 linebreaks - 8 * 2 chars
    try expectEqualStrings(
        \\z⠀⠀⠀⠀u⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\o⠀⠀⠀⠀b⠀⠀⠀c
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\x⠀⠀⠀⠀v⠀⠀⠀h
    , list.items);
}

test "format canvas with color" {
    // force colors
    terminfo.TermInfo.testing();

    var c = try Canvas.init(std.testing.allocator, 10, 10, color.Color.by_name(.bright_yellow));
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    c.point(.{ .x = 0, .y = 0 }, color.Color.by_name(.red), null);
    c.point(.{ .x = 0, .y = 0.5 }, color.Color.by_name(.black), null);
    c.point(.{ .x = 0, .y = 0.99 }, color.Color.by_name(.black), null);
    c.point(.{ .x = 0.5, .y = 0.99 }, color.Color.by_name(.black), null);
    // intentionally leave right bottom blank
    // c.point(.{.x=0.99, .y=0.99}, color.Color.by_name(.black), null);
    c.point(.{ .x = 0.99, .y = 0.5 }, color.Color.by_name(.black), null);
    c.point(.{ .x = 0.99, .y = 0 }, color.Color.by_lookup(123), null);
    c.point(.{ .x = 0.5, .y = 0 }, color.Color.by_name(.black), null);
    c.point(.{ .x = 0.5, .y = 0.5 }, color.Color.by_name(.blue), null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 100 * (14 + 3) // 3 chars per unicode, 14 for bg and reset
    + 9 // linebreaks
    + 7 * 3 // 7 x fg color by name
    + 9), // 1 x fg color by lookup
        list.items.len);
    try expectEqualStrings("\x1b[30;103m⠁\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[30;103m⠁\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\n" ++
        "\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\n" ++
        "\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\n" ++
        "\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\n" ++
        "\x1b[30;103m⡀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[34;103m⡀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[30;103m⢀\x1b[39;49m\n" ++
        "\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\n" ++
        "\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\n" ++
        "\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\n" ++
        "\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\n" ++
        "\x1b[31;103m⡀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[30;103m⡀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[103m⠀\x1b[39;49m\x1b[38;5;123;103m⢀\x1b[39;49m", list.items);
}

test "fill char in canvas" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    c.fillChar(.{ .x = 0.5, .y = 0.5 });

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠀⣿⠀
        \\⠀⠀⠀
    , list.items);
}

test "line in canvas" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.line(.{ .x = 0, .y = 0 }, .{ .x = 0.99, .y = 0.99 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⡜
        \\⠀⡜⠀
        \\⡜⠀⠀
    , list.items);
}

test "line in canvas with chars" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.line(.{ .x = 0, .y = 0 }, .{ .x = 0.99, .y = 0.99 }, null, 'X');

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 25), list.items.len); // 3 chars per unicode, 2 linebreaks, - 4 unicode u8

    try expectEqualStrings(
        \\⠀⠀X
        \\⠀⡜⠀
        \\X⠀⠀
    , list.items);
}

test "line in one point in canvas" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.line(.{ .x = 0.5, .y = 0.5 }, .{ .x = 0.6, .y = 0.55 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠀⠐⠀
        \\⠀⠀⠀
    , list.items);
}

test "point out of canvas" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    c.point(.{ .x = -1, .y = -1 }, null, null);
    c.point(.{ .x = 2, .y = 2 }, null, null);
    c.point(.{ .x = 0.5, .y = 2 }, null, null);
    c.point(.{ .x = 0.5, .y = -1 }, null, null);
    c.point(.{ .x = 2, .y = 0.5 }, null, null);
    c.point(.{ .x = -1, .y = 0.5 }, null, null);
    c.point(.{ .x = -0.2, .y = -0.2 }, null, null);
    c.point(.{ .x = -0.1, .y = -0.02 }, null, null);
    c.point(.{ .x = 1, .y = 1 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠀⠀⠀
        \\⠀⠀⠀
    , list.items);
}

test "horizontal line out of canvas" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.line(.{ .x = -0.99, .y = 0.5 }, .{ .x = 2, .y = 0.5 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠒⠒⠒
        \\⠀⠀⠀
    , list.items);
}

test "vertical line out of canvas" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.line(.{ .x = 0.5, .y = -0.99 }, .{ .x = 0.5, .y = 2 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⢸⠀
        \\⠀⢸⠀
        \\⠀⢸⠀
    , list.items);
}

test "line out of canvas reversed" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.line(.{ .x = 2, .y = 0.5 }, .{ .x = -0.99, .y = 0.5 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠒⠒⠒
        \\⠀⠀⠀
    , list.items);
}

test "vertical line out of canvas reversed" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.line(.{ .x = 0.5, .y = 2 }, .{ .x = 0.5, .y = -0.99 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⢸⠀
        \\⠀⢸⠀
        \\⠀⢸⠀
    , list.items);
}

test "line in canvas small y" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.line(.{ .x = 0.5, .y = 0.5 }, .{ .x = 0.7, .y = 0.55 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠀⠐⠂
        \\⠀⠀⠀
    , list.items);
}

test "line in canvas small x" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.line(.{ .x = 0.5, .y = 0.5 }, .{ .x = 0.55, .y = 0.6 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠀⠘⠀
        \\⠀⠀⠀
    , list.items);
}

test "line completly out of canvas" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.line(.{ .x = -0.5, .y = -0.99 }, .{ .x = -0.6, .y = 2 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠀⠀⠀
        \\⠀⠀⠀
    , list.items);
}

test "line flat out of canvas" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.line(.{ .x = -3, .y = -1 }, .{ .x = 3, .y = 1 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠀⠀⠀
        \\⡠⠔⠉
    , list.items);
}

test "line vertical outside canvas" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.line(.{ .x = -0.2, .y = -0.2 }, .{ .x = -0.2, .y = 1.2 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠀⠀⠀
        \\⠀⠀⠀
    , list.items);
}

test "simple rect in canvas" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.rect(.{ .x = 0.2, .y = 0.2 }, .{ .x = 0.7, .y = 0.7 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⢀⣀⡀
        \\⢸⠀⡇
        \\⠘⠒⠃
    , list.items);
}

test "simple rect in canvas with chars" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.rect(.{ .x = 0.2, .y = 0.2 }, .{ .x = 0.7, .y = 0.7 }, null, 'O');

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 21), list.items.len); // 3 chars per unicode, 2 linebreaks - 8 unicode u8

    try expectEqualStrings(
        \\O⣀O
        \\⢸⠀⡇
        \\O⠒O
    , list.items);
}

test "rect through canvas horizontally" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.rect(.{ .x = -0.2, .y = 0.2 }, .{ .x = 1.2, .y = 0.8 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠤⠤⠤
        \\⠀⠀⠀
        \\⠒⠒⠒
    , list.items);
}

test "rect through canvas vertically" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.rect(.{ .x = 0.2, .y = -0.2 }, .{ .x = 0.8, .y = 1.2 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⢸⠀⡇
        \\⢸⠀⡇
        \\⢸⠀⡇
    , list.items);
}

test "rect outside canvas" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.rect(.{ .x = -0.2, .y = -0.2 }, .{ .x = 1.2, .y = 1.2 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠀⠀⠀
        \\⠀⠀⠀
    , list.items);
}

test "rect in large Canvas" {
    var c = try Canvas.init(std.testing.allocator, 255, 255, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    try c.rect(.{ .x = -0.2, .y = -0.2 }, .{ .x = 1.2, .y = 1.2 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 195329), list.items.len); // 3 chars per unicode, 2 linebreaks
}

test "text inside canvas" {
    var c = try Canvas.init(std.testing.allocator, 10, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    c.text(.{ .x = 0.1, .y = 0.5 }, "Hello", null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 82), list.items.len); // 3 chars per unicode, 2 linebreaks, -10 unicode u8
    try expectEqualStrings(
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀Hello⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
    , list.items);
}

test "text inside canvas too large" {
    var c = try Canvas.init(std.testing.allocator, 10, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    c.text(.{ .x = 0.1, .y = 0.5 }, "Hello World, how are you?", null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 74), list.items.len); // 3 chars per unicode, 2 linebreaks, -18 unicode u8
    try expectEqualStrings(
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀Hello Wor
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
    , list.items);
}

test "text inside canvas move out left" {
    var c = try Canvas.init(std.testing.allocator, 10, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    // 5 chars back
    c.text(.{ .x = -0.5, .y = 0.5 }, "Hello World, how are you?", null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 72), list.items.len); // 3 chars per unicode, 2 linebreaks, -20 unicode u8
    try expectEqualStrings(
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\ World, ho
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
    , list.items);
}

test "text below canvas" {
    var c = try Canvas.init(std.testing.allocator, 10, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    // 5 chars back
    c.text(.{ .x = 0.1, .y = -0.5 }, "Hello", null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 92), list.items.len); // 3 chars per unicode, 2 linebreaks
    try expectEqualStrings(
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
    , list.items);
}

test "text above canvas" {
    var c = try Canvas.init(std.testing.allocator, 10, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    // 5 chars back
    c.text(.{ .x = 0.1, .y = 1.5 }, "Hello", null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 92), list.items.len); // 3 chars per unicode, 2 linebreaks
    try expectEqualStrings(
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
        \\⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
    , list.items);
}

test "points with very large coordinates" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    c.point(.{ .x = 1e200, .y = 1e200 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠀⠀⠀
        \\⠀⠀⠀
    , list.items);
}
test "points with very small coordinates" {
    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    c.point(.{ .x = -1e200, .y = -1e200 }, null, null);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠀⠀⠀
        \\⠀⠀⠀
    , list.items);
}
