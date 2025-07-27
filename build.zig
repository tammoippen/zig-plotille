const std = @import("std");

pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardOptimizeOption(.{});

    const strip = b.option(bool, "strip", "Omit debug symbols") orelse false;
    const dynamic = b.option(bool, "dynamic", "Force output to be dynamically linked") orelse false;
    // const emit_h = b.option(bool, "emit-h", "Generate a C header file (.h)") orelse false;
    const filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter");

    const name = "plotille";
    const entry = b.path("src/main.zig");
    const version = try std.SemanticVersion.parse("0.0.1");
    const module = b.addModule(name, .{
        .root_source_file = entry,
        .target = target,
        .optimize = mode,
        .strip = strip,
    });

    if (!dynamic) {
        const lib = b.addStaticLibrary(.{
            .name = name,
            .root_module = module,
            .version = version,
        });
        const installed_lib = b.addInstallArtifact(lib, .{});
        // installed_lib.emitted_h = lib.getEmittedH();
        b.getInstallStep().dependOn(&installed_lib.step);
    } else {
        const lib = b.addSharedLibrary(.{
            .name = name,
            .root_module = module,
            .version = version,
        });
        const installed_lib = b.addInstallArtifact(lib, .{});
        // installed_lib.emitted_h = lib.getEmittedH();
        b.getInstallStep().dependOn(&installed_lib.step);
    }

    const test_step = b.step("test", "Run library tests");
    const tests = b.addTest(.{
        .name = name,
        .root_module = module,
        .filter = filter,
    });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
}
