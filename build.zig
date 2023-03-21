const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
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
    const emit_h = b.option(bool, "emit-h", "Generate a C header file (.h)") orelse false;
    const filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter");

    const name = "zig-plotille";
    const entry = "src/main.zig";
    const version = try std.builtin.Version.parse("1.0.0");
    const module = b.addModule(name, .{ .source_file = .{ .path = entry } });

    if (!dynamic) {
        const lib = b.addStaticLibrary(.{
            .name = name,
            .root_source_file = .{ .path = entry },
            .target = target,
            .optimize = mode,
            .version = version,
        });
        lib.strip = strip;
        lib.emit_h = emit_h;
        lib.install();
    } else {
        const shared_lib = b.addSharedLibrary(.{
            .name = name,
            .root_source_file = .{ .path = entry },
            .target = target,
            .optimize = mode,
            .version = version,
        });
        shared_lib.strip = strip;
        shared_lib.emit_h = emit_h;
        shared_lib.install();
    }

    const test_step = b.step("test", "Run library tests");
    const tests = b.addTest(.{
        .name = name,
        .root_source_file = .{ .path = entry },
        .target = target,
        .optimize = mode,
        .version = version,
    });
    tests.strip = strip;
    tests.setFilter(filter);
    test_step.dependOn(&tests.step);

    const example_step = b.step("examples", "Build example exe's.");
    const example_run_step = b.step("run", "Run example exe's.");
    example_run_step.dependOn(example_step);
    const example_names = [_][]const u8{ "names", "lookup", "hsl", "terminfo", "house", "hist" };
    inline for (example_names) |example| {
        const exe = b.addExecutable(.{
            .name = example,
            .root_source_file = .{ .path = "./examples/" ++ example ++ ".zig" },
            .target = target,
            .optimize = mode,
            .version = version,
        });
        // exe.addPackagePath(name, entry);
        exe.addModule(name, module);
        exe.strip = strip;
        example_step.dependOn(&exe.step);
        example_step.dependOn(&b.addInstallArtifact(exe).step);

        const exe_run = exe.run();
        example_run_step.dependOn(&exe_run.step);
        if (std.mem.eql(u8, example, "hsl")) {
            const ranges = exe.run();
            const ranges_args = [_][]const u8{ "45", "90" };
            ranges.addArgs(&ranges_args);
            example_run_step.dependOn(&ranges.step);

            const short = exe.run();
            const short_args = [_][]const u8{ "--short", "0", "45", "90", "135", "180", "225", "270", "315", "360" };
            short.addArgs(&short_args);
            example_run_step.dependOn(&short.step);
        }
    }
}
