const std = @import("std");
const mem = std.mem;

const testing = std.testing;
const assert = std.debug.assert;
const expect = testing.expect;

const terminfo = @import("./terminfo.zig");

// Surround `text` with control characters for coloring
//
// c.f. http://en.wikipedia.org/wiki/ANSI_escape_code
//
// There are 3 color modes possible:
//     - `names`:  corresponds to 3/4 bit encoding; provide colors as lower case
//                 with underscore names, e.g. 'red', 'bright_green'
//     - `byte`: corresponds to 8-bit encoding; provide colors as int ∈ [0, 255];
//                 compare 256-color lookup table
//     - `rgb`: corresponds to 24-bit encoding; provide colors either in 3- or 6-character
//                 hex encoding or provide as a list / tuple with three ints (∈ [0, 255] each)
//
// With `fg` you can specify the foreground, i.e. text color, and with `bg` you
// specify the background color. The resulting `text` also gets the `RESET` signal
// at the end, s.t. no coloring swaps over to following text!
//
// Make sure to set the colors corresponding to the `mode`, otherwise you get
// `ValueErrors`.
//
// If you do not want a foreground or background color, leave the corresponding
// paramter `None`. If both are `None`, you get `text` directly.
//
// When you stick to mode `names` and only use the none `bright_` versions,
// the color control characters conform to ISO 6429 and the ANSI Escape sequences
//
// Color names for mode `names` are:
//     black red green yellow blue magenta cyan white     <- ISO 6429
//     bright_black bright_red bright_green bright_yellow
//     bright_blue bright_magenta bright_cyan bright_white
//
// (trying other names will raise ValueError)
// If you want to use colorama (https://pypi.python.org/pypi/colorama), you should
// also stick to the ISO 6429 colors.
//
// The environment variables `NO_COLOR` (https://no-color.org/) and `FORCE_COLOR`
// (only toggle; see https://nodejs.org/api/tty.html#tty_writestream_getcolordepth_env)
// have some influence on color output.
//
// If you do not run in a TTY, e.g. pipe to some other program or redirect output
// into a file, color codes are stripped as well.
//
// Parameters:
//     text: str        Some text to surround.
//     fg: multiple     Specify the foreground / text color.
//     bg: multiple     Specify the background color.
//     color_mode: str  Specify color input mode; 'names' (default), 'byte' or 'rgb'
//     no_color: bool   Remove color optionally. default=False
// Returns:
//     str: `text` enclosed with corresponding coloring controls

pub const ColorMode = enum(c_uint) {
    none,
    names,
    lookup,
    rgb,
};

export const ESC = '\x1b';

pub const ColorName = enum(c_uint) {
    black = 0,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    bright_black,
    bright_red,
    bright_green,
    bright_yellow,
    bright_blue,
    bright_magenta,
    bright_cyan,
    bright_white,
    bright_black_old,
    bright_red_old,
    bright_green_old,
    bright_yellow_old,
    bright_blue_old,
    bright_magenta_old,
    bright_cyan_old,
    bright_white_old,
    invalid,
};

// Foreground color codes
const FGColors = [_][]const u8{
    "30", // black
    "31", // red
    "32", // green
    "33", // yellow
    "34", // blue
    "35", // magenta
    "36", // cyan
    "37", // white
    "90", // bright_black
    "91", // bright_red
    "92", // bright_green
    "93", // bright_yellow
    "94", // bright_blue
    "95", // bright_magenta
    "96", // bright_cyan
    "97", // bright_white
    "1;30", // bright_black, old variant
    "1;31", // bright_red, old variant
    "1;32", // bright_green, old variant
    "1;33", // bright_yellow, old variant
    "1;34", // bright_blue, old variant
    "1;35", // bright_magenta, old variant
    "1;36", // bright_cyan, old variant
    "1;37", // bright_white, old variant
};

