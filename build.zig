const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("zig_memory", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    _ = mod;

    const test_step = b.step("test", "Run library tests");

    addTest(b, test_step, "root", "src/root.zig", target, optimize);
    addTest(b, test_step, "shared_ptr", "src/shared_ptr.zig", target, optimize);
    addTest(b, test_step, "atomic_shared_ptr", "src/atomic_shared_ptr.zig", target, optimize);
    addTest(b, test_step, "deleter", "src/deleter.zig", target, optimize);
    addTest(b, test_step, "example", "src/example.zig", target, optimize);
}

fn addTest(
    b: *std.Build,
    test_step: *std.Build.Step,
    name: []const u8,
    path: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const tests = b.addTest(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
        }),
    });

    test_step.dependOn(&b.addRunArtifact(tests).step);
}
