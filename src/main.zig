// usingnamespace @import("./color.zig");
usingnamespace @import("./dots.zig");

// C API

export fn dots_init() Dots {
    return Dots.init();
}
export fn dots_str(self: Dots, buf: [*]u8, len: usize) u8 {
    return self.str(buf[0..len]);
}
export fn dots_fill(self: *Dots) void {
    return self.fill();
}
export fn dots_clear(self: *Dots) void {
    return self.clear();
}
export fn dots_set(self: *Dots, x: u8, y: u8) void {
    return self.set(x, y);
}
export fn dots_unset(self: *Dots, x: u8, y: u8) void {
    return self.unset(x, y);
}