// Background color codes
const BGColors = [_][]const u8{
    "40", // black
    "41", // red
    "42", // green
    "43", // yellow
    "44", // blue
    "45", // magenta
    "46", // cyan
    "47", // white
    "100", // bright_black
    "101", // bright_red
    "102", // bright_green
    "103", // bright_yellow
    "104", // bright_blue
    "105", // bright_magenta
    "106", // bright_cyan
    "107", // bright_white
    "1;40", // bright_black, old variant
    "1;41", // bright_red, old variant
    "1;42", // bright_green, old variant
    "1;43", // bright_yellow, old variant
    "1;44", // bright_blue, old variant
    "1;45", // bright_magenta, old variant
    "1;46", // bright_cyan, old variant
    "1;47", // bright_white, old variant
};

pub const Color = extern struct {
    mode: ColorMode,
    name: ColorName,
    lookup: u8,
    rgb: [3]u8,

    pub fn no_color() Color {
        // https://en.wikipedia.org/wiki/ANSI_escape_code#3-bit_and_4-bit
        return Color{
            .mode = .none,
            .name = .invalid,
            .lookup = 0,
            .rgb = [3]u8{ 0, 0, 0 },
        };
    }
    pub fn by_name(name: ColorName) Color {
        // https://en.wikipedia.org/wiki/ANSI_escape_code#3-bit_and_4-bit
        return Color{
            .mode = .names,
            .name = name,
            .lookup = 0,
            .rgb = [3]u8{ 0, 0, 0 },
        };
    }
    pub fn by_lookup(idx: u8) Color {
        // https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
        // 0-  7:  standard colors (as in ESC [ 30–37 m)
        // 8- 15:  high intensity colors (as in ESC [ 90–97 m)
        // 16-231:  6 × 6 × 6 cube (216 colors): 16 + 36 × r + 6 × g + b (0 ≤ r, g, b ≤ 5)
        // 232-255:  grayscale from black to white in 24 steps
        return Color{
            .mode = .lookup,
            .name = .invalid,
            .lookup = idx,
            .rgb = [3]u8{ 0, 0, 0 },
        };
    }
    pub fn by_rgb(r: u8, g: u8, b: u8) Color {
        // https://en.wikipedia.org/wiki/ANSI_escape_code#24-bit
        //
        return Color{
            .mode = .rgb,
            .name = .invalid,
            .lookup = 0,
            .rgb = [_]u8{ r, g, b },
        };
    }
    pub fn by_hsl(h: f64, s: f64, l: f64) Color {
        // https://en.wikipedia.org/wiki/ANSI_escape_code#24-bit
        // converts hsl values into rgb values.
        assert(h >= 0 and h <= 360);
        assert(s >= 0 and s <= 1);
        assert(l >= 0 and l <= 1);
        var r: f64 = l;
        var g: f64 = l;
        var b: f64 = l;

        if (s > 0) {
            const q = if (l < 0.5) l * (1.0 + s) else l + s - l * s;
            const p = 2 * l - q;
            const h_ = h / 360.0;

            r = hue_to_rgb(p, q, h_ + 1.0 / 3.0);
            g = hue_to_rgb(p, q, h_);
            b = hue_to_rgb(p, q, h_ - 1.0 / 3.0);
        }

        return Color{
            .mode = .rgb,
            .name = .invalid,
            .lookup = 0,
            .rgb = [_]u8{ @floatToInt(u8, r * 255), @floatToInt(u8, g * 255), @floatToInt(u8, b * 255) },
        };
    }
    fn hue_to_rgb(p: f64, q: f64, t: f64) f64 {
        var t_ = t;
        if (t < 0) {
            t_ += 1.0;
        }
        if (t > 1) {
            t_ -= 1.0;
        }
        if (t_ < 1.0 / 6.0) {
            return p + (q - p) * 6.0 * t_;
        }
        if (t_ < 0.5) {
            return q;
        }
        if (t_ < 2.0 / 3.0) {
            return p + (q - p) * (2.0 / 3.0 - t_) * 6.0;
        }
        return p;
    }
};

pub const ColorOptions = extern struct {
    no_color: bool = false,
    reset_all: bool = false,
    fg: Color = Color.no_color(),
    bg: Color = Color.no_color(),

    pub fn hasColor(self: ColorOptions) bool {
        return self.fg.mode != .none or self.bg.mode != .none;
    }
};

