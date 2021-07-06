const std = @import("std");

pub fn build(b: *std.build.Builder) void {
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

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    var dots_tests = b.addTest("src/dots.zig");
    dots_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
    test_step.dependOn(&dots_tests.step);

    var main_fmt = b.addFmt(&[_][]const u8{ "build.zig", "src/main.zig", "src/dots.zig" });
    const fmt_step = b.step("fmt", "Format the library.");
    fmt_step.dependOn(&main_fmt.step);
}
