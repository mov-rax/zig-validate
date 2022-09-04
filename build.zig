const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zig-validate", "src/validate.zig");
    lib.setBuildMode(mode);
    lib.install();

    const validate_tests = b.addTest("src/validate.zig");
    validate_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&validate_tests.step);

    const docs = b.addTest("src/lib.zig");
    docs.emit_docs = .emit;

    const docs_step = b.step("docs", "Generate docs");
    docs_step.dependOn(&docs.step);
}