test "color by name" {
    const c = Color.by_name(.bright_blue);

    try expect(c.mode == .names);
    try expect(c.name == .bright_blue);
}

test "color by index" {
    const c = Color.by_lookup(123);

    try expect(c.mode == .lookup);
    try expect(c.lookup == 123);
}

test "color by rgb" {
    const c = Color.by_rgb(255, 0, 0);

    try expect(c.mode == .rgb);
    try expect(mem.eql(u8, c.rgb[0..], ([3]u8{ 255, 0, 0 })[0..]));
}

test "color by hsl red" {
    const c = Color.by_hsl(0, 1, 0.5);

    try expect(c.mode == .rgb);
    try expect(mem.eql(u8, c.rgb[0..], ([3]u8{ 255, 0, 0 })[0..]));
}

test "color by hsl green" {
    const c = Color.by_hsl(120.0, 1.0, 0.5);

    try expect(c.mode == .rgb);
    try expect(mem.eql(u8, c.rgb[0..], ([3]u8{ 0, 255, 0 })[0..]));
}

test "color by hsl blue" {
    const c = Color.by_hsl(240.0, 1.0, 0.5);

    try expect(c.mode == .rgb);
    try expect(mem.eql(u8, c.rgb[0..], ([3]u8{ 0, 0, 255 })[0..]));
}

test "color by hsl white" {
    const c = Color.by_hsl(0, 0, 1);

    try expect(c.mode == .rgb);
    try expect(mem.eql(u8, c.rgb[0..], ([3]u8{ 255, 255, 255 })[0..]));
}

test "color by hsl black" {
    const c = Color.by_hsl(0, 0, 0);

    try expect(c.mode == .rgb);
    try expect(mem.eql(u8, c.rgb[0..], ([3]u8{ 0, 0, 0 })[0..]));
}

test "color by hsl other" {
    const c = Color.by_hsl(123, 0.8, 0.5);

    try expect(c.mode == .rgb);
    try expect(mem.eql(u8, c.rgb[0..], ([3]u8{ 25, 229, 35 })[0..]));
}

pub fn colorPrint(writer: anytype, comptime fmt: []const u8, args: anytype, options: ColorOptions) !void {
    if (!options.hasColor()) {
        try writer.print(fmt, args);
        return;
    }

    const info = terminfo.TermInfo.get();

    // no color on no_color, NO_COLOR, FORCE_COLOR=0|false|none
    if (options.no_color or info.no_color or (info.force_color != null and !info.force_color.?)) {
        try writer.print(fmt, args);
        return;
    }

    // no color on not stdout tty (except FORCE_COLOR as something valid set)
    if (!(info.stdout_interactive or (info.force_color != null and info.force_color.?))) {
        try writer.print(fmt, args);
        return;
    }

    try writer.print("{c}[", .{ESC});

    if (options.fg.mode != .none) {
        switch (options.fg.mode) {
            .names => try names(options.fg.name, true, writer),
            .lookup => try lookups(options.fg.lookup, true, writer),
            .rgb => try rgbs(options.fg.rgb, true, writer),
            .none => unreachable,
        }
    }

    if (options.bg.mode != .none) {
        if (options.fg.mode != .none) {
            try writer.writeAll(";");
        }
        switch (options.bg.mode) {
            .names => try names(options.bg.name, false, writer),
            .lookup => try lookups(options.bg.lookup, false, writer),
            .rgb => try rgbs(options.bg.rgb, false, writer),
            .none => unreachable,
        }
    }

    try writer.writeAll("m");
    try writer.print(fmt, args);
    if (options.reset_all) {
        try writer.print("{c}[0m", .{ESC});
    } else {
        try writer.print("{c}[39;49m", .{ESC});
    }
}

fn names(color_name: ColorName, is_fg: bool, writer: anytype) !void {
    if (is_fg) {
        const fg_code = FGColors[@enumToInt(color_name)];
        try writer.writeAll(fg_code);
    } else {
        const bg_code = BGColors[@enumToInt(color_name)];
        try writer.writeAll(bg_code);
    }
}

