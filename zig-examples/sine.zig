const std = @import("std");

const plt = @import("plotille");

const pi = 3.141592653589793;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // detect terminal information
    try plt.terminfo.TermInfo.detect(allocator);

    const writer = std.io.getStdOut().writer();

    var fig = try plt.figure.Figure.init(allocator, 60, 20, null);
    defer fig.deinit();

    // Configure the plot
    fig.xmin = 0;
    fig.xmax = 10;
    fig.ymin = -2;
    fig.ymax = 2;

    // Generate sine wave data
    var x_data: [100]f64 = undefined;
    var y_data: [100]f64 = undefined;
    for (0..100) |i| {
        x_data[i] = @as(f64, @floatFromInt(i)) * 10.0 / 99.0;
        y_data[i] = @sin(x_data[i]);
    }

    // Add plots
    try fig.plot(&x_data, &y_data, .{ .lc = plt.color.Color.by_name(.blue), .label = "sin(x)" });

    // Add scatter points
    const points_x = [_]f64{ 1, 3, 5, 7, 9 };
    const points_y = [_]f64{ 0.8, -0.5, 0.2, -0.9, 0.1 };
    try fig.scatter(&points_x, &points_y, .{ .lc = plt.color.Color.by_name(.red), .label = "data", .marker = 'o' });

    // Add annotations
    try fig.text(5, 1.5, "Peak", plt.color.Color.by_name(.green));
    try fig.axhline(0.8, .{ .lc = plt.color.Color.by_name(.yellow) });

    try fig.prepare();
    try writer.print("{}\n", .{fig});
}
