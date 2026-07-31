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

    // Build static library by default
    const c_entry = b.path("src/c-api.zig");
    const c_module = b.addModule("plotille-c", .{
        .root_source_file = c_entry,
        .target = target,
        .optimize = mode,
        .strip = strip,
        .link_libc = true,
    });
    const static_lib = b.addLibrary(.{
        .name = name,
        .root_module = c_module,
        .version = version,
        .linkage = .static,
    });
    const installed_static_lib = b.addInstallArtifact(static_lib, .{});
    b.getInstallStep().dependOn(&installed_static_lib.step);

    // Build dynamic library by default (unless static-only is requested)
    const shared_lib = b.addLibrary(.{
        .name = name,
        .root_module = c_module,
        .version = version,
        .linkage = .dynamic,
    });
    const installed_shared_lib = b.addInstallArtifact(shared_lib, .{});
    b.getInstallStep().dependOn(&installed_shared_lib.step);

    const test_step = b.step("test", "Run library tests");
    const tests = b.addTest(.{
        .name = name,
        .root_module = module,
    });
    if (filter) |f| {
        tests.filters = &.{f};
    }
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
}
