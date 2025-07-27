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

// C API

// Dots

export fn dots_init() dots.Dots {
    return dots.Dots{};
}
export fn dots_str(self: dots.Dots, buf: [*]u8, len: usize) usize {
    var fbs = std.io.fixedBufferStream(buf[0..len]);
    std.fmt.format(fbs.writer(), "{s}", .{self}) catch |err| switch (err) {
        error.NoSpaceLeft => return 0,
    };
    return fbs.pos;
}
export fn dots_fill(self: *dots.Dots) void {
    return self.fill();
}
export fn dots_clear(self: *dots.Dots) void {
    return self.clear();
}
export fn dots_set(self: *dots.Dots, x: u8, y: u8) void {
    return self.set(x, y);
}
export fn dots_unset(self: *dots.Dots, x: u8, y: u8) void {
    return self.unset(x, y);
}

// Color

export fn color_no_color() color.Color {
    return color.Color.no_color();
}

export fn color_by_name(name: color.ColorName) color.Color {
    return color.Color.by_name(name);
}

export fn color_by_lookup(idx: u8) color.Color {
    return color.Color.by_lookup(idx);
}

export fn color_by_rgb(r: u8, g: u8, b: u8) color.Color {
    return color.Color.by_rgb(r, g, b);
}

export fn color_by_hsl(h: f64, s: f64, l: f64) color.Color {
    return color.Color.by_hsl(h, s, l);
}

export fn color_print(buf: [*]u8, len: usize, text: [*:0]const u8, options: color.ColorOptions) usize {
    var fbs = std.io.fixedBufferStream(buf[0..len]);
    color.colorPrint(fbs.writer(), "{s}", .{text}, options) catch |err| switch (err) {
        error.NoSpaceLeft => return 0,
    };
    fbs.writer().writeByte(0) catch |err| switch (err) {
        error.NoSpaceLeft => return 0,
    };
    return fbs.pos;
}

// terminfo

export fn get_terminfo(out: *terminfo.TermInfo) bool {
    if (terminfo.TermInfo.is_set()) {
        out.* = terminfo.TermInfo.get();
        return true;
    }
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    terminfo.TermInfo.detect(allocator) catch |err| switch (err) {
        error.Overflow => return false,
        error.OutOfMemory => return false,
        error.InvalidWtf8 => return false,
        error.InvalidCharacter => return false,
    };
    out.* = terminfo.TermInfo.get();
    return true;
}
