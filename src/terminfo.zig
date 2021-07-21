const std = @import("std");

var info: ?TermInfo = null;

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
        };
    }

    pub fn detect(allocator: *std.mem.Allocator) !void {
        const stdout_tty = std.io.getStdOut().isTty();

        // on windows needs allocator to put key into utf16
        // free on its own
        const no_color = std.process.hasEnvVar(allocator, "NO_COLOR") catch unreachable;

        // on issues, ignore force_color
        const opt_force_color_str = std.process.getEnvVarOwned(allocator, "FORCE_COLOR") catch |err| switch(err) {
            error.EnvironmentVariableNotFound => null,
            else => return err,
        };

        var force_color: ?bool = null;
        if (opt_force_color_str) |force_color_str| {
            defer allocator.free(force_color_str);
            const fc_lower = try std.ascii.allocLowerString(allocator, force_color_str);
            force_color = !(std.mem.eql(u8, fc_lower, "0") or std.mem.eql(u8, fc_lower, "false") or std.mem.eql(u8, fc_lower, "none"));
        }

        info = TermInfo{
            .stdout_tty = stdout_tty,
            .no_color = no_color,
            .force_color = force_color,
        };
    }
};
