const std = @import("std");
const color = @import("./color.zig");
const dots = @import("./dots.zig");

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

export fn color_by_name(name: c_uint) color.Color {
    return color.Color.by_name(@intToEnum(color.ColorName, name));
}
