const std = @import("std");
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

const color = @import("./color.zig");
const dots = @import("./dots.zig");
const terminfo = @import("./terminfo.zig");

const XCoord = struct {
    braille_idx: u9,
    char_idx: u8,
    dot_idx: u1,
};
const YCoord = struct {
    braille_idx: u10,
    char_idx: u8,
    dot_idx: u2,
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
            .canvas = try allocator.alloc(dots.Dots, width * height),
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
        self.x_delta_pt = std.math.absFloat((xmax - xmin) / @intToFloat(f64, self.width * 2)); // 2 points in left
        self.y_delta_pt = std.math.absFloat((ymax - ymin) / @intToFloat(f64, self.height * 4)); // 4 points in up
    }

    /// Transform an x-coordinate of the reference system to an index
    /// of a braille point and char index.
    /// As we have a width defined as u8, and 2 points per character
    /// we are in the range of u9.
    fn transform_x(self: Canvas, x: f64) XCoord {
        const braille_idx = @floatToInt(u9, (x - self.xmin) / self.x_delta_pt);
        return XCoord{
            .braille_idx = braille_idx,
            .char_idx = @truncate(u8, braille_idx >> 1), // / 2
            .dot_idx = @truncate(u1, braille_idx), // % 2
        };
    }

    /// Transform an y-coordinate of the reference system to an index
    /// of a braille point and char index.
    /// As we have a height defined as u8, and 4 points per character
    /// we are in the range of u0.
    fn transform_y(self: Canvas, y: f64) YCoord {
        const braille_idx = @floatToInt(u10, (y - self.ymin) / self.y_delta_pt);
        return YCoord{
            .braille_idx = braille_idx,
            .char_idx = @truncate(u8, braille_idx >> 2), // / 4
            .dot_idx = @truncate(u2, braille_idx), // % 4
        };
    }

    pub fn point(self: *Canvas, x: f64, y: f64, fg_color: ?color.Color) void {
        const x_coord = self.transform_x(x);
        const y_coord = self.transform_y(y);

        if (x_coord.char_idx < 0 or x_coord.char_idx >= self.width or y_coord.char_idx < 0 or y_coord.char_idx >= self.height) {
            // out of canvas
            return;
        }
        const idx = y_coord.char_idx * self.width + x_coord.char_idx;
        self.canvas[idx].set(x_coord.dot_idx, y_coord.dot_idx);
        if (fg_color) |c| {
            self.canvas[idx].color.fg = c;
        }
    }

    pub fn fillChar(self: *Canvas, x: f64, y: f64) void {
        const x_coord = self.transform_x(x);
        const y_coord = self.transform_y(y);

        if (x_coord.char_idx < 0 or x_coord.char_idx >= self.width or y_coord.char_idx < 0 or y_coord.char_idx >= self.height) {
            // out of canvas
            return;
        }
        const idx = y_coord.char_idx * self.width + x_coord.char_idx;
        self.canvas[idx].fill();
    }

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
            var w_idx: u9 = 0;
            while (w_idx < self.width) : (w_idx += 1) {
                const idx: usize = @intCast(usize, h_idx * self.width) + w_idx;
                var d = self.canvas[idx];
                d.color.bg = self.bg;
                try writer.print("{}", .{d});
            }
            if (h_idx > 0) {
                try writer.writeAll("\n");
            }
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

test "compute x-coordinates of braille points" {
    const c = try Canvas.init(std.testing.allocator, 1, 1, color.Color.by_name(.blue));
    defer c.deinit(std.testing.allocator);

    {
        const coord = c.transform_x(0);
        try expectEqual(@as(usize, 0), coord.braille_idx);
        try expectEqual(@as(usize, 0), coord.char_idx);
        try expectEqual(@as(usize, 0), coord.dot_idx);
    }
    {
        const coord = c.transform_x(0.24);
        try expectEqual(@as(usize, 0), coord.braille_idx);
        try expectEqual(@as(usize, 0), coord.char_idx);
        try expectEqual(@as(usize, 0), coord.dot_idx);
    }
    {
        const coord = c.transform_x(0.25);
        try expectEqual(@as(usize, 0), coord.braille_idx);
        try expectEqual(@as(usize, 0), coord.char_idx);
        try expectEqual(@as(usize, 0), coord.dot_idx);
    }
    {
        const coord = c.transform_x(0.49);
        try expectEqual(@as(usize, 0), coord.braille_idx);
        try expectEqual(@as(usize, 0), coord.char_idx);
        try expectEqual(@as(usize, 0), coord.dot_idx);
    }
    {
        const coord = c.transform_x(0.5);
        try expectEqual(@as(usize, 1), coord.braille_idx);
        try expectEqual(@as(usize, 0), coord.char_idx);
        try expectEqual(@as(usize, 1), coord.dot_idx);
    }
    {
        const coord = c.transform_x(0.75);
        try expectEqual(@as(usize, 1), coord.braille_idx);
        try expectEqual(@as(usize, 0), coord.char_idx);
        try expectEqual(@as(usize, 1), coord.dot_idx);
    }
    {
        const coord = c.transform_x(0.99);
        try expectEqual(@as(usize, 1), coord.braille_idx);
        try expectEqual(@as(usize, 0), coord.char_idx);
        try expectEqual(@as(usize, 1), coord.dot_idx);
    }
    {
        const coord = c.transform_x(1);
        try expectEqual(@as(usize, 2), coord.braille_idx);
        try expectEqual(@as(usize, 1), coord.char_idx);
        try expectEqual(@as(usize, 0), coord.dot_idx);
    }
}

