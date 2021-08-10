const std = @import("std");

pub const line_separator = if (std.Target.current.os.tag == std.Target.Os.Tag.windows) "\r\n" else "\n";
