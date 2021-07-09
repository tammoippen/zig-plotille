const std = @import("std");
const ascii = std.ascii;
const assert = std.debug.assert;
const mem = std.mem;

const testing = std.testing;
const expect = testing.expect;

const ColorMode = enum {
    names,
    bytes,
    rgb,
};

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
// as defined in http://ascii-table.com/ansi-escape-sequences.php.
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
pub fn color(text: []const u8, out: []u8, fg: []const u8, bg: []const u8, mode: ColorMode, no_color: bool) usize {
    if (fg.len == 0 and bg.len == 0) {
        mem.copy(u8, out, text);
        return text.len;
    }

    if (no_color) { // or os.environ.get('NO_COLOR'))
        mem.copy(u8, out, text);
        return text.len;
    }

    var idx: usize = 0;

    if (mode == ColorMode.names) {
        if (fg.len == 1 and bg.len == 1) {
            idx = names(@intToEnum(ColorName, fg[0]), @intToEnum(ColorName, bg[0]), out);
        } else if (fg.len == 1) {
            idx = names(@intToEnum(ColorName, fg[0]), null, out);
        } else if (bg.len == 1) {
            idx = names(null, @intToEnum(ColorName, bg[0]), out);
        } else {
            unreachable;
        }
    }
    mem.copy(u8, out[idx..], text);
    idx += text.len;
    out[idx] = ESC;
    out[idx + 1] = '[';
    out[idx + 2] = '0';
    out[idx + 3] = 'm';
    idx += 4;

    return idx;
}

pub fn color_names(text: []const u8, out: []u8, fg: ?ColorName, bg: ?ColorName, no_color: bool) usize {
    if (fg != null and bg != null) {
        return color(text, out, &[_]u8{@enumToInt(fg.?)}, &[_]u8{@enumToInt(bg.?)}, ColorMode.names, no_color);
    } else if (fg) |true_fg| {
        return color(text, out, &[_]u8{@enumToInt(true_fg)}, &[0]u8{}, ColorMode.names, no_color);
    } else if (bg) |true_bg| {
        return color(text, out, &[0]u8{}, &[_]u8{@enumToInt(true_bg)}, ColorMode.names, no_color);
    } else {
        unreachable;
    }
}

const ESC = ascii.control_code.ESC;
const ColorName = enum(u8) {
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
    "1;30", // bright_black
    "1;31", // bright_red
    "1;32", // bright_green
    "1;33", // bright_yellow
    "1;34", // bright_blue
    "1;35", // bright_magenta
    "1;36", // bright_cyan
    "1;37", // bright_white
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
};

fn names(optional_fg: ?ColorName, optional_bg: ?ColorName, out: []u8) usize {
    assert(optional_fg != null or optional_bg != null);

    var idx: usize = 0;
    out[idx] = ESC;
    out[idx + 1] = '[';
    idx += 2;

    if (optional_fg) |fg| {
        const fg_code = FGColors[@enumToInt(fg)];
        mem.copy(u8, out[idx..], fg_code);
        idx += fg_code.len;
    }

    if (optional_bg) |bg| {
        if (optional_fg != null) {
            out[idx] = ';';
            idx += 1;
        }
        const bg_code = BGColors[@enumToInt(bg)];
        mem.copy(u8, out[idx..], bg_code);
        idx += bg_code.len;
    }

    out[idx] = 'm';
    idx += 1;
    return idx;
}

test "names with optional fg, bg" {
    var buff: [10]u8 = undefined;

    var len = names(ColorName.red, null, &buff);
    try expect(len == 5);
    try expect(mem.eql(u8, "\x1b[31m", buff[0..len]));

    len = names(null, ColorName.red, &buff);
    try expect(len == 5);
    try expect(mem.eql(u8, "\x1b[41m", buff[0..len]));

    len = names(ColorName.bright_green, ColorName.red, &buff);
    try expect(len == 10);
    try expect(mem.eql(u8, "\x1b[1;32;41m", buff[0..len]));
}

test "color in names mode" {
    var buff: [30]u8 = undefined;

    var len = color("Some text", &buff, &[_]u8{@enumToInt(ColorName.red)}, &[0]u8{}, ColorMode.names, false);
    try expect(len == 18);
    try expect(mem.eql(u8, "\x1b[31mSome text\x1b[0m", buff[0..len]));

    len = color_names("Some text", &buff, ColorName.red, null, false);
    try expect(len == 18);
    try expect(mem.eql(u8, "\x1b[31mSome text\x1b[0m", buff[0..len]));

    len = color_names("Some text", &buff, null, ColorName.red, false);
    try expect(len == 18);
    try expect(mem.eql(u8, "\x1b[41mSome text\x1b[0m", buff[0..len]));

    len = color_names("Some text", &buff, ColorName.bright_magenta, ColorName.red, false);
    try expect(len == 23);
    try expect(mem.eql(u8, "\x1b[1;35;41mSome text\x1b[0m", buff[0..len]));
}
