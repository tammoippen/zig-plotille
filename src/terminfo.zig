const std = @import("std");

var info: ?TermInfo = null;


pub const TermInfo = struct {
    stdout_interactive: bool,
    // respect NO_COLOR env var: https://no-color.org/
    no_color: bool,
    // respect FORCE_COLOR env var somewhat: https://nodejs.org/api/tty.html#tty_writestream_getcolordepth_env
    // if set and 0, false or none, same effect as NO_COLOR
    // on all other values force color on (but not the respective kind)
    force_color: ?bool,

    pub fn get() ?TermInfo {
        return info;
    }

    pub fn detect(allocator: *mem.Allocator) !TermInfo {
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
            // try to make lower, if oom, the string is quite large => force_color=true
            const fc_lower = std.ascii.allocLowerString(allocator, force_color_str) catch force_color_str;
            force_color = !(std.mem.eql(u8, fc_lower, "0") or std.mem.eql(u8, fc_lower, "false") or std.mem.eql(u8, fc_lower, "none"));
        }
        fba.reset(); // do not use opt_force_color_str anymore!!!

        info = TermInfo{
            .stdout_interactive = stdout_tty,
            .no_color = no_color,
            .force_color = force_color,
        };

        return info.?;
    }
};
