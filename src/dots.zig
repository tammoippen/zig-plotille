const std = @import("std");
const assert = std.debug.assert;
const unicode = std.unicode;

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

const xy2dot = [4][2]u3{
    [2]u3{ 6, 7 },
    [2]u3{ 2, 5 },
    [2]u3{ 1, 4 },
    [2]u3{ 0, 3 },
};

const Dots = struct {
    dots: u8,

    pub fn init() Dots {
        return Dots{
            .dots = 0,
        };
    }

    pub fn str(self: Dots, buf: []u8) !u3 {
        assert(buf.len >= 3);
        var v: u21 = 0x2800;
        v += self.dots;
        return try unicode.utf8Encode(v, buf);
    }

    pub fn fill(self: *Dots) void {
        self.dots = 0xff;
    }

    pub fn clear(self: *Dots) void {
        self.dots = 0;
    }

    pub fn set(self: *Dots, x: u8, y: u8) void {
        const one: u8 = 1;
        self.dots |= one << xy2dot[y][x];
    }
};

const testing = std.testing;
const expect = testing.expect;
const mem = std.mem;

test "test clear and full char" {
    var d = Dots.init();
    var buff: [20]u8 = undefined;

    var len = try d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));

    d.fill();
    len = try d.str(&buff);
    try expect(mem.eql(u8, "⣿", buff[0..len]));

    d.clear();
    len = try d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));
}

test "set individual vals" {
    var buff: [20]u8 = undefined;
    var d = Dots.init();

    var len = try d.str(&buff);
    try expect(mem.eql(u8, "⠀", buff[0..len]));

    d.set(0, 0);
    len = try d.str(&buff);
    try expect(mem.eql(u8, "⡀", buff[0..len]));

    d.clear();
    d.set(0, 1);
    len = try d.str(&buff);
    try expect(mem.eql(u8, "⠄", buff[0..len]));

    d.clear();
    d.set(0, 2);
    len = try d.str(&buff);
    try expect(mem.eql(u8, "⠂", buff[0..len]));

    d.clear();
    d.set(0, 3);
    len = try d.str(&buff);
    try expect(mem.eql(u8, "⠁", buff[0..len]));

    d.clear();
    d.set(1, 0);
    len = try d.str(&buff);
    try expect(mem.eql(u8, "⢀", buff[0..len]));

    d.clear();
    d.set(1, 1);
    len = try d.str(&buff);
    try expect(mem.eql(u8, "⠠", buff[0..len]));

    d.clear();
    d.set(1, 2);
    len = try d.str(&buff);
    try expect(mem.eql(u8, "⠐", buff[0..len]));

    d.clear();
    d.set(1, 3);
    len = try d.str(&buff);
    try expect(mem.eql(u8, "⠈", buff[0..len]));
}
