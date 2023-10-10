const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.build.Builder) void {
    
    comptime {
        const current_zig = builtin.zig_version;
        const min_zig = std.SemanticVersion.parse("0.11.0-dev.1836+28364166e") catch return;
        if (current_zig.order(min_zig) == .lt) {
            @compileError(std.fmt.comptimePrint("Your zig version ({}) does not meet the minimum requirement ({}) to run zig-validate.", .{current_zig, min_zig}));
        }
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("zig-validate", .{
        .source_file = .{ .path = "src/lib.zig" },
        .dependencies = &[_]std.Build.ModuleDependency{},
    });

    const lib = b.addStaticLibrary(.{
        .name = "zig-validate",
        .root_source_file = .{.path = "src/validate.zig"},
        .target = target,
        .optimize = optimize,
        .version = .{
            .major = 0,
            .minor = 1,
            .patch = 0,
        },
    });
    lib.install();

    const validate_tests = b.addTest(.{
        .name = "validate tests",
        .root_source_file = .{.path = "src/validateTests.zig"}
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&validate_tests.step);

    const docs = b.addTest(.{
        .name = "docs",
        .root_source_file = .{.path = "src/lib.zig"}});
    docs.emit_docs = .emit;

    const docs_step = b.step("docs", "Generate docs");
    docs_step.dependOn(&docs.step);
}
