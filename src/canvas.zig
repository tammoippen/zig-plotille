const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

const color = @import("./color.zig");
const dots = @import("./dots.zig");

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
    /// of a braille point.
    /// As we have a width defined as u8, and 2 points per character
    /// we are in the range of u9.
    fn transform_x(self: Canvas, x: f64) u9 {
        return @floatToInt(u9, (x - self.xmin) / self.x_delta_pt);
    }

    /// Transform an y-coordinate of the reference system to an index
    /// of a braille point.
    /// As we have a height defined as u8, and 4 points per character
    /// we are in the range of u0.
    fn transform_y(self: Canvas, y: f64) u10 {
        return @floatToInt(u10, (y - self.ymin) / self.y_delta_pt);
    }
};

test "init and deinit Canvas" {
    const c = try Canvas.init(std.testing.allocator, 10, 10, color.Color.by_name(.blue));
    defer c.deinit(std.testing.allocator);

    try expect(c.xmin == 0);
    try expect(c.ymin == 0);
    try expect(c.x_delta_pt == 0.05);
    try expect(c.xmax == 1);
    try expect(c.ymax == 1);
    try expect(c.y_delta_pt == 0.025);
}

test "compute coordinates of braille points" {
    const c = try Canvas.init(std.testing.allocator, 1, 1, color.Color.by_name(.blue));
    defer c.deinit(std.testing.allocator);

    try expect(c.transform_x(0) == 0);
    try expect(c.transform_x(0.24) == 0);
    try expect(c.transform_x(0.25) == 0);
    try expect(c.transform_x(0.49) == 0);
    try expect(c.transform_x(0.5) == 1);
    try expect(c.transform_x(0.75) == 1);
    try expect(c.transform_x(0.99) == 1);
    try expect(c.transform_x(1) == 2);

    try expect(c.transform_y(0) == 0);
    try expect(c.transform_y(0.25) == 1);
    try expect(c.transform_y(0.5) == 2);
    try expect(c.transform_y(0.75) == 3);
    try expect(c.transform_y(0.99) == 3);
    try expect(c.transform_y(1) == 4);
}
