const std = @import("std");
const color = @import("./color.zig");

var info: ?TermInfo = null;

const rgb_termprogs = [_][]const u8{
    "hyper", "wezterm", "vscode"
};
const lookup_termprogs = [_][]const u8{
    "apple_terminal"
};


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
    suggested_color_mode: ?color.ColorMode,

    pub fn get() TermInfo {
        return info orelse @panic("You have to initialize the TermInfo with either `set` or `detect`") ;
    }

    pub fn set(terminfo: TermInfo) void {
        info = terminfo;
    }

    pub fn testing() void {
        // set, such that colors will always be printed
        info = TermInfo{
            .no_color = false,
            .force_color = true,
            .stdout_tty = true,
            .suggested_color_mode = null,
        };
    }

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
        const opt_force_color_str = std.process.getEnvVarOwned(allocator, "FORCE_COLOR") catch |err| switch(err) {
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
    fn getColorMode(allocator: *std.mem.Allocator) !?color.ColorMode {
        if (isWindowsTerminal(allocator) or isDomTerm(allocator)) {
            std.debug.print("win/dom term\n", .{});
            return .rgb;
        }

        // TODO: COLORTERM

        const opt_termprogram = try getTermProgram(allocator);
        if (opt_termprogram) |termprogram| {
            defer allocator.free(termprogram);
            for (rgb_termprogs) |name| {
                if (std.mem.eql(u8, name, termprogram)) {
                    std.debug.print("term rgb: {s}\n", .{termprogram});
                    return .rgb;
                }
            }
            for (lookup_termprogs) |name| {
                if (std.mem.eql(u8, name, termprogram)) {
                    std.debug.print("term lookup: {s}\n", .{termprogram});
                    return .rgb;
                }
            }
            // TODO: iterm => lookup , iterm >=3 => rgb via TERM_PROGRAM_VERSION
        }

        return null;
    }
    /// free on its own
    fn isWindowsTerminal(allocator: *std.mem.Allocator) bool {
        // on windows needs allocator to put key into utf16
        // https://github.com/microsoft/terminal/issues/1040#issuecomment-496691842
        return std.process.hasEnvVar(allocator, "WT_SESSION") catch unreachable;
    }
    /// free on its own
    fn isDomTerm(allocator: *std.mem.Allocator) bool {
        // on windows needs allocator to put key into utf16
        // https://domterm.org/Detecting-domterm-terminal.html
        return std.process.hasEnvVar(allocator, "DOMTERM") catch unreachable;
    }
    /// free returned string
    fn getTermProgram(allocator: *std.mem.Allocator) !?[]const u8 {
        const term_program = std.process.getEnvVarOwned(allocator, "TERM_PROGRAM") catch |err| switch(err) {
            error.EnvironmentVariableNotFound => null,
            else => return err,
        };
        if (term_program) |tp| {
            defer allocator.free(tp);
            return try std.ascii.allocLowerString(allocator, tp);
        }
        return null;
    }
};