test "compute y-coordinates of braille points" {
    const c = try Canvas.init(std.testing.allocator, 1, 1, color.Color.by_name(.blue));
    defer c.deinit(std.testing.allocator);

    {
        const coord = c.transform_y(0);
        try expectEqual(@as(usize, 0), coord.braille_idx);
        try expectEqual(@as(usize, 0), coord.char_idx);
        try expectEqual(@as(usize, 0), coord.dot_idx);
    }
    {
        const coord = c.transform_y(0.25);
        try expectEqual(@as(usize, 1), coord.braille_idx);
        try expectEqual(@as(usize, 0), coord.char_idx);
        try expectEqual(@as(usize, 1), coord.dot_idx);
    }
    {
        const coord = c.transform_y(0.5);
        try expectEqual(@as(usize, 2), coord.braille_idx);
        try expectEqual(@as(usize, 0), coord.char_idx);
        try expectEqual(@as(usize, 2), coord.dot_idx);
    }
    {
        const coord = c.transform_y(0.75);
        try expectEqual(@as(usize, 3), coord.braille_idx);
        try expectEqual(@as(usize, 0), coord.char_idx);
        try expectEqual(@as(usize, 3), coord.dot_idx);
    }
    {
        const coord = c.transform_y(0.99);
        try expectEqual(@as(usize, 3), coord.braille_idx);
        try expectEqual(@as(usize, 0), coord.char_idx);
        try expectEqual(@as(usize, 3), coord.dot_idx);
    }
    {
        const coord = c.transform_y(1);
        try expectEqual(@as(usize, 4), coord.braille_idx);
        try expectEqual(@as(usize, 1), coord.char_idx);
        try expectEqual(@as(usize, 0), coord.dot_idx);
    }
}

test "simple format canvas" {
    var c = try Canvas.init(std.testing.allocator, 10, 10, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    c.point(0, 0, null);
    c.point(0, 0.5, null);
    c.point(0, 0.99, null);
    c.point(0.5, 0.99, null);
    // intentionally leave right bottom blank
    // c.point(0.99, 0.99, null);
    c.point(0.99, 0.5, null);
    c.point(0.99, 0, null);
    c.point(0.5, 0, null);
    c.point(0.5, 0.5, null);

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

test "format canvas with color" {
    // force colors
    terminfo.TermInfo.testing();

    var c = try Canvas.init(std.testing.allocator, 10, 10, color.Color.by_name(.bright_yellow));
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    c.point(0, 0, color.Color.by_name(.red));
    c.point(0, 0.5, color.Color.by_name(.black));
    c.point(0, 0.99, color.Color.by_name(.black));
    c.point(0.5, 0.99, color.Color.by_name(.black));
    // intentionally leave right bottom blank
    // c.point(0.99, 0.99, color.Color.by_name(.black));
    c.point(0.99, 0.5, color.Color.by_name(.black));
    c.point(0.99, 0, color.Color.by_lookup(123));
    c.point(0.5, 0, color.Color.by_name(.black));
    c.point(0.5, 0.5, color.Color.by_name(.blue));

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
    // force colors
    terminfo.TermInfo.testing();

    var c = try Canvas.init(std.testing.allocator, 3, 3, color.Color.no_color());
    defer c.deinit(std.testing.allocator);

    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();

    c.fillChar(0.5, 0.5);

    try list.writer().print("{}", .{c});
    try expectEqual(@as(usize, 29), list.items.len); // 3 chars per unicode, 2 linebreaks

    try expectEqualStrings(
        \\⠀⠀⠀
        \\⠀⣿⠀
        \\⠀⠀⠀
    , list.items);
}
