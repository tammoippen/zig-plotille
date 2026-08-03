const std = @import("std");
const json = std.json;

const plt = @import("plotille");
const TermInfo = plt.terminfo.TermInfo;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    try TermInfo.detect(io, init.minimal.environ, allocator);
    const info = TermInfo.get();

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const writer = &stdout_writer.interface;
    defer writer.flush() catch {};
    try writer.print("{f}\n", .{json.fmt(info, .{})});
}
