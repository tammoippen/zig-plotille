const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const plotille = b.dependency("plotille", .{
        .target = target,
        .optimize = mode,
    });

    const example_names = [_][]const u8{ "names", "lookup", "hsl", "terminfo", "hist", "house" };
    const run_step = b.step("run", "Run exe.");
    inline for (example_names) |example| {
        const exe = b.addExecutable(.{
            .name = example,
            .root_source_file = b.path(example ++ ".zig"),
            .target = target,
            .optimize = mode,
            .version = try std.SemanticVersion.parse("1.0.0"),
        });
        exe.root_module.addImport("plotille", plotille.module("plotille"));
        b.installArtifact(exe);
        const exe_run = b.addRunArtifact(exe);
        run_step.dependOn(&exe_run.step);

        if (std.mem.eql(u8, example, "hsl")) {
            const ranges = b.addRunArtifact(exe);
            const ranges_args = [_][]const u8{ "45", "90" };
            ranges.addArgs(&ranges_args);
            run_step.dependOn(&ranges.step);

            const short = b.addRunArtifact(exe);
            const short_args = [_][]const u8{ "--short", "0", "45", "90", "135", "180", "225", "270", "315", "360" };
            short.addArgs(&short_args);
            run_step.dependOn(&short.step);
        }
    }
}
