const std = @import("std");
const json = std.json;

const plt = @import("zig-plotille");
const TermInfo = plt.terminfo.TermInfo;

pub fn main() !void {
    // I use this example for testing, hence provide a testing allocator
    try TermInfo.detect(std.testing.allocator);
    const info = TermInfo.get();

    const writer = std.io.getStdOut().writer();
    try json.stringify(info, .{}, writer);
    try writer.writeByte('\n');
}
