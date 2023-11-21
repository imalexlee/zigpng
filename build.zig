const Build = @import("std").Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("zigpng", .{
        .source_file = .{ .path = "zigpng.zig" },
    });

    const zigpng_build_test = b.addTest(.{
        .name = "zigpng_tests",
        .root_source_file = .{ .path = "zigpng.zig" },
        .target = target,
        .optimize = optimize,
    });

    zigpng_build_test.linkLibC();
    zigpng_build_test.linkSystemLibrary("z");
    b.installArtifact(zigpng_build_test);

    const run_test_cmd = b.addRunArtifact(zigpng_build_test);

    // Force running of the test command even if you don't have changes
    run_test_cmd.has_side_effects = true;
    run_test_cmd.step.dependOn(b.getInstallStep());

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_test_cmd.step);

    const build_only_test_step = b.step("test_build_only", "Build the tests but does not run it");
    build_only_test_step.dependOn(&zigpng_build_test.step);
    build_only_test_step.dependOn(b.getInstallStep());
}
