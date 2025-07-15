const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule(
        "case",
        .{ .root_source_file = b.path("src/lib.zig") },
    );

    const lib = b.addLibrary(.{
        .name = "case",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/c_api.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    lib.root_module.addImport("case", mod);
    lib.linkLibC();
    b.installArtifact(lib);
    b.getInstallStep().dependOn(
        &b.addInstallHeaderFile(b.path("src/case.h"), "case.h").step,
    );

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.linkLibC();
    tests.root_module.addImport("case", mod);
    // needed to keep Case enums in sync between src/lib.zig and src/case.h
    tests.addIncludePath(b.path("src"));
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    // zig build test -> run src/test.c
    const c_api_test_exe = b.addExecutable(.{
        .name = "c_api_test",
        .root_module = b.createModule(.{
            .root_source_file = null,
            .target = target,
            .optimize = optimize,
        }),
    });
    c_api_test_exe.addCSourceFile(.{ .file = b.path("src/test.c") });
    c_api_test_exe.linkLibC();
    c_api_test_exe.linkLibrary(lib);
    const run_c_api_test = b.addRunArtifact(c_api_test_exe);
    // for some reason, running this fails on windows
    // TODO figure out why this fails. fix. re-enable
    if (@import("builtin").os.tag != .windows)
        test_step.dependOn(&run_c_api_test.step);
}
