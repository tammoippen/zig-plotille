const std = @import("std");

// I plot upside down, hence the different order
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

    pub fn str(self: Dots, buf: []u8) ![]const u8 {
        return try std.fmt.bufPrint(buf, "0x{x:2}", .{self.dots});
    }

    pub fn fill(self: *Dots) void {
        self.dots = 0xff;
    }
    pub fn clear(self: *Dots) void {
        self.dots = 0;
    }
    pub fn set(self: *Dots, x: u8, y: u8) void {
        const one: u8 = 1;
        self.dots |= one << xy2dot[x][y];
    }
};

const testing = std.testing;
const expect = testing.expect;
const mem = std.mem;

// test "print the struct" {
//     const d = Dots.init();

//     std.debug.print("d: {}\n", .{d});
// }

test "test clear and full char" {
    var d = Dots.init();
    var buff: [20]u8 = undefined;

    var s = try d.str(&buff);
    try expect(mem.eql(u8, "0x 0", s));

    d.fill();
    s = try d.str(&buff);
    try expect(mem.eql(u8, "0xff", s));

    d.clear();
    s = try d.str(&buff);
    try expect(mem.eql(u8, "0x 0", s));
}

test "set individual vals" {
    var buff: [20]u8 = undefined;
    var d = Dots.init();

    d.set(0, 0);
    var s = try d.str(&buff);
    try expect(mem.eql(u8, "0x40", s));

    d.clear();
    d.set(0, 1);
    s = try d.str(&buff);
    try expect(mem.eql(u8, "0x80", s));

    d.clear();
    d.set(1, 0);
    s = try d.str(&buff);
    try expect(mem.eql(u8, "0x 4", s));

    d.clear();
    d.set(1, 1);
    s = try d.str(&buff);
    try expect(mem.eql(u8, "0x20", s));

    d.clear();
    d.set(2, 0);
    s = try d.str(&buff);
    try expect(mem.eql(u8, "0x 2", s));

    d.clear();
    d.set(2, 1);
    s = try d.str(&buff);
    try expect(mem.eql(u8, "0x10", s));

    d.clear();
    d.set(3, 0);
    s = try d.str(&buff);
    try expect(mem.eql(u8, "0x 1", s));

    d.clear();
    d.set(3, 1);
    s = try d.str(&buff);
    try expect(mem.eql(u8, "0x 8", s));

}
