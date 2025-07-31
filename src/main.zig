const std = @import("std");

pub const color = @import("./color.zig");
pub const dots = @import("./dots.zig");
pub const terminfo = @import("./terminfo.zig");
pub const canvas = @import("./canvas.zig");
pub const hist = @import("./hist.zig");
pub const figure = @import("./figure.zig");

comptime {
    _ = color;
    _ = dots;
    _ = terminfo;
    _ = canvas;
    _ = hist;
    _ = figure;
}
