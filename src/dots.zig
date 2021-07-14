const std = @import("std");
const assert = std.debug.assert;
const unicode = std.unicode;

const testing = std.testing;
const expect = testing.expect;
const mem = std.mem;

const color = @import("./color.zig");

// Dot ordering: \u2800 '⠀' - \u28FF '⣿' Coding according to ISO/TR 11548-1
//
// Hence, each dot on or off is 8bit, i.e. 256 posibilities. With dot number
// one being the msb and 8 is lsb:
//
//   idx:  0 1 2 3 4 5 6 7
//   bits: 0 0 0 0 0 0 0 0
//
//   Ordering of dots:
//
//   0  3
//   1  4
//   2  5
//   6  7

const xy2dot = [_][2]u8{
    [_]u8{ 1 << 6, 1 << 7 },
    [_]u8{ 1 << 2, 1 << 5 },
    [_]u8{ 1 << 1, 1 << 4 },
    [_]u8{ 1 << 0, 1 << 3 },
};

pub const Dots = extern struct {
    dots: u8,
    // color: ?color.Color,

    pub fn init() Dots {
        return Dots{
            .dots = 0,
            // .fg_color = null,
            // .bg_color = null,
        };
    }

    pub fn str(self: Dots, buf: []u8) u3 {
        assert(buf.len >= 3);
        var local_buffer: [3]u8 = undefined;
        var v: u21 = 0x2800;
        v += self.dots;
        const len = unicode.utf8Encode(v, &local_buffer) catch unreachable;
        // if (self.color) (
        //     color.color(local_buffer, buff, )
        // )
        mem.copy(u8, buf, &local_buffer);
        return len;
    }

    pub fn fill(self: *Dots) void {
        self.dots = 0xff;
    }

    pub fn clear(self: *Dots) void {
        self.dots = 0;
    }

    pub fn set(self: *Dots, x: u8, y: u8) void {
        self.dots |= xy2dot[y][x];
    }

    pub fn unset(self: *Dots, x: u8, y: u8) void {
        self.dots &= ~xy2dot[y][x];
    }
};

test "test clear and full char" {
    var d = Dots.init();
    var buff: [20]u8 = undefined;

    var len = d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));

    d.fill();
    len = d.str(&buff);
    try expect(mem.eql(u8, "⣿", buff[0..len]));

    d.clear();
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));
}

test "set and unset individual vals" {
    var buff: [20]u8 = undefined;
    var d = Dots.init();

    var len = d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));

    d.set(0, 0);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⡀", buff[0..len]));
    d.unset(0, 0);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));

    d.set(0, 1);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠄", buff[0..len]));
    d.unset(0, 1);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));

    d.set(0, 2);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠂", buff[0..len]));
    d.unset(0, 2);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));

    d.set(0, 3);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠁", buff[0..len]));
    d.unset(0, 3);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));

    d.set(1, 0);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⢀", buff[0..len]));
    d.unset(1, 0);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));

    d.set(1, 1);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠠", buff[0..len]));
    d.unset(1, 1);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));

    d.set(1, 2);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠐", buff[0..len]));
    d.unset(1, 2);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));

    d.set(1, 3);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠈", buff[0..len]));
    d.unset(1, 3);
    len = d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));
}

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
