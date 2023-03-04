const std = @import("std");
const ansi = @import("ansi.zig");
pub const utils = @import("utils.zig");
pub const defaults = @import("defaults.zig");

/// ### Comptime validation of `Target` type by a `Validator` Type.
/// #### Returns a type containing decls from both types.
/// If validation fails, a comptimeError will occur with a descriptive error message on how
/// the `Target` fails to conform to the `Validator`.
///
/// Requirements for the `Target` type is defined in `Validator` like the following:
///
/// ```zig
/// const funcName = (fn (*@This()) OutputType);
/// ```
///
/// Function implementations can also be added to the `Validator` to be used at the
/// output type.
///
/// The following is an example of a generic Validator and a Target and verifying it:
/// ```zig
/// pub fn Validator(comptime T: type) type {
///     return struct{
///         pub const calc = (*T, i32, i32) i32;
///         pub const gfunc = (*T, T.Item, T.Item) T.Item;
///         pub fn validatorFunction(self: *T, a: T.Item, b: T.Item) T.Item {
///             return T.gfunc(a, b);
///         }
///     };
/// }
/// pub const Target = struct{
///     pub const Item = i32;
///     pub fn calc(self: *@Self(), a: i32, b: i32) i32 {
///         return a * a + b * b;
///     }
///     pub fn gfunc(self: *@This(), a: Item, b: Item) Item {
///         return a + b;
///     }
/// };
///
/// const Validated = static(Target, Validator(Target));
/// ```
///
///
/// For more examples see `validateTests.zig`
pub fn static(comptime Target: type, comptime Validator: type) genStruct(Target, Validator) {
    comptime {
        const target = utils.colors.target;
        const validator = utils.colors.validator;
        const normal = utils.colors.normal;
        var extractedT = utils.extract(Target, .target);
        var extractedV = utils.extract(Validator, .validator);
        var errors: []const utils.types.AssertError = &.{};
        if (std.meta.fields(Validator).len > 0)
            @compileError(validator("`" ++ @typeName(Validator) ++ "`") ++ normal(" is an invalid Validator due to the number of fields being nonzero."));
        for (extractedV) |req| {
            errors = errors ++ utils.assertIsConforming(.{ .name = @typeName(Validator), .type = Validator }, .{ .name = @typeName(Target), .type = Target }, req, extractedT);
        }
        if (errors.len != 0) {
            var res: []const u8 = std.fmt.comptimePrint(target("`{s}`") ++ normal(" does not conform to ") ++ validator("`{s}`") ++ "\n", .{ @typeName(Target), @typeName(Validator) });
            for (errors, 0..) |err, i| {
                res = res ++ target(std.fmt.comptimePrint("{}:", .{i + 1})) ++ "\n" ++ err.desc ++ "\n";
            }
            @compileError(res);
        }
        return genStruct(Target, Validator){};
    }
}

pub fn wrapped(comptime Target: type, comptime wrappers: []const defaults.DefaultWrappers) type {
    for (wrappers) |w| {
        if (w.Type.checkType(Target))
            return w.Wrapper(Target);
    }
    return Target;
}

pub fn static2(comptime Target: type, comptime Validator: type, comptime wrappers: []const defaults.DefaultWrappers) genStruct(wrapped(Target, wrappers), Validator) {
    return static(wrapped(Target, wrappers), Validator);
}

/// Similar to ValidateWith, however with the following additions/changes:
/// - Declarations within Target and Validator are merged into a single comptime struct
/// - Function overloading supported. (any function in Validator can get overloaded by a similarly-named on in Target).
/// - All declarations are turned into comptime fields as a result.
pub fn staticFnOverride(comptime Target: type, comptime Validator: type) utils.StructMerge(Validator, Target) {
    comptime {
        _ = static(Target, Validator);
        return utils.StructMerge(Validator, Target){};
    }
}

pub fn dynamic(comptime VTable: type, comptime Implementation: type) VTable {
    comptime {
        const vt = utils.colors.target;
        const impl = utils.colors.validator;
        const normal = utils.colors.normal;
        var extractedVT = utils.extract(VTable, .vtable);
        var extractedI = utils.extract(Implementation, .target);
        var errors: []const utils.types.AssertError = &.{};
        if (std.meta.fields(Implementation).len > 0)
            @compileError(impl("`" ++ @typeName(Implementation) ++ "`") ++ normal(" is an invalid VTable implementation due to the number of fields being nonzero."));
        for (extractedVT) |req| {
            errors = errors ++ utils.assertIsConforming(.{ .name = @typeName(VTable), .type = VTable }, .{ .name = @typeName(Implementation), .type = Implementation }, req, extractedI);
        }
        if (errors.len != 0) {
            var res: []const u8 = std.fmt.comptimePrint(impl("`{s}`") ++ normal(" does not conform to ") ++ vt("`{s}`") ++ "\n", .{ @typeName(Implementation), @typeName(VTable) });
            for (errors, 0..) |err, i| {
                res = res ++ impl(std.fmt.comptimePrint("{}:", .{i + 1})) ++ "\n" ++ err.desc ++ "\n";
            }
            @compileError(res);
        }
        return utils.vtableify(VTable, Implementation);
    }
}

pub fn ValidationResult(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: []const u8,
    };
}

pub fn staticTesting(comptime Target: type, comptime Validator: type) ValidationResult(genStruct(Target, Validator)) {
    comptime {
        const target = utils.colors.target;
        const validator = utils.colors.validator;
        const normal = utils.colors.normal;
        var extractedT = utils.extract(Target, .target);
        var extractedV = utils.extract(Validator, .validator);
        var errors: []const utils.types.AssertError = &.{};
        if (std.meta.fields(Validator).len > 0)
            @compileError(validator("`" ++ @typeName(Validator) ++ "`") ++ normal(" is an invalid Validator due to the number of fields being nonzero."));
        for (extractedV) |req| {
            errors = errors ++ utils.assertIsConforming(.{ .name = @typeName(Validator), .type = Validator }, .{ .name = @typeName(Target), .type = Target }, req, extractedT);
        }
        if (errors.len != 0) {
            var res: []const u8 = std.fmt.comptimePrint(target("`{s}`") ++ normal(" does not conform to ") ++ validator("`{s}`") ++ "\n", .{ @typeName(Target), @typeName(Validator) });
            for (errors, 0..) |err, i| {
                res = res ++ target(std.fmt.comptimePrint("{}:", .{i + 1})) ++ "\n" ++ err.desc ++ "\n";
            }
            return .{ .err = res };
        }
        return .{ .ok = genStruct(Target, Validator){} };
    }
}

fn genStruct(comptime T: type, comptime V: type) type {
    return struct {
        comptime Target: type = T,
        comptime Validator: type = V,
    };
}
