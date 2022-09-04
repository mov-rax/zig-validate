const std = @import("std");

pub const AssertError = struct { desc: []const u8 };

pub const TypeStruct = struct { name: []const u8, info: std.builtin.Type };

pub const ValidationStruct = struct {
    name: []const u8,
    type: type,
};
