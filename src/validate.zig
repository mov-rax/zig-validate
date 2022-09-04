const std = @import("std");
const ansi = @import("ansi.zig");
const utils = @import("utils.zig");

/// ### Comptime validation of `Target` type by a `Validator` Type.
/// #### Returns a type containing decls from both types.
/// If validation fails, a comptimeError will occur with a descriptive error message on how 
/// the `Target` fails to conform to the `Validator`.
///
/// Requirements for the `Target` type is defined in `Validator` like the following:
///
/// ```zig 
/// const _funcName = (fn (*@This()) OutputType);
/// ```
/// Function name requirements can be prefixed by _ to avoid namespacing abiguity when
/// using the output type.
/// 
/// Function implementations can also be added to the `Validator` to be used at the 
/// output type.
/// 
/// The following is an example of a generic Validator and a Target and verifying it:
/// ```zig
/// pub fn Validator(comptime T: type) type {
///     return struct{
///         pub const _calc = (*T, i32, i32) i32;
///         pub const _gfunc = (*T, T.Item, T.Item) T.Item;
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
/// const Validated = ValidateWith(Target, Validator(Target));
/// ```
///
/// For more examples see `validateTests.zig`
pub fn ValidateWith(
    comptime Target: type, 
    comptime Validator: type) type {

    const target = utils.colors.target;
    const validator = utils.colors.validator;
    const normal = utils.colors.normal;
    var extractedT = utils.extract(Target, false);
    var extractedV = utils.extract(Validator, true);
    var errors: []const utils.types.AssertError = &.{};
    for (extractedV) |req| {
        //@compileError(std.fmt.comptimePrint("{any}", .{req.info}));
        errors = errors ++ utils.assertIsConforming(.{
            .name = @typeName(Validator),
            .type = Validator
        }, 
        .{
            .name = @typeName(Target),
            .type = Target
        },
        req, extractedT);
    } 
    if (errors.len != 0) {
        var res: []const u8 = std.fmt.comptimePrint(
            target("`{s}`") ++ normal(" does not conform to ") ++ validator("`{s}`") ++ "\n", 
            .{@typeName(Target), @typeName(Validator)});
        for (errors) |err, i| {
            res = res 
                ++ target(std.fmt.comptimePrint("{}:", .{i+1}))
                ++ "\n" ++ err.desc ++ "\n";
        }
        @compileError(res);
    }
    return struct{
        pub usingnamespace Target;
        pub usingnamespace Validator;
    };
}