test "names with optional fg, bg" {
    var buff: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buff);

    try names(.red, true, fbs.writer());
    try expect(fbs.pos == 2);
    try expect(mem.eql(u8, "31", fbs.getWritten()));
    fbs.reset();

    try names(.red, false, fbs.writer());
    try expect(fbs.pos == 2);
    try expect(mem.eql(u8, "41", fbs.getWritten()));
    fbs.reset();

    try names(.bright_green, true, fbs.writer());
    try expect(fbs.pos == 2);
    try expect(mem.eql(u8, "92", fbs.getWritten()));
    fbs.reset();

    try names(.bright_green, false, fbs.writer());
    try expect(fbs.pos == 3);
    try expect(mem.eql(u8, "102", fbs.getWritten()));
    fbs.reset();

    try names(.bright_magenta_old, true, fbs.writer());
    try expect(fbs.pos == 4);
    try expect(mem.eql(u8, "1;35", fbs.getWritten()));
    fbs.reset();

    try names(.bright_magenta_old, false, fbs.writer());
    try expect(fbs.pos == 4);
    try expect(mem.eql(u8, "1;45", fbs.getWritten()));
    fbs.reset();
}

test "color in names mode" {
    var buff: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buff);

    try colorPrint(fbs.writer(), "Some text", .{}, .{ .fg = Color.by_name(.red) });
    try expect(fbs.pos == 22);
    try expect(mem.eql(u8, "\x1b[31mSome text\x1b[39;49m", fbs.getWritten()));
    fbs.reset();

    try colorPrint(fbs.writer(), "Some text", .{}, .{ .bg = Color.by_name(.red) });
    try expect(fbs.pos == 22);
    try expect(mem.eql(u8, "\x1b[41mSome text\x1b[39;49m", fbs.getWritten()));
    fbs.reset();

    try colorPrint(fbs.writer(), "Some text", .{}, .{ .fg = Color.by_name(.bright_magenta), .bg = Color.by_name(.red) });
    try expect(fbs.pos == 25);
    try expect(mem.eql(u8, "\x1b[95;41mSome text\x1b[39;49m", fbs.getWritten()));
    fbs.reset();
}

const FG_LOOKUP_NUM = "38;5;";
const BG_LOOKUP_NUM = "48;5;";

fn lookups(color_lookup: ?u8, is_fg: bool, writer: anytype) !void {
    if (is_fg) {
        try writer.print("{s}{}", .{ FG_LOOKUP_NUM, color_lookup });
    } else {
        try writer.print("{s}{}", .{ BG_LOOKUP_NUM, color_lookup });
    }
}

test "lookups with optional fg, bg" {
    var buff: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buff);

    try lookups(3, true, fbs.writer());
    try expect(fbs.pos == 6);
    try expect(mem.eql(u8, "38;5;3", fbs.getWritten()));
    fbs.reset();

    try lookups(25, false, fbs.writer());
    try expect(fbs.pos == 7);
    try expect(mem.eql(u8, "48;5;25", fbs.getWritten()));
    fbs.reset();

    try lookups(33, true, fbs.writer());
    try expect(fbs.pos == 7);
    try expect(mem.eql(u8, "38;5;33", fbs.getWritten()));
    fbs.reset();

    try lookups(245, false, fbs.writer());
    try expect(fbs.pos == 8);
    try expect(mem.eql(u8, "48;5;245", fbs.getWritten()));
    fbs.reset();
}

test "color in lookup mode" {
    var buff: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buff);

    try colorPrint(fbs.writer(), "Some text", .{}, .{ .fg = Color.by_lookup(44) });
    try expect(fbs.pos == 27);
    try expect(mem.eql(u8, "\x1b[38;5;44mSome text\x1b[39;49m", fbs.getWritten()));
    fbs.reset();

    try colorPrint(fbs.writer(), "Some text", .{}, .{ .bg = Color.by_lookup(5) });
    try expect(fbs.pos == 26);
    try expect(mem.eql(u8, "\x1b[48;5;5mSome text\x1b[39;49m", fbs.getWritten()));
    fbs.reset();

    try colorPrint(fbs.writer(), "Some text", .{}, .{ .fg = Color.by_lookup(123), .bg = Color.by_lookup(76) });
    try expect(fbs.pos == 36);
    try expect(mem.eql(u8, "\x1b[38;5;123;48;5;76mSome text\x1b[39;49m", fbs.getWritten()));
    fbs.reset();
}

