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
    color: color.ColorOptions = .{},

    pub fn format(
        self: Dots,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        // ignored options -> conform to signature
        _ = options;
        _ = fmt;

        var buff: [3]u8 = undefined;
        var v: u21 = 0x2800;
        v += self.dots;
        var len = unicode.utf8Encode(v, &buff) catch unreachable;
        assert(len == 3);

        if (self.color.hasColor()) {
            try color.colorPrint(writer, "{s}", .{buff}, self.color);
        } else {
            try writer.print("{s}", .{buff});
            // try writer.writeAll(" ");
        }
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
    var buff: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buff);

    var d = Dots{};

    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠀", fbs.getWritten());
    fbs.reset();

    d.fill();
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⣿", fbs.getWritten());
    fbs.reset();

    d.clear();
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠀", fbs.getWritten());
    fbs.reset();
}

test "set and unset individual vals" {
    var buff: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buff);

    var d = Dots{};

    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠀", fbs.getWritten());
    fbs.reset();

    d.set(0, 0);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⡀", fbs.getWritten());
    fbs.reset();
    d.unset(0, 0);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠀", fbs.getWritten());
    fbs.reset();

    d.set(0, 1);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠄", fbs.getWritten());
    fbs.reset();
    d.unset(0, 1);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠀", fbs.getWritten());
    fbs.reset();

    d.set(0, 2);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠂", fbs.getWritten());
    fbs.reset();
    d.unset(0, 2);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠀", fbs.getWritten());
    fbs.reset();

    d.set(0, 3);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠁", fbs.getWritten());
    fbs.reset();
    d.unset(0, 3);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠀", fbs.getWritten());
    fbs.reset();

    d.set(1, 0);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⢀", fbs.getWritten());
    fbs.reset();
    d.unset(1, 0);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠀", fbs.getWritten());
    fbs.reset();

    d.set(1, 1);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠠", fbs.getWritten());
    fbs.reset();
    d.unset(1, 1);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠀", fbs.getWritten());
    fbs.reset();

    d.set(1, 2);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠐", fbs.getWritten());
    fbs.reset();
    d.unset(1, 2);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠀", fbs.getWritten());
    fbs.reset();

    d.set(1, 3);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠈", fbs.getWritten());
    fbs.reset();
    d.unset(1, 3);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⠀", fbs.getWritten());
    fbs.reset();
}

test "colored dots" {
    terminfo.TermInfo.testing();
    var buff: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buff);

    var d = Dots{};
    d.set(0, 0);

    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqualStrings("⡀", fbs.getWritten());
    fbs.reset();

    d.color.fg = color.Color.by_name(.red);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqual(fbs.pos, 16);
    try expectEqualStrings("\x1b[31m⡀\x1b[39;49m", fbs.getWritten());
    fbs.reset();

    d.color.bg = color.Color.by_lookup(123);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqual(fbs.pos, 25);
    try expectEqualStrings("\x1b[31;48;5;123m⡀\x1b[39;49m", fbs.getWritten());
    fbs.reset();

    d.color.fg = color.Color.by_rgb(1, 22, 133);
    try std.fmt.format(fbs.writer(), "{s}", .{d});
    try expectEqual(fbs.pos, 36);
    try expectEqualStrings("\x1b[38;2;1;22;133;48;5;123m⡀\x1b[39;49m", fbs.getWritten());
    fbs.reset();
}
