const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule(
        "case",
        .{ .source_file = .{ .path = "src/lib.zig" } },
    );

    const lib = b.addStaticLibrary(.{
        .name = "case",
        .root_source_file = .{ .path = "src/c_api.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib.addModule("case", mod);
    lib.linkLibC();
    lib.addIncludePath(.{ .path = "src" });
    b.installArtifact(lib);
    b.getInstallStep().dependOn(
        &b.addInstallHeaderFile("src/case.h", "case.h").step,
    );

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });
    tests.linkLibC();
    tests.addModule("case", mod);
    // needed to keep Case enums in sync between src/lib.zig and src/case.h
    tests.addIncludePath(.{ .path = "src" });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    // zig build test -> run src/test.c
    const c_api_test_exe = b.addExecutable(.{
        .name = "c_api_test",
        .root_source_file = .{ .path = "src/test.c" },
        .target = target,
        .optimize = optimize,
    });
    c_api_test_exe.linkLibC();
    c_api_test_exe.linkLibrary(lib);
    const run_c_api_test = b.addRunArtifact(c_api_test_exe);
    test_step.dependOn(&run_c_api_test.step);
}
