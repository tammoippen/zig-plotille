const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const plotille = b.dependency("plotille", .{
        .target = target,
        .optimize = mode,
    });
    const exe = b.addExecutable(.{
        .name = "house",
        .root_source_file = b.path("house.zig"),
        .target = target,
        .optimize = mode,
        .version = try std.SemanticVersion.parse("1.0.0"),
    });
    exe.root_module.addImport("plotille", plotille.module("plotille"));
    b.installArtifact(exe);

    const exe_run = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run exe's.");
    run_step.dependOn(&exe_run.step);
}
