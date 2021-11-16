pub const line_separator = if (@import("builtin").target.os.tag == .windows) "\r\n" else "\n";
