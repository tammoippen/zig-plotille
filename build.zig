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

    const build_files = [_][]const u8{"build.zig"};
    const source_files = [_][]const u8{ "src/color.zig", "src/dots.zig", "src/main.zig" };
    const example_files = [_][]const u8{ "src/names_example.zig", "src/lookup_example.zig", "src/hsl_example.zig" };

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

    const example_step = b.step("examples", "Build example exe's.");
    for (example_files) |example| {
        var iter = std.mem.split(std.fs.path.basename(example), ".");
        const exe = b.addExecutable(iter.next().?, example);
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.setOutputDir("zig-out/examples");
        example_step.dependOn(&exe.step);
        // exe.install();

        const exe_run = exe.run();
        example_step.dependOn(&exe_run.step);
    }

    const test_step = b.step("test", "Run library tests");
    for (source_files) |source| {
        const tests = b.addTest(source);
        tests.setBuildMode(mode);
        test_step.dependOn(&tests.step);
    }

    const fmt_step = b.step("fmt", "Format the library.");
    var build_fmt = b.addFmt(&build_files);
    var main_fmt = b.addFmt(&source_files);
    var example_fmt = b.addFmt(&example_files);
    fmt_step.dependOn(&build_fmt.step);
    fmt_step.dependOn(&main_fmt.step);
    fmt_step.dependOn(&example_fmt.step);
}
