const std = @import("std");
const ascii = std.ascii;
const assert = std.debug.assert;
const mem = std.mem;

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
        mem.copy(u8, text, out);
        return text.len;
    }

    if (no_color) { // or os.environ.get('NO_COLOR'))
        mem.copy(u8, text, out);
        return text.len;
    }

    if (mode == ColorMode.names) {
        const start_len = names(fg, bg, out);
        return start_len;
    }
    mem.copy(u8, text, out);
    return text.len;
}

const FGColorName = enum(u8) {
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,
    // bright_black = 1;30,
    // bright_red = 1;31,
    // bright_green = 1;32,
    // bright_yellow = 1;33,
    // bright_blue = 1;34,
    // bright_magenta = 1;35,
    // bright_cyan = 1;36,
    // bright_white = 1;37,
};

const BGColorName = enum(u8) {
    black = 40,
    red = 41,
    green = 42,
    yellow = 43,
    blue = 44,
    magenta = 45,
    cyan = 46,
    white = 47,
    bright_black = 100,
    bright_red = 101,
    bright_green = 102,
    bright_yellow = 103,
    bright_blue = 104,
    bright_magenta = 105,
    bright_cyan = 106,
    bright_white = 107,
};

fn names(fg: []const u8, bg: []const u8, out: []u8) usize {
    assert(fg.len <= 1);
    assert(bg.len <= 1);
    assert(bg.len + fg.len >= 1);

    return 0;
}
