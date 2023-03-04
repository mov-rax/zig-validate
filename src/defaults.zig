const std = @import("std");
const colors = @import("colors.zig");

// Subset of std.builtin.Type that is used for default functionality in static dispatch
// Requires a `type` that holds a validator that provides functionality.
const GenericType = union(enum) {
    none,
    /// Numbers
    /// Any integral or float type
    number,
    /// Any float type
    float,
    /// Any integral type
    integer,
    /// Any signed integral type
    signedInteger,
    /// Any unsigned integral type
    unsignedInteger,
    /// Any boolean type
    bool,
    other: type,
    // Other (not yet implemented.)
    // pointer,
    // array,
    // vector,
    // optional,
    // @"enum",
    // enumLiteral,
    // @"union",
    // @"fn",
    // @"error",
    // errorUnion,
    // errorSet,
    // @"opaque",
    // frame,
    // anyFrame,

    pub fn checkType(comptime self: @This(), comptime T: type) bool {
        switch (self) {
            .none => {
                return false;
            },
            .number => {
                return std.meta.trait.isNumber(T);
            },
            .float => {
                return std.meta.trait.isFloat(T);
            },
            .integer => {
                return std.meta.trait.isIntegral(T);
            },
            .signedInteger => {
                return std.meta.trait.isSignedInt(T);
            },
            .unsignedInteger => {
                return std.meta.trait.isUnsignedInt(T);
            },
            .bool => {
                return (T == bool) or (T == u1);
            },
            .other => |t| {
                return t == T;
            },
        }
    }
};

pub const DefaultWrappers = struct {
    Type: GenericType = .none,
    Wrapper: (fn (type) type),
};

pub fn genUnwrapper(T: type, WrapperT: type, field: @Type(.EnumLiteral)) fn (anytype) T {
    comptime {
        if (!@hasField(WrapperT, @tagName(field))) {
            @compileError(std.fmt.comptimePrint(colors.target("{s}") ++ colors.normal(" does not have the field ") ++ colors.validator("'{s}'"), .{ @typeName(WrapperT), @tagName(field) }));
        }
    }
    return struct {
        pub fn func(val: anytype) T {
            const V = @TypeOf(val);
            if (comptime T == V) {
                return val;
            } else if (comptime WrapperT == V) {
                return @field(val, @tagName(field));
            } else {
                @compileError(colors.normal("Expected type ") ++ colors.target(@typeName(T)) ++ colors.normal(" or a wrapper type ") ++ colors.target(@typeName(WrapperT)));
            }
        }
    }.func;
}

pub fn Number(T: type) type {
    return struct {
        const Self = @This();
        const unwrap = genUnwrapper(T, Self, .val);
        val: T,

        pub fn add(self: Self, other: anytype) @This() {
            return Self{ .val = self.val + unwrap(other) };
        }

        pub fn sub(self: Self, other: anytype) @This() {
            return Self{ .val = self.val - unwrap(other) };
        }

        pub fn mul(self: Self, other: anytype) @This() {
            return Self{ .val = self.val * unwrap(other) };
        }

        pub fn div(self: Self, other: anytype) @This() {
            return Self{ .val = self.val / unwrap(other) };
        }
    };
}
//
// var oof = static(input, SomeValidator, .{
//    .Type = .number,
//    .Wrapper = someWrappingTypeFunction
// })
//
