// Kudos to ajalt/mordant for the initial research!
// https://github.com/ajalt/mordant/blob/master/mordant/src/commonMain/kotlin/com/github/ajalt/mordant/terminal/TerminalDetection.kt

const std = @import("std");
const color = @import("./color.zig");

var info: ?TermInfo = null;

const rgb_termprogs = [_][]const u8{ "hyper", "wezterm", "vscode" };
const lookup_termprogs = [_][]const u8{"apple_terminal"};
const rgb_level = [_][]const u8{ "24bit", "24bits", "direct", "truecolor" };
const lookup_level = [_][]const u8{ "256", "256color", "256colors" };
const rgb_term = [_][]const u8{"alacritty"};
const lookup_term = [_][]const u8{
// TODO: on win 10, cygwin supports .rgb
"cygwin"};
const names_term = [_][]const u8{ "xterm", "vt100", "vt220", "screen", "color", "linux", "ansi", "rxvt", "konsole" };

pub const TermInfo = struct {
    // whether stdout is a tty / is interactive
    // if is false, then we probably pipe or
    // redirect into a file
    stdout_tty: bool,
    // respect NO_COLOR env var: https://no-color.org/
    no_color: bool,
    // respect FORCE_COLOR env var somewhat: https://nodejs.org/api/tty.html#tty_writestream_getcolordepth_env
    // if set and 0, false or none, same effect as NO_COLOR
    // on all other values force color on (but not the respective kind)
    force_color: ?bool,
    suggested_color_mode: color.ColorMode,

    /// Get the 'cached' TermInfo. Set via `set(...)` or `detect(...)` beforehand.
    pub fn get() TermInfo {
        return info orelse @panic("You have to initialize the TermInfo with either `set(...)` or `detect(...)`");
    }

    /// Set your own TermInfo for testing, forcing color on / off.
    pub fn set(terminfo: TermInfo) void {
        info = terminfo;
    }

    /// Shorthand set-call, such that colors will always be printed.
    pub fn testing() void {
        info = TermInfo{
            .no_color = false,
            .force_color = true,
            .stdout_tty = true,
            .suggested_color_mode = .rgb,
        };
    }

    /// Read out environment variables, hence the allocator.
    pub fn detect(allocator: *std.mem.Allocator) !void {
        const stdout_tty = std.io.getStdOut().isTty();
        const no_color = isNoColorSet(allocator);
        const force_color = try forceColors(allocator);
        const color_mode = try getColorMode(allocator);

        info = TermInfo{
            .stdout_tty = stdout_tty,
            .no_color = no_color,
            .force_color = force_color,
            .suggested_color_mode = color_mode,
        };
    }

    /// free on its own
    fn isNoColorSet(allocator: *std.mem.Allocator) bool {
        // on windows needs allocator to put key into utf16
        // https://no-color.org/
        return std.process.hasEnvVar(allocator, "NO_COLOR") catch unreachable;
    }
    /// free on its own
    fn forceColors(allocator: *std.mem.Allocator) !?bool {
        // https://nodejs.org/api/tty.html#tty_writestream_getcolordepth_env
        var force_color: ?bool = null;

        // on issues, ignore force_color
        const opt_force_color_str = std.process.getEnvVarOwned(allocator, "FORCE_COLOR") catch |err| switch (err) {
            error.EnvironmentVariableNotFound => null,
            else => return err,
        };

        if (opt_force_color_str) |force_color_str| {
            defer allocator.free(force_color_str);
            const fc_lower = try std.ascii.allocLowerString(allocator, force_color_str);
            force_color = !(std.mem.eql(u8, fc_lower, "0") or std.mem.eql(u8, fc_lower, "false") or std.mem.eql(u8, fc_lower, "none"));
        }
        return force_color;
    }
    /// free on its own
    fn getColorMode(allocator: *std.mem.Allocator) !color.ColorMode {
        if (isWindowsTerminal(allocator) or isDomTerm(allocator) or isKittyTerm(allocator)) {
            return .rgb;
        }

        const opt_colorterm = try getEnvVar(allocator, "COLORTERM");
        if (opt_colorterm) |colorterm| {
            defer allocator.free(colorterm);
            for (rgb_level) |rgb_lvl| {
                if (std.mem.eql(u8, colorterm, rgb_lvl)) {
                    return .rgb;
                }
            }
        }

        const opt_termprogram = try getEnvVar(allocator, "TERM_PROGRAM");
        if (opt_termprogram) |termprogram| {
            defer allocator.free(termprogram);
            for (rgb_termprogs) |name| {
                if (std.mem.eql(u8, name, termprogram)) {
                    return .rgb;
                }
            }
            if (std.mem.eql(u8, "iterm.app", termprogram)) {
                return try checkiTerm(allocator);
            }
            for (lookup_termprogs) |name| {
                if (std.mem.eql(u8, name, termprogram)) {
                    return .lookup;
                }
            }
            // TODO: iterm => lookup , iterm >=3 => rgb via TERM_PROGRAM_VERSION
        }

        const opt_term = try getEnvVar(allocator, "TERM");
        if (opt_term) |term| {
            defer allocator.free(term);

            var iter = std.mem.split(term, "-");
            const opt_term_part = iter.next();
            const opt_level_part = if (opt_term_part != null) iter.next() else null;

            if (opt_level_part) |level_part| {
                for (rgb_level) |rgb_lvl| {
                    if (std.mem.eql(u8, level_part, rgb_lvl)) {
                        return .rgb;
                    }
                }
                for (lookup_level) |lookup_lvl| {
                    if (std.mem.eql(u8, level_part, lookup_lvl)) {
                        return .lookup;
                    }
                }
            }

            if (opt_term_part) |term_part| {
                for (rgb_term) |rgb_t| {
                    if (std.mem.eql(u8, term_part, rgb_t)) {
                        return .rgb;
                    }
                }
                for (lookup_term) |lookup_t| {
                    if (std.mem.eql(u8, term_part, lookup_t)) {
                        return .lookup;
                    }
                }
                for (names_term) |names_t| {
                    if (std.mem.eql(u8, term_part, names_t)) {
                        return .names;
                    }
                }
            }
        }

        return .none;
    }
    /// free on its own
    fn isWindowsTerminal(allocator: *std.mem.Allocator) bool {
        // on windows needs allocator to put key into utf16
        // https://github.com/microsoft/terminal/issues/1040#issuecomment-496691842
        const opt_wt_session = std.process.getEnvVarOwned(allocator, "WT_SESSION") catch |err| switch (err) {
            error.EnvironmentVariableNotFound => null,
            // oom or utf8 errors, hence var is set and more than on char
            else => return true,
        };
        if (opt_wt_session) |wt_session| {
            defer allocator.free(wt_session);
            return wt_session.len > 0;
        } else {
            return false;
        }
    }
    /// free on its own
    fn isDomTerm(allocator: *std.mem.Allocator) bool {
        // on windows needs allocator to put key into utf16
        // https://domterm.org/Detecting-domterm-terminal.html
        return std.process.hasEnvVar(allocator, "DOMTERM") catch unreachable;
    }
    /// free on its own
    fn isKittyTerm(allocator: *std.mem.Allocator) bool {
        // on windows needs allocator to put key into utf16
        // https://github.com/kovidgoyal/kitty/issues/957#issuecomment-420318828
        return std.process.hasEnvVar(allocator, "KITTY_WINDOW_ID") catch unreachable;
    }
    /// free on its own
    /// assumes that TERM_PROGRAM lower == iterm.app
    fn checkiTerm(allocator: *std.mem.Allocator) !color.ColorMode {
        const opt_version = try getEnvVar(allocator, "TERM_PROGRAM_VERSION");
        if (opt_version) |version| {
            defer allocator.free(version);
            // get major version
            var iter = std.mem.split(version, ".");
            const first = iter.next();
            if (first) |major_str| {
                const major = try std.fmt.parseUnsigned(u8, major_str, 10);
                if (major >= 3) {
                    return .rgb;
                }
            }
        }
        return .lookup;
    }
    /// free returned string
    /// Get optional and lowercase string.
    fn getEnvVar(allocator: *std.mem.Allocator, name: []const u8) !?[]const u8 {
        const opt_value = std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
            error.EnvironmentVariableNotFound => null,
            else => return err,
        };
        if (opt_value) |value| {
            defer allocator.free(value);
            return try std.ascii.allocLowerString(allocator, value);
        }
        return null;
    }
};

test "detect frees memory" {
    try TermInfo.detect(std.testing.allocator);
    _ = TermInfo.isNoColorSet(std.testing.allocator);
    _ = try TermInfo.forceColors(std.testing.allocator);
    _ = try TermInfo.getColorMode(std.testing.allocator);
    _ = TermInfo.isWindowsTerminal(std.testing.allocator);
    _ = TermInfo.isDomTerm(std.testing.allocator);
    _ = TermInfo.isKittyTerm(std.testing.allocator);
    _ = try TermInfo.checkiTerm(std.testing.allocator);
    const opt_term = try TermInfo.getEnvVar(std.testing.allocator, "TERM");
    if (opt_term) |term| {
        defer std.testing.allocator.free(term);
    }
}

// other tests via examples/terminfo.zig and examples/test_terminfo.py
