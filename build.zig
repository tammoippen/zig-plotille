const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zig-plotille", "src/main.zig");
    lib.setTarget(target);
    lib.setBuildMode(mode);
    // lib.emit_h = true;
    lib.install();

    const shared_lib = b.addSharedLibrary("zig-plotille", "src/main.zig", b.version(1, 0, 0));
    shared_lib.setTarget(target);
    shared_lib.setBuildMode(mode);
    // shared_lib.emit_h = true;
    shared_lib.install();

    const test_step = b.step("test", "Run library tests");
    const tests = b.addTest("src/main.zig");
    tests.setBuildMode(mode);
    test_step.dependOn(&tests.step);

    const example_step = b.step("examples", "Build example exe's.");
    const example_names = [_][]const u8{ "names", "lookup", "hsl" };
    inline for (example_names) |example| {
        const exe = b.addExecutable(example, "./examples/" ++ example ++ ".zig");
        exe.addPackagePath("zig-plotille", "src/main.zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();
        example_step.dependOn(&exe.step);

        const exe_run = exe.run();
        example_step.dependOn(&exe_run.step);
        if (std.mem.eql(u8, example, "hsl")) {
            const ranges = exe.run();
            const ranges_args = [_][]const u8{ "45", "90" };
            ranges.addArgs(&ranges_args);
            example_step.dependOn(&ranges.step);

            const short = exe.run();
            const short_args = [_][]const u8{ "--short", "0", "45", "90", "135", "180", "225", "270", "315", "360" };
            short.addArgs(&short_args);
            example_step.dependOn(&short.step);
        }
    }
}
