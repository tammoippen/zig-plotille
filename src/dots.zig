const std = @import("std");
const assert = std.debug.assert;
const unicode = std.unicode;

const testing = std.testing;
const expectEqual = testing.expectEqual;
const expectEqualStrings = testing.expectEqualStrings;
const mem = std.mem;

const color = @import("./color.zig");
const terminfo = @import("./terminfo.zig");

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

const MIN_BUFF_LEN_COLOR_DOTS = 3 // utf8 braille dots
    + 2 * 16 // rgb uses most chars, e.g. 38;2;123;123;123
    + 3 // ansi-code start marker ESC[ .. m
    + 8; // ansi-code end marker ESC[39;49m

pub const Dots = extern struct {
    dots: u8 = 0,
    char: u8 = 0,
    color: color.ColorOptions = .{},

    pub fn format(
        self: Dots,
        writer: anytype,
    ) !void {
        var buff: [3]u8 = undefined;
        var v: u21 = 0x2800;
        v += self.dots;
        const len = unicode.utf8Encode(v, &buff) catch unreachable;
        assert(len == 3);

        if (self.color.hasColor()) {
            if (self.char == 0) {
                try color.colorPrint(writer, "{s}", .{buff}, self.color);
            } else {
                try color.colorPrint(writer, "{c}", .{self.char}, self.color);
            }
        } else if (self.char == 0) {
            try writer.print("{s}", .{buff});
        } else {
            try writer.print("{c}", .{self.char});
        }
    }

    pub fn fill(self: *Dots) void {
        self.dots = 0xff;
    }

    pub fn clear(self: *Dots) void {
        self.dots = 0;
        self.char = 0;
    }

    pub fn set(self: *Dots, x: u8, y: u8) void {
        self.dots |= xy2dot[y][x];
    }

    pub fn unset(self: *Dots, x: u8, y: u8) void {
        self.dots &= ~xy2dot[y][x];
    }
};

test "test clear and full char" {
    var buff: [100]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buff);

    var d = Dots{};

    try w.print("{f}", .{d});
    try expectEqualStrings("⠀", w.buffered());
    w.end = 0;

    d.fill();
    try w.print("{f}", .{d});
    try expectEqualStrings("⣿", w.buffered());
    w.end = 0;

    d.clear();
    try w.print("{f}", .{d});
    try expectEqualStrings("⠀", w.buffered());
    w.end = 0;
}

test "set and unset individual vals" {
    var buff: [100]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buff);

    var d = Dots{};

    try w.print("{f}", .{d});
    try expectEqualStrings("⠀", w.buffered());
    w.end = 0;

    d.set(0, 0);
    try w.print("{f}", .{d});
    try expectEqualStrings("⡀", w.buffered());
    w.end = 0;
    d.unset(0, 0);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠀", w.buffered());
    w.end = 0;

    d.set(0, 1);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠄", w.buffered());
    w.end = 0;
    d.unset(0, 1);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠀", w.buffered());
    w.end = 0;

    d.set(0, 2);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠂", w.buffered());
    w.end = 0;
    d.unset(0, 2);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠀", w.buffered());
    w.end = 0;

    d.set(0, 3);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠁", w.buffered());
    w.end = 0;
    d.unset(0, 3);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠀", w.buffered());
    w.end = 0;

    d.set(1, 0);
    try w.print("{f}", .{d});
    try expectEqualStrings("⢀", w.buffered());
    w.end = 0;
    d.unset(1, 0);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠀", w.buffered());
    w.end = 0;

    d.set(1, 1);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠠", w.buffered());
    w.end = 0;
    d.unset(1, 1);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠀", w.buffered());
    w.end = 0;

    d.set(1, 2);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠐", w.buffered());
    w.end = 0;
    d.unset(1, 2);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠀", w.buffered());
    w.end = 0;

    d.set(1, 3);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠈", w.buffered());
    w.end = 0;
    d.unset(1, 3);
    try w.print("{f}", .{d});
    try expectEqualStrings("⠀", w.buffered());
    w.end = 0;
}

test "colored dots" {
    terminfo.TermInfo.testing();
    var buff: [100]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buff);

    var d = Dots{};
    d.set(0, 0);

    try w.print("{f}", .{d});
    try expectEqualStrings("⡀", w.buffered());
    w.end = 0;

    d.color.fg = color.Color.by_name(.red);
    try w.print("{f}", .{d});
    try expectEqual(w.end, 16);
    try expectEqualStrings("\x1b[31m⡀\x1b[39;49m", w.buffered());
    w.end = 0;

    d.color.bg = color.Color.by_lookup(123);
    try w.print("{f}", .{d});
    try expectEqual(w.end, 25);
    try expectEqualStrings("\x1b[31;48;5;123m⡀\x1b[39;49m", w.buffered());
    w.end = 0;

    d.color.fg = color.Color.by_rgb(1, 22, 133);
    try w.print("{f}", .{d});
    try expectEqual(w.end, 36);
    try expectEqualStrings("\x1b[38;2;1;22;133;48;5;123m⡀\x1b[39;49m", w.buffered());
    w.end = 0;
}

test "set / unset char" {
    var buff: [100]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buff);

    var d = Dots{};
    d.char = 'x';

    try w.print("{f}", .{d});
    try expectEqualStrings("x", w.buffered());
    w.end = 0;

    d.clear();
    try w.print("{f}", .{d});
    try expectEqualStrings("⠀", w.buffered());
    w.end = 0;
}

test "color char" {
    terminfo.TermInfo.testing();
    var buff: [100]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buff);

    var d = Dots{};
    d.char = 'x';
    d.color.fg = color.Color.by_rgb(111, 222, 255);

    try w.print("{f}", .{d});
    try expectEqualStrings("\x1b[38;2;111;222;255mx\x1b[39;49m", w.buffered());
    w.end = 0;
}

test "set char and dots" {
    var buff: [100]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buff);

    var d = Dots{};
    d.char = 'x';

    try w.print("{f}", .{d});
    try expectEqualStrings("x", w.buffered());
    w.end = 0;

    d.set(0, 1);
    try w.print("{f}", .{d});
    try expectEqualStrings("x", w.buffered());
    w.end = 0;

    d.char = 0;
    try w.print("{f}", .{d});
    try expectEqualStrings("⠄", w.buffered());
    w.end = 0;

    d.char = 'o';
    try w.print("{f}", .{d});
    try expectEqualStrings("o", w.buffered());
    w.end = 0;
}