const FG_RGB_NUM = "38;2;";
const BG_RGB_NUM = "48;2;";

fn rgbs(color_rgb: [3]u8, is_fg: bool, writer: anytype) !void {
    if (is_fg) {
        try writer.print("{s}{};{};{}", .{ FG_RGB_NUM, color_rgb[0], color_rgb[1], color_rgb[2] });
    } else {
        try writer.print("{s}{};{};{}", .{ BG_RGB_NUM, color_rgb[0], color_rgb[1], color_rgb[2] });
    }
}

test "rgbs with optional fg, bg" {
    var buff: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buff);

    var len = try rgbs([3]u8{ 255, 0, 0 }, true, fbs.writer());
    try expect(fbs.pos == 12);
    try expect(mem.eql(u8, "38;2;255;0;0", fbs.getWritten()));
    fbs.reset();

    len = try rgbs([_]u8{ 34, 25, 100 }, false, fbs.writer());
    try expect(fbs.pos == 14);
    try expect(mem.eql(u8, "48;2;34;25;100", fbs.getWritten()));
    fbs.reset();

    len = try rgbs([_]u8{ 1, 2, 3 }, true, fbs.writer());
    try expect(fbs.pos == 10);
    try expect(mem.eql(u8, "38;2;1;2;3", fbs.getWritten()));
    fbs.reset();

    len = try rgbs([_]u8{ 100, 200, 50 }, false, fbs.writer());
    try expect(fbs.pos == 15);
    try expect(mem.eql(u8, "48;2;100;200;50", fbs.getWritten()));
    fbs.reset();
}

test "color in rgb mode" {
    var buff: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buff);

    try colorPrint(fbs.writer(), "Some text", .{}, .{ .fg = Color.by_rgb(44, 22, 11) });
    try expect(fbs.pos == 33);
    try expect(mem.eql(u8, "\x1b[38;2;44;22;11mSome text\x1b[39;49m", fbs.getWritten()));
    fbs.reset();

    try colorPrint(fbs.writer(), "Some text", .{}, .{ .bg = Color.by_rgb(5, 66, 100) });
    try expect(fbs.pos == 33);
    try expect(mem.eql(u8, "\x1b[48;2;5;66;100mSome text\x1b[39;49m", fbs.getWritten()));
    fbs.reset();

    try colorPrint(fbs.writer(), "Some text", .{}, .{ .fg = Color.by_hsl(123, 0.8, 0.5), .bg = Color.by_rgb(76, 89, 9) });
    try expect(fbs.pos == 47);
    try expect(mem.eql(u8, "\x1b[38;2;25;229;35;48;2;76;89;9mSome text\x1b[39;49m", fbs.getWritten()));
    fbs.reset();
}

test "color in mixed modes" {
    var buff: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buff);

    try colorPrint(fbs.writer(), "Some text", .{}, .{ .fg = Color.by_rgb(44, 22, 11), .bg = Color.by_name(.yellow) });
    try expect(fbs.pos == 36);
    try expect(mem.eql(u8, "\x1b[38;2;44;22;11;43mSome text\x1b[39;49m", fbs.getWritten()));
    fbs.reset();

    try colorPrint(fbs.writer(), "Some text", .{}, .{ .fg = Color.by_lookup(155), .bg = Color.by_rgb(5, 66, 100) });
    try expect(fbs.pos == 42);
    try expect(mem.eql(u8, "\x1b[38;5;155;48;2;5;66;100mSome text\x1b[39;49m", fbs.getWritten()));
    fbs.reset();

    try colorPrint(fbs.writer(), "Some text", .{}, .{ .fg = Color.by_name(.bright_cyan_old), .bg = Color.by_lookup(254) });
    try expect(fbs.pos == 33);
    try expect(mem.eql(u8, "\x1b[1;36;48;5;254mSome text\x1b[39;49m", fbs.getWritten()));
    fbs.reset();
}
